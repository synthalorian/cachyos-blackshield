---
name: llama-swap-auto-eviction
description: Auto-evict running models when a new one is requested on 16GB VRAM GPUs
version: 1.0.0
author: synthclaw
---

# llama-swap auto-eviction

On a 16GB VRAM card (RX 9070 XT), multiple llama-swap-managed models can't coexist — requesting model B while model A is loaded will OOM. This skill implements automatic eviction to keep llama-swap's own pool single-model.

**Scope clarification (2026-05, live test):** The eviction wrapper is only required *within* llama-swap's own model pool. `llama-swap` and `ollama` run as separate processes using the same AMD GPU driver and *can* coexist without eviction. Do NOT add the eviction wrapper to ollama models. For cross-engine co-existence, see `llama-swap-debugging` Section X.

## How it works

Every model's `cmd:` in llama-swap config.yaml is wrapped with `evict-and-launch.sh`, a script that:

1. Runs `pkill -SIGTERM llama-server` to kill ALL currently running llama-server processes
2. Sleeps 2 seconds for VRAM to be released by the kernel
3. `exec`s the real llama-server command

Since the script is part of the `cmd:` that llama-swap runs on-demand, the eviction happens before the new model spawns — the old model is dead before the new one starts loading.

## Setup

### Script location

`/home/synth/.local/bin/evict-and-launch.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
pkill -SIGTERM llama-server 2>/dev/null || true
sleep 2
exec "$@"
```

### Config modification

Every `cmd:` in the config.yaml must be prefixed with the wrapper:

```yaml
  model-name:
    cmd: /home/synth/.local/bin/evict-and-launch.sh /home/synth/llama.cpp/build/bin/llama-server --model ...
```

Applied with:
```bash
patch --replace_all \
  /home/synth/llama.cpp/llama-swap/config.yaml \
  "cmd: /home/synth/llama.cpp/build/bin/llama-server" \
  "cmd: /home/synth/.local/bin/evict-and-launch.sh /home/synth/llama.cpp/build/bin/llama-server"
```

## Verification

1. Load model A (e.g., 35b): `curl -X POST http://127.0.0.1:8080/v1/chat/completions ... -d '{"model":"35b",...}'`
2. Check VRAM: `rocm-smi --showmeminfo vram | grep "VRAM Total Used"`
3. Request model B (e.g., dscv2): `curl -X POST http://127.0.0.1:8080/v1/chat/completions ... -d '{"model":"dscv2",...}'`
4. Verify model A process is dead: `ps aux | grep llama-server`
5. Verify correct model responds: check `"model":"synthclaw-dscv2-128k"` in response

## Pitfalls

- **pkill race**: `pkill -SIGTERM llama-server` in the wrapper kills ALL llama-server processes. The newly spawned process hasn't started yet (it's still in the shell script before `exec`), so it's safe. But if two requests arrive simultaneously for different models, both wrappers could kill each other's target. llama-swap serializes spawns in practice so this is unlikely.
- **Unloading vs eviction**: TTL-based unloading still runs independently. With the eviction wrapper, TTL is effectively irrelevant for concurrency — the old model never has a TTL to expire because it's killed on the next request.
- **New model additions**: Any new model added to the config MUST use the wrapper, or it won't evict previous models.
- **Kimi K2.6 models missing eviction wrapper** → The Kimi K2.6 entries (synthclaw-35bkimi-128k/256k/512k) historically omitted `evict-and-launch.sh` based on an incorrect race-condition theory. In practice, without the wrapper, these models load on first request and never unload — TTL eviction does not work for direct-launched entries. The process stays resident indefinitely, consuming ~8.7GB RAM and significant CPU even with zero active requests. Always use the eviction wrapper for ALL models in the llama-swap pool. See `llama-swap` skill `references/kimi-k2.6-deployment.md` for corrected config.
- **Hermes fallback chain TTL leak**: When local models are in Hermes `fallback_providers`, unsupported API calls (e.g., `/v1/memories/retrieve` → 404) still count as activity and reset TTL. Models in the fallback chain never cool down. Either remove local models from fallback (use only via `-m` flag) or put the lightest model first. See `llama-swap` skill "Hermes fallback_providers causes TTL leaks" pitfall.
