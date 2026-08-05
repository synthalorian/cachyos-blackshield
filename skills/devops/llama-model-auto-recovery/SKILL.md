---
name: llama-model-auto-recovery
description: Auto-recovery protocol for llama-swap models — clears failed-state caches, manages TTL-based memory release, and watches for orphaned child processes.
---

# llama-model-auto-recovery

Use this skill when llama-swap models enter "failed state" after manual SIGTERM/SIGKILL, or when you need to understand the TTL-based memory release protocol.

## The Problem

Manually killing a llama-swap child process (`llama-server`) leaves it in a **failed-state cache** inside llama-swap. The daemon refuses all subsequent requests to that model with:
```
unable to start process: process is in a failed state and can not be restarted
```

Restarting llama-swap (which clears the in-memory cache) may then spawn a **new** child on the same port while the **old** orphan still holds it → port conflict.

## The Protocol

### Immediate recovery (manual)

```bash
# 1. Kill any orphan llama-server processes still holding ports
pkill -SIGTERM llama-server 2>/dev/null || true
sleep 2

# 2. Verify ports are free
ss -tlnp | grep -E '808[0-9]|809[0-9]|810[0-9]'

# 3. Restart llama-swap (clears failed-state cache)
systemctl --user restart llama-swap
sleep 3

# 4. Verify recovery
curl -s http://127.0.0.1:8080/v1/models | grep "error" || echo "clean"

# 5. Pre-warm the 35bkimi model
curl -s -m 180 -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"synthclaw-35bkimi-128k","messages":[{"role":"user","content":"ping"}],"max_tokens":1}'
```

### Auto-recovery (cron watchdog)

A `no_agent` cron job runs every 5 minutes at `~/.hermes/scripts/llama-swap-watchdog.sh`:

1. **Ping check** — hits `/v1/models` on localhost:8080
2. **Failed-state detection** — greps response for `error`/`failed`/`unavailable`
3. **Cleanup** — kills orphan `llama-server` processes, waits 2s for VRAM release
4. **Restart** — `systemctl --user restart llama-swap` clears the cache
5. **Deep health check** — every 6th run (~30 min), sends a 1-token test request to 35bkimi

### Memory release (TTL)

- `synthclaw-35bkimi-128k`: **TTL = 480 seconds** (8 minutes)
- After 8 minutes of inactivity, llama-swap SIGTERMs the child
- VRAM is released back to the GPU
- Next request to the model spawns a fresh instance (on-demand)

## Key Files

- **Watchdog script**: `/home/synth/.hermes/scripts/llama-swap-watchdog.sh`
- **llama-swap config**: `/home/synth/llama.cpp/llama-swap/config.yaml`
- **Systemd service**: `~/.config/systemd/user/llama-swap.service`
- **Reference — systemd dependency traps**: `references/systemd-dependency-trap.md`

## Hermes Coverage

Hermes systemd services (`hermes-gateway`, `hermes-proxy`) already have `Restart=always` and auto-recover within 5 seconds of any crash or SIGTERM. The CLI session is user-initiated and must be manually restarted.

## OpenClaw Gateway (claw) Coverage

The watchdog also checks `openclaw-gateway.service` every 5 minutes. If the service is down (e.g. config validation failure, crash loop), it:
1. Runs `systemctl --user reset-failed openclaw-gateway.service` — clears the systemd `start-limit-hit` counter
2. Runs `systemctl --user restart openclaw-gateway.service` — attempts restart

### Common failure: invalid `thinkingFormat`

If the gateway failed with `Invalid config at ~/.openclaw/openclaw.json` pointing to a `thinkingFormat` value, see the `openclaw` skill for the allowed values list and fix procedure.

## Pitfalls

- **Failed-state cache is in-memory** — only a daemon restart clears it. `pkill llama-swap` without systemd causes a respawn loop (Restart=always). Always use `systemctl --user restart llama-swap`.
- **Orphan children survive restart** — systemd `Restart=always` on llama-swap only restarts the daemon, NOT its children. Always `pkill llama-server` before restart.
- **TTL expiry vs manual kill** — TTL-based unloads are clean and don't trigger failed state. Manual `kill <pid>` sends SIGTERM which can trigger failed state because the request proxy sees "connection refused" before the daemon notices the child is gone.
- **Health check race** — New spawns can take 40+ seconds to load the model. The config has `healthCheckTimeout: 300` to give plenty of room. If you see repeated "failed to check health", check VRAM availability.
- **systemd `start-limit-hit`** — After 5 rapid failures in 60 seconds, systemd refuses further restart attempts. You must clear the counter with `systemctl --user reset-failed <service>` before the service will restart again. This applies to ANY systemd service with `Restart=always` that fails to start — llama-swap, openclaw-gateway, Hermes gateway, etc.
- **The `BindsTo` dependency trap** — Disabling `llama-swap.service` alone is useless if `llama-swap-prewarm.service` (or any companion unit) is enabled and has `BindsTo=llama-swap.service`. The companion starts at login via `default.target` and **pulls up** the main service as a dependency. Always check `systemctl --user list-unit-files | grep llama` and disable ALL related units if you want the service to stay down. To permanently stop auto-start: `systemctl --user disable llama-swap-prewarm.service && systemctl --user stop llama-swap-prewarm.service && systemctl --user stop llama-swap.service`.
- **Hermes does NOT auto-start llama-swap on demand** — If llama-swap is down and you switch to a local model in Hermes, you'll get a connection refused error. Hermes has no socket-activation or auto-start logic for local providers. You must start the service manually (`systemctl --user start llama-swap.service`) or keep it auto-starting on login.
