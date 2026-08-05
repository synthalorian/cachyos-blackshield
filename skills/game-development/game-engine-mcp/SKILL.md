---
name: game-engine-mcp
description: "Set up and troubleshoot MCP bridges for Unity, Godot, and Unreal Engine — enabling AI agents to control editors directly (create scenes, spawn objects, edit scripts, run tests)."
version: 1.0.0
author: synthclaw
license: MIT
platforms: [linux, macos, windows]
triggers:
  - user asks to wire up an engine MCP
  - user says "connect to Unity/Godot/Unreal"
  - user wants AI to control the editor directly
  - new game engine project needs MCP bridge
metadata:
  hermes:
    tags: [game-development, mcp, unity, godot, unreal, editor-automation]
    related_skills: [native-mcp, scaffold-unity-project]
---

# Game Engine MCP Bridges

Connect AI agents to Unity, Godot, and Unreal Engine editors via the Model Context Protocol (MCP). Each engine has its own bridge server that translates MCP tool calls into engine-specific operations.

## Architecture

```\nAI Agent (Hermes)\n  └─ MCP Client (stdio transport)\n       ├─ Unity → uvx mcpforunityserver → Unity Editor (MCPForUnity plugin, HTTP :8080)\n       ├─ Godot → python3 bridge_script.py → Godot Editor (custom addon, TCP :6400)\n       │          OR\n       │          npx @coding-solo/godot-mcp → Godot Engine (npm package)\n       └─ Unreal → uv run unreal_mcp_server_advanced.py → Unreal Editor (MCP C++ plugin, TCP)\n```

Each bridge requires two running components:
1. **The engine editor** with its MCP plugin/addon enabled
2. **The MCP bridge server** that Hermes connects to

## Prerequisites

- **uv** — Python package installer for Unity & Unreal bridges
- **Node.js + npx** — for the Godot bridge
- **Hermes native-mcp client** (built-in, no extra install needed)

```bash
# Verify
uv --version
npx --version
```

## Engine-Specific Setup

### Unity (CoplayDev/unity-mcp)

**Repo**: https://github.com/CoplayDev/unity-mcp

**Unity side** — one-time install:
1. Open project in Unity Editor
2. **Window → Package Manager → + → Add package from git URL...**
3. Paste: `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#main`
4. Wait for import
5. **Window → MCP for Unity → Start Server**
6. Verify green: "🟢 Connected ✓"

**Hermes config** (already in ~/.hermes/config.yaml):
```yaml
mcp_servers:
  unity:
    command: uvx
    args:
    - --from
    - mcpforunityserver
    - mcp-for-unity
    - --transport
    - stdio
```

### Godot (custom addon + Python bridge)

Some Godot projects (like Blood Legacy) ship their own custom MCP addon — a Godot EditorPlugin that opens a TCP server. When that's the case, use a Python bridge script instead of the npm package.

**How it works**:
- The Godot EditorPlugin opens a TCP server on port 6400 with a custom JSON protocol
- A Python bridge script (`godot_mcp_bridge.py`) translates between stdio MCP (what Hermes speaks) and the TCP/JSON protocol
- The bridge exposes 20+ tools: scene management, object creation/deletion, script editing, asset import, material/mesh assignment, editor playback control

**Godot side** — enable the addon:
1. Open the project in Godot Editor
2. **Project → Project Settings → Plugins**
3. Find the MCP addon and set Status to **Enable**
4. Verify in the output log: `Godot MCP Server listening on port 6400`

**Bridge side** — the Python script:
```python
# Connects to Godot's TCP port 6400 and translates MCP tool calls
# Sits in the project root: e.g., /path/to/Project/godot_mcp_bridge.py
```

**Hermes config**:
```yaml
mcp_servers:
  godot:
    command: python3
    args:
    - /path/to/Project/godot_mcp_bridge.py
```

**Note**: If the project doesn't have a custom addon, use `npx -y @coding-solo/godot-mcp` instead for the standard npm Godot MCP bridge.

### Unreal Engine (flopperam/unreal-engine-mcp)

**Repo**: https://github.com/flopperam/unreal-engine-mcp

**Requirements**: Unreal Engine 5.5+, Python 3.12+, uv, the MCP plugin compiled

**Unreal side** — one-time install:
1. Clone the repo: `git clone https://github.com/flopperam/unreal-engine-mcp.git`
2. Copy the plugin into your project:
   ```
   cp -r unreal-engine-mcp/UnrealMCP/ YourProject/Plugins/
   ```
3. Open project in UE Editor
4. **Edit → Plugins → Search "UnrealMCP" → Enable → Restart Editor**
5. Rebuild project when prompted
6. Start the Python bridge:
   ```
   cd unreal-engine-mcp/Python
   uv run unreal_mcp_server_advanced.py
   ```

**Hermes config**:
```yaml
mcp_servers:
  unreal:
    command: uv
    args:
    - --directory
    - /path/to/unreal-engine-mcp/Python
    - run
    - unreal_mcp_server_advanced.py
```

## Troubleshooting

### "Connection refused" / Server unreachable
The engine editor must be running with the MCP plugin started BEFORE the bridge server connects. The bridge server talks to a local endpoint inside the engine.

**Fix**: Start the engine first, start the plugin's server, then connect the bridge.

### Unity-MCP fails to import from git URL
Unity's Package Manager requires git to be reachable. Ensure you have internet access. If the main branch fails, try the beta branch:
```
https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#beta
```

### Unreal plugin compilation fails
The flopperam MCP plugin targets UE 5.5+. For older engine versions (5.3, 5.4), you may need:
- The **chongdashu/unreal-mcp** project (1.9k stars, but last commit was a year ago)
- Manual porting of the plugin source

### "uvx" or "npx" not found
Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`
Node.js/npx ships together — install via your package manager.

### Engine MCP tools don't appear after config
MCP servers fail gracefully if unreachable. Hermes logs the failure at startup. Three solutions:
1. Restart Hermes with the engine running
2. Or tell the agent "reconnect to [engine]" — the agent can retry the connection
3. Check that the `mcp_servers` YAML is valid (indentation matters)

### Hermes config file
Located at `~/.hermes/config.yaml`. The `mcp_servers` section is a flat mapping of server names to configs. Each entry must specify EITHER `command` + `args` (stdio transport) OR `url` (HTTP transport), not both.

## Known Limitations

- All three bridges require the engine editor to be OPEN and RUNNING — they don't work headless
- The Unreal bridge repo must be cloned locally (can't run via uvx from PyPI like Unity's)
- The godot-mcp npm bridge auto-downloads on first `npx` run (~30s)
- Project `.uproject` EngineAssociation may need updating if the installed UE version differs from what the project targets

## References

See `references/engine-mcp-commands.md` for exact commands, URLs, and paths used in this profile's setup.
