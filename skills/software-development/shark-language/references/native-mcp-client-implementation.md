# Native MCP Client Implementation

## Overview

OpenShark's native MCP client was implemented in commit `1f2ca68` (post-v0.3.0). It replaces the planned Hermes bridge with a first-class Rust implementation.

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `src/mcp/protocol.rs` | ~250 | JSON-RPC 2.0 types, MCP structs, protocol constants |
| `src/mcp/transport.rs` | ~280 | StdioTransport, SseTransport, TransportMessage enum |
| `src/mcp/mod.rs` | ~295 | McpConnection, McpManager, connection lifecycle |
| `src/tools/mcp.rs` | ~140 | McpToolAdapter (Tool trait wrapper), result formatting |

## Architecture Decisions

### Enum over dyn Trait

Used `McpTransport` enum instead of `Box<dyn Transport>` because async traits are not dyn-compatible in Rust. This avoids the `async-trait` crate entirely.

### Stdio Transport

Spawns subprocess via `tokio::process::Command`, communicates over stdin/stdout with newline-delimited JSON. stderr is inherited (so server errors are visible).

### SSE Transport

HTTP POST for requests, SSE stream for notifications. Uses `reqwest` with `eventsource-stream` for SSE parsing.

### Tool Adapter Pattern

`McpToolAdapter` implements OpenShark's `Tool` trait by calling `McpManager::call_tool()` asynchronously. Since `Tool::execute` is synchronous, uses `tokio::task::block_in_place` when in an async context, or creates a new runtime as fallback.

## Config Format

```toml
[gateway.mcp]
enabled = true

[[gateway.mcp.servers]]
name = "filesystem"
transport = { stdio = { command = "npx", args = ["-y", "@modelcontextprotocol/server-filesystem", "/path"] } }

[[gateway.mcp.servers]]
name = "api"
transport = { sse = { url = "http://localhost:3000/sse", headers = {} } }
```

## Testing

Verified against `@modelcontextprotocol/server-filesystem`:
1. `initialize` handshake — protocol version negotiation
2. `tools/list` — discovered 14 tools
3. `tools/call` — executed `list_directory` successfully

Unit tests in `src/mcp/protocol.rs` cover JSON-RPC serialization/parsing.

## Integration Points

- **TUI**: `App::init_mcp()` connects on startup, `App::shutdown_mcp()` disconnects on exit
- **CLI**: `openshark mcp status` shows configured servers
- **Tool system**: MCP tools are not yet auto-registered in `get_tools()` — they exist as adapters but require explicit integration

## Future Work

- Auto-register MCP tools in the tool registry so LLM can use them
- Add MCP tool schemas to the system prompt
- Implement `resources/list` and `prompts/list` for full MCP support
- Add per-server health checks and reconnection
