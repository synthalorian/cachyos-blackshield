# Hermes Wingman Backend Architecture

Full Rust HTTP backend pattern for wrapping CLI-based tools with a Flutter GUI. Routes, state management, model discovery, provider classification, model probing, chat handler, gateway control, setup detection.

## Project Layout

```
wingman/
  backend/
    Cargo.toml          # axum + tokio + serde + reqwest + rusqlite + tower-http
    src/main.rs         # 1215-line monolith — single binary, no modules
  lib/
    services/
      hermes_api_client.dart   # BackendService (ChangeNotifier + HermesService)
      hermes_client.dart       # CLI fallback
      hermes_service.dart      # Abstract interface
    screens/
      models/
        models_screen.dart     # Model browser with favorites, probing, provider groups
      chat/
        chat_screen.dart
      config/
        config_screen.dart
      gateway/
        gateway_screen.dart
      dashboard/
        dashboard_screen.dart  # Status grid, quick actions, recent sessions
      sessions/
        sessions_screen.dart
      logs/
        logs_screen.dart
      cron/
        cron_screen.dart
      setup/
        setup_wizard_screen.dart
  pubspec.yaml          # provider, yaml, path_provider
```

## Backend Server (axum + tokio)

### Dependencies

```toml
[dependencies]
axum = { version = "0.8", features = ["json"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_yaml = "0.9"
reqwest = { version = "0.12", features = ["json", "blocking"] }
rusqlite = { version = "0.34", features = ["bundled"] }
tower-http = { version = "0.6", features = ["cors"] }
anyhow = "1"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4"] }
regex = "1"
```

### State Pattern

```rust
#[derive(Clone)]
struct AppState {
    hermes_home: PathBuf,
}

impl AppState {
    fn new() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home/synth".into());
        Self { hermes_home: PathBuf::from(format!("{}/.hermes", home)) }
    }
    fn config_path(&self) -> PathBuf { self.hermes_home.join("config.yaml") }
    fn gateway_state_path(&self) -> PathBuf { self.hermes_home.join("gateway_state.json") }
    fn logs_dir(&self) -> PathBuf { self.hermes_home.join("logs") }
    fn agent_log(&self) -> PathBuf { self.logs_dir().join("agent.log") }
    fn wingman_models_path(&self) -> PathBuf { self.hermes_home.join("wingman_probed.json") }
}
```

### All 16 Routes

| Route | Method | Handler | Purpose |
|-------|--------|---------|---------|
| `/health` | GET | `health` | Backend alive + Hermes installed + config exists |
| `/config` | GET | `get_config` | Full config YAML + parsed JSON |
| `/config/write` | POST | `write_config` | Overwrite entire config.yaml |
| `/config/update` | POST | `update_config` | Partial update by key |
| `/models` | GET | `get_models` | Local, cloud, current model, provider |
| `/models/switch` | POST | `switch_model` | Write model: to config.yaml |
| `/models/probe` | POST | `probe_model_handler` | Test model with real request, cache result |
| `/chat` | POST | `chat_handler` | Send message, get response (direct API + CLI fallback) |
| `/sessions` | GET | `get_sessions` | List recent sessions from `hermes sessions list` |
| `/logs` | GET | `get_logs` | Read agent.log (CLI + direct file fallback) |
| `/gateway` | GET | `get_gateway` | Gateway state from gateway_state.json |
| `/gateway/toggle` | POST | `gateway_toggle` | Start/stop gateway |
| `/cron` | GET | `get_cron` | List cron jobs |
| `/providers` | GET | `get_providers` | List configured providers with type/keys |
| `/setup/detect` | GET | `detect_setup` | Check installation, config, keys, models, connected platforms |
| `/setup/install` | POST | `install_hermes` | Install Hermes via pip with error handling |

### Server Setup

```rust
#[tokio::main]
async fn main() {
    let state = Arc::new(AppState::new());
    let app = Router::new()
        .route("/health", get(health))
        .route("/config", get(get_config))
        .route("/config/write", post(write_config))
        .route("/config/update", post(update_config))
        .route("/models", get(get_models))
        .route("/models/switch", post(switch_model))
        .route("/models/probe", post(probe_model_handler))
        .route("/chat", post(chat_handler))
        .route("/sessions", get(get_sessions))
        .route("/logs", get(get_logs))
        .route("/gateway", get(get_gateway))
        .route("/gateway/toggle", post(gateway_toggle))
        .route("/cron", get(get_cron))
        .route("/providers", get(get_providers))
        .route("/setup/detect", get(detect_setup))
        .route("/setup/install", post(install_hermes))
        .layer(CorsLayer::permissive())
        .with_state(state);
    let listener = tokio::net::TcpListener::bind("127.0.0.1:9120").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

### Hermes CLI Helper

```rust
fn run_hermes(args: &[&str]) -> Result<(String, String, i32), String> {
    let output = Command::new("hermes")
        .args(args)
        .env("PAGER", "cat")
        .output()
        .map_err(|e| format!("Failed to run hermes: {}", e))?;
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    Ok((stdout, stderr, output.status.code().unwrap_or(-1)))
}
```

## Provider Classification

```rust
enum ProviderType { Ollama, LlamaSwap, CloudApiKey, CloudOAuth, Unknown }

fn classify_provider(name: &str, cfg: &serde_yaml::Value) -> ProviderType {
    let base_url = cfg["base_url"].as_str().unwrap_or("");
    if base_url.contains("localhost:8080") || base_url.contains("127.0.0.1:8080") {
        return ProviderType::LlamaSwap;
    }
    if base_url.contains("localhost:11434") || base_url.contains("127.0.0.1:11434") {
        return ProviderType::Ollama;
    }
    if name.ends_with("-oauth") || cfg["oauth"].is_mapping() || cfg["auth_type"].as_str() == Some("oauth") {
        return ProviderType::CloudOAuth;
    }
    if cfg["api_key"].is_string() || cfg["api_key_env"].is_string() {
        return ProviderType::CloudApiKey;
    }
    ProviderType::Unknown
}
```

## Model Discovery (discover_models)

1. **Read config.yaml** — get current model, providers map, fallback chain
2. **Query llama-swap** at `http://127.0.0.1:8080/v1/models` via curl subprocess (NOT reqwest blocking — would hang tokio)
3. **Parse response** into local model entries with `source: "local"` or `"fallback"` (if in fallback chain)
4. **Build cloud models** from universal catalog — tag each as `"configured"` (user has provider) or `"available"` (not configured)
5. **Universal catalog** covers: xAI/Grok, Google/Gemini, Anthropic/Claude, OpenAI, DeepSeek/Nous, Meta/Llama, Mistral, Qwen
6. **Fallback fallback**: if no providers configured at all, show a minimal hardcoded default set

## Model Probing (probe_model_via_curl)

1. Map model prefix (`deepseek/`, `x-ai/`, `llama-swap/`, etc.) to config provider name
2. Read `base_url` and `api_key` from provider config
3. Send tiny POST via curl subprocess: `{"model": name, "messages": [{"role": "user", "content": "say hi"}], "max_tokens": 20}`
4. Parse JSON response — check BOTH `content` AND `reasoning_content` (for reasoning models)
5. On HTTP error, read response BODY (not just status code) for real error message
6. Cache result to `~/.hermes/wingman_probed.json`
7. Set `--max-time 30` for cold models that need VRAM loading

**PITFALL: Reasoning models** output chain-of-thought to `reasoning_content`. A probe with `max_tokens: 1` gets empty content. Use `max_tokens: 20` and check both fields.

**PITFALL: llama-swap HTTP 500** returns the error in the response BODY (HTML/text), not JSON. Don't skip non-success status codes — always parse the body.

## Chat Handler (handle_chat)

Two-tier approach:
1. **Direct API call**: Determine provider from current model prefix, build curl POST to `{base_url}/chat/completions`, check `content` + `reasoning_content`
2. **CLI fallback**: `hermes -z "message"` or `hermes --resume SESSION -z "message"`, extract session ID from stderr via regex

## Gateway Toggle

Gateway `stop` prompts for stdin confirmation. Must pipe `"y\n"` to child's stdin:

```rust
match std::process::Command::new("hermes")
    .args(["gateway", "stop"])
    .stdin(std::process::Stdio::piped())
    .spawn()
{
    Ok(mut child) => {
        if let Some(stdin) = child.stdin.take() {
            use std::io::Write;
            let _ = write!(&stdin, "y\n");
            drop(stdin);
        }
        let output = child.wait_with_output()?;
    }
}
```

## Gateway State Parsing

Gateway state JSON has a `gateway_state` field (`"running"` / `"stopped"`). Platforms list persists even after stop — NEVER use `platforms.isNotEmpty` to infer running state.

```rust
let is_running = json["gateway_state"].as_str() == Some("running");
```

## Setup Detection (detect_setup)

Check installation via BOTH hardcoded paths AND `which`:

```rust
let hermes_bin = ["/usr/bin/hermes", "/usr/local/bin/hermes", "/home/synth/.local/bin/hermes"]
    .iter()
    .find(|p| std::path::Path::new(p).exists())
    .map(|p| p.to_string())
    .or_else(|| {
        std::process::Command::new("which")
            .arg("hermes")
            .output().ok()
            .and_then(|o| if o.status.success() {
                String::from_utf8(o.stdout).ok().map(|s| s.trim().to_string())
            } else { None })
    });
```

Also check: config exists, API keys present, model configured, connected gateway platforms.

## Error Handling Pattern

Every handler returns `Json<serde_json::Value>` with a consistent structure:

```rust
// Success
Json(json!({"success": true, "model": body.model}))

// Error
Json(json!({"success": false, "error": e.to_string()}))
```

Some handlers use `Result<Json<...>, StatusCode>` for axum's built-in error handling.

## Testing Endpoints

```bash
# Health
curl http://127.0.0.1:9120/health

# Models
curl http://127.0.0.1:9120/models

# Config
curl http://127.0.0.1:9120/config

# Chat
curl -X POST http://127.0.0.1:9120/chat -H 'Content-Type: application/json' -d '{"message": "hi"}'

# Switch model
curl -X POST http://127.0.0.1:9120/models/switch -H 'Content-Type: application/json' -d '{"model": "deepseek/deepseek-v4-flash"}'

# Probe model
curl -X POST http://127.0.0.1:9120/models/probe -H 'Content-Type: application/json' -d '{"model": "deepseek/deepseek-v4-flash"}'

# Sessions
curl 'http://127.0.0.1:9120/sessions?limit=5'

# Logs
curl 'http://127.0.0.1:9120/logs?lines=10&level=all'

# Gateway
curl http://127.0.0.1:9120/gateway

# Gateway toggle
curl -X POST http://127.0.0.1:9120/gateway/toggle -H 'Content-Type: application/json' -d '{"action": "start"}'

# Cron
curl http://127.0.0.1:9120/cron

# Providers
curl http://127.0.0.1:9120/providers

# Setup detect
curl http://127.0.0.1:9120/setup/detect
```
