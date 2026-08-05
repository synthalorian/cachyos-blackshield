---
name: hermes-mcp-integration
description: Wiring, updating, and cleaning MCP servers and agent extensions in Hermes config.yaml. Covers connect flows, manual YAML edits, dependency workarounds, and removal of legacy integrations.
---

# Hermes MCP Integration

## Triggers
- Adding or replacing MCP servers (e.g. `agentmemory connect hermes`)
- Cleaning legacy MCP/hook entries from `~/.hermes/config.yaml`
- npm/pnpm install conflicts on agent tools
- Manual config merge for Hermes YAML

## Workflow
1. Run the agent's native `connect <agent>` command first.
2. Capture the exact YAML snippet it recommends.
3. Use targeted patch on `~/.hermes/config.yaml` to replace old entries (never append duplicates).
4. For npm installs that hit peer-dep conflicts (common with anthropic/claude-agent-sdk), always use `--legacy-peer-deps`.
5. After edit, advise user to restart Hermes session.

## Pitfalls
- Hermes connect often reports "manual install required" for YAML-based agents — always perform the patch yourself.
- Old entries (peon-ping, etc.) must be fully removed from mcp_servers block and any skill/hook dirs.
- Do not run global `npm install -g` if the project has local anthropic version conflicts; build locally instead.

## References
- `references/agentmemory-hermes.md` — exact config block, connect output, and install notes for agentmemory on Hermes
