# agentmemory + Hermes Wiring (2026-05-19)

## Connect Output
```
agentmemory connect hermes --force
→ Using MCP. Hooks also available.
⚠ hermes (manual install required: yaml-merge-not-implemented)
```

## Required config.yaml Addition
```yaml
mcp_servers:
  agentmemory:
    command: npx
    args:
    - -y
    - "@agentmemory/mcp"
    enabled: true

memory:
  provider: agentmemory
```

## Install Notes
- Clone → `npm install --legacy-peer-deps` (anthropic-sdk peer conflict)
- `npm run build`
- Replace any prior `peon-ping` mcp_servers entry entirely when migrating.

## Verification
After restart: `agentmemory status` or new Hermes session should load the MCP.