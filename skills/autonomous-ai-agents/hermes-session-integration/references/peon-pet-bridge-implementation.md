# Peon-Pet Bridge Implementation Notes

Validated Pattern 2 (Format Translator) — end-to-end working as of 2026-05-19.

## Architecture

```
~/.hermes/sessions/*.jsonl
    ↓ hermes-bridge.py (systemd user service)
~/.claude/projects/hermes/<uuid>.jsonl
    ↓ peon-pet JsonlWatcher (polls every 500ms)
peon-pet animations
```

## Bridge Script

**Location:** `/home/synth/projects/peon-pet/hermes-bridge.py` (~600 lines)

Key behaviors:
- Watches `~/.hermes/sessions/` for new/modified files
- Generates deterministic UUID v5 from Hermes filenames for session mapping
- Translates Hermes flat JSONL → Claude Code nested JSONL format
- Tracks per-file offsets to only process new lines
- Output directory: `~/.claude/projects/hermes/`
- Supports `--once` flag for single-pass testing
- Runs continuously with inotify/watchdog for real-time translation

## Session File Mapping

| Hermes source | Translated output |
|---------------|-------------------|
| `~/.hermes/sessions/20260519_193455_f1d131.jsonl` | `~/.claude/projects/hermes/<uuid-v5>.jsonl` |

The UUID is generated deterministically from the Hermes filename so the mapping is stable across bridge restarts.

## Event Flow (validated)

1. User sends message in Hermes → `role: "user"` record appended to session JSONL
2. Bridge detects new line → translates to `type: "user"` with nested `message` object
3. Peon-pet JsonlWatcher reads translated line → emits `UserPromptSubmit` → pet starts typing animation
4. Agent responds with tool calls → bridge translates → pet keeps typing
5. Agent finishes (`finish_reason: "stop"`) → bridge appends `type: "system", subtype: "turn_duration"` → pet celebrates
6. Tool error → bridge detects error content → pet shows annoyed animation

## Verification Commands

```bash
# Check bridge is running
systemctl --user status hermes-peon-bridge.service

# Check translated files exist and are growing
ls -la ~/.claude/projects/hermes/
watch -n1 'wc -l ~/.claude/projects/hermes/*.jsonl'

# Single-pass test
python3 /home/synth/projects/peon-pet/hermes-bridge.py --once

# Bridge logs
journalctl --user -u hermes-peon-bridge.service -f
```

## Peon-Pet Launch

```bash
cd /home/synth/projects/peon-pet
npx electron .
```

No `bun`. No `npm start` (the package.json scripts may use bun).
