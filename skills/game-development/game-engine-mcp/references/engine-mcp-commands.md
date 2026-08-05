# Game Engine MCP — Session Commands & Paths

Concrete paths and commands from the session that set up MCP bridges for three engines.

## Unity-MCP

| Item | Value |
|------|-------|
| Git URL (main) | `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#main` |
| Git URL (beta) | `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#beta` |
| Unity plugin port | `localhost:8080` |
| PyPI package | `mcpforunityserver` |
| Hermes server name | `unity` |
| Hermes command | `uvx --from mcpforunityserver mcp-for-unity --transport stdio` |

## Godot-MCP (custom addon bridge)

Use this when the Godot project ships its own MCP EditorPlugin (like Blood Legacy's `addons/godot_mcp/`).

| Item | Value |
|------|-------|
| Plugin type | Custom Godot EditorPlugin (TCP server on port 6400) |
| Protocol | JSON over raw TCP (`{"type":"CMD","params":{}}`) |
| Bridge script | `godot_mcp_bridge.py` (sits in the project root) |
| Bridge type | Python MCP server (FastMCP-compatible, stdio transport) |
| Hermes server name | `godot` |
| Hermes command | `python3 /path/to/Project/godot_mcp_bridge.py` |
| Tools exposed | 20+ (scene CRUD, object CRUD, scripts, assets, materials, editor control) |
| Godot engine path | `/usr/bin/godot` |

**Alternative** (no custom addon): `npx -y @coding-solo/godot-mcp`

**Bridge script location**: `/home/synth/projects/Blood-Legacy/godot_mcp_bridge.py`

## Unreal-MCP (flopperam/unreal-engine-mcp)

| Item | Value |
|------|-------|
| Repo URL | `https://github.com/flopperam/unreal-engine-mcp.git` |
| Hermes server name | `unreal` |
| Hermes command | `uv --directory /home/synth/projects/unreal-engine-mcp/Python run unreal_mcp_server_advanced.py` |
| Plugin path | `unreal-engine-mcp/UnrealMCP/` (copied to project `Plugins/`) |
| Engine requirement | UE 5.5+ |
| Installed UE version | UE 5.7.4 at `/home/synth/UnrealEngine/` |
| Python version | 3.14.4 (meets 3.12+ requirement) |

## Hermes Config Section

The current `mcp_servers` block in `~/.hermes/config.yaml`:

```yaml
mcp_servers:
  agentmemory:
    command: npx
    args: [-y, '@agentmemory/mcp']
    env:
      AGENTMEMORY_URL: http://localhost:3111
  unity:
    command: uvx
    args: [--from, mcpforunityserver, mcp-for-unity, --transport, stdio]
  godot:
    command: python3
    args: [/home/synth/projects/Blood-Legacy/godot_mcp_bridge.py]
  unreal:
    command: uv
    args: [--directory, /home/synth/projects/unreal-engine-mcp/Python, run, unreal_mcp_server_advanced.py]
```

## Project Structure

| Project | Engine | Path | LOC | Type |
|---------|--------|------|-----|------|
| Holy Lands | Unity C# | `/home/synth/projects/holy-lands/` | ~12k | Crusader-era action RPG |
| Synthocalypse | Unreal C++ | `/home/synth/projects/synthocalypse/` | 38k | Space bounty hunter (UE 5.3→5.7) |
| Blood Legacy | Godot GDScript | `/home/synth/projects/Blood-Legacy/` | 45k | Generational roguelite (Godot 4.5) |

## Engine Installation Paths

- Unity: `/home/synth/Unity/Hub/Editor/6000.4.6f1/Editor/Unity`
- Unreal: `/home/synth/UnrealEngine/` (UE 5.7.4)
- Godot: `/usr/bin/godot`
