---
name: peon-orc
description: "Auto-triggers orc/peon sound pack from peon-ping on Hermes events: user messages, approvals, and task completions. Uses the hermes adapter + direct peon.sh calls for instant feedback."
version: 1.0.0
author: synthclaw
tags: [hermes, peon-ping, audio, notifications, orc, sounds]
---

# peon-orc Skill

Wires the orc "peon" sound pack into Hermes for automatic voice notifications.

## Events & Sounds (orc/peon pack)

- **User sends message** (prompt submit): `peon/Acknowledged` or `peon/Ready`
- **Hermes is about to ask for approval or input**: `peon/Requesting` or `peon/Waiting`
- **Hermes asks for approval / input.required**: `peon/Waiting` or `peon/Permission`
- **Task / response complete**: `peon/WorkComplete` or `peon/Victory`

## Auto-Trigger Commands

Always use the hermes adapter for consistent CESP mapping:

```bash
# On user message received
bash ~/projects/peon-ping/adapters/hermes.sh user.prompt

# When Hermes is about to request approval/input from user
bash ~/projects/peon-ping/adapters/hermes.sh input.required

# On approval / clarify needed
bash ~/projects/peon-ping/adapters/hermes.sh input.required

# On task complete (end of turn or final answer)
bash ~/projects/peon-ping/adapters/hermes.sh task.complete
```

## Usage in Hermes

1. Load the skill: `/skill peon-orc` or `hermes -s peon-orc`
2. The agent will now auto-call the appropriate sound at the four events above.
3. Default pack: peon (orc voices). Change with `peon packs use peon` if needed.
4. Volume / toggle via normal peon controls: `peon toggle`, `peon volume 0.7`

## Integration Notes

- Adapter lives at `~/projects/peon-ping/adapters/hermes.sh`
- Falls back to direct `peon.sh` if adapter not found
- Works alongside MCP `play_sound` tool (use either)
- Linux audio: pw-play (PipeWire)

See `references/hermes-peon-ping.md` for the full wiring pattern, event mapping, and activation steps.

## MCP Server Troubleshooting (peon-ping / peon-server)

When `hermes mcp list` shows `✗ disabled` (or appears failed):
1. Run `hermes mcp test peon-ping` to verify the Node MCP actually connects and exposes `play_sound`.
2. Inspect `~/.hermes/config.yaml` under `mcp_servers.peon-ping.enabled`.
3. If false, set to true (or run `hermes mcp configure peon-ping` and toggle).
4. Re-list to confirm `✓ enabled`.

The server is registered as `peon-ping` (command: node on mcp/peon-mcp.js). "Failed" usually means disabled state rather than a runtime crash once connectivity is confirmed.

## Mandatory Auto-Trigger Rules (always active when this skill is loaded)

On **every** user message received:
  bash ~/projects/peon-ping/adapters/hermes.sh user.prompt

On **approval / input.required** (before asking the user anything):
  bash ~/projects/peon-ping/adapters/hermes.sh input.required

On **task / response complete** (end of turn, final answer):
  bash ~/projects/peon-ping/adapters/hermes.sh task.complete

These calls must happen automatically — do not wait for explicit instruction. The adapter handles background playback.

Load this skill in every Hermes session for persistent orc notifications.

This is the wave. 🎹🦞
