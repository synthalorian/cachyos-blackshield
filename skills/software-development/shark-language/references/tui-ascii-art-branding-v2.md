# TUI ASCII Art Branding (Updated)

Lessons from the "APEKFARK" incident — how to get block-letter ASCII art right the first time.

## The Problem

ASCII art that looks correct in a text editor can render ambiguously in a terminal due to:
- Font rendering differences (some terminals compress horizontal spacing)
- Block characters bleeding together without sufficient gaps
- Letters that share shapes (P/B, E/F, N/M, S/5, etc.)

## Letter Shape Reference

For 7-char wide block letters using `█` and spaces:

```
O:  █████  P:  █████  E:  █████  N:  ██   ██  S:   █████
   ██   ██     ██   ██     ██        ████ ████     ██
   ██   ██     ██████      █████     ██ █ ██      █████
   ██   ██     ██          ██        ██   ██          ██
    █████      ██          █████     ██   ██      █████

H:  ██   ██  A:   ███   R:  █████   K:  ██   ██
   ██   ██     ██ ██      ██   ██     ██  ██
   ███████     █████      ██████      █████
   ██   ██     ██ ██      ██  ██      ██  ██
   ██   ██    ██   ██     ██   ██     ██   ██
```

**Critical shapes that fail most often:**
- **P** — Must have a gap in the lower right (loop only on top half). Solid rectangle reads as B/D.
- **E** — Needs 3 distinct horizontal bars. Two bars reads as F.
- **N** — Needs a clear diagonal. Two vertical bars reads as H/M.
- **S** — Needs curves (top-right bulge, bottom-left bulge). Straight bars read as 5/F.
- **R** — Needs the loop + diagonal leg. Loop alone reads as P/B.
- **K** — Needs two diagonals meeting at center. One diagonal reads as N.

## The "Squint Test"

Before committing ASCII art, view it at 50% zoom or from across the room. If it doesn't read clearly, fix the ambiguous letters.

## Coloring in ratatui

```rust
for content_line in msg.content.lines() {
    let line_style = if msg.role == "system" && content_line.contains('█') {
        Style::default()
            .fg(current_theme().border_unfocused)  // purple
            .add_modifier(Modifier::BOLD)
    } else {
        content_style
    };
    lines.push(Line::from(vec![Span::styled(content_line, line_style)]));
}
```

## Sidebar Header with Hardcoded Emoji

When config emoji is empty but you still want branding:

```rust
let mut header_lines = vec![
    Line::from(vec![
        Span::styled("🦞 ", shark_style()),
        Span::styled(agent_name, highlight_style()),
        Span::styled(format!(" v{}", crate::VERSION), muted_style()),
    ]),
];
```

## File Locations

| Element | File | Function ~ |
|---------|------|-----------|
| ASCII art welcome | `src/tui/mod.rs` | `run()` ~675 |
| ASCII art (agent soul) | `src/agent/soul.rs` | `welcome_message()` ~130 |
| Sidebar header | `src/tui/mod.rs` | `draw_sidebar()` ~1595 |
| Color detection | `src/tui/mod.rs` | `draw_chat_area()` ~1780 |
