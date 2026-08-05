# TUI Color Contrast Pitfall — Invisible ASCII Art

## Problem

When rendering ASCII art or logos in a ratatui TUI with a dark purple background, using purple-adjacent colors (`RAT_PURPLE_1`, `#9333ea`) can make text hard to read if the user expects high visibility.

**Real example from OpenShark:**
```rust
// Low contrast on deep purple bg (#1a0033) — user may prefer brighter
Span::styled(
    "█ █ █▀▀ █▄░█ ▀▄▀ █░█ █▀▀ █▄▀",
    Style::default().fg(RAT_PURPLE_1).add_modifier(Modifier::BOLD),
)
```

The `RAT_PURPLE_1` (#9333ea) has lower luminance contrast against `RAT_DEEP_PURPLE` (#1a0033) than cyan/white/pink. The result is a softer, more integrated look that some users prefer as "on-brand" — but it is objectively less readable.

## When to Use What

**User preference matters.** synth has explicitly chosen to keep `RAT_PURPLE_1` for the OpenShark ASCII logo because:
- It matches the synthwave purple aesthetic
- The logo is decorative chrome, not critical reading text
- The structural fix (centering + proper sizing) solved the actual complaint

| Color | Hex | Best For | Avoid For |
|---|---|---|---|
| `RAT_CYAN` | `#22d3ee` | Primary accent, highest contrast | — |
| `RAT_WHITE` | `#f8fafc` | Body text, clean readable | — |
| `RAT_PINK_1` | `#ec4899` | Synthwave accent, good contrast | — |
| `RAT_YELLOW_1` | `#facc15` | Highlights, very high contrast | — |
| `RAT_PURPLE_1` | `#9333ea` | Borders, decorative lines, **on-brand logos** | Body text, error messages |
| `RAT_PURPLE_2` | `#a855f7` | Subtle accents | Body text |

## The Real Lesson: Ask Before Changing Colors

**Pitfall:** When a user reports a visual issue (clipping, misplacement, wrong size), the agent assumes the color is the problem and changes it without asking. The user then has to correct: "no, keep the color, fix the layout."

**Rule:** For UI/visual bugs, separate **structural** issues (position, size, clipping, alignment) from **aesthetic** issues (color, font, style). Fix structure first. Only change aesthetics if:
1. The user explicitly asks, OR
2. The color makes text literally unreadable (not just "I think this could be brighter")

## Code Pattern: Centered, Sized Logo (Original Color Kept)

```rust
let logo_lines: Vec<&str> = vec![
    "  ██████  ██████  ███████ ███    ██ ██   ██ ██████  ",
    " ██    ██ ██   ██ ██      ████   ██ ██  ██  ██   ██ ",
    " ██    ██ ██████  █████   ██ ██  ██ █████   ██████  ",
    " ██    ██ ██      ██      ██  ██ ██ ██  ██  ██   ██ ",
    "  ██████  ██      ███████ ██   ████ ██   ██ ██   ██ ",
];

let chat_width = inner.width as usize;
for text in logo_lines {
    let padding = chat_width.saturating_sub(text.len()) / 2;
    let padded = " ".repeat(padding) + text;
    lines.push(Line::from(vec![Span::styled(
        padded,
        Style::default().fg(RAT_PURPLE_1).add_modifier(Modifier::BOLD),
    )]));
}
```

Key structural fixes:
- **Width**: Logo trimmed to ~52 chars so it fits in the chat area (80% of screen with sidebar open)
- **Centering**: `padding = (chat_width - text_len) / 2` — dynamically calculated, not hardcoded
- **Color**: Kept as `RAT_PURPLE_1` per user preference

## General Rule

For any text on `RAT_DEEP_PURPLE` bg:
- **Never use** `RAT_PURPLE_1` or `RAT_PURPLE_2` for body text / error messages / critical UI
- **Never use** `RAT_DEEP_PURPLE_2` (#2d0052) for text
- **Prefer** cyan, white, pink, or yellow for anything that must be readable at a glance
- `RAT_PURPLE_1`/`RAT_PURPLE_2` are safe for **borders, dividers, decorative logos** where the user explicitly wants the softer integrated look

## Testing

After changing TUI colors, rebuild and visually verify:
```bash
cd /home/synth/projects/openshark
cargo build --release
cargo install --path . --force
openshark
```

If testing in a headless environment, use tmux capture instead:
```bash
tmux new-session -d -s openshark-test "openshark"
sleep 2
tmux capture-pane -t openshark-test -p > /tmp/tui.txt
cat /tmp/tui.txt
```
