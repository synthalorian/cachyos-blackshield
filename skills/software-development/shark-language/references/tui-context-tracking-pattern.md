# TUI Context Window Tracking

Pattern for displaying model context window usage (Max Ctx / Ctx Used) in the TUI sidebar.

## Problem

Users don't know how much of the model's context window they've consumed. This leads to:
- Unexpected truncation when context exceeds model limits
- No visibility into when to start a new session
- No warning before hitting the ceiling

## Solution

Track `model_context_length` from config and estimate `context_used` from `model_messages`. Display both in the sidebar with a percentage and color-coded warning.

## Implementation

### 1. Store max context in App

```rust
struct App {
    // ... existing fields ...
    model_context_length: usize,
}
```

Initialize from model config:
```rust
let model_context_length = model_config.as_ref()
    .map(|m| m.context_length)
    .unwrap_or(128000);
```

### 2. Calculate context used

```rust
/// Estimate context used in tokens (rough word-count based).
fn context_used(&self) -> usize {
    self.model_messages.iter()
        .map(|m| m.content.split_whitespace().count())
        .sum()
}
```

**Note:** This is a rough estimate (word count ≈ token count × 0.75). For precise tracking, use a tokenizer like `tiktoken-rs` or the provider's token count API.

### 3. Render with color-coded percentage

```rust
let ctx_used = app.context_used();
let ctx_pct = if app.model_context_length > 0 {
    (ctx_used * 100 / app.model_context_length).min(100)
} else { 0 };

let ctx_color = if ctx_pct > 80 {
    error_style()      // Red — danger zone
} else if ctx_pct > 50 {
    accent_style()     // Yellow/orange — caution
} else {
    text_style()       // Normal — green/white
};

Line::from(vec![
    Span::styled("Ctx Used ", muted_style()),
    Span::styled(format!("{} ({}%)", ctx_used, ctx_pct), ctx_color),
]),
```

### 4. Add Max Ctx line

```rust
Line::from(vec![
    Span::styled("Max Ctx  ", muted_style()),
    Span::styled(format!("{}", app.model_context_length), text_style()),
]),
```

## Sidebar Layout Adjustments

The session info section grows from 5 to 7 lines:

```rust
Constraint::Length(9),  // Session info (7 lines + padding)
```

Lines:
1. Session ID (first 8 chars)
2. Model name
3. Max Ctx
4. Ctx Used (with %)
5. Duration
6. Tokens (user/assistant word count)
7. Tools (tool call count)

## Color Thresholds

| Usage | Color | Meaning |
|-------|-------|---------|
| 0-50% | Normal (white/green) | Safe |
| 50-80% | Accent (yellow/orange) | Caution — consider new session soon |
| 80%+ | Error (red) | Danger — context may truncate |

## Future Improvements

- Use actual tokenizer for precise token count
- Show a mini progress bar instead of just percentage
- Add a system message warning when crossing 80%
- Suggest `/new` or branch when near limit

## Related

- `tui-per-session-metrics-pattern.md` — Sidebar performance metrics
- `tui-tabbed-sidebar-pattern.md` — Sidebar layout and scrolling
