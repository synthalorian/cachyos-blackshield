# TUI Real-Time Reasoning Display Pattern

**Session:** 2026-05-31  
**Context:** OpenShark TUI with Kimi k2.6 streaming

## Problem

Reasoning models (Kimi k2.6, DeepSeek-R1, etc.) emit `reasoning_content` alongside `content` in streaming deltas. The user wants to see this reasoning **in real-time** as it streams, before the actual response content appears — as a live activity indicator and transparency feature.

**What the user rejected:**
1. ❌ Hidden/collapsible reasoning box — "i want it to display thoughts while its actually streaming"
2. ❌ Raw `<think>` tags mixed with response — looks like broken output
3. ❌ Reasoning appended to final message — pollutes chat history
4. ❌ Static "thinking..." label — gives no actual content

## Solution: Dual-Stream Ephemeral Reasoning

Extract both `content` and `reasoning_content` from provider deltas, route them through separate event types, accumulate in separate fields, render reasoning first with muted styling, and discard reasoning on completion (only `content` commits to chat history).

### Architecture

```
Provider SSE Stream
    │
    ├─ delta.reasoning_content → StreamEvent::ReasoningChunk("<think>...")
    └─ delta.content → StreamEvent::Chunk("actual response...")
         │
         ▼
    TUI Event Handler
         │
    ├─ ReasoningChunk → app.reasoning_content (ephemeral)
    └─ Chunk → app.streaming_content (commits to history)
         │
         ▼
    draw_chat_area()
         │
    ├─ Render reasoning lines first (muted, 💭 prefix)
    └─ Render content lines below (normal, syntax highlighted)
```

### Implementation Steps

#### 1. Add `ReasoningChunk` to `StreamEvent` enum

```rust
pub enum StreamEvent {
    Start,
    Chunk(String),
    ReasoningChunk(String),  // NEW: model's internal reasoning
    ToolSuggestion { name: String, args: String },
    ToolResult { name: String, result: String },
    FollowUp { content: String },
    ResponseComplete { content: String, metrics: ResponseMetrics },
    Error(String),
    Done,
}
```

#### 2. Add reasoning fields to `App`

```rust
pub struct App {
    // ... existing fields ...
    pub streaming_content: String,
    pub reasoning_content: String,  // ephemeral — not saved to history
    pub is_reasoning: bool,         // tracks if we're in reasoning phase
}
```

Initialize in `App::new()`:
```rust
reasoning_content: String::new(),
is_reasoning: false,
```

#### 3. Clear reasoning on stream start

```rust
StreamEvent::Start => {
    self.is_streaming = true;
    self.streaming_content.clear();
    self.reasoning_content.clear();  // clear previous reasoning
    self.is_reasoning = true;
    self.stream_start_time = Some(Instant::now());
}
```

#### 4. Extract both fields in provider

In `src/providers/mod.rs`, parse both `content` and `reasoning_content`:

```rust
// In the SSE delta parsing loop:
let content = delta
    .get("content")
    .and_then(|c| c.as_str())
    .filter(|s| !s.is_empty());

let reasoning = delta
    .get("reasoning_content")
    .and_then(|c| c.as_str())
    .filter(|s| !s.is_empty());

// Send reasoning first (if any), then content
if let Some(r) = reasoning {
    let _ = tx.send(StreamEvent::ReasoningChunk(r.to_string()));
}
if let Some(c) = content {
    let _ = tx.send(StreamEvent::Chunk(c.to_string()));
}
```

#### 5. Route `<think>` chunks in background task

In `stream_model_response_task`, detect reasoning chunks and route appropriately:

```rust
// After parsing the delta from provider:
if let Some(chunk) = chunk {
    // Check if this is reasoning content (wrapped in <think> or from reasoning_content field)
    if chunk.starts_with("<think>") || chunk.ends_with("</think>") || is_reasoning_phase {
        let _ = app_tx.send(StreamEvent::ReasoningChunk(chunk));
    } else {
        let _ = app_tx.send(StreamEvent::Chunk(chunk));
    }
}
```

#### 6. Handle `ReasoningChunk` in event loop

```rust
StreamEvent::ReasoningChunk(text) => {
    self.reasoning_content.push_str(&text);
    self.is_reasoning = true;
}
StreamEvent::Chunk(text) => {
    self.streaming_content.push_str(&text);
    self.is_reasoning = false;  // now in content phase
}
```

#### 7. Render reasoning before content in `draw_chat_area`

```rust
// Render reasoning content first (if any)
if !app.reasoning_content.is_empty() {
    for line in app.reasoning_content.lines() {
        let wrapped = textwrap::wrap(line, wrap_width);
        for wrapped_line in wrapped {
            lines.push(Line::from(vec![
                Span::styled("💭 ", theme.muted_style()),
                Span::styled(wrapped_line.to_string(), theme.muted_style()),
            ]));
        }
    }
    // Add a subtle separator when transitioning to content
    if !app.streaming_content.is_empty() {
        lines.push(Line::from(vec![
            Span::styled("─".repeat(width as usize), theme.muted_style()),
        ]));
    }
}

// Then render streaming content normally (with syntax highlighting)
if !app.streaming_content.is_empty() {
    // ... existing content rendering with syntax highlighting ...
}
```

#### 8. Only commit `streaming_content` to chat history

```rust
StreamEvent::ResponseComplete { content, metrics } => {
    self.is_streaming = false;
    self.stream_start_time = None;
    
    // Only content goes to chat history — reasoning is ephemeral
    let final_content = self.streaming_content.clone();
    self.chat_history.push(Message::assistant(final_content));
    
    // Clear ephemeral state
    self.streaming_content.clear();
    self.reasoning_content.clear();
    self.is_reasoning = false;
}
```

### Visual Design

**Reasoning lines:**
- Prefix: `💭 ` (thought bubble emoji)
- Style: `muted_style()` — dimmed/gray color
- No syntax highlighting (it's natural language thinking)
- Wraps at chat area width

**Content lines:**
- Normal rendering with full syntax highlighting
- Code blocks get borders and language-specific colors
- Appears below reasoning with a subtle separator

**Example output:**
```
💭 Let me analyze the user's request. They want to add a spinner to the TUI.
💭 I should check the existing App struct for streaming-related fields...
💭 The spinner should use Braille characters for smooth animation.
─────────────────────────────────────────
Here's how to add an animated spinner to the TUI:

1. Add `spinner_frame: usize` to the `App` struct...
```

### Key Design Decisions

1. **Ephemeral reasoning** — `reasoning_content` is never saved to chat history or SQLite. It's display-only state that clears on completion.
2. **Separate accumulation** — Two `String` fields prevent interleaving/mixing. Reasoning and content are independently buffered.
3. **Visual distinction** — Muted color + emoji prefix makes it immediately clear what's reasoning vs. actual response.
4. **No `<think>` tags visible** — The provider or background task strips/wraps tags. User sees clean text, not XML soup.
5. **No final message pollution** — Only `streaming_content` becomes the assistant's message in history.

### Pitfalls

1. **Don't commit reasoning to history** — If `reasoning_content` gets appended to the final message, the user sees `<think>` tags in chat history forever.
2. **Clear reasoning on ALL completion paths** — `ResponseComplete`, `Error`, `Done`. Missing any path leaks reasoning into the next message.
3. **Don't mix reasoning and content in one field** — Interleaving creates `<think>` tag soup in the final output. Keep separate fields.
4. **Reasoning can be empty** — Not all models emit reasoning. The UI must handle `reasoning_content.is_empty()` gracefully (no separator, no empty space).
5. **Wrap reasoning text** — Reasoning can be long. Use `textwrap` to prevent horizontal overflow.
6. **Provider field names vary** — Kimi uses `reasoning_content`, DeepSeek uses `reasoning_content` inside `delta`, other models may use different fields. Check your provider's API docs.

### Scope-Matching System Prompt

When showing reasoning, models may over-elaborate on simple prompts because they "see themselves thinking." Add an explicit instruction to the system prompt:

```
Match your response scope to the request complexity. For simple prompts ("test", "hello", single-word queries), give brief, direct answers. Do not synthesize the entire system architecture unless asked.
```

This prevents the model from writing 500 words of reasoning for a 1-word prompt.

### Testing Checklist

1. Send "test" — verify reasoning appears briefly, then content appears below
2. Send a complex coding request — verify reasoning shows planning steps
3. Verify reasoning disappears after response completes
4. Verify chat history contains only content, no reasoning
5. Verify no `<think>` tags visible anywhere in the UI
6. Verify reasoning clears on error (e.g., network timeout)
7. Verify empty reasoning doesn't create extra whitespace

## Related

- `references/kimi-reasoning-filter.md` — Original "hide reasoning" approach (superseded by this pattern for users who want visibility)
- `references/tui-spinner-activity-indicator-pattern.md` — Spinner + elapsed timer for activity indication (complementary to reasoning display)
- `references/tui-async-background-task-pattern.md` — Background task architecture for streaming
