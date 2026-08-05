# Pixel Font Legibility in HTML Canvas / 5x7 Grids

When rendering custom pixel fonts in HTML Canvas (or any bitmap context) for retro title screens, splash screens, or UI elements, **diagonal strokes can become ambiguous at scale**. A letter that reads clearly at 1x may look like a different letter when rendered at 4x–8x scale with thick outlines and glow effects.

## The Problem (OpenShark Case Study)

The word "OPENSHARK" used a 5x7 pixel font rendered at 6x scale with magenta outline glow. The `N` character:

```javascript
'N': [
    '10001',
    '11001',
    '10101',  // ← thin diagonal: single pixel wide
    '10011',
    '10001',
    '10001',
    '10001'
],
```

At 6x scale with a 3-pixel-thick outline, the single-pixel diagonal steps were too subtle. The `N` was visually interpreted as a `K` — the diagonal didn't read clearly against the vertical strokes.

## The Fix: Thicken Diagonal Strokes

Redesign the font matrix to make diagonals 2 pixels wide in key rows:

```javascript
'N': [
    '10001',
    '11001',
    '11101',  // ← thickened: diagonal now 2 pixels
    '10111',  // ← thickened: diagonal now 2 pixels
    '10011',
    '10001',
    '10001'
],
```

The diagonal now has visible "mass" at 6x scale. The character is unambiguously an `N`.

## General Rules for 5x7 Pixel Font Design

### 1. Diagonal strokes need width at scale
| Scale | Minimum diagonal width |
|-------|------------------------|
| 1x–2x | 1 pixel (fine) |
| 3x–4x | 1–2 pixels (test) |
| 5x+ | 2 pixels (recommended) |

At 5x+ scale with outlines/glows, single-pixel diagonals get swallowed by the outline layer. Always thicken them.

### 2. Distinguish similar letters at the matrix level

Letters that are easily confused in pixel fonts:
- **N vs H**: N needs a clear diagonal; H has a horizontal crossbar
- **N vs K**: K has diagonals branching from the middle; N has one continuous diagonal
- **M vs W**: M has outer verticals + center V; W is an inverted M
- **B vs 8**: B has straight right side; 8 is fully rounded

When in doubt, exaggerate the distinguishing feature by 1 extra pixel.

### 3. Test at target scale with all effects

A pixel font that looks fine in isolation may fail when:
- Outlines/glows are applied (outer layers blur fine details)
- The font is centered in a layout (adjacent letters create visual noise)
- CRT scanlines or filters overlay the text

Always render the full word with all visual effects before declaring it done.

### 4. Use programmatic verification for ambiguous characters

Before committing a pixel font, render each character individually and verify:

```javascript
function testChar(char, scale, outlineWidth) {
    // Render char at target scale with outline
    // Save or display for visual inspection
    // Ask: "What letter is this?" — if answer != char, redesign
}

['N', 'K', 'H', 'M', 'W'].forEach(c => testChar(c, 6, 3));
```

## Complete 5x7 Pixel Font Reference (OpenShark)

```javascript
const font5x7 = {
    'O': ['01110','10001','10001','10001','10001','10001','01110'],
    'P': ['11110','10001','10001','11110','10000','10000','10000'],
    'E': ['11111','10000','10000','11110','10000','10000','11111'],
    'N': ['10001','11001','11101','10111','10011','10001','10001'],  // thickened diagonal
    'S': ['01111','10000','10000','01110','00001','00001','11110'],
    'H': ['10001','10001','10001','11111','10001','10001','10001'],
    'A': ['01110','10001','10001','11111','10001','10001','10001'],
    'R': ['11110','10001','10001','11110','10100','10010','10001'],
    'K': ['10001','10010','10100','11000','10100','10010','10001'],
    '.': ['00000','00000','00000','00000','00000','01100','01100'],
    ' ': ['00000','00000','00000','00000','00000','00000','00000'],
};
```

## When to Use Code-Based Pixel Fonts vs AI-Generated Assets

| Approach | When to Use | Trade-off |
|----------|-------------|-----------|
| **Code-based pixel font** (Canvas/SVG) | Dynamic text (version numbers, user names), interactive UIs, small labels | Requires manual font design, legibility work |
| **AI-generated title image** (FAL) | Static title screens, hero banners, repo README assets | One-time generation, no runtime flexibility |

For the main project title (e.g., "OPENSHARK"), prefer AI generation for A-tier quality. For dynamic elements (version strings, taglines that change), use code-based pixel fonts with the legibility rules above.
