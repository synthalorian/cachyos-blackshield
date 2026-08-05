# JSONL Schema Comparison: Hermes vs Claude Code

## Hermes Session JSONL

**Location:** `~/.hermes/sessions/YYYYMMDD_HHMMSS_<hex>.jsonl`

Each line is a standalone JSON object. Three roles cycle: user → assistant → tool → assistant → ...

### User message
```json
{
  "role": "user",
  "content": "The user's message text",
  "timestamp": "2026-05-19T18:54:45.890869"
}
```

### Assistant message (text only)
```json
{
  "role": "assistant",
  "content": "Agent's response text",
  "reasoning": null,
  "reasoning_content": null,
  "finish_reason": "stop",
  "timestamp": "2026-05-19T18:54:45.890869"
}
```

### Assistant message (tool calls)
```json
{
  "role": "assistant",
  "content": "",
  "reasoning": null,
  "finish_reason": "tool_calls",
  "tool_calls": [{
    "id": "call_d9a3f0aa72ab49c6bafe0d75",
    "call_id": "call_d9a3f0aa72ab49c6bafe0d75",
    "response_item_id": "fc_d9a3f0aa72ab49c6bafe0d75",
    "type": "function",
    "function": {
      "name": "terminal",
      "arguments": "{\"command\":\"ls -la\"}"
    }
  }],
  "timestamp": "2026-05-19T18:54:45.890869"
}
```

### Tool result
```json
{
  "role": "tool",
  "name": "terminal",
  "tool_name": "terminal",
  "content": "{ \"output\": \"...\", \"exit_code\": 0 }",
  "tool_call_id": "call_d9a3f0aa72ab49c6bafe0d75",
  "timestamp": "2026-05-19T18:54:45.890869"
}
```

### Key characteristics
- All fields are flat — no nested `message` object
- `content` is always a string (JSON-encoded for tool results)
- Timestamps are ISO 8601 strings with microseconds
- No `type` field — `role` is the discriminator
- No `cwd` or project path in the JSONL — derived from filename/session metadata
- No `sessionId` in individual records — the filename IS the session ID

---

## Claude Code Session JSONL

**Location:** `~/.claude/projects/<encoded-path>/<uuid>.jsonl`

Each line has a `type` field as the primary discriminator.

### Types observed
- `queue-operation` — internal queue management
- `user` — user message with `message.role` and `message.content`
- `assistant` — assistant message with nested message structure
- `system` — system events (turn_duration, etc.)
- `progress` — agent_progress for sub-agents

### User message
```json
{
  "parentUuid": "...",
  "isSidechain": false,
  "promptId": "...",
  "type": "user",
  "message": {
    "role": "user",
    "content": "text or array of content blocks"
  }
}
```

### System event (turn end)
```json
{
  "type": "system",
  "subtype": "turn_duration",
  "durationMs": 1234,
  ...
}
```

### Key characteristics
- Nested `message` object with its own `role` and `content`
- `content` can be a string OR an array of typed blocks: `[{type: "text", text: "..."}, {type: "tool_use", ...}]`
- Has `parentUuid`, `isSidechain`, `promptId` for conversation tree tracking
- `type: "system", subtype: "turn_duration"` signals turn completion (peon-pet maps to `Stop`)
- `sessionId` appears in queue-operation records
- Subdirectory structure: `<uuid>/subagents/agent-<agentId>.jsonl` for background agents
- Tool uses are embedded in the assistant content array, not a separate top-level field

---

## Translation Table (Hermes → Claude Code format)

For Pattern 2 (format translator), map Hermes records to Claude Code JSONL:

| Hermes record | Claude Code record |
|---------------|-------------------|
| `{"role": "user", "content": "..."}` | `{"type": "user", "message": {"role": "user", "content": "..."}}` |
| `{"role": "assistant", "content": "text", "finish_reason": "stop"}` | `{"type": "assistant", "message": {"role": "assistant", "content": [{"type": "text", "text": "text"}]}}` followed by `{"type": "system", "subtype": "turn_duration"}` |
| `{"role": "assistant", "tool_calls": [...]}` | `{"type": "assistant", "message": {"role": "assistant", "content": [{"type": "tool_use", "id": "...", "name": "...", "input": {...}}]}}` |
| `{"role": "tool", "content": "..."}` | `{"type": "user", "message": {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "...", "content": "..."}]}}` |

## peon-pet Event Detection (from jsonl-watcher.js)

peon-pet's `JsonlWatcher` processes each line and emits events:

- **SessionStart/SessionSeen** — new file detected (SessionStart if after startup, SessionSeen if file existed)
- **SessionCwd** — first record with a `cwd` field
- **UserPromptSubmit** — assistant record with `tool_use` content blocks OR non-empty text
- **Stop** — system record with `subtype: "turn_duration"`
- **PermissionRequest** — tool_use without matching tool_result after 7s timeout
- **PostToolUseFailure** — tool_result with `is_error: true`
- **SubagentStart/Stop** — `agent_progress` records in main session or separate subagent files

## peon-pet Relay Format (HTTP polling)

The relay server serves this JSON on `GET /state`:

```json
{
  "sessions": {
    "uuid-v4-session-id": {
      "timestamp": 1700000000,
      "event": "UserPromptSubmit",
      "cwd": "/home/user/project"
    }
  }
}
```

- `timestamp` is Unix seconds (not milliseconds, not ISO)
- `event` must be one of: `SessionStart`, `Stop`, `UserPromptSubmit`, `PermissionRequest`, `PostToolUseFailure`, `PreCompact`
- Sessions not in the response are treated as ended
- Valid events map to animations: SessionStart→waking, Stop→celebrate, UserPromptSubmit→typing, PermissionRequest→alarmed, PostToolUseFailure→annoyed, PreCompact→alarmed
