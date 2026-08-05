# Rust TUI: Unicode Width Trait Import Pitfall

## Problem

When working with terminal UI layouts in Rust, you need to measure the display width of strings (not byte length) to properly center or truncate content. The `unicode-width` crate provides `UnicodeWidthStr` for `str` and `UnicodeWidthChar` for `char`.

**Common mistake:** Importing only `UnicodeWidthStr` and trying to call `.width()` on a `char`:

```rust
use unicode_width::UnicodeWidthStr; // Only covers &str

fn wave_line(frame_width: usize) -> String {
    for ch in full.chars() {
        let ch_width = ch.width().unwrap_or(1); // ERROR: no method `width` on `char`
    }
}
```

**Compiler error:**
```
error[E0599]: no method named `width` found for type `char` in the current scope
  --> src/tui/ascii_art.rs:66:27
   |
66 |         let ch_width = ch.width().unwrap_or(1);
   |                           ^^^^^ method not found in `char`
   |
   = help: items from traits can only be used if the trait is in scope
```

## Solution

Import **both** traits:

```rust
use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

fn wave_line(frame_width: usize) -> String {
    for ch in full.chars() {
        let ch_width = ch.width().unwrap_or(1); // ✅ Works now
    }
}
```

## When You Need Each Trait

| Trait | Use On | Common Use Case |
|-------|--------|----------------|
| `UnicodeWidthStr` | `&str`, `String` | Centering a line, checking if text fits in a frame |
| `UnicodeWidthChar` | `char` | Iterating characters to build exact-width strings (e.g., repeating wave patterns to fill a terminal width) |

## Context

This pitfall commonly arises when:
1. Building ASCII art that must fit exact terminal dimensions
2. Creating progress bars or horizontal rules that span full width
3. Implementing text wrapping with proper wide-char handling (CJK, emoji, block chars)
4. Trimming repeated patterns to exact display width (like the OpenShark splash screen waves)

**Rule:** If your code iterates `chars()` and calls `.width()`, you need `UnicodeWidthChar`. If you only call `.width()` on `&str`, `UnicodeWidthStr` is sufficient.
