# Block-Character Wordmark Patterns

Session: OpenShark TUI splash screen wordmark design (2026-05-31).

## The Core Problem

When designing wordmarks from `█` block characters for terminal UIs, the spacing between letters is the #1 source of bugs. Unlike pyfiglet/figlet fonts which handle kerning automatically, hand-designed block wordmarks require explicit, consistent separators.

## The Golden Rules

1. **Every letter must be the SAME width** — if your alphabet mixes 4-wide and 5-wide letters, the wordmark will be impossible to center and will look lopsided.
2. **Use exactly ONE separator width between letters** — we use 2 spaces. Never mix single spaces (internal letter gaps) with double spaces (letter separators) in the same design. The parser cannot tell them apart.
3. **Never use single spaces inside letters** — if a letter like "O" needs a gap, use a different pattern (e.g., `██ ██` with a 1-space internal gap is fine ONLY if your separator is 2+ spaces).
4. **Every letter must be readable in isolation** — test each letter by itself before assembling the wordmark.

## What Went Wrong (OpenShark v0)

The original wordmark:
```
 ████   ████  ██████  ████  ██  ██ ██████  ████   ████  ██  ██ ████  ██  ██
```

- Mixed 3-space and 2-space separators
- Used single spaces as internal letter gaps (e.g., `██  ██` for O's sides)
- Result: parser couldn't distinguish internal gaps from separators
- Rendered as: "OOFPHFAANYYI" / "DOG PHANTOM" / "DOPHNHANNYI"

## What Worked (OpenShark v1)

All letters exactly 5 chars wide, separated by exactly 2 spaces:

```
O =  ███     P = ████     E = █████    N = ██ ██
    ██ ██        ██ ██        ██           ████
    ██ ██        ████         ████         █████
    ██ ██        ██            ██           █ ███
     ███         ██           █████        ██ ██

S =  ████     H = ██ ██     A =  ███      R = ████
    ██             ██ ██        ██ ██        ██ ██
     ███           █████        █████        ████
       ██          ██ ██        ██ ██        ██ ██
    ████           ██ ██        ██ ██        ██ ██

K = ██ ██
    ██ ██
    ███
    ██ ██
    ██ ██
```

Full wordmark (61 cols wide, 5 rows):
```
 ███   ████   █████  ██ ██   ████  ██ ██   ███   ████   ██ ██
██ ██  ██ ██  ██     ████   ██     ██ ██  ██ ██  ██ ██  ██ ██
██ ██  ████   ████   █████   ███   █████  █████  ████   ███
██ ██  ██     ██     █ ███     ██  ██ ██  ██ ██  ██ ██  ██ ██
 ███   ██     █████  ██ ██  ████   ██ ██  ██ ██  ██ ██  ██ ██
```

## Letter Design Cheat Sheet

All letters 5-wide, using only `█` and ` ` (space):

| Letter | Row 0 | Row 1 | Row 2 | Row 3 | Row 4 | Notes |
|--------|-------|-------|-------|-------|-------|-------|
| A | ` ███ ` | `██ ██` | `█████` | `██ ██` | `██ ██` | Pointed top, bar mid |
| E | `█████` | `██   ` | `████ ` | `██   ` | `█████` | 3 horizontal bars |
| H | `██ ██` | `██ ██` | `█████` | `██ ██` | `██ ██` | Bar in middle |
| K | `██ ██` | `██ ██` | `███  ` | `██ ██` | `██ ██` | Diagonal feel |
| N | `██ ██` | `████ ` | `█████` | `█ ███` | `██ ██` | **Diagonal connection** — distinct from H |
| O | ` ███ ` | `██ ██` | `██ ██` | `██ ██` | ` ███ ` | Rounded (space gaps) |
| P | `████ ` | `██ ██` | `████ ` | `██   ` | `██   ` | Loop on right |
| R | `████ ` | `██ ██` | `████ ` | `██ ██` | `██ ██` | P + leg |
| S | ` ████` | `██   ` | ` ███ ` | `   ██` | `████ ` | Zigzag curve |

**Critical:** N and H must be visually distinct. H has a horizontal bar in the middle row. N has diagonal mass shifted — rows 1-2 are left-heavy, row 3 is right-heavy.

## Centering in ratatui

When rendering ASCII art in ratatui, there are TWO centering mechanisms:

1. **Pre-computed padding** — add left spaces in the string itself
2. **Widget alignment** — `Paragraph.alignment(Alignment::Center)`

**NEVER use both.** If your strings already have left padding for centering, set the Paragraph to `Alignment::Left`. Double-centering pushes content right and creates drift.

```rust
// WRONG — double centering
let banner = Paragraph::new(text)
    .alignment(Alignment::Center);  // Don't do this if text has padding!

// RIGHT — text has padding, widget is left-aligned
let banner = Paragraph::new(text)
    .alignment(Alignment::Left);    // Padding is pre-computed
```

## Wave/Water Patterns

For water lines that span full terminal width, generate dynamically:

```rust
fn wave_line(frame_width: usize) -> String {
    let wave_char = '≈';
    wave_char.to_string().repeat(frame_width)
}
```

Don't hardcode wave width — terminals vary. The fin should sit directly ON the first wave line, not have its own separate merge line.

## Testing Checklist for Block Wordmarks

- [ ] Each letter is readable in isolation
- [ ] All letters same width
- [ ] Consistent separator width (2+ spaces)
- [ ] No ambiguous single-space gaps
- [ ] Renders correctly when centered
- [ ] No double-centering in renderer
- [ ] Visually distinct similar letters (N≠H, O≠Q, etc.)
