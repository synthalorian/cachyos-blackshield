# On-Demand Auto-Start Pattern for llama-swap

## Problem

You want local models to start automatically when you type `claw 35bkimi` or `hermes 35bkimi`, but you don't want llama-swap running in the background 24/7 eating VRAM.

## Why socket activation doesn't work

llama-swap is a Go binary that binds to its listen port internally (`--listen localhost:8080`). It does NOT support systemd's `LISTEN_FDS` socket inheritance protocol. If you try socket activation:

1. systemd creates the socket on port 8080
2. llama-swap starts and tries to bind port 8080 itself
3. `bind: address already in use` → crash loop

See `references/socket-activation-failure.md` for full details.

## Solution: wrapper-script auto-start

Create a helper script that checks if llama-swap is running, starts it if not, waits for readiness, then returns. Call this from your CLI wrappers before routing to local models.

### Step 1: Create the helper

Place at `~/.local/bin/ensure-llama-swap` (see [scripts/ensure-llama-swap.sh](../scripts/ensure-llama-swap.sh) in this skill for the full script):

```bash
#!/usr/bin/env bash
if ! curl -s --max-time 2 http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
    echo "🦞 llama-swap not running, starting..." >&2
    systemctl --user start llama-swap.service
    for i in {1..30}; do
        if curl -s --max-time 2 http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
            echo "🦞 llama-swap ready" >&2
            exit 0
        fi
        sleep 1
    done
    echo "🦞 ERROR: llama-swap failed to start" >&2
    exit 1
fi
```

Make it executable: `chmod +x ~/.local/bin/ensure-llama-swap`

Key design choices:
- **Prints to stderr** (`>&2`) so stdout stays clean for piped tools
- **Uses curl health check** not `systemctl is-active` — the service can be "active" before the port is actually listening
- **30-second timeout** with 1s polling — enough for large models to initialize
- **Idempotent** — safe to call multiple times; does nothing if already running

### Step 2: Patch your CLI wrappers

**For `claw` wrapper** (`~/.local/bin/claw`):

```bash
# In the local model branch, before exec:
if [ "$USE_LOCAL" = true ]; then
    ensure-llama-swap          # <-- add this line
    export OPENAI_API_KEY="$LOCAL_API_KEY"
    export OPENAI_BASE_URL="$LOCAL_BASE_URL"
    exec "$REAL_CLAW" --model "openai/$RESOLVED" "$@"
fi
```

**For `hermes` wrapper** (`~/.local/bin/hermes`):

```bash
# In the shorthand resolution branch, before exec:
if [[ " ${!SHORTHAND_MAP[@]} " =~ " $1 " ]]; then
    RESOLVED="${SHORTHAND_MAP[$1]}"
    shift
    ensure-llama-swap          # <-- add this line
    # ... rest of exec
fi
```

### Step 3: Ensure systemd service is configured for manual start

The service should NOT auto-start on login. Disable any prewarm or auto-start:

```bash
systemctl --user disable llama-swap-prewarm.service  # if exists
systemctl --user disable llama-swap.service
systemctl --user stop llama-swap.service
```

Service file (`~/.config/systemd/user/llama-swap.service`) should use `Restart=on-failure` (not `always`) so it doesn't respawn if you intentionally stop it:

```ini
[Service]
Type=simple
ExecStart=/home/synth/go/bin/llama-swap --config /home/synth/llama.cpp/llama-swap/config.yaml --listen localhost:8080
Restart=on-failure
RestartSec=5
```

## Result

- `claw 35bkimi` → auto-starts llama-swap → routes to local model
- `hermes 35bkimi` → auto-starts llama-swap → launches Hermes TUI with local model
- No background server when not in use
- Manual start still works: `systemctl --user start llama-swap.service`

## Variations

**Faster start for known-warm models:** If you know a specific model is already loaded (e.g., via TTL), skip the full health check and just check the proxy port:
```bash
curl -s --max-time 1 http://127.0.0.1:8080/v1/models | grep -q "$MODEL" && exit 0
```

**Parallel pre-warm:** For scripts that need multiple models warm at once, fire requests in parallel (see main SKILL.md pre-warming section).

**Desktop integration:** Add `ensure-llama-swap` to a Hyprland keybinding or Walker launcher command for one-key local model access.
