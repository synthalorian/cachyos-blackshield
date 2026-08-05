# Spawn debug checklist — llama-swap won't start a llama-server

## Quick check

```bash
# 1. Is llama-swap running and listening?
ps aux | grep llama-swap
ss -tulpn | grep 8080

# 2. Does it see your model?
curl -s http://127.0.0.1:8080/v1/models | jq '.data[].id'
```

If the model appears in the list but never spawns, proceed.

## Step-by-step

### A. Verify config structure

```bash
# Check every model has both 'cmd' and 'proxy'
yq eval '.models[] | {cmd: .cmd, proxy: .proxy}' /path/to/config.yaml
```

**Fix:** Add missing `proxy` lines with explicit ports matching `--port` in `cmd`.

### B. Test the command manually

Extract the exact `cmd` string from your config (without the `cmd:` key) and run it:

```bash
# Example (adapt to your model)
/home/synth/llama.cpp/build/bin/llama-server \
  --model /home/synth/models/synthclaw-35b-128k/synthclaw-35b-128k-Q4_K_M.gguf \
  --ctx-size 131072 --n-gpu-layers 99 \
  --port 8084 --host 127.0.0.1 \
  --alias test-35b --jinja --reasoning-budget 0 \
  --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 \
  --threads 8 --threads-batch 16 --mlock --metrics \
  --parallel 2 --cont-batching
```

**Expected:** It prints logs and ends with `main: server is listening on http://127.0.0.1:8084`.

**If it hangs:** That's normal — model loading can take 10–60 seconds for 27B–35B. Wait or use `timeout 120` to let it start.

**If it exits with error:** Fix the underlying issue (missing file, bad flag, GPU OOM) before proceeding.

### C. Confirm health endpoint

Once manual spawn succeeds:

```bash
curl -s http://127.0.0.1:8084/health
```

Should return plain `"ok"` or `200`. If not, check:
- `--host` binding (use `127.0.0.1`, not `0.0.0.0` for simplicity)
- Firewall blocking loopback (unlikely on localhost)

### D. Trigger via llama-swap

With manual spawn killed, restart llama-swap and send a request:

```bash
# Restart with debug logging
pkill -f llama-swap
llama-swap --config /path/to/config.yaml --listen localhost:8080 --logLevel debug &

# Wait 2s, then request
curl -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"your-model","messages":[{"role":"user","content":"test"}],"max_tokens":3}'
```

Watch the llama-swap logs (in the terminal where you started it, or redirect to a file).

**Success:** You see `spawning` then `upstream ready` then a response.

**Failure messages:**

| Error | Likely cause |
|-------|--------------|
| `no upstream available to check /health` | `proxy` missing or port mismatch |
| `timeout waiting for health check` | `healthCheckTimeout` too low, model too slow, or `--port`/`proxy` mismatch |
| `fork/exec ...: permission denied` | `cmd` points to non-executable or missing binary |
| `exit status 1` (silent) | `cmd` string malformed (embedded `\n`, bad quoting) |

### E. Resource bottlenecks

If everything looks right but spawn still fails:

```bash
# GPU memory
nvidia-smi   # NVIDIA
rocm-smi      # AMD ROCm
rocm-smi --showmeminfo vram   # AMD detailed VRAM breakdown

# System RAM
free -h

# Check dmesg for OOM kills
dmesg | tail -20 | grep -i kill
```

70B-class models may need 40+ GB VRAM; 35B MoE with `--n-gpu-layers 99` can require 20–30 GB depending on quantization.

### E2. VRAM contention between models (silent spawn failure)

When multiple models are configured and another large model is already running, a new model's spawn may fail silently:

**Symptom on the client:** The request hangs for `healthCheckTimeout` then returns a timeout error (curl exit code 28). No useful error message is returned to the client.

**Symptom in llama-swap logs:** Look for two patterns:
1. Repeated `Connection refused on http://127.0.0.1:<port>/health` — the health check keeps retrying because the child never opened its port
2. `common_fit_params: failed to fit params to free device memory: n_gpu_layers already set by user to N, abort` — the smoking gun. The model started loading, llama-server's memory fitting algorithm determined it couldn't fit in available VRAM, and it exited before binding the port.

**Why it's confusing:** Unlike a crash or segfault, VRAM exhaustion during init does NOT trigger llama-swap's "failed state" cache. The child process simply dies during startup. On the next request, llama-swap tries again from scratch — creating an infinite loop of spawn-attempt → fail → retry → timeout.

**Diagnosis:**
```bash
# 1. Check how much VRAM is available
rocm-smi --showmeminfo vram
# Compare: "VRAM Total Used Memory" vs "VRAM Total Memory"
# If < 2 GB free and model needs > that, this is the issue

# 2. Check which model is hogging VRAM
ps aux | grep llama-server

# 3. Kill the competing model and retry
kill <competing-pid>
systemctl --user restart llama-swap   # clear stale state
curl -s --max-time 180 -X POST ...    # test again

# 4. If it works with VRAM freed, you have contention
```

**Mitigation options (pick one):**
- Reduce `--n-gpu-layers` on competing models to leave VRAM headroom
- Reduce `--ctx-size` on models that don't need full context
- Increase `ttl` so models unload faster when idle
- Schedule models to run separately (don't use large models simultaneously)
- On a 16 GB card, two large MoE models (e.g., 35b at 30 layers + dscv2 at 27 layers) cannot coexist — only one can be hot at a time

### E3. Misleading error: "Failed to parse input at pos N"

Two distinct causes produce the same `Failed to parse input at pos N: ...` error. Diagnose before treating.

#### Cause 1: VRAM exhaustion (existing documentation)

When VRAM is exhausted and the model fails mid-init, the client may see `Failed to parse input at pos N: <truncated input>` rather than a clean timeout. This happens because the llama-server process partially initializes (tokenizer loads, model doesn't), then the tokenizer chokes when trying to process the rendered prompt — or the backend returns this error from a stale failed-state process.

**Don't be misled** into debugging the chat template or tokenizer. If you see this error plus the symptom that the same model works with a minimal request (`{"role":"user","content":"hi"}`) but fails with a long system prompt, check VRAM first. The longer prompt means more KV cache allocation, which fails when VRAM is tight.

#### Cause 2: Stale llama-swap process (different config)

When multiple llama-swap instances exist (systemd units, background shells), a stale process serving an OLD config that doesn't have the requested model will return `Failed to parse input at pos N` — not a clean model-not-found error. The content at pos N changes across retries because different downstream processes (or the error handler itself) respond differently each time.

**Diagnosis pattern (from ds14b debug):**
```bash
# Symptom 1: Error content at pos N changes per retry
# Retry 1: "pos 11: synthclaw"
# Retry 2: "pos 11: I'm trying to help a user..."  
# Retry 3: "pos 11: Hi! I'm DeepSeek-R1..."

# Symptom 2: Same model works via direct curl
curl -s -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"ds14b","messages":[{"role":"user","content":"test"}],"max_tokens":10}'
# → Returns 200 with valid response

# Symptom 3: Multiple llama-swap PIDs
ps aux | grep llama-swap
# → If you see more than one, or the PID doesn't match systemd, stale process confirmed

# Root cause check: journalctl shows different config
journalctl --user -u llama-swap -n 20 --no-pager | grep "listening on"
# → e.g., "Llama Swap Server - MiniMax M2.7..." — wrong config active
```

**Fix:** Identify and stop ALL stale llama-swap processes, then restart the correct one:
```bash
# Kill any old llama-swap (they may be orphaned from shell sessions)
pkill -f llama-swap 2>/dev/null
# Then restart via systemd (which uses the correct config)
systemctl --user restart llama-swap
# Verify correct process and config
curl -s http://127.0.0.1:8080/v1/models | jq '.data[].id'
# Should show ALL models, not just a subset
```

**Prevention:** Never start llama-swap manually from a shell with `&`. Always use `systemctl --user` or the systemd unit file. Manual instances outlive shell sessions and compete on port 8080, silently overriding the systemd-managed one.

### F. Permissions & SELinux/AppArmor

```bash
# If using SELinux
getenforce
# Temporarily permissive for testing
sudo setenforce 0

# AppArmor (Ubuntu)
sudo aa-status | grep llama
```

### G. Log collection

Capture full llama-swap output:

```bash
# Start with log to file
llama-swap --config config.yaml --listen localhost:8080 2>&1 | tee /tmp/llama-swap.log

# Or, if already running, send USR1 to dump logs (if supported by build)
kill -USR1 <pid>
```
