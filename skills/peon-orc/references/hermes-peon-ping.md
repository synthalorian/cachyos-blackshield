# Hermes + peon-ping Integration Pattern

## Core Components
- `adapters/hermes.sh`: Maps Hermes events (user.prompt, input.required, task.complete) to CESP hook names (SessionStart, Notification, Stop). Pipes JSON to peon.sh.
- MCP server: `mcp/peon-mcp.js` (after `cd mcp && npm install`). Exposes `play_sound` tool + catalog resources. Registered via `hermes mcp add peon-ping --command node --args ...`
- Auto-trigger skill: `peon-orc` instructs agent to call adapter at four points:
  - User message → `user.prompt`
  - Agent about to request approval → `input.required`
  - Explicit approval needed → `input.required`
  - Task complete → `task.complete`

## Event Mapping (orc/peon pack)
- user.prompt → peon/Acknowledged or peon/Ready
- input.required (pre-request) → peon/Requesting or peon/Waiting
- input.required (approval) → peon/Waiting or peon/Permission
- task.complete → peon/WorkComplete or peon/Victory

## Activation
- Load: `hermes -s peon-orc` or `/skill peon-orc`
- Works on Linux (pw-play). Volume via `peon volume` or MCP env PEON_VOLUME.
- Fallback: direct `bash ~/projects/peon-ping/adapters/hermes.sh <event>`

## Why This Works
Adapter gives hook-style notifications + desktop visuals. MCP gives agent-driven choice. Skill encodes the auto-trigger rules so the LLM fires sounds without manual calls every time.