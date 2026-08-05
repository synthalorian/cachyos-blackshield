# llama-server RAM Leak Diagnosis — Systematic Hunt Pattern

Session: 2026-05-31. Symptom: llama-server consuming 8.7GB RAM (27% of 32GB) with no active local model requests.

## Diagnosis Workflow

When llama-server is eating RAM unexpectedly, run this sequence:

```bash
# 1. Find the top memory consumers
ps aux --sort=-%mem | head -20

# 2. Hunt specifically for llama processes
ps aux | grep -i 'llama' | grep -v grep

# 3. Check which model is loaded and its args
ps aux | grep 'llama-server' | grep -v grep
# Look for: --model, --ctx-size, --mlock, --port, --alias

# 4. Check system RAM state
free -h

# 5. Check llama-swap's view of loaded models
curl -s http://localhost:8080/v1/models | jq '.data[].id'

# 6. Check who's connected to the backend
ss -tunap | grep <PORT>
# TIME-WAIT sockets are normal; ESTABLISHED means active clients

# 7. Inspect the config for the loaded model
grep -A 20 'alias: <MODEL_NAME>' /home/synth/llama.cpp/llama-swap/config.yaml
```

## Root Causes Found in This Session

### Missing evict-and-launch.sh wrapper

The Kimi K2.6 model entries called `llama-server` directly instead of through the eviction wrapper:

```yaml
# WRONG — process stays loaded forever, TTL doesn't evict
  synthclaw-35bkimi-128k:
    cmd: /home/synth/llama.cpp/build/bin/llama-server ...

# CORRECT — evicts on next model request
  synthclaw-35bkimi-128k:
    cmd: /home/synth/.local/bin/evict-and-launch.sh /home/synth/llama.cpp/build/bin/llama-server ...
```

**Why TTL fails for direct-launched entries:** llama-swap's TTL mechanism sends SIGTERM to the child process it spawned. When `cmd:` is the binary directly, this works. But in practice, if the process has `--mlock` set, the kernel may delay or complicate clean shutdown. More importantly, if ANY client (Hermes fallback chain, health checks, stale connections) touches the model before TTL expires, the timer resets. The eviction wrapper guarantees cleanup regardless of TTL state.

### --mlock pins pages in RAM

The `--mlock` flag tells the OS to lock model pages in physical RAM, preventing swap. This is good for performance but means the process's RSS equals its full working set — there's no "soft" footprint. Combined with large context:

- `--ctx-size 131072` (128K context)
- `--cache-type-k q8_0 --cache-type-v q8_0` (8-bit KV cache)
- 35B MoE model with `--n-gpu-layers 24` (most layers on GPU, but KV cache and remaining layers on CPU RAM)

Result: ~8.7GB RSS that cannot be swapped out.

### --ctx-size 131072 is massive

At 128K context with q8_0 KV cache, the KV cache alone is:
- ~2 bytes per head per layer per token (q8_0 is 1 byte + overhead)
- For a 35B model with ~64 heads, 64 layers: significant allocation
- Even with partial GPU offload, the CPU-side KV cache reservation is large

If you're not actually using 128K context, reduce `--ctx-size` to 32768 or 65536.

## Quick Fixes

1. **Kill the process immediately:** `kill <PID>` or `pkill -SIGTERM llama-server`
2. **Fix the config:** Add `evict-and-launch.sh` wrapper to all model entries
3. **Reduce context size** if you don't need the full window
4. **Remove --mlock** if you prefer swap resilience over performance (not recommended for interactive use)
5. **Check Hermes fallback_providers** — if local models are in the fallback chain, memory retrieval 404s keep resetting TTL

## Prevention

- Always audit new model entries for the eviction wrapper
- Run `ps aux | grep llama-server` periodically to catch strays
- Set aggressive TTLs (300-480s) for large models
- Monitor with: `watch -n 5 'ps aux | grep llama-server | grep -v grep'`
