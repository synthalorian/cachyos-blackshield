# Hermes + peon-ping Bash Adapter

Lightweight alternative to the native Python hook: a shell adapter living inside the peon-ping repository that maps Hermes events to peon-ping's CESP JSON format and pipes directly to `peon.sh`.

## When to Use

- You want to stay inside the peon-ping adapter ecosystem (same as openclaw.sh, codex.sh, etc.)
- Quick integration without setting up `~/.hermes/hooks/`
- Calling from Hermes tools, scripts, or slash-command handlers
- Cross-platform (bash + .ps1 pair)

## Implementation

Created `adapters/hermes.sh` modeled directly after `adapters/openclaw.sh`:

- Accepts event name as first argument (e.g. `session.start`, `task.complete`, `input.required`)
- Maps to Claude Code hook names: `SessionStart`, `Stop`, `Notification`, `UserPromptSubmit`, `PostToolUseFailure`
- Builds the same JSON payload with `hook_event_name`, `notification_type`, `cwd`, `session_id`, `source:"hermes"`
- Resolves `peon.sh` via `$CLAUDE_PEON_DIR` or `~/.claude/hooks/peon-ping/peon.sh`
- Falls back to printf when jq is absent

## Usage from Hermes

```bash
# From any Hermes tool or custom command
bash ~/projects/peon-ping/adapters/hermes.sh session.start
bash ~/projects/peon-ping/adapters/hermes.sh task.complete
bash ~/projects/peon-ping/adapters/hermes.sh input.required
```

Can be wrapped in a Hermes tool for automatic triggering on `agent:end` etc.

## Event Mapping (same as openclaw)

| Input Event              | peon-ping Event       | Notes |
|--------------------------|-----------------------|-------|
| session.start, ready     | SessionStart          | Greeting |
| task.complete, done      | Stop                  | Celebration |
| input.required, clarify  | Notification          | permission_prompt |
| task.error, fail         | PostToolUseFailure    | Error sound |
| task.acknowledge         | UserPromptSubmit      | Acknowledge |

## Advantages over Python Hook

- No gateway restart required
- Lives with the peon-ping source (easy to contribute upstream)
- Reuses all existing peon-ping logic and pack handling
- Works immediately after `install.sh --local`

## Next Steps

- Add `adapters/hermes.ps1` for Windows parity
- Register as a Hermes tool so sounds fire automatically on lifecycle events
- Update peon-ping README badges and adapter list to include Hermes

This pattern keeps peon-ping as the single source of truth for sound selection while Hermes only supplies the event trigger.