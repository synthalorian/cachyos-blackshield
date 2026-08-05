# Hermes CLI Wrapper Architecture

**Class-level pattern:** Wrapping a Python CLI tool (Hermes Agent) with a Rust HTTP backend + Flutter frontend.

## Architecture Diagram

```
┌──────────────────────────────┐
│   Flutter App (GUI)          │  ← HermesApiClient implements HermesService
│   HermesApiClient (HTTP)     │  ← context.read<HermesService>()
├──────────────────────────────┤
│   Rust Backend (axum:9120)   │  ← single binary, zero runtime deps
│   - Spawns hermes CLI        │
│   - Reads config.yaml        │
│   - Reads state.db (SQLite)  │
│   - Reads gateway_state.json │
│   - Probes models via curl   │
├──────────────────────────────┤
│   Hermes Agent (Python)      │
│   ~/.hermes/config.yaml      │
│   ~/.hermes/state.db         │
│   ~/.hermes/gateway_state.json│
│   ~/.hermes/logs/agent.log   │
└──────────────────────────────┘
```

## Common Interface Pattern

Both the CLI-based client and the HTTP API client implement the same abstract class so the app can switch between them at startup:

```dart
// lib/services/hermes_service.dart
abstract class HermesService {
  Future<bool> isHermesAvailable();
  Future<HermesStatus> getStatus();
  Future<List<HermesSession>> listSessions({int limit = 20});
  Future<String> getConfigRaw();
  Future<void> setConfigValue(String key, String value);
  Future<List<LogEntry>> readLogs({int lines = 50, String level = 'all'});
  Future<List<GatewayPlatform>> getGatewayStatus();
  // ...
}
```

```dart
// lib/services/hermes_api_client.dart  —  HTTP backend
class HermesApiClient implements HermesService { ... }

// lib/services/hermes_client.dart  —  CLI fallback (deprecated)
class HermesClient implements HermesService { ... }
```

```dart
// main.dart — inject whichever is available
final backend = BackendService();
final started = await backend.start();
final apiClient = started ? HermesApiClient() : null;

Provider<HermesService>(
  create: (_) => apiClient ?? HermesClient() as HermesService,
)
```

## Backend Lifecycle Management

```dart
class BackendService {
  Process? _process;
  bool _ready = false;

  Future<bool> start({Duration timeout = const Duration(seconds: 10)}) async {
    // 1. Find binary (dev path first, then release, then search common locations)
    // 2. Spawn with Process.start
    // 3. Poll /health every 200ms until ready or timeout
    // 4. Return true/false
  }
}
```

Binary path discovery strategy:
- Dev: `backend/target/debug/hermes-wingman-backend`
- Release: `backend/target/release/hermes-wingman-backend`
- Bundled: `hermes-wingman-backend` (same directory as app binary)
- Fallback: search `~/projects/hermes_wingman/backend/target/`

## Rust Backend: All-in-One Main.rs Structure

Keep the backend in a single `main.rs` for simplicity (under 800 lines is manageable):

| Section | Purpose |
|---------|---------|
| `AppState` | Shared state (hermes_home path) |
| `run_hermes()` | Spawn hermes CLI subprocess |
| `read_file()` | Read a file with error handling |
| `discover_models()` | Query llama-swap API, parse config, build model list |
| `probe_model()` | Test a model with curl POST |
| `handle_chat()` | Run hermes --oneshot with optional session resume |
| `parse_log_line()` | Extract timestamp + level + message from log lines |
| HTTP handlers | One async fn per endpoint |
| `#[tokio::main]` | Routes, CORS, bind, serve |

## Endpoints

| Method | Path | What it does |
|--------|------|-------------|
| GET | /health | Hermes version, config exists, backend status |
| GET | /config | Full config.yaml (raw + parsed) |
| POST | /config/update | Update specific keys via string replacement |
| POST | /config/write | Replace entire config.yaml content |
| GET | /models | Local + cloud + fallback + current model |
| POST | /models/switch | Change default model via `hermes config set` |
| POST | /models/probe | Test if a model responds |
| POST | /chat | Send message via --oneshot, return response |
| GET | /sessions | List recent sessions (parsed CLI table) |
| GET | /logs | Tail agent.log with level filtering |
| GET | /gateway | Read gateway_state.json (running field, not platforms length) |
| POST | /gateway/toggle | Start or stop gateway via action: "start"/"stop" |
| GET | /cron | List cron jobs |
| GET | /providers | Parse provider config |
| GET | /setup/detect | Full installation/diagnostic check |
| POST | /setup/install | Install Hermes via pip |

## Config Writing: String Replacement Approach

Never use serde_yaml's in-place Value mutation for config editing — the borrow checker makes it painful and the round-trip through serde_yaml can reorder keys or reformat comments. Instead, use simple line-based string replacement:

```rust
for (key, value) in updates {
    let search_key = key.rsplit('.').next().unwrap_or(key);
    let val_str = /* serialize value */;
    
    // Find line starting with "search_key:" and replace it
    for line in result.lines() {
        if line.trim().starts_with(&format!("{}:", search_key)) {
            let indent = line.len() - line.trim_start().len();
            new_lines.push(format!("{}{}: {}", " ".repeat(indent), search_key, val_str));
        } else {
            new_lines.push(line.to_string());
        }
    }
}
```

This preserves comments, ordering, and indentation. For new keys that don't exist yet, append to the appropriate section.

## Gateway State JSON Structure

```json
{
  "gateway_state": "running",
  "pid": 1352,
  "platforms": {
    "discord": { "state": "connected", "error_code": null, "error_message": null },
    "telegram": { "state": "retrying", "error_code": "telegram_connect_error", "error_message": "..." }
  },
  "active_agents": 0
}
```

Always read `gateway_state.json` directly instead of parsing `hermes gateway status` output (systemd format).

## Model Discovery: Two Sources

1. **llama-swap API** (`http://127.0.0.1:8080/v1/models`): Returns currently registered models with their IDs. Response format: `{"data": [{"id": "model-name", "object": "model", ...}]}`

2. **Config fallback_providers**: Lists model references that will be tried if the primary fails. These may reference model names that no longer exist — always cross-reference with the API.

Models are tagged with a `source` field: `"local"` (from llama-swap API), `"fallback"` (from config), or `"cloud"` (curated list of popular cloud models).

## Key Rust Dependencies

```toml
[dependencies]
axum = { version = "0.8", features = ["json"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_yaml = "0.9"
tower-http = { version = "0.6", features = ["cors"] }
regex = "1"
```

Note: `reqwest` is deliberately excluded — all HTTP calls from the backend use `std::process::Command::new("curl")` to avoid blocking the tokio runtime. If high-frequency async HTTP is needed later, add `reqwest` without the `blocking` feature and use the async API.
