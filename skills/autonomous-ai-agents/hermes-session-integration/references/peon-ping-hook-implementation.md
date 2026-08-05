# peon-ping Native Hook Implementation

Validated implementation of peon-ping (Warcraft III voice notifications) as a Hermes native Python hook.

## Architecture

```
Hermes gateway lifecycle event
  → HookRegistry.emit("agent:end", {...})
    → peon-ping/handler.py handle("agent:end", context)
      → _map_event() → translate to Claude Code event format
        → _fire_peon() → pipe JSON to peon.sh
          → peon.sh → plays sound via pw-play/paplay
```

## Files

- `~/.hermes/hooks/peon-ping/HOOK.yaml` — manifest declaring events
- `~/.hermes/hooks/peon-ping/handler.py` — async handler

## Event Mapping

| Hermes Event | Claude Code Event | peon-ping Sound Category |
|---|---|---|
| `session:start` | `SessionStart` | session.start (greeting) |
| `agent:start` | `UserPromptSubmit` | task.acknowledge |
| `agent:end` (ok) | `Stop` | task.complete |
| `agent:end` (error) | `PostToolUseFailure` | task.error |
| `agent:step` | (ignored) | — |
| `session:end` | `Stop` | session.end |

## Key Design Decisions

### agent:step is ignored
agent:step fires every tool-call iteration. A complex task might trigger 20+ steps. Playing a sound for each would be unbearable. Only acknowledge start/end/error events.

### 3-second cooldown on agent:start
The acknowledge sound fires once when the agent starts processing. Without cooldown, rapid gateway message processing could stack sounds. Implemented via `_cooldown_ok("acknowledge")` check.

### Error detection heuristic
agent:end doesn't have an explicit success/error flag. The handler checks the response text for signals: `["error", "failed", "exception", "traceback"]`. This catches most error responses without false positives on normal responses.

### Async subprocess execution
`_fire_peon()` runs in a thread pool executor via `loop.run_in_executor()` so the blocking subprocess call doesn't stall the gateway's event loop. 10-second timeout prevents peon.sh hangs from blocking anything.

### peon.sh location resolution
Mirrors the Claude Code layout: `$CLAUDE_PEON_DIR` or `$CLAUDE_CONFIG_DIR/hooks/peon-ping` or `~/.claude/hooks/peon-ping/peon.sh`. peon-ping is already installed at this path on synth's system.

## peon-ping Config

Config at `~/.claude/hooks/peon-ping/config.json`:
- `default_pack`: currently `wc3_peon` (Warcraft III Peon voice lines)
- `pack_rotation`: `["sc_kerrigan", "sc_battlecruiser"]` (Starcraft voices)
- `volume`: 0.3
- `enabled`: true
- `linux_audio_player`: "" (auto-detects pw-play on PipeWire)

## Linux Audio Pipeline (Omarchy)

1. handler.py pipes JSON to peon.sh
2. peon.sh reads config, resolves sound file from active pack
3. peon.sh calls `pw-play --volume 0.3 <file.mp3>` (PipeWire)
4. Fallback chain: pw-play → paplay → ffplay → mpv → aplay

## Testing

```bash
# Direct peon.sh test
echo '{"hook_event_name":"SessionStart","notification_type":"","cwd":"/home/synth","session_id":"hermes-test","permission_mode":""}' | bash ~/.claude/hooks/peon-ping/peon.sh

# Handler smoke test
cd ~/.hermes/hooks/peon-ping
python3 -c "
import asyncio
from handler import handle
asyncio.run(handle('session:start', {
    'platform': 'cli',
    'user_id': 'synth',
    'session_id': 'test',
    'session_key': '/home/synth',
}))
"
```

## Hook Discovery

Hermes gateway discovers hooks at startup:
1. Scans `~/.hermes/hooks/*/`
2. Each directory needs `HOOK.yaml` + `handler.py`
3. HOOK.yaml must have `name` and `events` (list of event strings)
4. handler.py must export top-level `async def handle(event_type, context)`
5. Errors in hooks are caught and logged, never block the gateway

Hook is loaded on gateway startup. To activate immediately: restart the gateway or start a new session.
