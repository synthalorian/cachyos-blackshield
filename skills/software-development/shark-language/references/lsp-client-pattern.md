# LSP Client Pattern for Rust CLI Tools

Lightweight LSP client for symbol understanding in an AI coding harness.

## Architecture

```
src/
├── lsp/
│   └── mod.rs           # LspClient struct, JSON-RPC over stdio
└── tools/
    └── lsp.rs           # Tool wrapper, auto-detects language server
```

## LspClient Core

Spawns a language server as a child process, communicates via JSON-RPC over stdin/stdout:

```rust
pub struct LspClient {
    server: Child,
    stdin: Arc<Mutex<ChildStdin>>,
    stdout: Arc<Mutex<BufReader<ChildStdout>>>,
    request_id: Arc<Mutex<i64>>,
    root_uri: String,
}
```

### Key Methods

| Method | Purpose |
|--------|---------|
| `start(cmd, args, root)` | Spawn server, send initialize, send initialized |
| `open_document(path, lang_id, content)` | Notify server of file content |
| `goto_definition(path, line, col)` | Returns `Vec<Symbol>` with file/line/char |
| `hover(path, line, col)` | Returns type/signature info as `Option<String>` |
| `document_symbols(path)` | Returns all symbols in file with kinds |
| `shutdown()` | Send shutdown + exit, wait for process |

### JSON-RPC Protocol

```rust
// Send request
fn send_request(&self, method: &str, params: Value) -> Result<Value> {
    let request = json!({
        "jsonrpc": "2.0",
        "id": self.next_id(),
        "method": method,
        "params": params
    });
    self.send_message(&request)?;
    self.read_response(id)
}

// Message format: Content-Length header + JSON body
fn send_message(&self, message: &Value) -> Result<()> {
    let body = message.to_string();
    let header = format!("Content-Length: {}\r\n\r\n", body.len());
    // write header + body to stdin
}
```

**CRITICAL:** Read headers line-by-line until empty line (`\r\n`), then read the body. Don't try to read fixed-size chunks — LSP servers may send multiple messages or split across buffer boundaries.

### Response Parsing

```rust
fn read_response(&self, expected_id: i64) -> Result<Value> {
    // Read header lines until \r\n
    // Read body into buffer
    // Parse JSON, extract "result" field
}
```

## Tool Wrapper

Auto-detects language server from file extension:

| Extension | Server | Args | langId |
|-----------|--------|------|--------|
| `.rs` | `rust-analyzer` | `&[]` | `rust` |
| `.py` | `pylsp` | `&[]` | `python` |
| `.js`, `.ts` | `typescript-language-server` | `&["--stdio"]` | `typescript` |
| `.go` | `gopls` | `&[]` | `go` |
| `.c`, `.cpp`, `.h` | `clangd` | `&[]` | `cpp` |

## Usage from TUI

```
> TOOL:lsp symbols src/main.rs
> TOOL:lsp def src/main.rs 10 5
> TOOL:lsp hover src/main.rs 10 5
```

## Known Limitations

- One-shot per tool invocation — spawns fresh server each time. For production, use a persistent connection pool.
- No cancellation support — long-running LSP operations block.
- Error recovery is minimal — if server crashes, tool returns error.
