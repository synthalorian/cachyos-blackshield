# Real-Time Reasoning Streaming Pattern

Converting a buffered LLM streaming implementation into true real-time reasoning + content streaming in a Rust TUI harness.

## Problem

Most initial streaming implementations collect all chunks into a `Vec<String>` and return them after the full response completes. This means reasoning/thinking content (e.g., Kimi's `reasoning_content` delta) only appears after the model finishes — the user sees nothing during the thinking phase, then everything dumps at once.

## Solution Architecture

### 1. Provider Layer — Tagged Chunk Enum

Define a discriminated enum so the consumer knows whether each chunk is reasoning or content:

```rust
#[derive(Debug, Clone)]
pub enum StreamChunk {
    Reasoning(String),
    Content(String),
}
```

### 2. Provider Method — Return a Receiver

Instead of `async fn chat_stream(...) -> Result<(Vec<String>, StreamMetrics)>`, use:

```rust
pub async fn chat_stream_realtime(
    &self,
    request: ChatRequest,
) -> Result<(tokio::sync::mpsc::UnboundedReceiver<StreamChunk>, StreamMetrics)>
```

Implementation:
- Create `(tx, rx)` channel pair immediately
- Spawn the HTTP SSE streaming in a `tokio::spawn` background task
- The task sends `StreamChunk::Reasoning(r)` for `reasoning_content` deltas and `StreamChunk::Content(c)` for `content` deltas
- Return `rx` instantly so the caller starts receiving before the first byte arrives
- Return placeholder `StreamMetrics` — actual metrics computed by the consumer

```rust
let (tx, rx) = tokio::sync::mpsc::unbounded_channel::<StreamChunk>();

// Spawn HTTP streaming work
tokio::spawn(async move {
    let response = request_builder.send().await?;
    let mut stream = response.bytes_stream();
    let mut buffer = String::new();

    while let Some(chunk) = stream.next().await {
        // ... SSE line parsing ...
        if let Some(r) = reasoning {
            let _ = tx.send(StreamChunk::Reasoning(r.to_string()));
        }
        if let Some(c) = content {
            let _ = tx.send(StreamChunk::Content(c.to_string()));
        }
    }
});

Ok((rx, StreamMetrics { /* placeholder */ }))
```

### 3. Background Task — Forward with Translation

The TUI's background task receives from the provider's `StreamChunk` channel and forwards to the TUI's `StreamEvent` channel:

```rust
match provider.chat_stream_realtime(request).await {
    Ok((mut chunk_rx, mut metrics)) => {
        let mut full_content = String::new();
        let stream_start = Instant::now();
        let mut first_token_time: Option<Instant> = None;

        while let Some(chunk) = chunk_rx.recv().await {
            match chunk {
                StreamChunk::Reasoning(r) => {
                    let _ = tx.send(StreamEvent::ReasoningChunk(r));
                }
                StreamChunk::Content(c) => {
                    if first_token_time.is_none() {
                        first_token_time = Some(Instant::now());
                    }
                    full_content.push_str(&c);
                    let _ = tx.send(StreamEvent::Chunk(c));
                }
            }
        }

        // Compute real metrics now that stream is done
        metrics.first_token_latency_ms = /* ... */;
        metrics.total_latency_ms = /* ... */;

        let _ = tx.send(StreamEvent::ResponseComplete {
            content: full_content.clone(),
            metrics,
        });

        // Post-stream: tool detection, follow-up, etc. using full_content
    }
}
```

### 4. TUI Rendering — Syntax Highlighted Reasoning

Render reasoning content with the same syntax highlighter used for regular content, so code in the model's thinking gets highlighted:

```rust
let highlighted = syntax_highlight::extract_and_highlight(&app.reasoning_content);
for (is_code, block_lines) in highlighted {
    if is_code {
        lines.push(Line::from(vec![
            Span::styled("┌─ think ─────────────────────────────", muted_style()),
        ]));
        for hl_line in block_lines {
            lines.push(hl_line);
        }
        lines.push(Line::from(vec![
            Span::styled("└─────────────────────────────────────", muted_style()),
        ]));
    } else {
        for hl_line in block_lines {
            lines.push(Line::from(vec![
                Span::styled("💭 ", muted_style()),
                Span::styled(line_text, muted_style()),
            ]));
        }
    }
}
```

## Key Design Decisions

1. **Channel-to-channel translation** — Provider uses `StreamChunk`, TUI uses `StreamEvent`. The background task is the adapter layer. Don't conflate the two enums.

2. **Placeholder metrics** — `chat_stream_realtime` returns placeholder metrics because real values (first token latency, total latency) require the consumer's perspective. The consumer computes them after the stream closes.

3. **Accumulate full_content** — Even though chunks stream in real-time, the background task still accumulates `full_content` for post-stream tool detection, follow-up requests, and persistence.

4. **Separate reasoning from content in state** — `App` has both `reasoning_content: String` and `streaming_content: String`. This lets the TUI render them in distinct visual zones (reasoning above, content below).

5. **Syntax highlighting for reasoning** — Models often write code in their thinking. Using the same highlighter for both reasoning and content gives consistent visual treatment.

## Provider-Specific Reasoning Field Mapping

| Provider | Reasoning Field | Content Field |
|----------|----------------|---------------|
| Kimi (OpenAI-compatible) | `choices[0].delta.reasoning_content` | `choices[0].delta.content` |
| Anthropic | `delta.text` (no separate reasoning) | `delta.text` |
| OpenAI o1/o3 | `choices[0].delta.content` (reasoning embedded) | same |
| DeepSeek | `choices[0].delta.reasoning_content` | `choices[0].delta.content` |

## Pitfall: Think Tag Flooding

When migrating from buffered to real-time streaming, the old `chat_stream` method may still wrap reasoning chunks in `<think>...</think>` tags. If the new realtime path doesn't strip these, they leak into chat history as raw text.

**Symptom:** Chat floods with garbled repeated `<think>think>word<think>think>...` text.

**Root cause:** The old `chat_stream` wraps reasoning in `<think>` tags. The TUI's old logic stripped them. But with `chat_stream_realtime`, reasoning comes through `StreamChunk::Reasoning` raw — no tags. However, if the model ALSO includes `<think>` tags in its regular content (or if old cached responses replay), they appear verbatim.

**Fix — `strip_think_tags()`:**
```rust
fn strip_think_tags(text: &str) -> String {
    let mut result = text.to_string();
    while let Some(start) = result.find("<think>") {
        if let Some(end) = result.find("</think>") {
            result.replace_range(start..end + 8, "");
        } else {
            break;
        }
    }
    result.trim().to_string()
}
```

Apply in `ResponseComplete` before saving to chat history:
```rust
let clean_content = strip_think_tags(&content);
self.add_assistant_message(clean_content);
```

## Persistent Reasoning in Chat History

By default, reasoning is ephemeral — it streams live but disappears when the response completes. To preserve it in scrollback:

```rust
// In ResponseComplete handler:
if !self.reasoning_content.is_empty() {
    let reasoning_msg = ChatMessage {
        role: "assistant".to_string(),
        content: format!("<think>{}\n</think>", self.reasoning_content.trim()),
        images: None,
        timestamp: Utc::now(),
        multi_model_responses: Vec::new(),
    };
    self.messages.push(reasoning_msg);
}
let clean_content = strip_think_tags(&content);
self.add_assistant_message(clean_content);
```

This saves reasoning as a separate collapsible message (rendered with `extract_and_highlight` if your message renderer supports it) before the clean assistant response.

## When to Use This Pattern

- Any Rust TUI harness that streams from LLM APIs
- When the provider exposes separate reasoning and content streams
- When users want to see the model's thought process in real-time (like OpenCode, Claude Code, Hermes)
- When reasoning contains code that should be syntax-highlighted

## When NOT to Use

- Simple chat UIs where buffering is acceptable
- Providers that don't expose reasoning separately (everything goes through `Content`)
- Gateway/messaging platforms where message fragmentation is problematic
