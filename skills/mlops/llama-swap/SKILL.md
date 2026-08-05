---
name: llama-swap
description: Multi-model orchestration for llama.cpp — configure proxy routing, on-demand spawning, health checks, and debug spawning failures.
version: 1.0.0
author: synthclaw (Orchestra Research)
license: MIT
dependencies: []
platforms: [linux, macos]
metadata:
  hermes:
    tags: [llama.cpp, orchestration, multi-model, proxy, on-demand, health-check]
---

# llama-swap — model orchestration for llama.cpp

Use this skill when configuring, troubleshooting, or understanding **llama-swap** — the OpenAI-compatible router that manages multiple `llama-server` instances and routes requests to the appropriate model on-demand.

## When to use

- Set up multi-model serving with unique ports per model
- Debug "no upstream available" or "unable to start process" errors
- Configure health checks, TTL unloading, and model aliases
- Route requests through a single OpenAI-compatible endpoint
- Understand on-demand spawning behavior (models start on first request)
- Assign explicit ports and proxy URLs for each model profile

## Core concepts

### Architecture
llama-swap is a **request router + process manager**:
- Listens on a single port (default 8080) with OpenAI API endpoints
- For each incoming request, spawns a `llama-server` child with the requested model (if not already running)
- Health-checks the child at `checkEndpoint` (default `/health`) before routing
- Unloads idle models after `ttl` seconds via SIGTERM

### Required fields per model (YAML)

Every model definition **must** include:
- `cmd` — command to start `llama-server` (can be multi-line literal `|` or folded `>`)
- `proxy` — **upstream URL** where llama-swap should forward requests (e.g., `http://127.0.0.1:8081`)
- `ttl` — seconds of inactivity before auto-unload (0 = never)
- `aliases` — list of alternate model names accepted by the router

### Port strategy

Each model instance **must** use a unique, fixed port:
- Never use `${PORT}` placeholder if the `proxy` field is required
- Assign ports sequentially starting at 8081 (8080 is llama-swap itself)
- Ensure ports don't conflict with other services

### Command format

The `cmd` field can be:
- Single-line: `cmd: llama-server --port 8081 -m model.gguf`
- Multi-line literal (`|`): preserves newlines — **must** be parseable by shell
- Multi-line folded (`>`): folds newlines into spaces — safer for readability

**Pitfall:** If `cmd` contains literal `\n` characters (bad YAML parsing), the command fails silently. Always verify the command is actual shell syntax, not a string with embedded escape sequences.

### Health checking

- llama-swap polls `http://<proxy>/health` until it returns 200 or `healthCheckTimeout` expires
- On timeout: `unable to start process: no upstream available to check /health`
- Fix: ensure `proxy` URL matches the `--port` in `cmd` and llama-server binds to that port

### On-demand spawning

Models **do not** start when llama-swap launches. They spawn on the **first request** for that model name. Subsequent requests reuse the running instance until TTL expiry.

To pre-warm: send a simple curl request to `/v1/chat/completions` for each model.

## Diagnostic workflow

1. **Confirm llama-swap is listening**
   ```bash
   ss -tulpn | grep 8080
   curl http://127.0.0.1:8080/v1/models
   ```

2. **Check child processes**
   ```bash
   ps aux | grep llama-server
   ```
   No children is normal until first request.

3. **Trigger a request**
   ```bash
   curl -X POST http://127.0.0.1:8080/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"model":"your-model","messages":[{"role":"user","content":"hi"}],"max_tokens":5}'
   ```

4. **If spawn fails** — look for `no upstream available`:
   - Verify `proxy` field exists and uses correct port
   - Verify `cmd` has `--port <that-same-port>` and `--host 127.0.0.1`
   - Manually test `llama-server` with identical args to isolate errors

5. **If child never appears**:
   - Enable `logLevel: debug` in config
   - Check system resources (GPU memory, RAM) for OOM kills
   - **Check llama-swap logs for `common_fit_params: failed to fit`** — this is VRAM exhaustion during model init. The child process starts loading, can't fit into available VRAM, and exits before opening its port. Unlike a crash, this does NOT mark the model as failed — llama-swap keeps retrying on every request, causing repeated timeouts.
   - Check VRAM with `rocm-smi --showmeminfo vram` (AMD) or `nvidia-smi` (NVIDIA). Look for total used vs free — if another model is consuming VRAM, this model may not have room.
   - Test a minimal `llama-server` command to rule out binary issues

6. **If child spawns but health fails**:
   - Confirm llama-server actually listens on the expected port
   - Check firewall/SELinux/AppArmor blocking loopback
   - Increase `healthCheckTimeout` (model load can take 30–120s)

## Process management: systemd user service

llama-swap may be managed by a systemd user service on this system. Check with:

```bash
systemctl --user list-units | grep llama-swap
cat ~/.config/systemd/user/llama-swap.service
```

If the service file contains `Restart=always`, systemd auto-restarts llama-swap within **5 seconds** of any exit (kill, crash, `pkill`). This means:

- **`kill <pid>` is ineffective** — the process respawns. You'll see a new PID emerge after ~5s.
- **`pkill -f llama-swap` loops forever** — each kill triggers a restart, not a stop.
- **Cannot rebind port 8080 via kill + restart** — the old instance respawns before your new one can bind.

**Always use systemd commands to manage the lifecycle:**

```bash
systemctl --user restart llama-swap   # graceful restart with new config
systemctl --user stop llama-swap      # actually stops it (no restart)
systemctl --user start llama-swap     # start after stop
```

**Detecting the trap:** If you `pkill llama-swap` and `ss -tlnp | grep 8080` still shows a listening `llama-swap` process a few seconds later, it's systemd-managed. Don't fight it — use `systemctl --user` instead.

**PITFALL (background process vs systemd):** If you start llama-swap manually in a terminal background session while the systemd service is active, both will compete for port 8080. The daemon (started first by systemd) holds the socket. Your manual instance fails with `bind: address already in use`. Always stop the systemd service first if you want to run manually:
```bash
systemctl --user stop llama-swap
/home/synth/go/bin/llama-swap --config ... --listen localhost:8080
```

**PITFALL — The prewarm backdoor:** Disabling `llama-swap.service` alone does NOT prevent it from starting on login. If `llama-swap-prewarm.service` is enabled and contains `BindsTo=llama-swap.service`, systemd starts the prewarm at login, which **pulls up llama-swap as a dependency** even when the main service is disabled. Check all related units:

```bash
systemctl --user list-unit-files | grep llama-swap
systemctl --user is-enabled llama-swap-prewarm.service
```

To fully stop auto-start, disable BOTH:
```bash
systemctl --user disable llama-swap-prewarm.service
systemctl --user disable llama-swap.service
systemctl --user stop llama-swap-prewarm.service
systemctl --user stop llama-swap.service
```

**PITFALL — Socket activation does NOT work with llama-swap:** llama-swap binds to its listen port internally (`--listen localhost:8080`). It does NOT support systemd's `LISTEN_FDS` socket inheritance. If you try socket activation, the socket unit holds port 8080, then llama-swap starts and tries to bind the same port — `address already in use` — and enters a crash loop. Socket activation only works with applications designed to accept an inherited file descriptor (e.g., nginx, sshd). llama-swap is not one of them.

**On-demand alternatives to socket activation:**
1. **Manual start** — `systemctl --user start llama-swap` when you need it
2. **Wrapper script** — a shell function that checks if llama-swap is running, starts it if not, then proxies the request. See [references/on-demand-autostart.md](references/on-demand-autostart.md) for the `ensure-llama-swap` pattern used with `claw` and `hermes` wrappers.
3. **Hermes provider switching** — keep llama-swap stopped; only switch to it via `-m <model> --provider llama-swap` when explicitly needed. Hermes will NOT auto-start it — you'll get connection refused if it's down, which is the signal to start it.

## Cold-start latency: health check timeout

Llama-swap waits up to `healthCheckTimeout` seconds (default 240) for a model to pass its `/health` check before either routing the request or returning a timeout. Large models on GPU-constrained systems can take 2–3 minutes to load, which is within the default window — so the client just sits there.

### What makes cold-start slow

The bottleneck is almost always **GPU-side initialization**, not disk I/O:

- **Disk read** of a 13 GB GGUF at ~1.3 GB/s (LUKS-encrypted NVMe sustained): ~10 seconds
- **GPU buffer allocation** (Vulkan memory mapping, layer upload): dominates the remaining time
- **Model initialization**: template parsing, KV cache allocation, tokenizer init

Diagnose the split:
```bash
# Disk speed check (sustained read)
dd if=/path/to/model.gguf of=/dev/null bs=4M count=250 2>&1 | tail -2

# Watch for the model process to appear
ps aux | grep llama-server

# Check process state: Dl = loading GPU buffers, Rl = running
ps -o pid,state,cmd <llama-server-pid>
```

### Mitigation: pre-warming (preferred)

Pre-warming loads the model at system boot so the cold-start wait happens when nobody's watching. The model stays hot via TTL (default 900s = 15 min), then unloads naturally. This is preferred over `ttl: 0` for users who don't want permanent VRAM occupancy.

**Set up a systemd pre-warm service:**

1. Create a pre-warm script at `~/.local/bin/prewarm-models.sh` (see [scripts/prewarm-models.sh](../scripts/prewarm-models.sh) in this skill)
2. Create a systemd one-shot unit at `~/.config/systemd/user/llama-swap-prewarm.service` (see [templates/llama-swap-prewarm.service](../templates/llama-swap-prewarm.service) in this skill)
3. Enable it: `systemctl --user daemon-reload && systemctl --user enable llama-swap-prewarm.service`

The service fires once at boot after `llama-swap.service`, sends a dummy request to each model, and exits. Models remain loaded according to their configured TTL.

**PITFALL — Sequential pre-warming:** A script that pre-warms models in sequence (35b first, then GLM) will block the GLM request until the 35b finishes loading (~3 min). Design pre-warm scripts to fire requests in parallel:
```bash
# Parallel approach
for MODEL in "synthclaw-35b-128k" "synthclaw-glm51-128k"; do
  curl -s -X POST http://127.0.0.1:8080/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer llama-swap-local" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":1}" \
    --max-time 300 &
done
wait
```

### Alternative: ttl: 0 (permanent residency)

Set `ttl: 0` to keep a model loaded in VRAM forever. Use this only when:
- The GPU is dedicated to this model
- You have enough VRAM headroom (check total vs used)
- You accept that it never unloads until llama-swap restarts

```yaml
  my-model:
    ttl: 0  # never unload
```

**PITFALL:** On a 16 GB card with 27 models configured, setting ttl: 0 on a 35B model (~14 GB VRAM used when loaded alongside a 9B model) leaves almost no headroom for other models. A second large model spawn will OOM and go into failed state.

### Perceived slowness from conversation history accumulation

Even when a model is warm and running fast, responses can feel slow if the conversation has accumulated a massive token history. Every new message reprocesses the entire history during prompt evaluation.

**Symptoms:**
- First message of a session is fast, but responses degrade over time
- 50+ message conversations show 5–15 second prompt processing per message
- llama-swap logs show `n_tokens` growing (e.g., 16K+ tokens per request)

**Diagnosis from logs:**
```bash
journalctl --user -u llama-swap | grep "prompt processing done"
# Look for n_tokens — this is your prompt length growing
```

**Mitigations:**
- Clear conversation history periodically / start fresh sessions
- Reduce `--ctx-size` if you don't need the full context window
- Use `--cache-type-k q4_0 --cache-type-v q4_0` to halve KV cache memory at the cost of slight quality
- Expect ~0.5–1 ms per token of prompt processing; at 1300 tok/s, a 16K prompt takes ~12 seconds

## Pitfalls

- **Missing `proxy`** → `no upstream available to check /health` is the error
- **`${PORT}` placeholder** → not expanded by llama-swap; use explicit numbers
- **Port collision** → two models on same port causes immediate health failure
- **`cmd` with backslash-n** (from `|` with bad editor) → command becomes one invalid string
- **`--host` mismatch** → if `cmd` uses `--host 0.0.0.0` but `proxy` uses `127.0.0.1`, health check may still work but be aware of binding scope
- **TTL too low** → model unloads during long conversation; set `ttl` generously for interactive use
- **GPU memory overcommit** → spawning second model may fail if VRAM exhausted; check `nvidia-smi` or `rocm-smi`
- **VRAM exhaustion → silent timeout (health check)** → When VRAM is insufficient, llama-server's init phase calls `common_fit_params` which logs `failed to fit params to free device memory: n_gpu_layers already set by user to N, abort` and exits. The child process dies BEFORE the health check port opens. Llama-swap sees only `Connection refused on http://127.0.0.1:<port>/health` and keeps retrying until `healthCheckTimeout`. The client sees a timeout, not a useful error. This is distinct from the "failed state" cache — the child never started, so no failed state is set and llama-swap keeps retrying on each request.
  
  **Diagnosis:**
  1. Check VRAM with `rocm-smi --showmeminfo vram` or `nvidia-smi`
  2. Check llama-swap logs for `common_fit_params: failed to fit` — that's the smoking gun
  3. Test with a minimal request (no system prompt, short content) — if the model loads fine alone but fails when another large model is running, it's VRAM contention
  4. Free VRAM by killing competing llama-server processes (`kill <pid>`) or waiting for TTL unloads
  
  **Fix:** Reduce `--n-gpu-layers` on one of the competing models, reduce `--ctx-size`, or schedule their usage so they don't overlap.
- **Jinja template format mismatch** → Models generate responses in the chat format they were TRAINED on, not whatever format the Jinja template uses. A custom template with `<|turn|>` tokens will cause the model to echo those tokens back as garbage text instead of producing a coherent response. Each model architecture uses a specific format:
  - **Qwen**: ChatML (`<|im_start|>` / `<|im_end|>`)
  - **DeepSeek (Coder)**: Plain text (`User:` / `Assistant:`)
  - **Gemma**: Llama 3 style (`<|start_header_id|>` / `<|end_header_id|>` / `<|eot_id|>`)
  - **Llama**: Llama 3 style (same as Gemma)
  
  The Jinja template's job is to format the PROMPT (input) in the model's expected format. The model's RESPONSE (output) will be in whatever format it was trained on — the template has no effect on the output format. If the template uses a format that doesn't match the model's training format, the model will produce incoherent output that mixes template tokens with attempted responses.
  
  **Diagnosis:** If the model's response starts with template control tokens (`<|turn|>`, `<|im_start|>`, etc.) or repeats the conversation history, the Jinja template format doesn't match what the model was trained to generate.
  
  **Fix:** Use the model's native format. For the synthclaw identity, inject it as system prompt CONTENT within the correct format, not by inventing a new format.

- **Process failed state cache** → When a llama-server child process crashes (bad GGUF, GPU OOM, segfault), llama-swap marks it as "process is in a failed state and can not be restarted" and refuses subsequent requests to that model. The daemon does NOT auto-recover. Fix: restart llama-swap entirely — `systemctl --user restart llama-swap` — to clear the per-model failure cache. Just killing the child process isn't enough; the daemon's in-memory state persists the failure.

- **Duplicate model entries with same GGUF** → If two model entries (e.g., `ds14b` and `dscv2`) point to the same GGUF file and differ only in `--n-gpu-layers`, a crash in one entry's spawn will NOT affect the other's cache. But if the root cause is the GGUF itself (corrupt, incompatible with binary), both will fail independently. Use distinct GGUFs to get distinct failure states; use aliases to give a single model multiple names.

- **Hung backend (alive but not responding)** — A `llama-server` child process can enter a state where it's alive (port open via `ss`, process visible in `ps`, GPU memory allocated) but silently drops all API requests. Requests to `http://127.0.0.1:<port>/v1/chat/completions` hang until timeout. The process never crashes, so llama-swap never marks it as "failed" — the proxy just returns 502 / connection timeout.

  **Diagnosis:** Send a minimal test request directly to the backend port (bypass the llama-swap proxy). If the call hangs but the port is open, the backend is hung. Compare with a working backend (e.g., 9B on port 8087) to confirm the symptom.

  **Fix:**
  1. Kill the hung backend process: `kill <pid>`
  2. Verify port is freed: `ss -tlnp | grep <port>` should show nothing
  3. Restart llama-swap to re-spawn cleanly: `systemctl --user restart llama-swap`
  4. Test through the proxy: `curl -s http://localhost:8080/v1/chat/completions -d '{"model":"<model-name>","messages":[{"role":"user","content":"ping"}],"max_tokens":5}'`

  **Critical:** Killing the backend alone is NOT sufficient. Llama-swap's proxy does NOT auto-restart a dead backend — it just returns "connection refused" on the next request. A daemon restart is required.

  **Root cause observed:** The GLM-5.1 distilled 9B model (Jackrong/Qwen3.5-9B-GLM5.1-Distill-v1-GGUF) hangs with a silent-death pattern: first request works, second request hangs forever. The process stays alive (port open, GPU memory allocated, visible in `ps`) but silently drops all API requests.

  **Diagnosis pattern:** Send a direct request to the backend port. If it hangs but port is open → hung backend. Compare with a known-working model.

  **Root cause — `--flash-attn on` incompatibility with DeltaNet:** This model's hybrid architecture (8 full-attention + 24 DeltaNet layers) cannot use flash attention. DeltaNet's compressed fixed-size state is incompatible with flash-attn's memory layout for KV cache reuse/recycling. The first request works because KV cache is freshly allocated; the second request hangs because flash-attn tries to reuse a corrupted or incompatible state.

  **Fix — strip flash-attn AND cont-batching:**
  1. Remove `--flash-attn on` from the model's `cmd` in llama-swap config
  2. Remove `--cont-batching` (also problematic with DeltaNet)
  3. Keep `--parallel 1` (prevents slot contention)
  4. Restart llama-swap: `systemctl --user restart llama-swap`
  5. Verify with two sequential test requests

  Workaround before root cause was identified: systemctl restart llama-swap to spawn a fresh process.

  See `references/hang-diagnosis.md` for the full diagnosis workflow.

- **Two config files — machine-dependent which is real.** The AMD box (RX 9070 XT) uses `/home/synth/llama.cpp/llama-swap/config.yaml`; the `~/.config/llama-swap/config.yaml` there is STALE (flat format, `${PORT}`, no `proxy`). On **synthesis** (i7-8700K / GTX 1080 Ti) it is the OPPOSITE: `~/.config/llama-swap/config.yaml` is the live macro-driven config and `/home/synth/llama.cpp/llama-swap/` doesn't exist. Never trust the path from memory — verify against the running process: `ps aux | grep llama-swap | grep -- --config`. Editing the wrong file has zero effect.

- **Vulkan device renumbering breaks the ENTIRE fleet at once** — After a llama.cpp binary upgrade, device names can shift (e.g. `Vulkan1` → `Vulkan0`). Symptom: EVERY model fails instantly with `upstream command exited prematurely` (sub-second), and manual runs show `error while handling argument "-dev": invalid device: Vulkan1`. Diagnosis: `llama-server --list-devices` shows the real names. Fix: update the `-dev` value in the `llama` macro (one line fixes all models). If only ONE model fails but the rest work, it's not this — it's model-specific.

- **MoE CPU-offload RAM ceiling (16GB systems)** — For hybrid MoE like Qwen3.6-35B-A3B with `-ot ".ffn_.*_exps.=CPU"`, the expert tensors mmap in system RAM. A GGUF whose expert pool exceeds ~13GB (e.g. IQ4_XS at 18GB) loads fine and passes health checks, then swap-thrashes during generation (<1 tok/s, swap usage climbing GBs) — the daemon log shows health pass followed by a multi-minute stall, NOT an error. Fit check: GGUF size − ~2.5GB non-expert ≈ expert pool; expert pool + desktop RAM usage must stay under total RAM. On synthesis (16GB), Q2_K_XL (12.6GB) is the fitting quant for 35B-A3B, yielding ~2.5–3.5 tok/s warm. Symptoms-to-fix: don't debug llama-swap — check `free -h` swap delta during a request.

- **Qwen3.6-35B-A3B KV cache is tiny despite 256K context** — Hybrid linear attention: only 10 of 40 layers are full attention (2 KV heads × 256 head_dim). 256K ctx at q8_0 ≈ 2.85GB KV total; linear-layer state is fixed-size (~250MB) regardless of context. Whole model footprint on an 11GB GPU: ~5.7GB with experts on CPU. No YaRN needed — 262144 is the native arch ceiling. Keep `--parallel 1` (DeltaNet stability) and NEVER `-fa on` (flash-attn + linear attention = hang on second request).

- **TTL unloading at scale** → At scale (20+ models), TTL-unload messages flood journald every few seconds. This is normal behavior — llama-swap regularly sweeps expired models. The unload log lines are harmless info-level messages, not errors. Filter them out of monitoring with `journalctl --user -u llama-swap | grep -v Unloading`.

- **OpenCode + synthclaw-35b first turn takes ~6.5 minutes — NOT a hang** → OpenCode fires two requests per turn: `small=true agent=title` (~1 min) then `small=false agent=synthclaw` with the full system prompt + tool schemas (~30K+ tokens). With `--parallel 1` they serialize, and at ~100 tok/s prompt processing the main request needs ~6.5 min warm. Killing the client at 2-4 min shows as `no valid JSON data found in stream` in llama-swap logs (client disconnect, not server failure). Verified 2026-08-01: unthrottled run completes in 6m38s with correct output. Subsequent turns are faster (prompt prefix cache). If this is too slow, use `synthclaw-fast` (9B) for opencode instead.

- **Missing `evict-and-launch.sh` wrapper → RAM leak** → Some model entries may call `llama-server` directly in `cmd:` instead of through the eviction wrapper script (e.g., `/home/synth/.local/bin/evict-and-launch.sh`). When the wrapper is missing, the model process stays resident in RAM indefinitely — TTL expiry may not reliably kill it, especially with `--mlock` pinning pages. This manifests as a `llama-server` process consuming multiple GB of RAM with no active requests.

  **Diagnosis:**
  1. `ps aux | grep llama-server` — note the loaded model's `--alias`
  2. `grep -A 5 '<alias>:' /path/to/llama-swap-config.yaml` — check if `cmd:` starts with the wrapper script or the binary directly
  3. Compare with working models that DO use the wrapper

  **Fix:** Change `cmd:` from direct binary invocation to wrapper + binary:
  ```yaml
  # WRONG — stays loaded forever
    cmd: /home/synth/llama.cpp/build/bin/llama-server --model ...

  # CORRECT — evicts properly
    cmd: /home/synth/.local/bin/evict-and-launch.sh /home/synth/llama.cpp/build/bin/llama-server --model ...
  ```
  Restart llama-swap after editing config: `systemctl --user restart llama-swap`

  **Prevention:** When adding new model entries, copy an existing working entry that uses the wrapper. Never type the `cmd:` line from scratch.

- **Phi-4 `--flash-attn on` → immediate SIGABRT (core dumped)** — Microsoft Phi-4 (and Phi-4 reasoning variants) crash on startup when `--flash-attn on` is passed. The error manifests as `signal: aborted (core dumped)` from llama-swap with no useful preceding log. This is a model-architecture incompatibility with the flash-attention kernel in llama.cpp's Vulkan backend.

  **Diagnosis:** Test without `--flash-attn on` — if the same model loads fine, flash-attn is the culprit.
  
  **Fix:** Remove `--flash-attn on` from all Phi-4 entries in llama-swap config. The model runs fine without it (prompt processing ~874 tok/s on RX 9070 XT at 40 GPU layers).

- **Phi-4 `--cont-batching` → SIGABRT** — Phi-4 also crashes when `--cont-batching` is enabled. Use `--parallel 1` without cont-batching for stable operation.

- **Phi-4 `--rope-scaling yarn` → SIGABRT** — Phi-4 does not support YARN rope scaling. Attempting to extend context beyond the model's native length (even without YARN, at 256K+ ctx-size) causes core dumps during KV cache allocation. Cap Phi-4 context at ~64K for stable operation.

- **Phi-4 `--reasoning on --reasoning-format deepseek` → SIGABRT** — Phi-4 Reasoning Plus has its own built-in reasoning template (ChatML with `<think>` / `</think>` tags embedded in the GGUF's Jinja template). Passing `--reasoning on --reasoning-format deepseek` causes a core dump during model initialization because the reasoning pipeline conflicts with the model's native template.

  **Diagnosis:** The model works with `--jinja` alone (uses built-in template) but crashes when reasoning flags are added.
  
  **Fix:** Strip `--reasoning on --reasoning-format deepseek` from Phi-4 entries. Rely on `--jinja` to use the model's native ChatML template which already includes `<think>` reasoning blocks. If you need reasoning output, the model produces it natively — no special flags required.

  **Working Phi-4 config pattern:**
  ```yaml
  synthclaw-phi4-128k:
    cmd: /home/synth/.local/bin/evict-and-launch.sh /home/synth/llama.cpp/build/bin/llama-server
      --model /home/synth/models/phi-4/Phi-4-reasoning-plus-Q4_K_M.gguf
      --jinja --ctx-size 131072 --n-gpu-layers 40 --port 8108 --host 127.0.0.1
      --alias synthclaw-phi4-128k
      --cache-type-k q8_0 --cache-type-v q8_0 --threads 8 --threads-batch 16
      --mlock --metrics --parallel 2 --cont-batching
    proxy: http://127.0.0.1:8108
    ttl: 900
  ```

- **Phi-4 256K+ ctx-size → SIGABRT** — Even without YARN rope scaling, Phi-4 core dumps when `--ctx-size` exceeds ~64K. The KV cache allocation fails during model initialization. This is a hard limit of the model architecture / llama.cpp implementation for this GGUF, not a VRAM issue (the same model loads fine at 128K with identical GPU layers). **Do not create Phi-4 variants above 128K context.** If you need 256K or 512K context, use Mistral Small 3.2 or Qwen models instead.

  **Session evidence:** Attempted 256K and 512K Phi-4 variants. Both produced `signal: aborted (core dumped)` immediately on spawn. Reduced to 64K — loaded successfully. User rejected 64K as insufficient and requested removal of the 256K/512K variants, keeping only the 128K Phi-4.

  **Context sizing principle:** Never compromise below the user's stated minimum context. If a model cannot run at the requested context size, omit the variant entirely rather than creating a gutted version with a smaller context. Offer alternative models that DO support the required context.

  **Practical implication:** For a user's local model fleet, Phi-4 should be deployed as a single 128K entry. Do not create a "phi4max" or "phi4ultra" shorthand — they will not work.

- **Hermes `fallback_providers` causes TTL leaks** → When local llama-swap models are listed in Hermes `fallback_providers` in `~/.hermes/config.yaml`, ANY failed or unsupported request routed to the model (including `/v1/memories/retrieve` which `llama-server` returns 404 for) resets the model's TTL timer. The model never cools down because Hermes sends memory retrieval requests every ~30 seconds during active sessions, each one counting as "activity" that resets TTL. A model with `ttl: 480` will stay loaded indefinitely if it's in the fallback chain.

  **Fix:** Remove local models from `fallback_providers` in Hermes config. Local models should only activate when explicitly requested via `-m <model> --provider llama-swap`. The fallback chain should use cloud providers only. If local fallback is needed for offline use, put the lightest model (9B) first in the chain and accept that it may stay warm.

  **Diagnosis:** Check `journalctl --user -u llama-swap | grep "memories/retrieve"` — if you see 404 responses every 30 seconds, Hermes is keeping the model alive through the fallback chain.

## Example minimal config

```yaml
healthCheckTimeout: 60
logLevel: info

models:
  "llama-3-8b":
    cmd: >
      /path/to/llama-server
      --model /models/llama-3-8b.Q4_K_M.gguf
      --port 8081 --host 127.0.0.1
      --alias llama-3-8b
    proxy: http://127.0.0.1:8081
    ttl: 900
    aliases:
      - llama-3-8b
      - gpt-4o-mini
```

## Absorbed Skill: llama-swap-debugging (consolidated 2026-05-27)

The `llama-swap-debugging` skill was consolidated into this umbrella. It contributed:
- Client integration debugging (claw wrapper, Hermes routing, API key placeholders)
- Model deployment workflow (new model addition, reasoning model config, identity injection)
- Wrapper symlink resolution patterns
- Ollama + llama-swap co-existence findings
- Kimi K2.6 hybrid attention model config
- KV cache planning for hybrid architectures
- Cloud provider routing (Z.AI coding plan vs standard API)

All reference files, scripts, and templates from the debugging skill are now in this skill's directories.

## References

- **[ram-leak-diagnosis.md](references/ram-leak-diagnosis.md)** — systematic workflow for finding why llama-server is consuming unexpected RAM; covers `ps`, `free`, `ss`, config audit, and the missing eviction wrapper pitfall
- **[config-fix.md](references/config-fix.md)** — root-cause analysis of missing `proxy` field causing `no upstream available` errors, with corrected YAML patterns
- **[model-vram-budgeting.md](references/model-vram-budgeting.md)** — how to determine if a GGUF model fits your VRAM; KV cache math, MoE vs dense models, model selection workflow
- **[port-assignment.md](references/port-assignment.md)** — recommended port ranges and conflict avoidance for multi-model deployments
- **[spawn-debug.md](references/spawn-debug.md)** — step-by-step process to isolate why llama-swap refuses to spawn a child (manual `llama-server` test, health check validation, log interpretation)
- **[model-provisioning-workflow.md](references/model-provisioning-workflow.md)** — complete end-to-end workflow for adding a new GGUF model: sizing, download, 5 config files to update, verification checklist, and deletion workflow. **CRITICAL:** Includes the partial-provisioning pitfall — adding a model to llama-swap config without updating the CLI resolver wrappers leaves the model invisible to `hermes`/`claw`.
- **[amd-gpu-layers.md](references/amd-gpu-layers.md)** — `--n-gpu-layers` tuning per model size and context length for 16 GB AMD GPUs (Vulkan backend); layer count tables for 9B through 32B models at 128k/256k/512k contexts
- **[failed-state-recovery.md](references/failed-state-recovery.md)** — diagnosis and recovery from "process is in a failed state and can not be restarted" error; root causes and manual llama-server test workflow
- **[hang-diagnosis.md](references/hang-diagnosis.md)** — full diagnosis workflow for hung backends (alive but not responding)
- **[co-existence-oct2025.md](references/co-existence-oct2025.md)** — llama-swap + Ollama co-existence on same GPU
- **[kimi-k2.6-deployment.md](references/kimi-k2.6-deployment.md)** — Kimi K2.6 reasoning-distilled model config, flash-attn incompatibility
- **[model-shorthand-resolution.md](references/model-shorthand-resolution.md)** — complete shorthand→modelID mapping for claw/hermes wrappers
- **[phi-4-deployment.md](references/phi-4-deployment.md)** — Microsoft Phi-4 / Phi-4 Reasoning Plus compatibility: flash-attn crash, reasoning flag incompatibility, YARN rope scaling incompatibility, `--cont-batching` incompatibility, working config, GPU layer tables, performance benchmarks
- **[socket-activation-failure.md](references/socket-activation-failure.md)** — why systemd socket activation does NOT work with llama-swap (bind conflict, crash loop, recovery, and practical on-demand alternatives)
- **[on-demand-autostart.md](references/on-demand-autostart.md)** — practical auto-start pattern: `ensure-llama-swap` wrapper script for CLI tools (claw, hermes) that starts llama-swap on first use without socket activation
- **[identity-rebrand-sweep.md](references/identity-rebrand-sweep.md)** — checklist for renaming AI assistant identity across all layers of a local LLM stack (Jinja templates, bash wrappers, systemd units, config files)

## Scripts

- **[scripts/prewarm-models.sh](scripts/prewarm-models.sh)** — parallel pre-warm script for systemd one-shot service
- **[scripts/verify-llama-swap-config.sh](scripts/verify-llama-swap-config.sh)** — config validation script
- **[scripts/ensure-llama-swap.sh](scripts/ensure-llama-swap.sh)** — on-demand auto-start wrapper; checks port 8080, starts systemd service if down, polls up to 30s for readiness. Integrate into CLI wrappers (claw, hermes) for transparent llama-swap startup
