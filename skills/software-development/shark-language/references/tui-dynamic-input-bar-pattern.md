# TUI Dynamic Input Bar Pattern — OpenShark ratatui

**Problem:** The input bar is hardcoded to `Constraint::Length(3)` — exactly 3 lines. When the user types past the available width, text wraps to line 4, 5, 6... but the bar never grows. The wrapped text is clipped into the void — invisible, unreadable.

**Secondary problem:** The cursor positioning assumes single-line input (`cursor_y = inner.y`). On wrapped text, the cursor appears on the wrong line, making editing impossible.

**Root Cause:** Two hardcoded assumptions:
1. `draw_ui()` uses `Constraint::Length(3)` for the input bar height
2. `draw_input_bar()` calculates `cursor_x = inner.x + app.cursor_position as u16` (no wrap accounting)

**Solution:** Compute height dynamically from text content, and position the cursor accounting for line wrapping.

## Implementation

### 1. Dynamic Height Function

```rust
/// Compute the visual height the input bar needs based on text length and wrap width.
fn input_bar_height(app: &App, area_width: u16) -> u16 {
    let available_width = area_width.saturating_sub(2).max(1) as usize; // minus borders
    let text = if app.input.is_empty() {
        "Type a message or command...".len()
    } else {
        app.input.len()
    };
    let lines = (text + available_width - 1) / available_width; // ceil division
    let lines = lines.max(1);
    // Cap at 8 lines so it doesn't eat the whole chat area
    let capped = lines.min(8);
    (capped as u16) + 2 // +2 for borders
}
```

**Key details:**
- Uses `saturating_sub(2)` to account for left+right borders
- `max(1)` prevents division by zero on tiny terminals
- Ceil division: `(text + width - 1) / width`
- Cap at 8 lines — the chat area must remain usable
- Add 2 for top+bottom borders

### 2. Layout Constraint Update

```rust
// In draw_ui():
let chat_layout = Layout::default()
    .direction(Direction::Vertical)
    .constraints([
        Constraint::Min(3),
        Constraint::Length(input_bar_height(app, main_layout[1].width)),
    ])
    .split(main_layout[1]);
```

**Note:** Pass `main_layout[1].width` (the chat pane width, not full terminal width) to `input_bar_height`.

### 3. Cursor Positioning with Wrap Accounting

```rust
// In draw_input_bar(), replace:
// let cursor_x = inner.x + app.cursor_position as u16;
// let cursor_y = inner.y;

let available_width = inner.width as usize;
let (cursor_x, cursor_y) = compute_wrapped_cursor_position(
    &app.input,
    app.cursor_position,
    available_width,
    inner.x,
    inner.y,
);
f.set_cursor_position((cursor_x, cursor_y));
```

### 4. Wrapped Cursor Computation (Word-Wrap Aware)

**CRITICAL:** `Paragraph::wrap(Wrap { trim: true })` uses **word-based wrapping** — it breaks at word boundaries, not character boundaries. The cursor calculation MUST match this behavior or the cursor will appear in the middle of words.

```rust
use unicode_width::UnicodeWidthChar;

/// Compute the actual screen (x, y) for the cursor given a text buffer,
/// a cursor byte position, and the available wrap width.
/// Uses word-wrapping logic to match Paragraph::wrap behavior.
fn compute_wrapped_cursor_position(
    text: &str,
    cursor_pos: usize,
    wrap_width: usize,
    base_x: u16,
    base_y: u16,
) -> (u16, u16) {
    if text.is_empty() || cursor_pos == 0 {
        return (base_x, base_y);
    }

    let before_cursor = &text[..cursor_pos.min(text.len())];
    let mut col: usize = 0;
    let mut row: u16 = 0;
    let mut word_start_col: usize = 0;
    let mut word_width: usize = 0;
    let mut in_word = false;

    // Process text character by character, tracking word boundaries
    for ch in before_cursor.chars() {
        if ch == '\n' {
            row += 1;
            col = 0;
            word_start_col = 0;
            word_width = 0;
            in_word = false;
        } else if ch.is_whitespace() {
            // End of word — commit it
            col = word_start_col + word_width;
            in_word = false;
            let space_width = ch.width().unwrap_or(1);
            if col + space_width > wrap_width {
                row += 1;
                col = 0;
            }
            col += space_width;
            word_start_col = col;
            word_width = 0;
        } else {
            // In a word
            if !in_word {
                word_start_col = col;
                word_width = 0;
                in_word = true;
            }
            let ch_width = ch.width().unwrap_or(1);
            word_width += ch_width;
            
            // Check if word needs to wrap
            if word_start_col + word_width > wrap_width && word_width > wrap_width {
                // Word is longer than line — force break at char boundary
                row += 1;
                word_start_col = 0;
                word_width = ch_width;
            } else if word_start_col + word_width > wrap_width {
                // Word doesn't fit — wrap to next line
                row += 1;
                word_start_col = 0;
                // word_width stays the same
            }
        }
    }
    
    // Final position is at the end of the last word
    col = word_start_col + word_width;

    (base_x + col as u16, base_y + row)
}
```

**Why word wrapping matters:** If the cursor calculation uses character wrapping but `Paragraph` uses word wrapping, the cursor will be on the wrong line whenever a word wraps. The cursor appears to "jump" into the middle of words.

**The bug:** Character-based wrapping breaks text at `col + ch_width > wrap_width`. Word-based wrapping only breaks at whitespace boundaries. For text like `... chronos-engine` at end-of-line:
- Character wrap: breaks at `chro` | `nos-engine` (middle of word)
- Word wrap: breaks at `... ` | `chronos-engine` (before the word)
- Cursor at end: character calc says row+1, col=3 (after `chr`), but word wrap says row+1, col=17 (after `chronos-engine`)

**Rule:** Always match the widget's wrap algorithm. If using `Paragraph::wrap`, use word-based cursor calculation.

## Verification

1. Type a long message that exceeds the terminal width
2. The input bar should grow to accommodate wrapped lines (up to 8 lines max)
3. The cursor should track correctly as you type, backspace, and navigate
4. Resize the terminal — the bar should recalculate height on next frame

## Files Modified

- `src/tui/mod.rs` — `draw_ui()`, `draw_input_bar()`, add `input_bar_height()`, add `compute_wrapped_cursor_position()`
- `Cargo.toml` — add `unicode-width = "0.2"` dependency
