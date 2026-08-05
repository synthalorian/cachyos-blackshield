---
name: sse-stream-transform
version: 2.0
category: software-development
description: >-
  Patterns for transforming streaming SSE (Server-Sent Events) data from LLM API
  proxying in Rust Axum backends, with emphasis on stateful filtering across
  chunk boundaries. Covers think-tag stripping, reasoning content handling, and
  the general pattern of maintaining mutable state through SSE stream lifetimes.
trigger: >-
  Building or debugging a Rust Axum backend that proxies LLM streaming
  responses, where the proxy needs to filter, transform, or strip content
  from streaming SSE output (think tags, reasoning content, custom formatting).
  Also triggered by bug reports of "blank responses from local models",
  "model not using my identity/customs", or "reasoning garbage leaking through"
  in LLM API proxies. ANY time the backend calls a provider API directly
  instead of through a CLI that handles identity injection.
  **ALSO triggered by 401 errors from OAuth-based providers (Nous free tier, xAI) —
  see the production-ready-rust-flutter-projects skill's OAuth section
  for the auth.json routing pattern.**
---

# SSE Stream Transform

## When to use this

You're building a Rust backend that proxies streaming LLM API responses via SSE (Server-Sent Events). The upstream model outputs content that needs filtering — think tags, reasoning traces, custom formatting — but you're seeing the raw unfiltered content appear in the downstream response. The fix isn't the regex or the filter logic itself; it's that the filter function lacks state across SSE chunk boundaries.

## Critical upstream: Identity injection (SOUL.md)

Before you can filter streaming output, you need the model to respond AS the right persona. When a Rust backend makes **direct HTTP calls** to a provider API (llama-swap, Ollama, cloud) rather than through a CLI like `hermes --oneshot`, it bypasses all identity injection. The model gets a bare `[{"role": "user", "content": "..."}]` — no system prompt, no persona, no soul.

**The fix: load ~/.hermes/SOUL.md and inject as system message.**

```rust
/// Load SOUL.md identity from ~/.hermes/SOUL.md
/// Returns empty string if not found.
fn load_soul_md() -> String {
    let soul_path = home_dir().join(".hermes").join("SOUL.md");
    match std::fs::read_to_string(&soul_path) {
        Ok(content) => content.trim().to_string(),
        Err(_) => String::new(),
    }
}

/// Build messages array with SOUL.md identity prepended.
fn build_chat_messages(message: &str) -> Vec<serde_json::Value> {
    let soul = load_soul_md();
    let mut msgs = Vec::new();
    if !soul.is_empty() {
        msgs.push(serde_json::json!({"role": "system", "content": soul}));
    }
    msgs.push(serde_json::json!({"role": "user", "content": message}));
    msgs
}

// Usage:
let messages = build_chat_messages(&user_message);
let payload = serde_json::json!({
    "model": model_name,
    "messages": messages,
    "stream": true,
    // ...
});
```

### The two-endpoint trap

LLM proxy backends typically have TWO chat endpoints — a **streaming** one (SSE) and a **non-streaming** one (HTTP POST → JSON response). Fixing only one while leaving the other bare is the most common mistake.

- **Streaming endpoint** (usually `/chat/stream`, SSE): Uses `build_chat_messages()` or inline injection
- **Non-streaming endpoint** (usually `/chat`, JSON): Also uses `load_soul_md()` and injects before resume context and user message

Both must inject the system prompt. The non-streaming one is also used by the Flutter frontend's model probing and single-turn requests.

### CLI fallback does NOT need injection

When the backend falls back to running `hermes -z <message>` or `hermes --oneshot <message>` through subprocess, identity injection is already handled by the CLI. Only direct HTTP calls to provider APIs need manual injection.

### The auth header bug pattern

When copying auth header construction between handlers, the format string can silently break. This exact bug was found in 3 places in a single backend:

```rust
// WRONG — literal "***" is printed instead of the key:
curl.arg(format!("Authorization: Bearer *** key"));

// RIGHT — proper interpolation:
curl.arg(format!("Authorization: Bearer {}", api_key));
```

The wrong version sends a literal `Authorization: Bearer *** key` as the actual header value for every request. The API accepts it (it looks vaguely like a real key), and the response generally fails with an auth error that looks like a model/server problem.

Search pattern: `format!(.*Bearer` in Rust code to find all auth header constructions. Audit every match for correct `{}` interpolation.

## Core pattern: stateful filtering across chunks

SSE streaming splits model output into arbitrary byte-sized chunks. When a transformation spans multiple chunks (e.g., `<think>` opens in chunk 3 and closes in chunk 15), a stateless filter function that resets state on each call will:

- **Miss the opening tag** — it arrived in an earlier chunk, so `in_think` starts `false`
- **Pass the closing tag through** — no opening tag was seen in this call, so `</think>` is treated as regular text
- **Leak all content in between** — since `in_think` was never set `true` for any chunk

### The fix: track mutable state across the stream

```rust
// In your stream handler — before the chunk processing loop:
let mut in_think: bool = false;

// Inside the per-chunk processing, pass state by reference:
let delta = strip_think_stream(chunk_text, &mut in_think);
if !delta.is_empty() {
    // forward to downstream consumer
}
```

### The stateful filter function

Replace a signature of `fn filter(s: &str) -> String` with:

```rust
fn strip_think_stream(s: &str, in_think: &mut bool) -> String {
    let mut result = String::with_capacity(s.len());
    let mut i = 0;
    let bytes = s.as_bytes();
    while i < bytes.len() {
        if !*in_think && i + 6 < bytes.len()
            && bytes[i] == b'<' && bytes[i+1] == b't'
            && bytes[i+2] == b'h' && bytes[i+3] == b'i'
            && bytes[i+4] == b'n' && bytes[i+5] == b'k'
            && bytes[i+6] == b'>'
        {
            *in_think = true;
            i += 7;
            continue;
        }
        if *in_think && i + 7 < bytes.len()
            && bytes[i] == b'<' && bytes[i+1] == b'/'
            && bytes[i+2] == b't' && bytes[i+3] == b'h'
            && bytes[i+4] == b'i' && bytes[i+5] == b'n'
            && bytes[i+6] == b'k' && bytes[i+7] == b'>'
        {
            *in_think = false;
            i += 8;
            continue;
        }
        if !*in_think {
            result.push(bytes[i] as char);
        }
        i += 1;
    }
    result
}
```

## Handling different model output formats

### Local GGUF models (Qwen via llama-server/llama-swap)
- Reasoning AND output both arrive in `choice["delta"]["content"]`
- Thinking is wrapped in `<think>...</think>` tags generated by the model's template
- Use the stateful `strip_think_stream` pattern above
- The `--reasoning off` flag in llama.cpp helps but Qwen models may still emit think tags

### Cloud API models (DeepSeek, others via OpenAI-compatible endpoints)
- Reasoning arrives in `choice["delta"]["reasoning_content"]` — a separate field
- Skip this field entirely — only process `choice["delta"]["content"]`
- Cloud models typically do NOT emit `<think>` tags in content
- Code pattern: `let raw = if !content.is_empty() { content } else { "" };`

### kimi-k2.6 via kimi-coding proxy (special case)
- Reasoning arrives in `choice["delta"]["reasoning_content"]` — a separate field (cloud model pattern)
- BUT the model ALSO emits `<think>...</think>` tags inside `choice["delta"]["content"]` — double emission
- Must handle BOTH: extract `reasoning_content` as structured reasoning, AND strip `<think>` blocks from `content`
- Deduplicate by preferring `reasoning_content` — do not emit the `<think>` block as content if `reasoning_content` was already emitted
- See `references/kimi-k2.6-tool-calling-integration.md` in the shark-language skill for full implementation

### Detection
When debugging: curl the streaming endpoint and look at raw SSE output. If you see:
- `"reasoning_content": "..."` — cloud model, skip the field (or emit as separate reasoning stream)
- `data: {"content":"<think>..."}` then `"content":"</think>"` many chunks later — local model, need stateful filter
- BOTH `"reasoning_content"` AND `"content":"<think>..."` — kimi-k2.6 double emission, deduplicate

## Common pitfalls

1. **Stateless filter**: The #1 mistake. A `fn(s: &str) -> String` resets state on every SSE delta. The opening `<think>` and closing `</think>` arrive in different chunks, so the filter misses both and all thinking leaks through.

2. **Treating `reasoning_content` as content**: Cloud models put reasoning in a separate field. Including it in the "fallback to reasoning if no content" logic dumps the model's internal monologue into the chat.

3. **Fragmented tags**: `<think>` can be split across chunks as `<thi` + `nk>`. The byte-matching pattern above handles this because it scans each chunk independently with the state, but if a chunk boundary falls IN the middle of `<think>`, the opening won't be detected. The fix: accumulate chunks in a small lookback buffer before matching. (This is rare in practice — modern SSE implementations usually deliver complete tokens.)

4. **Not verifying with curl first**: Always test streaming output with raw curl before debugging the Flutter/Dart frontend. Curl shows the unfiltered SSE data the backend emits.

5. **`data:` prefix without space**: SSE spec allows `data: {"key":...}` (no space after colon). Parsers that expect `data: ` (with space) silently drop all events. **Always use `starts_with("data:")` + `trim_start()`, never `starts_with("data: ")` + fixed offset.**

   ```rust
   // WRONG — misses events from proxies that omit the space
   if line.starts_with("data: ") {
       let data = &line[6..];  // panic if no space
   
   // RIGHT — handles both "data: {...}" and "data:{...}"
   if line.starts_with("data:") {
       let data = line["data:".len()..].trim_start();
   ```

   This was the root cause of a 0-token bug in OpenShark's Kimi proxy integration. The proxy at `127.0.0.1:8699` returns `data:{"delta":...}` with no space.

## In-memory model override pattern

When your backend has a model-switching endpoint (`POST /models/switch`), **never write the selected model to the user's config file**. Writing to config.yaml corrupts the user's global Hermes state — their CLI, Discord, Telegram all see the wrong model.

### The fix: Arc<Mutex<Option<String>>> in AppState

```rust
#[derive(Clone)]
struct AppState {
    hermes_home: PathBuf,
    /// In-memory model override. When Some, all chat requests use this model.
    /// When None, falls back to config.yaml's `model:` setting.
    override_model: Arc<Mutex<Option<String>>>,
}

impl AppState {
    fn new() -> Self {
        Self {
            hermes_home: hermes_home_dir(),
            override_model: Arc::new(Mutex::new(None)),
        }
    }
}
```

### Getter: override first, config fallback

```rust
fn get_active_model(state: &AppState) -> String {
    // Check in-memory override first
    if let Ok(lock) = state.override_model.lock() {
        if let Some(ref model) = *lock {
            return model.clone();
        }
    }
    // Fall back to config.yaml
    let config = read_config();
    config["model"].as_str()
        .or_else(|| config["model"]["default"].as_str())
        .unwrap_or_default()
}
```

### Switch handler: never touch config.yaml

```rust
async fn switch_model(
    State(state): State<Arc<AppState>>,
    Json(body): Json<SwitchModelRequest>,
) -> Json<serde_json::Value> {
    match state.override_model.lock() {
        Ok(mut override_model) => {
            let model = body.model.clone();
            if model.is_empty() {
                *override_model = None;
            } else {
                *override_model = Some(model.clone());
            }
            Json(serde_json::json!({"success": true, "model": model}))
        }
        Err(e) => Json(serde_json::json!({"success": false, "error": format!("Lock poisoned: {}", e)})),
    }
}
```

### Propagation into streaming handlers

The tokio::spawn block captures ownership via `async move`, so extract the model BEFORE the spawn:

```rust
async fn chat_stream_handler(
    State(state): State<Arc<AppState>>,
    Query(query): Query<ChatStreamQuery>,
) -> Sse<impl Stream<...>> {
    let (tx, rx) = mpsc::channel::<Result<Event, Infallible>>(32);
    let message = query.message;
    let active_model = get_active_model(&state);

    tokio::spawn(async move {
        // active_model is already captured — use it directly
        let current_model = if !active_model.is_empty() {
            &active_model
        } else {
            config["model"].as_str().unwrap_or("")
        };
        // ... rest of handler
    });
}
```

### Endpoint coverage

| Endpoint | Fix |
|---|---|
| `POST /models/switch` | Stores in `state.override_model` — NOT config.yaml |
| `GET /models` | Uses `get_active_model()` for the `current` field |
| `GET /chat/stream` | Captures `get_active_model()` before tokio::spawn |
| `POST /chat` | Passes `get_active_model()` to non-streaming handler |

## SSE streaming architecture pattern

End-to-end structure for a Rust Axum SSE endpoint that proxies LLM API responses:

### Channel setup

```rust
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use axum::response::sse::Event;

let (tx, rx) = mpsc::channel::<Result<Event, std::convert::Infallible>>(32);
```

### Spawn the streaming task

```rust
tokio::spawn(async move {
    // 1. Resolve model + provider
    let config = read_config();
    let current_model = /* from override or config */;
    let prefix = current_model.split('/').next().unwrap_or("");
    let model_short = current_model.split('/').last().unwrap_or(current_model);

    // 2. Route to provider
    let provider_name = match prefix {
        "llama-swap" => "llama-swap",
        "deepseek" | "nous" => "nous",
        "anthropic" | "claude" => "anthropic",
        // ... etc
        _ => prefix,
    };

    let base_url = config["providers"][provider_name]["base_url"]
        .as_str().unwrap_or("").to_string();

    // 3. If no direct provider, fall back to CLI
    if base_url.is_empty() {
        let output = Command::new("hermes")
            .args(&["-z", &message])
            .output();
        // emit output via tx
        return;
    }

    // 4. Stream via reqwest
    let payload = serde_json::json!({
        "model": model_short,
        "messages": build_chat_messages(&message),
        "stream": true,
        "max_tokens": 8192,
        "temperature": 0.7,
    });

    let client = reqwest::Client::new();
    let mut req = client.post(&chat_url)
        .header("Content-Type", "application/json");
    if /* has api key */ {
        req = req.header("Authorization", format!("Bearer {}", api_key));
    }

    match req.json(&payload).send().await {
        Ok(response) => {
            let mut stream = response.bytes_stream();
            let mut buffer = String::new();
            let mut in_think = false;

            while let Some(chunk) = stream.next().await {
                // parse SSE, strip think tags, emit via tx
            }
        }
        Err(e) => {
            let _ = tx.send(Ok(Event::default().data(
                serde_json::json!({"error": e.to_string()}).to_string()
            ))).await;
        }
    }
});

// 5. Return the ReceiverStream wrapped in Sse
let stream = ReceiverStream::new(rx);
Sse::new(stream).keep_alive(
    axum::response::sse::KeepAlive::new()
        .interval(Duration::from_secs(15))
        .text("keep-alive"),
)
```

### Provider routing logic

The same model-to-provider mapping must be duplicated in every endpoint that makes direct API calls. Extract it into a shared function or match block to avoid drift:

- **`llama-swap`** → config provider `llama-swap`, base_url `http://127.0.0.1:8080/v1`
- **`ollama`** → config provider `ollama`, base_url `http://127.0.0.1:11434/v1`
- **`x-ai`/`xai`/`grok`** → scan for `xai`/`grok` containing provider in config, fallback `xai-oauth`
- **`google`** → `gemini-oauth` or `gemini`
- **`deepseek`/`nous`** → try `nous` then `deepseek`
- **`anthropic`/`claude`** → `anthropic`
- **`openai`** → `openai`
- **`meta-llama`/`llama`** → `openai` (routed through OpenAI-compatible endpoint)

## Flutter frontend: Linux rendering fixes

When building a Flutter desktop app for Linux that displays LLM responses:

### Emoji rendering (tofu squares)

Flutter on Linux does not bundle an emoji font. Emoji characters like 🎹🦞 render as tofu squares (`ð¹ð¦`) unless you configure a fallback.

**Fix:** Add `fontFamilyFallback: ['Noto Color Emoji']` to every TextStyle in chat bubbles AND the global text theme:

```dart
// Theme level (applies to Theme.of(context).textTheme.* styles)
TextTheme(
  bodyLarge: TextStyle(color: scheme.text, fontFamilyFallback: ['Noto Color Emoji']),
  bodyMedium: TextStyle(color: scheme.textDim, fontFamilyFallback: ['Noto Color Emoji']),
  // ... all other text styles
)

// Chat bubble level (inline styles bypass theme)
Text(
  message.text,
  style: TextStyle(
    color: scheme.text,
    fontSize: 13,
    fontFamilyFallback: ['Noto Color Emoji'],  // ← critical for chat
  ),
)
```

**Prerequisite:** The emoji font must be installed on the system. Check with:
```bash
fc-match emoji
# Should show: NotoColorEmoji.ttf: "Noto Color Emoji" "Regular"
```

If missing: `sudo pacman -S noto-fonts-emoji` (Arch) or equivalent for other distros.

### Wayland window sizing

Flutter's GTK embedder does not size windows correctly on native Wayland — the content doesn't expand to fill the tiled area.

**Fix:** Force X11 backend via GDK_BACKEND environment variable in the desktop entry:
```bash
Exec=env GDK_BACKEND=x11 /path/to/hermes_wingman
```

## Verification

```bash
# Test local model streaming (switch first, wait for load)
curl -s -X POST http://127.0.0.1:9120/models/switch \
  -H 'Content-Type: application/json' \
  -d '{"model": "llama-swap/synthclaw-9b-128k"}'
sleep 8
timeout 30 curl -s -N "http://127.0.0.1:9120/chat/stream?message=hi" 2>&1

# Expected: no <think> tags, no reasoning traces, just the model's response
# Bad: data: {"content":"<think>..."} then data: {"content":"</think>"}
# Good: data: {"content":"🎹🦞 Synthclaw online..."}

# Test cloud model streaming
curl -s -X POST http://127.0.0.1:9120/models/switch \
  -H 'Content-Type: application/json' \
  -d '{"model": "deepseek/deepseek-v4-flash"}'
timeout 20 curl -s -N "http://127.0.0.1:9120/chat/stream?message=hi" 2>&1
```

## References

- `references/qwen-think-tag-quirk.md` — Details on how Qwen models emit `<think>` tags across SSE chunks and the specific multi-chunk discovery from the Hermes Wingman debugging session
