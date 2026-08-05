# TUI Cursor Whitespace Drift Bug — ratatui Word-Wrapped Input

**Symptom:** In a ratatui TUI with word-wrapped input, the block cursor appears 1 character to the left of where it should be for each space preceding the cursor position. For text `/swarm init build` with cursor at the end, the cursor lands on the `l` in `build` instead of after the `d`.

**Root Cause:** The `compute_wrapped_cursor_position()` function processes whitespace but never advances the column tracker (`col`) past the whitespace. When the next word starts, `word_start_col = col` uses the position *at* the whitespace instead of *after* it, causing a cumulative leftward drift of 1 column per space.

**Why it accumulates:** Every space in the input introduces a 1-character error. Two spaces = 2 columns off. The error is invisible until the cursor reaches the end of a word and the user notices it's on the wrong character.

## Buggy Code

```rust
} else if ch.is_whitespace() {
    // End of word — commit it
    col = word_start_col + word_width;
    in_word = false;
    word_start_col = col;              // ← BUG: col is at START of whitespace
    word_width = ch.width().unwrap_or(1);

    if col + word_width > wrap_width {
        row += 1;
        col = word_width;
        word_start_col = 0;
        word_width = word_width;
    }
} else {
    // In a word
    if !in_word {
        word_start_col = col;          // ← uses buggy col: starts at whitespace pos
        word_width = 0;
        in_word = true;
    }
```

## Fixed Code

```rust
} else if ch.is_whitespace() {
    // End of word — commit it
    col = word_start_col + word_width;
    in_word = false;
    let space_width = ch.width().unwrap_or(1);
    if col + space_width > wrap_width {
        // Space goes past wrap boundary — wrap to next line
        // The space itself is consumed by the line break (not shown)
        row += 1;
        col = 0;
    } else {
        col += space_width;            // ← FIX 1: advance past whitespace
    }
    word_start_col = col;              // now col is AFTER whitespace
    word_width = 0;
} else {
    // In a word
    if !in_word {
        word_start_col = col;          // ← now correct: starts after whitespace
        word_width = 0;
        in_word = true;
    }
```

## Key Changes

1. **Extract `space_width` early** — don't reuse `word_width` for two purposes
2. **Advance `col` past whitespace** — `col += space_width` after wrap check (FIX 1)
3. **Consume spaces at wrap boundary** — when a space hits the wrap width, it's consumed by the line break and NOT placed at the start of the next line (FIX 2). This matches `Paragraph::wrap(Wrap { trim: true })` behavior where leading whitespace on wrapped lines is trimmed.
4. **Reset `word_width = 0`** — whitespace doesn't contribute to next word's width
5. **Simplify wrap logic** — on wrap, `col = 0` (space consumed); otherwise `col += space_width`

## Trace Example: `/swarm init build`

With wrap_width = 60 (no wrapping occurs):

| Step | Buggy `col` | Fixed `col` | Notes |
|------|------------|-------------|-------|
| After `/swarm` | — | — | `word_width = 6` |
| After space | 6 | 7 | buggy: col stays at 6; fixed: col advances to 7 |
| After `init` | 10 | 11 | buggy: 6+4; fixed: 7+4 |
| After space | 10 | 12 | buggy: col stays at 10; fixed: col advances to 12 |
| After `build` | 15 | 17 | buggy: 10+5; fixed: 12+5 |

**Result:** Buggy cursor at column 15 (on `l`). Fixed cursor at column 17 (after `d`).

## Wrap Boundary Example

With wrap_width = 10 and text `hello world`:

| Step | Buggy `col` | Fixed `col` | Notes |
|------|------------|-------------|-------|
| After `hello` | — | — | `word_width = 5` |
| After space at col 5 | 6 (row 0) | 0 (row 1) | buggy: space placed at start of row 1; fixed: space consumed by wrap |
| After `world` | 11 (row 1) | 5 (row 1) | buggy: 6+5; fixed: 0+5 |

**Result:** Buggy cursor at column 11 (wrong row, wrong col). Fixed cursor at column 5, row 1 (correct).

## Detection Checklist

If a user reports cursor positioning issues in a ratatui TUI input field:

1. **Does the input use `Paragraph::wrap(Wrap { trim: true })`?** If yes, cursor must account for wrapping.
2. **Does the error correlate with spaces?** Type `abc def ghi` — if cursor is 2 chars left at end, it's this bug.
3. **Check `compute_wrapped_cursor_position()` or equivalent** — look for whitespace handling that doesn't advance `col`.
4. **Verify with single long word** — `abcdefghijklmnop` should cursor correctly (no spaces = no drift). If this works but spaced text doesn't, it's this bug.
5. **Does the bug affect ALL text starting with `/`?** If the user says "typing `/` before anything messes up the cursor," it's the same whitespace bug — `/` is not special, but `/swarm init build` has multiple spaces that trigger the drift.

## Files

- `src/tui/mod.rs` — `compute_wrapped_cursor_position()` in OpenShark
- Also applies to any ratatui TUI with word-wrapped input and custom cursor positioning

## Related

- `references/tui-dynamic-input-bar-pattern.md` — Full dynamic input bar implementation including this fix
- `references/swarm-agent-status-sync-pattern.md` — Swarm agent status sync: shared state vs clones, mutable message loops, broadcast channels for real-time TUI updates
