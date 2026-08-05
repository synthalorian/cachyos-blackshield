# Unity-MCP Server Reference

Source: https://github.com/CoplayDev/unity-mcp
License: MIT
Version: 9.6.9-beta.7 (latest as of May 2026)

## PyPI Package

- Package name: `mcpforunityserver`
- Command: `mcp-for-unity` (installed via `uvx --from mcpforunityserver mcp-for-unity`)
- Requires: Python 3.10+, `uv` installed
- Dependencies: fastmcp>=3.0.2, mcp>=1.16.0, fastapi>=0.104.0, uvicorn>=0.35.0

## Transport Options

### Stdio (recommended for Hermes)

```bash
uvx --from mcpforunityserver mcp-for-unity --transport stdio
```

### HTTP

First run the server:
```bash
uvx --from mcpforunityserver mcp-for-unity --transport http --http-url http://localhost:8080
```

Then configure client to connect to `http://localhost:8080/mcp`.

## Unity Plugin

- Package path in repo: `/MCPForUnity`
- Git URL for Package Manager: `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#main`
- Beta branch: append `#beta` instead of `#main`
- Menu: **Window → MCP for Unity**
- Default port: 8080
- Requires: Unity 2021.3 LTS+

## Architecture Notes

The Unity plugin runs a lightweight HTTP server INSIDE the Unity Editor process.
The Python MCP server translates MCP protocol (JSON-RPC over stdio or HTTP) into REST calls to the Unity plugin.
The Python server is the bridge layer — it does NOT run inside Unity.

## Tool Categories (from plugin)

The Unity-MCP plugin exposes tools for:
- Scene management (create, load, save, get hierarchy)
- GameObject manipulation (create, delete, modify, get components)
- Component editing (get/set properties, add/remove components)
- Asset management (import, move, delete, create folders)
- Play mode control (enter/exit play mode, get state)
- Console access (get logs, clear)
- Project introspection (list scenes, assets, tags, layers)
