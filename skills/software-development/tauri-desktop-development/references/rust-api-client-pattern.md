# Rust HTTP API Client Pattern (Tauri Desktop)

Pattern for building a Rust HTTP client module (`api.rs`) in a Tauri desktop app that mirrors a Rails service object (`janus_api.rb`). Both clients consume the same external JSON API, enabling dual-platform (web + desktop) apps from a single backend.

## Architecture

```
┌─────────────────────────┐
│  Backend API            │  e.g. Node.js/Express on :3001
│  (shared data source)   │
└──────┬──────────┬───────┘
       │          │
       ▼          ▼
┌──────────┐  ┌──────────┐
│ Rails    │  │ Tauri    │
│ Web App  │  │ Desktop  │
│          │  │          │
│ janus_   │  │ api.rs   │
│ api.rb   │  │ (Rust)   │
│ (Ruby)   │  │          │
└──────────┘  └──────────┘
```

## Key Design Decisions

### 1. Inline Tokio Runtime

Tauri commands are synchronous (`#[tauri::command] fn ... -> Result<String, String>`), but HTTP clients like `reqwest` are async. The pattern: **create a short-lived Tokio runtime per command call** rather than injecting one via state.

```rust
#[tauri::command]
fn get_channels(state: tauri::State<'_, Mutex<AppState>>) -> Result<String, String> {
    let (api_base, token) = {
        let s = state.lock().map_err(|e| e.to_string())?;
        (s.api_base.clone(), s.auth_token.clone())
    };
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
    rt.block_on(api::get_channels(&api_base, &token))
}
```

**Why not a shared runtime:** A shared runtime in Tauri state introduces lifetime complexities and doesn't improve performance meaningfully for the request-per-command pattern. The overhead of creating a runtime per call (~microseconds) is negligible compared to the HTTP round-trip.

### 2. Auth Token in AppState, Not Headers

The auth token flows through `AppState` (a `Mutex<AppState>` managed by Tauri), not hardcoded into the API client:

```rust
// state.rs
pub struct AppState {
    pub api_base: String,
    pub auth_token: Option<String>,
    pub user_name: Option<String>,
    pub user_id: Option<String>,
}

// lib.rs — store on register/login
if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&result) {
    if let Some(token) = parsed["data"]["token"].as_str() {
        state.lock().map_err(|e| e.to_string())?.auth_token = Some(token.to_string());
    }
}
```

The `api.rs` module receives the token as a parameter — it doesn't know about app state:

```rust
pub async fn get_channels(api_base: &str, token: &Option<String>) -> Result<String, String> {
    let url = format!("{}/api/channels", api_base);
    client().get(&url)
        .headers(headers(token))
        .send().await
        .map_err(|e| format!("Connection error: {}", e))?
        .text().await
        .map_err(|e| format!("Read error: {}", e))
}
```

### 3. String-returning Commands

Tauri commands return `Result<String, String>` (serialized JSON on success, error message on failure). The frontend JS parses the JSON string:

```javascript
// Frontend JS (Tauri webview)
let result = JSON.parse(await invoke('get_channels'));
// result = { success: true, data: [...] }
```

This keeps the Rust code simple — it just proxies the backend's raw JSON response. No deserialization/serialization overhead on the Rust side.

### 4. Mirror Rails Service Object

Each method in `api.rs` has a 1:1 correspondence with a method in the Rails `JanusApi` service:

| Purpose | Rails (`janus_api.rb`) | Rust (`api.rs`) |
|---------|----------------------|-----------------|
| Health | `self.health` → `get("/api/health")` | `get_health(api_base)` |
| Channels | `self.list_channels` → `get("/api/channels")` | `get_channels(api_base, token)` |
| Messages | `self.send_message(...)` → `post("/api/messages", ...)` | `send_message(api_base, token, ...)` |
| Auth | `self.register(...)` → `post("/api/auth/register", ...)` | `register(api_base, name, type)` |

This makes it easy to add new endpoints to both clients simultaneously.

## API Client Module Template

```rust
/// Janus API client in Rust

const DEFAULT_TIMEOUT: u64 = 15;

fn client() -> reqwest::Client {
    reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(DEFAULT_TIMEOUT))
        .build()
        .unwrap()
}

fn headers(token: &Option<String>) -> reqwest::header::HeaderMap {
    let mut h = reqwest::header::HeaderMap::new();
    h.insert(reqwest::header::CONTENT_TYPE, "application/json".parse().unwrap());
    if let Some(t) = token {
        h.insert(reqwest::header::AUTHORIZATION, format!("Bearer {}", t).parse().unwrap());
    }
    h
}

pub async fn get_health(api_base: &str) -> Result<String, String> {
    let url = format!("{}/api/health", api_base);
    client().get(&url)
        .headers(headers(&None))
        .send().await
        .map_err(|e| format!("Connection error: {}", e))?
        .text().await
        .map_err(|e| format!("Read error: {}", e))
}

pub async fn register(api_base: &str, name: &str, agent_type: &str) -> Result<String, String> {
    let url = format!("{}/api/auth/register", api_base);
    let body = serde_json::json!({ "name": name, "type": agent_type });
    let resp = client().post(&url)
        .headers(headers(&None))
        .json(&body)
        .send().await
        .map_err(|e| format!("Connection error: {}", e))?;
    resp.text().await.map_err(|e| format!("Read error: {}", e))
}

pub async fn get_channels(api_base: &str, token: &Option<String>) -> Result<String, String> {
    let url = format!("{}/api/channels", api_base);
    client().get(&url)
        .headers(headers(token))
        .send().await
        .map_err(|e| format!("Connection error: {}", e))?
        .text().await
        .map_err(|e| format!("Read error: {}", e))
}

pub async fn send_message(api_base: &str, token: &Option<String>, channel_id: &str,
    content: &str, author_id: &str, author_name: &str, author_type: &str) -> Result<String, String> {
    let url = format!("{}/api/messages", api_base);
    let body = serde_json::json!({
        "content": content, "authorId": author_id, "authorName": author_name,
        "authorType": author_type, "channelId": channel_id
    });
    let resp = client().post(&url)
        .headers(headers(token))
        .json(&body)
        .send().await
        .map_err(|e| format!("Connection error: {}", e))?;
    resp.text().await.map_err(|e| format!("Read error: {}", e))
}
```

## Cargo.toml Dependencies

```toml
[dependencies]
tauri = { version = "2", features = ["tray-icon"] }
tauri-plugin-shell = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
reqwest = { version = "0.12", features = ["json"] }
tokio = { version = "1", features = ["full"] }
```

## Registration in lib.rs

```rust
mod api;
mod state;
use state::AppState;

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(Mutex::new(AppState::new()))
        .invoke_handler(tauri::generate_handler![
            get_health,
            get_channels,
            register,
            send_message,
            // ... all commands
        ])
        .run(tauri::generate_context!())
        .expect("error while running app");
}
```