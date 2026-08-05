---
name: openclaw-tui-diagnostics
description: "Diagnose OpenClaw TUI launch failures: TTY requirements, launch path/wrapper drift, gateway vs embedded local mode, and first-screen status interpretation."
metadata:
  hermes:
    tags: [openclaw, tui, troubleshooting, terminal]
---

# OpenClaw TUI Diagnostics

Use this when `openclaw`, `openclaw tui`, or `openclaw tui --local` appears not to launch, exits immediately, hangs on `connecting`/`starting up`, or behaves differently between terminals and scripts.

## First Checks

Run these before changing config:

```bash
tty
echo "$TERM"
type -a openclaw
command -v openclaw
openclaw --version
systemctl --user status openclaw-gateway.service --no-pager
```

Do not assume `~/.local/bin/openclaw` exists or that PATH uses it. OpenClaw may resolve directly to `~/.npm-global/bin/openclaw` or a mise Node bin. Wrapper-specific fixes only apply after `type -a openclaw` proves the wrapper is the file being executed.

## Classify the Failure

### 1. Non-TTY execution

Hard failure text:

```text
OpenClaw TUI needs an interactive TTY. Use `openclaw agent --local ...` for automation.
```

This is expected outside an interactive terminal: scripts, pipes, `fish -c`, CI, cron, and some agent tool PTYs are not real TTYs. Verify with `tty`. To reproduce real-terminal behavior from automation, allocate a PTY:

```bash
script -qfec 'openclaw' /tmp/openclaw.typescript
```

If `timeout` kills that command, exit `124` means the TUI stayed running; it is not a crash.

### 2. Gateway TUI vs embedded local TUI

Bare `openclaw` commonly opens the gateway websocket TUI:

```text
openclaw tui - ws://127.0.0.1:18789 - agent main - session main
connecting | idle
```

Force embedded local runtime with:

```bash
openclaw tui --local
```

First screen:

```text
openclaw tui - local embedded - agent main - session main
local ready | idle
```

`local ready` means local embedded runtime mode, not necessarily a local model. Read the detailed status line for the model, e.g. `agent main | session main | openai/gpt-5.5`.

### 3. Hangs after the frame draws

If the border draws but status sits on `connecting`, check gateway health:

```bash
systemctl --user status openclaw-gateway.service --no-pager
journalctl --user -u openclaw-gateway.service -n 80 --no-pager
```

Restart only after capturing logs:

```bash
systemctl --user restart openclaw-gateway.service
```

If status sits on `starting up` in `--local` mode, capture the PTY transcript and compare the detailed status line before assuming a model/auth failure.

## Pitfalls

- Do not treat missing `~/.local/bin/openclaw` as the root cause by itself; it only matters if the user expected wrapper routing or model shorthand.
- Do not infer launch failure from a timeout in a PTY test. A TUI that remains open is supposed to keep running.
- Do not infer model/provider from `local ready` or `pondering`. Use the detailed status line and gateway logs.
- Keep wrapper subcommand advice conditional: verify the active binary path first.

## References

- `references/tui-launch-transcripts.md` — compact transcript patterns and command outputs from a real diagnostic pass.
