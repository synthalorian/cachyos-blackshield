# Socket Activation Failure with llama-swap

## What was attempted

Systemd socket activation was set up so llama-swap would start on-demand when something connected to port 8080:

```ini
# ~/.config/systemd/user/llama-swap.socket
[Socket]
ListenStream=127.0.0.1:8080
Accept=no
```

```ini
# ~/.config/systemd/user/llama-swap.service (modified)
[Unit]
Requires=llama-swap.socket
After=llama-swap.socket
```

## Why it failed

llama-swap does NOT support systemd's `LISTEN_FDS` / `SD_LISTEN_FDS_START` socket inheritance protocol. When started via socket activation:

1. systemd creates the socket and binds port 8080
2. systemd starts llama-swap.service
3. llama-swap parses `--listen localhost:8080` and tries to `bind()` port 8080 itself
4. `bind: address already in use` → exits with status 1
5. systemd restarts the service (`Restart=on-failure`) → loop forever

Log pattern:
```
llama-swap listening on localhost:8080
Server error: listen tcp 127.0.0.1:8080: bind: address already in use
```

## Recovery

1. Stop the failing service: `systemctl --user stop llama-swap.service`
2. Remove socket activation files:
   ```bash
   rm ~/.config/systemd/user/llama-swap.socket
   systemctl --user daemon-reload
   systemctl --user disable llama-swap.socket
   ```
3. Revert service file to standard config (no `Requires=llama-swap.socket`)
4. Decide on alternative on-demand strategy (see below)

## What DOES work for on-demand

Since socket activation is off the table, here are the practical alternatives:

### Option 1: Manual start (simplest)
```bash
systemctl --user start llama-swap   # when you need it
systemctl --user stop llama-swap    # when you're done
```

### Option 2: Wrapper function in shell config
```bash
llm-local() {
    if ! ss -tlnp | grep -q ':8080'; then
        systemctl --user start llama-swap
        sleep 2
    fi
    curl -s http://127.0.0.1:8080/v1/models
}
```

### Option 3: Hermes provider-only activation
Keep llama-swap stopped by default. Hermes is configured with `llama-swap` as a provider at `http://127.0.0.1:8080/v1`, but the **default model is a cloud provider** (`kimi-k2.6` via `kimi-coding`). Local models only activate when explicitly requested:

```bash
hermes -m synthclaw-35bkimi-128k --provider llama-swap "prompt here"
```

If llama-swap is down, Hermes returns a connection error — the signal to start it. This is intentional manual control, not automatic.

## Key insight

Socket activation requires application cooperation. The app must detect `LISTEN_FDS` in its environment and use `systemd-socket-activate` or `sd_listen_fds()` to inherit the pre-bound socket instead of calling `bind()` itself. llama-swap (Go binary, custom flag parsing) does not implement this. Most Go HTTP servers don't unless explicitly built with `github.com/coreos/go-systemd/activation`.

## Applicability

This lesson generalizes to ANY service that binds its own port:
- **Works with socket activation:** nginx, sshd, dockerd, systemd-resolved, cupsd — these are designed to inherit FDs
- **Does NOT work:** Any app that calls `listen()` / `bind()` itself without checking `LISTEN_FDS` — most custom Go binaries, Python Flask/FastAPI default servers, Node.js Express, etc.

When in doubt: check if the app has a `--socket-activation` flag or mentions `LISTEN_FDS` in docs. If not, assume it won't work.
