# OpenClaw TUI Launch Transcripts

Compact patterns from a real launch diagnostic where the user reported that the OpenClaw TUI did not launch.

## Observed path and service state

```text
type -a openclaw
openclaw is /home/synth/.npm-global/bin/openclaw

openclaw --version
OpenClaw 2026.7.1-2 (0790d9f)

systemctl --user status openclaw-gateway.service
Active: active (running)
```

The old wrapper path `~/.local/bin/openclaw` was absent, so wrapper-specific routing advice did not apply until the active path was verified.

## Non-TTY hard failure

Running bare `openclaw` without a real TTY produced:

```text
OpenClaw TUI needs an interactive TTY. Use `openclaw agent --local ...` for automation.
```

This is a launch-context failure, not a broken install.

## Real PTY probe

Using `script` allocated a real PTY:

```bash
TERM=xterm-256color timeout 12 script -qfec 'openclaw' /tmp/openclaw-bare.typescript
TERM=xterm-256color timeout 12 script -qfec 'openclaw tui --local' /tmp/openclaw-tui-local.typescript
```

Both commands timed out with exit `124`, meaning the TUI stayed alive until killed. First-screen patterns:

```text
openclaw tui - ws://127.0.0.1:18789 - agent main - session main
connecting | idle
agent main | session main | unknown | tokens ?
...
gateway connected | idle
agent main | session main | openai/gpt-5.5 | think medium | tokens ?/272k
```

```text
openclaw tui - local embedded - agent main - session main
starting up • 0s | local ready
agent main | session main | unknown | tokens ?
...
local ready | idle
agent main | session main | openai/gpt-5.5 | tokens ?/400k
```

Interpretation: binary and gateway were healthy; the useful distinction was TTY context plus gateway-vs-embedded mode.
