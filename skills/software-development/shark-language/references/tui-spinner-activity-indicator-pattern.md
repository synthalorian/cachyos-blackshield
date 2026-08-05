# TUI Spinner / Activity Indicator Pattern

Adding animated spinner + elapsed-time indicators to a ratatui-based TUI to show the user that the model is actively working (not hung).

## Problem

When streaming responses from slow models (e.g., kimi-k2.6 with 5-30s first-token latency), the TUI appears frozen:
- Static `▌` cursor gives no indication of activity
- Input bar shows static "Streaming response..." text
- User cannot tell if the model is thinking, the connection dropped, or the app crashed

## Solution: Animated Spinner + Elapsed Timer

### 1. Add State Fields to App

```rust
struct App {
    // ... existing fields ...
    /// Spinner animation frame (0-7) for showing activity during streaming.
    spinner_frame: usize,
    /// When the current stream started (for elapsed time display).
    stream_start_time: Option<Instant>,
}
```

Initialize in `App::new()`:
```rust
spinner_frame: 0,
stream_start_time: None,
```

### 2. Set Stream Start Time on StreamEvent::Start

```rust
StreamEvent::Start => {
    self.is_streaming = true;
    self.streaming_content.clear();
    self.stream_start_time = Some(Instant::now());
}
```

### 3. Clear on Completion / Error / Done

```rust
StreamEvent::ResponseComplete { content, metrics } => {
    self.is_streaming = false;
    self.stream_start_time = None;
    // ... rest of handling ...
}
StreamEvent::Error(msg) => {
    self.is_streaming = false;
    self.stream_start_time = None;
    // ...
}
StreamEvent::Done => {
    self.is_streaming = false;
    self.stream_start_time = None;
    // ...
}
```

### 4. Advance Spinner Frame Every Tick

In the main TUI loop (`run_app`), increment the frame counter on every tick:

```rust
if last_tick.elapsed() >= TICK_RATE {
    *last_tick = Instant::now();
    // Advance spinner frame every tick for smooth animation
    app.spinner_frame = app.spinner_frame.wrapping_add(1);
}
```

`TICK_RATE` should be ~16ms (60fps) for smooth animation.

### 5. Render in Chat Area

When `app.is_streaming`, render the agent header with spinner + elapsed time:

```rust
if app.is_streaming {
    const SPINNER_CHARS: &[char] = &['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    let spinner = SPINNER_CHARS[app.spinner_frame % SPINNER_CHARS.len()];
    let elapsed = app.stream_start_time.map(|t| t.elapsed().as_secs()).unwrap_or(0);
    let elapsed_str = if elapsed > 0 {
        format!(" [{}s]", elapsed)
    } else {
        String::new()
    };
    lines.push(Line::from(vec![
        Span::styled(format!("{} ", agent_emoji), shark_style()),
        Span::styled(agent_name, shark_style().add_modifier(Modifier::BOLD)),
        Span::styled(format!("  {} thinking{}", spinner, elapsed_str), accent_style()),
    ]));
    // ... render streaming_content lines ...
    lines.push(Line::from(vec![Span::styled("▌", accent_style())]));
}
```

### 6. Render in Input Bar Placeholder

Same spinner in the input bar placeholder for visibility even when chat is scrolled:

```rust
let input_text = if app.input.is_empty() {
    if app.is_streaming {
        const SPINNER_CHARS: &[char] = &['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
        let spinner = SPINNER_CHARS[app.spinner_frame % SPINNER_CHARS.len()];
        let elapsed = app.stream_start_time.map(|t| t.elapsed().as_secs()).unwrap_or(0);
        if elapsed > 0 {
            &format!("{} Streaming response... [{}s]", spinner, elapsed)
        } else {
            &format!("{} Streaming response...", spinner)
        }
    } else {
        "Type a message or command..."
    }
} else {
    &app.input
};
```

## Spinner Character Sets

| Set | Characters | Style |
|-----|-----------|-------|
| Braille (recommended) | `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` | Smooth, terminal-native |
| ASCII | `\|/-` | Simple, universally supported |
| Dots | `⣾⣽⣻⢿⡿⣟⣯⣷` | Blocky, high contrast |
| Arrows | `←↖↑↗→↘↓↙` | Directional |

Braille characters are recommended for TUI apps because:
- They render consistently across terminals
- They're narrow (1 column each)
- They have a smooth rotation feel
- No color needed for visibility

## Elapsed Time Display

Show seconds after 1s has passed. Format: `[5s]`, `[30s]`, `[2m]`.

For very long waits (>60s), consider showing minutes: `[1m 30s]`.

## Pitfalls

1. **Don't use `contains()` for modifier checks on keybindings** — use `==` for exact match. See `references/tui-keybinding-modifier-exact-match.md`.

2. **Spinner frame must wrap** — use `wrapping_add()` or `%` to avoid overflow on long sessions.

3. **Stream start time must be cleared on ALL completion paths** — `ResponseComplete`, `Error`, `Done`. Missing any path causes the timer to keep counting.

4. **Placeholder text lifetime** — The input bar placeholder is constructed as a `String` and referenced. Ensure the reference lives long enough for rendering.

5. **Linter false positives** — The standalone linter may flag `async fn` as "Rust 2015" errors. Trust `cargo check` / `cargo build` instead.

6. **Don't show reasoning_content from reasoning models** — Kimi k2.6 and similar models emit `reasoning_content` in delta chunks. This is the model's internal chain-of-thought and should be filtered out, not streamed to the user. See `references/kimi-reasoning-filter.md`.

## Testing

1. Start TUI, send a message to a slow model
2. Verify spinner animates (characters change every ~16ms)
3. Verify elapsed time increments every second
4. Verify spinner stops and timer clears when response completes
5. Verify spinner stops and timer clears on error

## Files Modified

- `src/tui/mod.rs` — App struct, App::new(), apply_stream_event(), run_app(), draw_chat_area(), draw_input_bar()
