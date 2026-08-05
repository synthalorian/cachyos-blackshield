# Auto-Configure Endpoint Design

The auto-configure endpoint is the core of any Hermes setup tool. It scans the user's environment, discovers available providers, and writes a working config.yaml — all without user intervention.

## Endpoint Contract

```
POST /setup/auto-configure
Body: {} (no input needed — fully automatic)
```

### Response

```json
{
  "success": true,
  "config_written": true,
  "default_model": "deepseek/deepseek-v4-flash",
  "discovered": [
    {"name": "llama-swap", "type": "local", "status": "running"},
    {"name": "ollama", "type": "local", "status": "running"},
    {"name": "openai", "type": "cloud", "source": "env:OPENAI_API_KEY", "status": "key_found"}
  ],
  "providers_count": 6,
  "fallback_count": 24
}
```

## Implementation (Rust Axum)

### Scan Order

1. **Local services** (quick port scan — 500ms timeout each)
2. **Cloud providers** (env var scan — instant)
3. **Existing config** (preserve already-configured providers)
4. **Model selection** (local first, then cloud, then existing)
5. **Config write** (merge, don't overwrite)

### Port Scan

```rust
fn check_port(port: u16) -> bool {
    use std::net::TcpStream;
    TcpStream::connect_timeout(
        &format!("127.0.0.1:{}", port).parse().unwrap(),
        std::time::Duration::from_millis(500),
    ).is_ok()
}

// Usage:
let llama_swap_running = check_port(8080);
let ollama_running = check_port(11434);
```

### llama-swap Model Discovery

When llama-swap is running, auto-discover its available models:

```rust
if let Ok(output) = std::process::Command::new("curl")
    .args(["-s", "--max-time", "2", "http://127.0.0.1:8080/v1/models"])
    .output()
{
    if let Ok(body) = serde_json::from_slice::<serde_json::Value>(&output.stdout) {
        if let Some(data) = body["data"].as_array() {
            for m in data {
                if let Some(id) = m["id"].as_str() {
                    fallback_providers.push(format!("llama-swap/{}", id));
                }
            }
        }
    }
}
```

### Env Var Scan

```rust
let env_key_map = vec![
    ("OPENAI_API_KEY", "openai", "https://api.openai.com/v1"),
    ("ANTHROPIC_API_KEY", "anthropic", "https://api.anthropic.com/v1"),
    ("GEMINI_API_KEY", "gemini", "https://generativelanguage.googleapis.com/v1beta"),
    ("GROK_API_KEY", "xai", "https://api.x.ai/v1"),
    ("MISTRAL_API_KEY", "mistral", "https://api.mistral.ai/v1"),
    ("DEEPSEEK_API_KEY", "nous", "https://api.nousresearch.com/v1"),
    ("OPENROUTER_API_KEY", "openrouter", "https://openrouter.ai/api/v1"),
];

for (env_var, provider_name, base_url) in &env_key_map {
    if let Ok(key) = std::env::var(env_var) {
        if !key.is_empty() && !providers.contains_key(*provider_name) {
            providers.insert(provider_name.to_string(), serde_json::json!({
                "base_url": base_url,
                "api_key_env": env_var,  // reference, not inline value
            }));
            discovered.push(serde_json::json!({
                "name": *provider_name,
                "type": "cloud",
                "source": format!("env:{}", env_var),
                "status": "key_found"
            }));
        }
    }
}
```

**CRITICAL:** Use `api_key_env` (env var reference) not `api_key` (inline value for cloud providers). This keeps secrets out of config.yaml. For local services (llama-swap, ollama) use `api_key` with a sentinel value like `"llama-swap-local"`.

### Model Selection Priority

```rust
// 1. First llama-swap model as default
if !fallback_providers.is_empty() {
    default_model = fallback_providers[0].clone();
}
// 2. Cloud provider with known model
else if !discovered.is_empty() {
    let cloud_model_map = [
        ("openai", "openai/gpt-4o-mini"),
        ("anthropic", "anthropic/claude-sonnet-4"),
        ("gemini", "google/gemini-2.5-flash"),
        ("xai", "x-ai/grok-4-mini"),
        ("mistral", "mistral/mistral-small"),
        ("nous", "deepseek/deepseek-v4-flash"),
    ];
    for (name, model) in &cloud_model_map {
        if discovered.iter().any(|d| d["name"] == *name) {
            default_model = model.to_string();
            break;
        }
    }
}
// 3. Preserve existing config model (highest priority)
if !existing_model.is_empty() {
    default_model = existing_model.to_string();
}
```

### Config YAML Generation (CRITICAL — Must Deep-Merge)

**WRONG — string building drops all non-provider sections:**
```rust
let mut config_yaml = String::new();
config_yaml.push_str(&format!("model: {}\n", default_model));
// + fallback_providers + providers
// Result: agent, delegation, display, terminal, security, etc. ALL LOST
```

**CORRECT — use serde_yaml Value deep-merge:**
```rust
// Parse existing config
let existing_raw = std::fs::read_to_string(&state.config_path()).unwrap_or_default();
let existing: serde_yaml::Value = serde_yaml::from_str(&existing_raw)
    .unwrap_or(serde_yaml::Value::Null);

// Clone and mutate in-place (all non-touched sections survive)
let mut config_value = existing.clone();

if let Some(mapping) = config_value.as_mapping_mut() {
    // Update model
    mapping.insert(
        serde_yaml::Value::String("model".into()),
        serde_yaml::Value::String(default_model.clone()),
    );

    // Update fallback_providers
    if !fallback_providers.is_empty() {
        let fb_list: Vec<serde_yaml::Value> = fallback_providers.iter()
            .map(|s| serde_yaml::Value::String(s.clone()))
            .collect();
        mapping.insert(
            serde_yaml::Value::String("fallback_providers".into()),
            serde_yaml::Value::Sequence(fb_list),
        );
    }

    // Build providers map from discovered + existing
    let mut providers_map = serde_yaml::Mapping::new();
    for (name, cfg) in &providers {
        let mut prov = serde_yaml::Mapping::new();
        if let Some(url) = cfg["base_url"].as_str() {
            prov.insert("base_url".into(), url.into());
        }
        if let Some(key) = cfg["api_key"].as_str() {
            prov.insert("api_key".into(), key.into());
        }
        if let Some(env) = cfg["api_key_env"].as_str() {
            prov.insert("api_key_env".into(), env.into());
        }
        providers_map.insert(name.clone().into(), serde_yaml::Value::Mapping(prov));
    }

    // Merge existing providers (existing takes precedence)
    if let Some(existing_provs) = mapping.get(&"providers".into()) {
        if let Some(existing_map) = existing_provs.as_mapping() {
            for (k, v) in existing_map {
                providers_map.insert(k.clone(), v.clone());
            }
        }
    }

    mapping.insert("providers".into(), serde_yaml::Value::Mapping(providers_map));
}

let config_yaml = serde_yaml::to_string(&config_value)
    .unwrap_or_else(|_| format!("model: {}", default_model));
let _ = std::fs::write(&state.config_path(), &config_yaml);
```

**Why this matters:** The existing config may contain:
- `model.provider: nous` — provider routing
- `agent.max_turns: 90` — session limits
- `delegation.model: deepseek/deepseek-v4-flash` — subagent model
- `display.skin: synthwave` — theme
- `terminal.backend: local` — terminal mode
- `security.tirith_enabled: true` — security
- `compression.*`, `checkpoints.*`, `approvals.*`, etc.

String-building destroys ALL of these. Deep-merge preserves them.

### Provider Probe (POST /setup/probe-provider)

After auto-configure, probe the selected provider to verify it works:

```rust
POST /setup/probe-provider
Body: {"provider": "openai", "model": "gpt-4o-mini"}  // model is optional for well-known providers

Response: {"success": true, "provider": "openai", "model": "gpt-4o-mini"}
Response (failure): {"success": false, "error": "Authentication failed — check your API key", "provider": "openai"}
```

The probe sends a minimal request:
- `model`: auto-picked for well-known providers (gpt-4o-mini for openai, claude-sonnet-4 for anthropic, etc.)
- `messages`: `[{"role": "user", "content": "say hi"}]`
- `max_tokens`: 10
- `stream`: false

**PITFALL (auth header):** When constructing the Authorization header, use proper Rust format string interpolation:
```rust
// CORRECT:
curl.arg("-H").arg(format!("Authorization: Bearer {}", api_key));

// WRONG — sends literal "Bearer *** key":
curl.arg("-H").arg(format!("Authorization: Bearer *** api_key));
// This silently breaks every API call — the provider gets "Bearer *** api_key"
// instead of "Bearer sk-xxx..." and returns 401.
```

**AUDIT PATTERN:** Search ALL `.rs` files for `format!(.*Bearer` to catch every occurrence. If you fix one but miss another, the unfixed endpoint still silently fails auth. The bug is easy to miss because the `curl -s` flag hides HTTP errors and the response body may show a generic error.

Error detection from response body:
- Contains "401" / "unauthorized" / "Unauthorized" / "auth" → "Authentication failed"
- Contains "429" / "rate" → "Rate limited"
- No "choices" array or empty content → "responded but no content"
- Non-JSON response → show raw snippet

**PITFALL (empty error for auth failures):** When curl returns non-200 and stdout is empty, the error message becomes an empty string. Add a fallback for blank responses:

```rust
let snippet = msg.chars().take(200).collect::<String>();
if snippet.trim().is_empty() {
    snippet = "no response from provider (check logs)".to_string();
}
```

## Chat Streaming via SSE

For real-time chat display in Hermes GUIs, implement SSE streaming:

```rust
// Axum handler returning SSE stream
async fn chat_stream_handler(
    Query(query): Query<ChatStreamQuery>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let (tx, rx) = mpsc::channel::<Result<Event, Infallible>>(32);

    tokio::spawn(async move {
        // 1. Determine provider from config (same logic as handle_chat)
        // 2. Make streaming API call with reqwest
        let payload = serde_json::json!({
            "model": model_short,
            "messages": [{"role": "user", "content": message}],
            "stream": true,
        });
        let response = client.post(&chat_url)
            .header("Authorization", format!("Bearer {}", api_key))
            .json(&payload)
            .send().await?;

        // 3. Parse SSE chunks from provider, forward as events
        let mut stream = response.bytes_stream();
        while let Some(chunk) = stream.next().await {
            // parse "data: {"choices":[{"delta":{"content":"..."}}]}"
            let evt = Event::default().data(json!({"content": delta}).to_string());
            tx.send(Ok(evt)).await;
        }
        tx.send(Ok(Event::default().data("[DONE]"))).await;
    });

    Sse::new(ReceiverStream::new(rx)).keep_alive(
        KeepAlive::new().interval(Duration::from_secs(15)).text("keep-alive"),
    )
}
```

### Flutter SSE Client

```dart
Future<void> _streamChat(BackendService service, String message, ChatMessage placeholder) async {
  final uri = Uri.parse('http://127.0.0.1:9120/chat/stream')
      .replace(queryParameters: {'message': message});
  final request = await HttpClient().getUrl(uri);
  final response = await request.close();

  await for (final chunk in response.transform(utf8.decoder)) {
    // Parse SSE lines, extract data.payload
    // Update placeholder text incrementally
  }
}
```

## End-to-End Verification

When building or modifying the setup wizard, always verify EVERY step with actual HTTP calls:

```bash
# 1. Check backend is running
curl -s http://127.0.0.1:9120/health

# 2. Test detect
curl -s http://127.0.0.1:9120/setup/detect | jq

# 3. Test install (hermes already installed shows "Requirement already satisfied")
curl -s -X POST http://127.0.0.1:9120/setup/install -H 'Content-Type: application/json' -d '{"method": "pip"}'

# 4. Test auto-configure
curl -s -X POST http://127.0.0.1:9120/setup/auto-configure -H 'Content-Type: application/json' -d '{}'

# 5. Test probe (choose a provider you configured)
curl -s -X POST http://127.0.0.1:9120/setup/probe-provider -H 'Content-Type: application/json' -d '{"provider": "openai", "model": "gpt-4o-mini"}'

# 6. Test SSE streaming
timeout 10 curl -s -N "http://127.0.0.1:9120/chat/stream?message=say+hello+in+3+words"

# 7. Finally, check config.yaml was written correctly
curl -s http://127.0.0.1:9120/config | jq '.parsed'
```

This catches format-string bugs, missing routes, and config merge issues before the user sees them.

## Rules for Any Language

1. **Never hardcode user paths.** Use `$HOME` env var + `which` command or `hermes_home_dir()` in Rust.
2. **Merge, don't overwrite.** Always deep-merge with existing config to preserve user settings.
3. **Use `api_key_env` for cloud keys.** Don't inline secrets into config.yaml.
4. **Auto-discover local models** when llama-swap is running (GET /v1/models).
5. **Return structured discovery data** so the UI can render provider cards.
6. **Test the result** with a minimal probe request.
7. **Format strings in Rust**: `format!("Bearer {}", key)`, never `format!("Bearer *** key)`.
8. **End-to-end verification**: When the user says "verify" or "end to end", run the actual service and hit the endpoints with curl. Code review alone isn't sufficient.
9. **Audit for auth-header bugs after any refactor:** Search `format!(.*Bearer` across ALL `.rs` files. Fixing one and missing another leaves a silent auth failure.
10. **Handle blank error responses:** When a probe returns non-200 and the body is empty, provide a fallback message like "no response from provider" instead of an empty error string.
