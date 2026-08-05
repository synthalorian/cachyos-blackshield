# Pixel Font to Block Character Conversion

Converting a 5×7 pixel font (HTML Canvas) to █ block characters for TUI rendering.

## The Technique

Given a pixel font defined as 0/1 grids:

```javascript
// HTML Canvas pixel font
const font = {
  'O': ['01110','10001','10001','10001','10001','10001','01110'],
  'P': ['11110','10001','10001','11110','10000','10000','10000'],
  // ... etc
};
```

Convert to Rust TUI block characters:
```rust
pub const WORDMARK: &str = r#" ███  ████  █████ █   █  ████ █   █  ███  ████  █   █
█   █ █   █ █     ██  █ █     █   █ █   █ █   █ █  █
█   █ █   █ █     ███ █ █     █   █ █   █ █   █ █ █
█   █ ████  ████  █ ███  ███  █████ █████ ████  ██
█   █ █     █     █  ██     █ █   █ █   █ █ █   █ █
█   █ █     █     █   █     █ █   █ █   █ █  █  █  █
 ███  █     █████ █   █ ████  █   █ █   █ █   █ █   █"#;
```

Conversion rule: `0 → space`, `1 → █`

## Complete 5×7 Character Set (OpenShark Session)

```rust
// Letters needed for "OPENSHARK" + "FAST. PRECISE. HUNGRY."
const FONT_5X7: &[(&str, [&str; 7])] = &[
    ("O", ["01110","10001","10001","10001","10001","10001","01110"]),
    ("P", ["11110","10001","10001","11110","10000","10000","10000"]),
    ("E", ["11111","10000","10000","11110","10000","10000","11111"]),
    ("N", ["10001","11001","11101","10111","10011","10001","10001"]),
    ("S", ["01111","10000","10000","01110","00001","00001","11110"]),
    ("H", ["10001","10001","10001","11111","10001","10001","10001"]),
    ("A", ["01110","10001","10001","11111","10001","10001","10001"]),
    ("R", ["11110","10001","10001","11110","10100","10010","10001"]),
    ("K", ["10001","10010","10100","11000","10100","10010","10001"]),
    ("F", ["11111","10000","10000","11110","10000","10000","10000"]),
    ("T", ["11111","00100","00100","00100","00100","00100","00100"]),
    ("I", ["01110","00100","00100","00100","00100","00100","01110"]),
    ("C", ["01111","10000","10000","10000","10000","10000","01111"]),
    ("U", ["10001","10001","10001","10001","10001","10001","01110"]),
    ("G", ["01111","10000","10000","10011","10001","10001","01111"]),
    ("Y", ["10001","10001","01010","00100","00100","00100","00100"]),
    (".", ["00000","00000","00000","00000","00000","01100","01100"]),
    (" ", ["00000","00000","00000","00000","00000","00000","00000"]),
];
```

## Key Pitfall: Missing Glyphs

If the font only defines `O`, `P`, `E`, `N`, `S`, `H`, `A`, `R`, `K` and you try to render `FAST. PRECISE. HUNGRY.`, the missing letters (`F`, `T`, `I`, `C`, `U`, `G`, `Y`) will silently render as spaces.

**Result:** `FAST. PRECISE. HUNGRY.` → `AS . PRE SE. H N R .`

**Fix:** Define the complete character set before rendering.

## Width Calculation

For a string with `n` letters:
- Each letter: 5 chars wide
- Inter-letter spacing: 1 char
- Total width: `n × 6 - 1` (last letter has no trailing space)

Example: "OPENSHARK" = 9 letters → 9 × 6 - 1 = **53 chars**
Example: "FAST. PRECISE. HUNGRY." = 22 chars → 22 × 6 - 1 = **131 chars** (too wide for most terminals)

## When Taglines Are Too Wide

Options:
1. **Use a compact 3×5 font** for the tagline (5 rows tall, 3 chars wide per letter)
2. **Remove inter-letter spacing** (saves ~20% width but hurts readability)
3. **Use plain styled text** — let the TUI colorizer handle it with hot pink bold styling
4. **Abbreviate** — "F.P.H." or similar

The OpenShark approach: 5×7 block wordmark + plain styled text tagline.
