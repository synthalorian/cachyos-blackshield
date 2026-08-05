# Hermes Backend Integration Patterns

## Chat Streaming: CLI vs Direct API

The Rust backend has TWO chat paths. Choosing the right one determines responsiveness.

### Fast Path: Direct Provider API

Used when the provider has `base_url` and `api_key` configured (OpenAI, Anthropic, any API-key provider). Makes HTTP calls directly to the provider's `/chat/completions` endpoint with `stream: true`. Streams tokens one-by-one via SSE. **No Python startup overhead.**

```rust
// In backend/src/main.rs chat_stream_handler
let chat_url = format!("{}/chat/completions", base_url);
// stream: true, reads bytes_stream(), forwards tokens as SSE events
```

### Slow Path: Hermes CLI Fallback

Used for OAuth providers (Nous, xAI) or when base_url/api_key are empty. Calls `hermes -z "message"` which starts a new Python process for EACH message (~300-500ms startup).

```rust
// Fallback — uses -z (oneshot) for clean, parseable output
let mut args = vec!["-z", &message];
std::process::Command::new(hermes_binary_path()).args(&args).output()
```

### CRITICAL: Do NOT use `hermes chat -Q` for programmatic streaming

`hermes chat -Q` outputs:
- A massive banner with all tools/skills (ASCII art)
- Welcome messages and tips
- Complex ANSI formatting and cursor positioning
- Multiplexed status lines (`⚕ main │ ctx -- │ [░░░░░░░░░░]`)

This is NOT suitable for SSE parsing. The `-z` (oneshot) mode produces clean stdout-only output that can be sent directly as an SSE event.

```rust
// WRONG: produces unparseable output
args = vec!["chat", "-Q", "-m", model];  // don't do this

// RIGHT: clean, parseable output  
args = vec!["-z", &message];              // the correct approach
```

### Chat Stream URL Must Use Service Base URL

In the Flutter `_streamChat` method, the URL for SSE must use the backend's actual `baseUrl`, NOT a hardcoded localhost. On mobile, the backend is at a remote IP.

```dart
// WRONG: only works when backend is local
final uri = Uri.parse('http://127.0.0.1:9120/chat/stream');

// RIGHT: works on desktop AND mobile
final uri = Uri.parse('${service.baseUrl}/chat/stream');
```

## Backend Networking for Mobile Access

### Binding to All Interfaces

The Rust backend defaults to `127.0.0.1:9120` (localhost only). For mobile devices to connect over LAN, it must bind to `0.0.0.0:9120`.

**Env var approach (implemented):**

The backend reads `BIND_ADDR` from environment:
```rust
let addr = std::env::var("BIND_ADDR")
    .unwrap_or_else(|_| "127.0.0.1:9120".to_string());
```

**Flutter auto-bind:**

When `BackendService` starts the backend process on desktop, it passes `BIND_ADDR=0.0.0.0:9120` so the backend is accessible from the network:
```dart
environment: {
  'HOME': Platform.environment['HOME'] ?? '/tmp',
  'PATH': Platform.environment['PATH'] ?? '/usr/local/bin:/usr/bin:/bin',
  'BIND_ADDR': '0.0.0.0:9120',
},
```

### Mobile LAN Auto-Discovery

When the mobile app can't connect to the saved backend URL, it scans the local subnet for port 9120. The `_discoverOnLAN()` method in `BackendService`:

1. Gets the phone's own IP via `NetworkInterface.list()`
2. Derives the subnet (e.g., 192.168.1.x) from the first non-loopback IPv4 address
3. Scans common host ranges (1-20, 50-60, 100-110, 200-210) for port 9120
4. Tests each candidate with `Socket.connect()` (300ms timeout per host)
5. On success, verifies via `/health` endpoint and saves the discovered URL

```dart
Future<String?> _discoverOnLAN() async {
  final interfaces = await NetworkInterface.list();
  // Find subnet from own IP
  // Scan hosts with Socket.connect(host, 9120, timeout: 300ms)
  // Return first URL that responds to GET /health
}
```

### Network Info Display (Desktop)

The Config screen shows a "Network Share" section that:
- Displays the computer's local IPs (auto-detected)
- Shows the connection string (e.g., `192.168.1.59:9120`)
- Lists the `BIND_ADDR=0.0.0.0:9120` command
- Mobile devices: scan for backend on LAN automatically