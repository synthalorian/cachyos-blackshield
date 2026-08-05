---
name: hermes-session-integration
description: "Bridge external tools and applications to Hermes by watching/transforming its session JSONL data. Covers schema mapping, relay servers, and real-time event translation patterns."
version: 1.0.0
author: synthclaw
license: MIT
tags: [hermes, session, jsonl, integration, bridge, event-stream, peon-pet]
---

# Hermes Session Integration

Build bridges between Hermes Agent's session data and external tools (desktop pets, dashboards, notification systems, monitoring) by reading and transforming the `~/.hermes/sessions/*.jsonl` transcript files.

## When to Use

- Connecting a desktop pet (peon-pet) or visual monitor to Hermes activity
- Building dashboards that track agent session state in real time
- Translating Hermes events into another tool's expected format
- Any task that requires observing Hermes sessions from outside the agent loop

## Hermes Session JSONL Schema

Files: `~/.hermes/sessions/YYYYMMDD_HHMMSS_<hex>.jsonl`

Each line is a JSON object. Key fields:

| Field | Type | Present on | Description |
|-------|------|------------|-------------|
| `role` | string | all | `"user"`, `"assistant"`, or `"tool"` |
| `content` | string | all | Message text (may be empty string for tool_calls-only turns) |
| `timestamp` | string | all | ISO 8601 (e.g. `"2026-05-19T18:54:45.890869"`) |
| `tool_calls` | array | assistant | OpenAI-format tool calls when agent invokes tools |
| `tool_call_id` | string | tool | Matches the tool_call id |
| `tool_name` | string | tool | Name of the tool that was called |
| `name` | string | tool | Same as tool_name |
| `finish_reason` | string | assistant | `"stop"` (done) or `"tool_calls"` (more work) |
| `reasoning` | string/null | assistant | Chain-of-thought content if model supports it |
| `reasoning_content` | string/null | assistant | Alternative reasoning field |
| `message_id` | string | some | Internal message ID |

### Event Mapping (Hermes → peon-pet)

| Hermes signal | Detection logic | peon-pet event |
|---------------|----------------|----------------|
| Session start | New .jsonl file appears in sessions dir | `SessionStart` → waking |
| User prompt | `role: "user"` record | `UserPromptSubmit` → typing |
| Agent working | `role: "assistant"` with `tool_calls` | `UserPromptSubmit` → typing (keep typing anim) |
| Task complete | `role: "assistant"` with `finish_reason: "stop"` | `Stop` → celebrate |
| Tool failure | `role: "tool"` with error content | `PostToolUseFailure` → annoyed |
| Long tool wait | `tool_calls` without matching tool result for >7s | `PermissionRequest` → alarmed |

## Integration Patterns

### Pattern 1: Relay Server (recommended)

Run a lightweight HTTP server that watches `~/.hermes/sessions/` and serves peon-pet's expected relay format:

```
GET http://127.0.0.1:19998/state
→ {"sessions": {"<uuid>": {"timestamp": 1700000000, "event": "UserPromptSubmit", "cwd": "/path"}}}
```

peon-pet polls this every 5 seconds. The relay:
1. Uses `inotify`/`watchdog` to tail session files
2. Tracks session state per file (offset, last event, UUID mapping)
3. Maps Hermes JSONL roles to peon-pet event names
4. Serves the state JSON on port 19998

Advantages: No forking, no modifying peon-pet source, runs alongside Hermes.

### Pattern 2: Format Translator

Write translated JSONL files to `~/.claude/projects/<dir>/<uuid>.jsonl` in Claude Code's format so peon-pet's built-in JSONL watcher reads them natively. Requires understanding Claude Code's JSONL schema (see references).

### Pattern 3: Hermes Webhook

Use Hermes' built-in webhook system (`hermes webhook subscribe`) to POST events to a local endpoint that translates and forwards to peon-pet's relay format. Good for gateway-mode Hermes where session files may be on a remote server.

## Session ID Handling

Hermes session filenames use `YYYYMMDD_HHMMSS_<8char-hex>.jsonl` format — NOT UUIDs. peon-pet validates session IDs as UUIDs (`/^[0-9a-f]{8}-...$/i`).

Options:
1. Generate a deterministic UUID v5 from the Hermes filename (stable across restarts)
2. Parse the hex suffix and pad to UUID format
3. Patch peon-pet's `isValidSessionId()` to accept Hermes-format IDs

## Linux/Wayland Notes for Electron-based tools (peon-pet)

peon-pet is Electron + Three.js, designed for macOS. To run on Linux/Hyprland:

- **Ozone flags** — add these in `main.js` before `app.whenReady()`:
  ```js
  app.commandLine.appendSwitch('ozone-platform-hint', 'auto');
  app.commandLine.appendSwitch('enable-features', 'UseOzonePlatform');
  ```
  Use `ozone-platform-hint=auto` (not `wayland` hardcode) so it works under both X11 and Wayland without manual switching.

- **app.dock guards** — wrap ALL `app.dock.*` calls:
  ```js
  if (process.platform === 'darwin' && app.dock) {
    app.dock.setIcon(iconPath);
    app.dock.setMenu(menu);
  }
  // Linux fallback:
  if (process.platform === 'linux' && mainWindow) {
    mainWindow.setIcon(iconPath);
  }
  ```

- **No launchctl** — `install.sh` uses macOS `launchctl`. Use systemd user service (see `templates/hermes-peon-bridge.service`) or `~/.config/autostart/` .desktop file instead.

- **Multi-monitor** — `screen.getPrimaryDisplay()` may return incorrect dimensions on multi-monitor Wayland — test thoroughly.

- **Launch** — `npx electron .` works from the project directory. Do NOT use `bun` (blocked on this system).

## Deployment (Pattern 2 — Format Translator)

When using Pattern 2 with a Python bridge script:

1. **Systemd user service** — run the bridge as a systemd user service for auto-restart and login persistence:
   ```
   ~/.config/systemd/user/hermes-peon-bridge.service
   ```
   See `templates/hermes-peon-bridge.service` for a known-good template.

2. **Enable and start:**
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now hermes-peon-bridge.service
   ```

3. **Logs:** `journalctl --user -u hermes-peon-bridge.service -f`

4. **Peon-pet itself** — launch separately via `npx electron .` or a .desktop autostart entry.

### Pattern 4: Native Python Hooks (recommended for notification/alert tools)

Hermes has a built-in event hook system at `~/.hermes/hooks/`. Each hook is a directory with `HOOK.yaml` (manifest) + `handler.py` (async handler). The gateway discovers and loads these at startup, firing `handle(event_type, context)` at every lifecycle point.

**When to use:** Sound notifications (peon-ping), desktop alerts, logging, metrics — any tool that needs to react to agent lifecycle events without reading session files.

**Advantages over JSONL bridge:**
- No daemon, no file watching, no systemd service needed
- Zero latency — handler is called directly in the gateway process
- Automatic lifecycle management (loaded at startup, errors are caught and logged)
- Runs in the gateway's event loop (async)

**Structure:**
```
~/.hermes/hooks/<hook-name>/
├── HOOK.yaml       # name, description, events list
└── handler.py      # async def handle(event_type, context): ...
```

**HOOK.yaml:**
```yaml
name: my-hook
description: What this hook does
events:
  - session:start
  - agent:start
  - agent:end
  - agent:step
  - session:end
```

**handler.py:**
```python
import asyncio, json, subprocess
from typing import Any, Dict

async def handle(event_type: str, context: Dict[str, Any]) -> None:
    # Map to your tool's event format and fire
    if event_type == "session:start":
        await _fire({"event": "ready", "session_id": context.get("session_id")})

async def _fire(payload: dict) -> None:
    loop = asyncio.get_running_loop()
    await loop.run_in_executor(None, _run_subprocess, payload)

def _run_subprocess(payload: dict) -> None:
    subprocess.run(["your-tool"], input=json.dumps(payload), timeout=10)
```

**Available events and their context:**

| Event | Context keys | When fired |
|-------|-------------|------------|
| `gateway:startup` | `{}` | Gateway process starts |
| `session:start` | `platform`, `user_id`, `session_id`, `session_key` | New session created |
| `agent:start` | `platform`, `user_id`, `chat_id`, `session_id`, `message` | Agent begins processing |
| `agent:step` | `platform`, `user_id`, `session_id`, `iteration`, `tool_names`, `tools` | Each tool-call iteration |
| `agent:end` | `platform`, `user_id`, `chat_id`, `session_id`, `message`, `response` | Agent finishes |
| `session:end` | `session_id` | Session ends (/new, /reset) |
| `session:reset` | `session_id` | Session reset completed |
| `command:*` | `platform`, `user_id`, `session_id`, `command`, `args` | Any slash command |

**Pattern: peon-ping integration**
The peon-ping hook maps Hermes events to Claude Code event names and pipes JSON to `peon.sh`. See `references/peon-ping-hook-implementation.md` for the full validated handler.

## Choosing a Pattern

| Pattern | Best for | Requires daemon? | Latency |
|---------|----------|-------------------|---------|
| 1. Relay Server | External HTTP consumers (dashboards, pets) | Yes (relay server) | ~5s poll |
| 2. Format Translator | Tools that read files natively (peon-pet) | Yes (bridge + systemd) | ~0.5-2s |
| 3. Webhook | Remote tools, multi-host setups | No (Hermes POSTs out) | ~1s |
| 4. Native Python Hook | Sound/alert/notification tools | No | Instant |

## References

- `references/hermes-and-claude-code-jsonl-schemas.md` — detailed schema comparison for format translation
- `references/peon-pet-bridge-implementation.md` — validated Pattern 2 implementation notes (bridge script, session mapping, event flow)
- `references/peon-ping-hook-implementation.md` — validated Pattern 4 implementation (native Python hook for peon-ping sound notifications)
- `references/hermes-peon-ping-bash-adapter.md` — bash adapter (hermes.sh) modeled after openclaw.sh for direct invocation from Hermes tools/scripts
- `templates/hermes-hook-HOOK.yaml` — starter HOOK.yaml manifest
- `templates/hermes-hook-handler.py` — starter handler.py with event mapping scaffolding

## Pitfalls

- **bun is blocked on this system** — use `npm install` for peon-pet setup, never `bun install`
- **Duplicate bridge processes** — before enabling the systemd service, kill any manually-started bridge instances (`pkill -f hermes-bridge`). Multiple translators writing the same output files causes corruption
- **peon-pet UUID validation** — session IDs must be UUID format or the relay path won't work without patching
- **Session file rotation** — Hermes writes new files per session, doesn't append to old ones. Watchers must detect new files, not just tail existing ones
- **Timestamp formats differ** — Hermes uses ISO 8601 strings, peon-pet relay expects Unix seconds. Must convert: `int(datetime.fromisoformat(ts).timestamp())`
- **Content field can be empty string** — when assistant responds with only tool_calls, `content` is `""`. Don't treat as an error
- **Native hooks load at gateway startup only** — adding a new hook to `~/.hermes/hooks/` requires a gateway restart to take effect. No hot-reload
- **handler.py must use `async def handle()`** — the hook registry imports and calls it as a coroutine. A sync function will crash at the first `await`
- **agent:end has no explicit error flag** — the context dict has `response` text but no `success`/`error` boolean. Use heuristic detection (scan for "error", "failed", "traceback" in response text) or check if response is empty
- **agent:step fires every tool iteration** — NEVER play sounds or send notifications on agent:step without heavy cooldown logic. A 20-step task fires 20 events in seconds. Ignore it entirely for notification use cases
- **Subprocess calls must run in executor** — blocking calls (subprocess.run, requests.get) will stall the gateway event loop. Always wrap with `loop.run_in_executor(None, ...)`
