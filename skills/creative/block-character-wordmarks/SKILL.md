---
title: Block Character Wordmarks
name: block-character-wordmarks
description: Design readable wordmarks and logos using Unicode block characters (█, ▓, ▒, ░) for terminal/TUI splash screens. Ensure letters are distinct, consistently spaced, and spell words correctly.
tags: [ascii-art, tui, splash-screen, pixel-font, wordmark, block-characters]
---

# Block Character Wordmarks

Designing wordmarks with Unicode block characters for terminal splash screens, headers, and TUI branding.

## Core Principles

1. **Consistency is everything**
   - Every letter must be the same width (or follow a strict grid)
   - Letter separators must be uniform (e.g., exactly 2 spaces between letters)
   - Never mix single-space internal gaps with double-space letter separators

2. **Letters must be DISTINCT**
   - N ≠ H ≠ K ≠ M — each must have a unique silhouette
   - N needs a visible diagonal (top-left to bottom-right)
   - H has a horizontal crossbar in the middle
   - K has diagonal arms extending from a vertical stem
   - M has a central peak/dip
   - Compare each letter side-by-side with its neighbors before shipping

3. **Spacing rules**
   - Use a fixed-width grid (e.g., 5×5 or 6×6 per letter)
   - Internal letter gaps: single space or no space
   - Letter separators: double space (or more)
   - Never use raw string literals with leading newlines — they break `.lines()` iteration

4. **Common letter widths in 5-wide block font**
   ```
   O =  ███  / ██ ██ / ██ ██ / ██ ██ /  ███
   P = ████  / ██ ██ / ████  / ██    / ██
   E = █████ / ██    / ████  / ██    / █████
   N = ██ ██ / ████  / █████ / █ ███ / ██ ██  ← diagonal visible
   S =  ████ / ██    /  ███  /    ██ / ████
   H = ██ ██ / ██ ██ / █████ / ██ ██ / ██ ██
   A =  ███  / ██ ██ / █████ / ██ ██ / ██ ██
   R = ████  / ██ ██ / ████  / ██ ██ / ██ ██
   K = ██ ██ / ██ ██ / ███   / ██ ██ / ██ ██
   ```

5. **Verification checklist**
   - [ ] Spell the word letter-by-letter out loud while tracing each character
   - [ ] Compare N vs H vs K side-by-side
   - [ ] Compare M vs W vs N
   - [ ] Check that no two letters are identical
   - [ ] Verify total width is consistent across all rows
   - [ ] Test centering in the target terminal width

## Common Pitfalls

- **Double-centering bug**: If the wordmark function adds left padding for centering, the TUI renderer must use `Alignment::Left`, not `Alignment::Center`
- **Leading newline in raw strings**: `r#"\n..."#` with `.lines().skip(1)` is fragile — remove the leading newline instead
- **Inconsistent separators**: Mixing 2-space and 3-space separators makes the wordmark impossible to parse visually
- **Diagonal letters in narrow grids**: N, M, W, K need extra care — a 5-wide grid may not be enough. Consider 6-wide for these letters.
- **Missing glyphs render as spaces**: If the pixel font only defines `OPENSHARK` letters, the tagline `FAST. PRECISE. HUNGRY.` will render as `AS . PRE SE. H N R .` — missing letters (`F`, `T`, `I`, `C`, `U`, `G`, `Y`) silently become blanks. Always define the complete character set needed for all text.
- **Tagline width explosion**: A full 5×7 pixel font tagline can exceed terminal width (e.g., "FAST. PRECISE. HUNGRY." = 132 chars). Either use a compact 3×5 font, remove inter-letter spacing, or fall back to plain styled text for long phrases.
- **HTML is canonical**: When translating a visual design from HTML canvas to TUI block characters, the HTML rendered output is the source of truth. Match it pixel-for-pixel, then verify the TUI result side-by-side.

## Testing

Always print the wordmark centered in the target width and read it aloud before shipping:
```rust
let banner = welcome_banner(80);
for line in banner.lines() {
    println!("{}", line);
}
```

## Related References

- `references/letterform_catalog.md` — Block character letterform reference (A-Z, common symbols)
- `references/pixel-font-html-canvas.md` — Bitmapped pixel fonts for HTML Canvas rendering (5×7 grids, missing glyph pitfalls, diagonal letter distinctness)
- `references/pixel-to-block-conversion.md` — Converting 5×7 pixel fonts (0/1 grids) to █ block characters for TUI rendering, complete character set, width calculations, tagline overflow strategies
