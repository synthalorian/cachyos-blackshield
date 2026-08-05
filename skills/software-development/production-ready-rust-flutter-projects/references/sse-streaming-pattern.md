# SSE Streaming Pattern (Axum + reqwest + Flutter)

## Architecture

Flutter sends `GET /chat/stream?message=...` → Rust backend spawns tokio task → makes streaming POST to LLM provider → forwards SSE chunks → Flutter updates UI in real-time.

This was implemented for Hermes Wingman's chat feature to replace synchronous POST chat.

## Backend Implementation

### Dependencies
```toml
axum = { version = "0.8", features = ["json"] }
reqwest = { version = "0.12", features = ["json", "stream"] }
tokio = { version = "1", features = ["full"] }
futures = "0.3"
tokio-stream = "0.1"
```

### Handler Pattern
The handler creates an mpsc channel, spawns a tokio task for the streaming work, and wraps the receiver in `Sse<ReceiverStream<...>>`.

**Key types:**
```rust
use axum::response::sse::Event;
use axum::response::Sse;
use futures::stream::Stream;
use std::convert::Infallible;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
```

**Return type:**
```rust
Sse<impl Stream<Item = Result<Event, Infallible>>>
```

**Channel creation:**
```rust
let (tx, rx) = mpsc::channel::<Result<Event, Infallible>>(32);
```

### Sending Events
Wrap all data in `Event::default().data(...)` — the Axum Sse type requires `Result<Event, _>`, not raw strings:

```rust
// Error event
let evt = Event::default().data(json!({"error": msg}).to_string());
let _ = tx.send(Ok(evt)).await;

// Content delta
let evt = Event::default().data(json!({"content": delta}).to_string());
let _ = tx.send(Ok(evt)).await;

// Stream done
let evt = Event::default().data("[DONE]");
let _ = tx.send(Ok(evt)).await;
```

### Keep-Alive
Prevent proxies from dropping idle connections:
```rust
Sse::new(ReceiverStream::new(rx)).keep_alive(
    KeepAlive::new()
        .interval(Duration::from_secs(15))
        .text("keep-alive"),
)
```

### Key Provider-Specific Details

#### OpenAI-compatible APIs
Use `"stream": true` in the request body. Response lines look like:
```
data: {"id":"...","choices":[{"delta":{"content":"Hello"}}]}

data: [DONE]
```

#### Parse both `content` and `reasoning_content`
Some models output reasoning in a separate field:
```rust
let content = choice["delta"]["content"].as_str().unwrap_or("");
let reasoning = choice["delta"]["reasoning_content"].as_str().unwrap_or("");
let delta = if !content.is_empty() { content } else if !reasoning.is_empty() { reasoning } else { "" };
```

#### Buffer for Partial Chunks
Chunks may arrive split mid-JSON. Accumulate partial chunks in a buffer and process complete lines:
```rust
let mut buffer = String::new();
while let Some(chunk) = stream.next().await {
    buffer.push_str(&String::from_utf8_lossy(&chunk));
    while let Some(line_end) = buffer.find('\n') {
        let line = buffer[..line_end].trim().to_string();
        buffer = buffer[line_end + 1..].to_string();
        // process line
    }
}
```

## Flutter Client

Use `dart:io` HttpClient with SSE parsing:

```dart
import 'dart:convert';
import 'dart:io';

Future<void> _streamChat(String message, ChatMessage placeholder) async {
  final uri = Uri.parse('http://127.0.0.1:9120/chat/stream')
      .replace(queryParameters: {'message': message});
  final client = HttpClient();
  final request = await client.getUrl(uri);
  final response = await request.close();

  final buffer = StringBuffer();
  String line = '';

  await for (final chunk in response.transform(utf8.decoder)) {
    for (var i = 0; i < chunk.length; i++) {
      if (chunk[i] == '\n') {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') {
            // Finalize: update placeholder with full buffer text
            setState(() { /* update message, set _sending = false */ });
            _scrollToBottom();
            return;
          }
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final content = json['content'] as String? ?? '';
            if (content.isNotEmpty) {
              buffer.write(content);
              setState(() { /* update placeholder text */ });
              _scrollToBottom();
            }
          } catch (_) {}
        }
        line = '';
      } else {
        line += chunk[i];
      }
    }
  }
}
```

### Placeholder Message Pattern
Add a placeholder message immediately before starting the stream, update it on each chunk:
```dart
// Before streaming:
final streamingMsg = ChatMessage(text: '...', isUser: false);
setState(() => _messages.add(streamingMsg));

// Replace in-place on each chunk:
setState(() {
  final idx = _messages.indexOf(placeholder);
  if (idx >= 0) _messages[idx] = ChatMessage(text: newText, isUser: false);
});
```

## Pitfalls Encountered

1. **`Sse<impl Stream<Item = Result<String, ...>>>` does NOT compile.** The Axum Sse type expects `Result<Event, E>`, not `Result<String, E>`. You must wrap in `Event::default().data(...)`.

2. **reqwest Cargo features.** With `features = ["json", "stream"]`, reqwest provides both `json()` payload support AND `bytes_stream()` for streaming. Without `"stream"`, `bytes_stream()` is not available.

3. **llama-swap cold start.** First request to a llama-swap model may return 503 while the model loads into VRAM. Streaming through the backend gives the user a spinning indicator instead of a hard error.

4. **Proxy timeout.** Without keep-alive pings, reverse proxies (nginx, Caddy, Cloudflare) drop SSE connections after ~60s of silence. Set keep-alive interval to 15s.
