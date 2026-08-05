# TUI Pixel Font Terminal Rendering

Converting HTML canvas pixel fonts to terminal ASCII art for splash screens.

## The Problem

HTML canvas draws individual squares with gaps between them. Terminal `█` full-block characters touch each other, making letters bleed together into unreadable blobs.

## The Solution: `▪` Small Black Square

`▪` (U+25AA) renders with natural gaps in most terminal fonts, preserving the pixel-art aesthetic while keeping letters distinct.

```rust
// BEFORE — unreadable blobs
pub const WORDMARK: &str = r#"███  ████  █████ ..."#;

// AFTER — readable pixel art  
pub const WORDMARK: &str = r#"▪▪▪  ▪▪▪▪  ▪▪▪▪▪ ..."#;
```

## Character Comparison

| Char | Pros | Cons |
|------|------|------|
| `█` | Dense, bold | Letters touch, illegible at small scale |
| `▪` | Natural gaps, readable | Slightly less dense |
| `■` | Medium density | Gaps vary by font |
| `●` | Round, distinctive | Doesn't look like pixels |

## Missing Character Detection

When adding a pixel font, verify ALL characters needed for your text exist in the font definition. The tagline "FAST. PRECISE. HUNGRY." needs: F, A, S, T, P, R, E, C, I, H, U, N, G, Y, .

If a character is missing, it renders as blank space — producing garbled output like "AS . PRE SE. H N R ."

## Tagline Width Strategy

A 5×7 pixel font with 1-char spacing produces very wide text:
- "OPENSHARK" = 53 chars
- "FAST. PRECISE. HUNGRY." = 132 chars (too wide for most terminals)

**Options:**
1. Use plain styled text for tagline (recommended)
2. Use a compact 3×5 font (harder to read)
3. Accept truncation on narrow terminals

## Implementation Checklist

1. Define 5×7 pixel patterns for all needed characters
2. Convert `0`→` `, `1`→`▪` for terminal output
3. Add 1-char spacing between letters
4. Verify with `cat` in terminal before shipping
5. Update TUI colorizer to detect `▪` instead of `█`

## N vs K Distinction

In a 5×7 font, N and K can look identical if not designed carefully:

**N:** Diagonal from top-left to bottom-right between two vertical bars
```
▪   ▪
▪▪  ▪
▪ ▪ ▪
▪  ▪▪
▪   ▪
```

**K:** Diagonals branch from middle-left, NO top-right pixel
```
▪  ▪
▪  ▪
▪ ▪
▪▪
▪ ▪
```

The key difference: K's top row should NOT have a pixel on the far right.
