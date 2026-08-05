# Hang Diagnosis — How to Detect and Fix a Hung llama-server Backend

## The Symptom

A `llama-server` child process is:
- ✅ Running (`ps aux | grep llama-server` shows it)
- ✅ Listening (`ss -tlnp | grep <port>` shows `LISTEN` state)
- ✅ Allocated in GPU memory (`rocm-smi` or `nvidia-smi` shows VRAM usage)
- ❌ Not responding to API requests (any `curl` to `/v1/chat/completions` hangs until timeout)

The process state is "S" (sleeping/interruptible), not "R" (running) or "D" (uninterruptible).

## How to Diagnose

### Step 1 — Verify the backend is registered in llama-swap

```bash
curl -s http://localhost:8080/v1/models | python3 -c "import json,sys; d=json.load(sys.stdin); print([m['id'] for m in d.get('data',[]) if 'glm51' in m['id']])"
```

Expected: the model appears in the list.

### Step 2 — Test through the proxy

```bash
timeout 15 curl -s http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"synthclaw-glm51-256k","messages":[{"role":"user","content":"ping"}],"max_tokens":3,"temperature":0,"stream":false}'
```

If this hangs or returns a 502, the backend is not responding.

### Step 3 — Test the backend directly (bypass proxy)

```bash
# Find the backend port from the proxy
ss -tlnp | grep llama-server

# Test each backend port directly
timeout 15 curl -s http://127.0.0.1:<port>/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"ping"}],"max_tokens":3,"temperature":0,"stream":false}'
```

If the direct call hangs (and the port is open), the backend is hung.
If the direct call works (but proxy fails), the proxy routing is broken.

### Step 4 — Compare with a healthy backend

Pick a model you know works (e.g., a 9B model on port 8087) and run the same test. If that works and GLM51 doesn't, GLM51 is specifically hung.

## Root Causes Observed

### GLM-5.1 Distilled 9B Hang

The GLM-5.1 distilled model (Jackrong/Qwen3.5-9B-GLM5.1-Distill-v1-GGUF) hung after processing a few chat requests through llama-swap. The process:
- Stayed alive (no crash, no segfault)
- Remained in GPU memory (76% VRAM on 16GB)
- Kept the port open
- Silently dropped all subsequent API requests

**Likely cause:** The model's hybrid architecture (8 full-attention + 24 DeltaNet layers) interacts differently with llama.cpp's slot management or `--cont-batching` than pure-attention models. The DeltaNet layers use a fixed-size state rather than KV cache, which may confuse llama.cpp's slot scheduling when `--parallel 1 --cont-batching` is enabled.

### Think Token GBNF Grammar Crash

Applying a GBNF grammar to suppress `<think>` tokens (`root ::= response  response ::= [^<]+`) caused the backend to crash/exit immediately on the next request if the grammar file wasn't found. The grammar also blocks `<` characters entirely, making it unsuitable for code generation (breaks HTML, templates, generics).

## The Fix

```bash
# 1. Kill the hung backend
kill <pid>

# 2. Verify port is freed
ss -tlnp | grep <port>
# Should show nothing

# 3. Restart llama-swap daemon
systemctl --user restart llama-swap

# 4. Wait for models to register
sleep 2
curl -s http://localhost:8080/v1/models | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'Total: {len(d.get(\"data\",[]))} models')"

# 5. Trigger the backend to spawn
curl -s --max-time 180 http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"<model-name>","messages":[{"role":"user","content":"ping"}],"max_tokens":3,"temperature":0,"stream":false}'

# 6. Verify it's responding
curl -s http://127.0.0.1:<port>/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"ping"}],"max_tokens":3,"temperature":0,"stream":false}'
```

## Why Killing the Backend Alone Doesn't Work

When you kill the hung `llama-server` child, llama-swap's proxy:
1. Detects that the upstream at `http://127.0.0.1:<port>` is dead
2. Returns "connection refused" / 502 on subsequent requests
3. Does NOT auto-spawn a new backend process
4. The model stays registered in `/v1/models` but is unreachable

This is different from the "process is in a failed state" error (which happens when spawning fails). The hung-backend death is invisible to llama-swap — the backend was alive, then killed, and the proxy never retries.

Only a daemon restart (`systemctl --user restart llama-swap`) spawns fresh backend processes on next request.
