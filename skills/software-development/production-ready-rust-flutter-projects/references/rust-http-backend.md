# Rust HTTP Backend + Flutter Frontend Architecture

Full architecture pattern used by **Hermes Wingman** — a native desktop companion for Hermes Agent.

## Architecture

```
┌──────────────────────────────┐
│      Flutter Desktop App     │
│  Hermes Wingman GUI          │
│                              │
│  ┌──────────────────────┐    │
│  │ HermesApiClient      │    │  HTTP requests → localhost:9120
│  │ (dart http package)  │────┼──────────────────┐
│  └──────────────────────┘    │                  │
│                              │                  │
│  ┌──────────────────────┐    │                  │
│  │ BackendService       │    │  Spawns binary   │
│  │ (Process.start)      │──┘                  ▼
│  └──────────────────────┘          ┌────────────────────┐
│                                    │  Rust HTTP Server  │
│                                    │  (axum + tokio)    │
└────────────────────────────────────┘  localhost:9120    │
                                      │                    │
                                      │  Reads config.yaml │
                                      │  Reads state.db    │
                                      │  Reads logs        │
                                      │  Spawns hermes CLI │
                                      │  Probes models     │
                                      └────────────────────┘
```

## Rust Backend (axum + tokio)

### Cargo.toml
```toml
[dependencies]
axum = { version = "0.8", features = ["json"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_yaml = "0.9"
tower-http = { version = "0.6", features = ["cors"] }
regex = "1"
anyhow = "1"
```

### Key Design Decisions

1. **Avoid `reqwest::blocking`** — It blocks the tokio async runtime and causes timeouts. Instead, use `std::process::Command::new("curl")` with `--max-time` for any HTTP probes. curl is virtually guaranteed to be available on any system that has Hermes installed.

2. **YAML manipulation** — Use `serde_yaml` for reading, but write config changes via simple string replacement on the raw text rather than rebuilding the YAML tree. The borrow checker makes in-place YAML mutation painful, and string replacement preserves comments and formatting.

3. **CLI wrapping** — The backend shells out to `hermes` via `std::process::Command` for everything: config changes (`hermes config set`), chat (`hermes --oneshot`), sessions (`hermes sessions list`), logs (`hermes logs`), and cron (`hermes cron list`). This is intentional — the backend adapts to whatever version of Hermes is installed rather than depending on internal APIs that change between versions.

4. **CORS** — Always use `CorsLayer::permissive()` during development. The Flutter app and Rust backend are separate processes; CORS is required even though they're on localhost.

### Endpoint Structure
```
GET  /health          — Hermes installation status, version
GET  /config          — Full config.yaml (raw + parsed)
POST /config/update   — Update config keys via dot-notation
GET  /models          — Local + cloud model list, fallback chain
POST /models/switch   — Change default model
POST /models/probe    — Test if a model actually responds
POST /chat            — Send message to Hermes, get response
GET  /sessions        — Recent Hermes sessions
GET  /logs            — agent.log with level filtering
GET  /gateway         — Gateway state and platform connections
GET  /cron            — Scheduled cron jobs
GET  /providers       — Configured providers with status
GET  /setup/detect    — Full environment detection
POST /setup/install   — Install Hermes via pip
```

### State Management
```rust
#[derive(Clone)]
struct AppState {
    hermes_home: PathBuf,
}
```
Keep state minimal — the backend is stateless for most operations, reading files and running commands on each request. Only state needed is the `hermes_home` path resolution.

## Flutter Frontend

### Backend Lifecycle Service
```dart
class BackendService {
  Process? _process;

  Future<void> start(String binaryPath, int port) async {
    _process = await Process.start(binaryPath, [port.toString()]);
    // Wait for backend to be ready
    for (int i = 0; i < 50; i++) {
      try {
        final resp = await http.get(Uri.parse('http://127.0.0.1:$port/health'));
        if (resp.statusCode == 200) return;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw Exception('Backend failed to start');
  }

  Future<void> stop() async {
    _process?.kill();
    _process?.waitForExit();
  }
}
```

### API Client
Replace all `Process.run('hermes', [...])` calls with HTTP requests to the backend. The client should:
- Point to `http://127.0.0.1:9120` by default
- Use `http` package for requests
- Return parsed JSON responses
- Handle connection errors gracefully (show "Backend not running" instead of crashing)

### Building and Bundling
- Build the Rust backend: `cargo build --release`
- Bundle location: `backend/target/release/hermes-wingman-backend`
- Flutter finds the binary relative to its own executable path at runtime
- For distribution, the Rust binary is included in the Flutter app's bundle directory

## When to Use This Pattern

**Use instead of flutter_rust_bridge when:**
- The backend primarily wraps CLI tools and does file I/O
- The API is request/response shaped (not streaming or high-frequency)
- You want zero FFI complexity
- The backend needs to be independently testable
- Cross-compilation simplicity matters

**Stick with flutter_rust_bridge when:**
- You need hundreds of calls per second
- Complex structs are passed between Rust and Dart
- Synchronous calls from Dart are required
- Memory efficiency matters (no serialization overhead)

## Pitfalls
- **Blocking reqwest in async handlers** — Always use curl subprocess or `reqwest` async, never `reqwest::blocking` inside axum handlers
- **YAML write-back** — String replacement is fragile for multi-level keys; only use for single-level or two-level writes (`model.default`, `providers.xai.base_url`)
- **CORS on localhost** — Easy to forget, easy to debug once you know, baffling without CORS middleware
- **Port conflicts** — Picking port 9120 is arbitrary; allow override via CLI arg or config
- **Backend process lifecycle** — Must kill the backend when Flutter exits; use `WidgetsBindingObserver` to detect app lifecycle events
