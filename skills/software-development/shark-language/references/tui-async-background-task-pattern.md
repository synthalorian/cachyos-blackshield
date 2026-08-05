# Async TUI Event Loop with Background Model Calls

Pattern for making a ratatui TUI responsive when calling slow APIs (LLM streaming, tool execution). The user message must appear immediately; the model response streams in via a background task.

## The Problem

A naive TUI blocks the event loop during the API call:

```rust
// ❌ BROKEN — blocks until model finishes
KeyCode::Enter => {
    let input = app.input.trim().to_string();
    app.add_user_message(input.clone());
    stream_model_response(app).await?;  // BLOCKS HERE
}
```

The user message is pushed to `app.messages` but the UI never redraws because `handle_input` → `process_user_input` → `stream_model_response` all run in one `.await` chain.

## The Fix: Background Task + Channel

### 1. Define a StreamEvent enum

```rust
#[derive(Debug)]
enum StreamEvent {
    Start,
    Chunk(String),
    ResponseComplete { content: String, metrics: StreamMetrics },
    ToolResult { name: String, args: String, result: String, success: bool },
    FollowUp(String),
    Error(String),
    Done,
}
```

### 2. Add a receiver to App

```rust
struct App {
    // ... other fields ...
    stream_rx: Option<tokio::sync::mpsc::UnboundedReceiver<StreamEvent>>,
}
```

### 3. Spawn the background task on Enter

```rust
async fn process_user_input(app: &mut App, input: String) -> Result<()> {
    app.add_user_message(input.clone());

    let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
    app.stream_rx = Some(rx);

    // Clone only Send-able fields — NOT MemoryStore (contains !Send rusqlite::Connection)
    let provider = app.provider.clone();
    let model = app.model.clone();
    let model_messages = app.model_messages.clone();

    tokio::spawn(async move {
        let _ = stream_model_response_task(tx, provider, model, model_messages).await;
    });

    Ok(())  // Returns immediately — event loop keeps running
}
```

### 4. Background task sends events

```rust
async fn stream_model_response_task(
    tx: tokio::sync::mpsc::UnboundedSender<StreamEvent>,
    provider: Provider,
    model: String,
    model_messages: Vec<Message>,
) -> Result<()> {
    let _ = tx.send(StreamEvent::Start);

    let request = ChatRequest::new(model, model_messages, true);
    match provider.chat_stream(request).await {
        Ok((chunks, metrics)) => {
            let mut full_content = String::new();
            for chunk in &chunks {
                full_content.push_str(chunk);
                let _ = tx.send(StreamEvent::Chunk(chunk.clone()));
            }
            let _ = tx.send(StreamEvent::ResponseComplete {
                content: full_content,
                metrics,
            });
        }
        Err(e) => {
            let _ = tx.send(StreamEvent::Error(format!("API Error: {}", e)));
        }
    }

    let _ = tx.send(StreamEvent::Done);
    Ok(())
}
```

### 5. Event loop drains the channel every frame

```rust
async fn run_app(terminal: &mut Terminal<impl Backend>, app: &mut App) -> Result<()> {
    loop {
        terminal.draw(|f| draw_ui(f, app))?;

        // Drain stream events before handling input
        if let Some(mut rx) = app.stream_rx.take() {
            while let Ok(event) = rx.try_recv() {
                app.apply_stream_event(event);
            }
            app.stream_rx = Some(rx);
        }

        let timeout = TICK_RATE
            .checked_sub(last_tick.elapsed())
            .unwrap_or_else(|| Duration::from_secs(0));

        if crossterm::event::poll(timeout)? {
            if let Event::Key(key) = event::read()? {
                if handle_input(app, key).await? {
                    break;
                }
            }
        }
        // ...
    }
}
```

### 6. Apply events on the main thread

```rust
impl App {
    fn apply_stream_event(&mut self, event: StreamEvent) {
        match event {
            StreamEvent::Start => {
                self.is_streaming = true;
                self.streaming_content.clear();
            }
            StreamEvent::Chunk(chunk) => {
                self.streaming_content.push_str(&chunk);
            }
            StreamEvent::ResponseComplete { content, metrics } => {
                self.is_streaming = false;
                self.add_assistant_message(content);
                // MemoryStore ops happen here on main thread
                let _ = self.memory.save_performance_metric(...);
            }
            StreamEvent::Error(msg) => {
                self.is_streaming = false;
                self.add_system_message(msg);
            }
            StreamEvent::Done => {
                self.is_streaming = false;
                self.stream_rx = None;
            }
            // ... handle other variants
        }
    }
}
```

## Key Insights

1. **`Option::take()` avoids borrow checker issues** — `app.stream_rx.take()` moves the receiver out, so `apply_stream_event` can borrow `app` mutably. Put it back with `app.stream_rx = Some(rx)`.

2. **Don't pass `!Send` types to spawned tasks** — `MemoryStore` contains `rusqlite::Connection` which is `!Send`. Clone only `Send`-able fields into the background task. Do persistence on the main thread.

3. **`try_recv()` is non-blocking** — The event loop drains whatever is ready without waiting. If the API is still in flight, the loop continues to the next frame.

4. **User message appears instantly** — Because `process_user_input` returns immediately after `add_user_message`, the next `terminal.draw()` shows the user's message. The model response fills in asynchronously.

5. **This also fixes "input lag"** — Even with `TICK_RATE = 16ms`, if the event loop is blocked on an API call, keystrokes queue up. With background tasks, input is always responsive.

## When NOT to use this

- If the API call is truly synchronous and fast (< 50ms), the overhead of spawning a task isn't worth it.
- If you need the model response before allowing the user to type again (rare).
- If the `App` struct is already `Send` (no `!Send` fields), you could use `Arc<tokio::sync::Mutex<App>>` instead of channels.
