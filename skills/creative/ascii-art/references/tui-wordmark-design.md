# TUI Wordmark Design — Session Notes

## Context

Designing ASCII art wordmarks and logos for terminal UIs, specifically for
OpenShark's ratatui-based TUI welcome screen. Quality target: match Hermes
Agent caduceus and CLASH block-letter quality.

## Hermes Analysis (What Makes It Good)

| Technique | Implementation | Effect |
|-----------|---------------|--------|
| 3D extrusion | `═ ║ ╔ ╗ ╚ ╝` double-line borders | Depth, architectural feel |
| Light-source shading | `▀ ▄` half-blocks | Simulates light from above |
| Internal structure | Hollow centers, walls/floors | Not solid blocks — readable at multiple scales |
| Vertical gradient | Character density variation | Bright top → darker bottom |
| Braille texture | `⠑⠒⠐⠄⠆⠁` | Organic patterns, airy/ethereal |
| Dynamic symmetry | Balanced but not rigid | Feels alive, not mechanical |
| Dual reading | Caduceus = classical AND antenna | Semantic density per pixel |

## CLASH Analysis (Block Letter Quality)

- Thick outlined block letters with internal negative space
- Hollow centers (purple background shows through)
- Slightly jagged low-res pixelation — intentional retro feel
- Letters are 7-8 cols wide, 5+ rows tall
- Dominant, centered, hero element

## OpenShark Design Evolution

### Attempt 1 (Failed)
- Blocky pixel font using `█` characters
- Got truncated by panel edge
- No internal structure, just solid blocks

### Attempt 2 (Failed)
- Gradient triangle fin with `▗▄▄` quadrant chars
- Gray artifact squares at top-left (terminal rendering issue)
- Too small, no symbolic depth

### Attempt 3 (Current — Good)
**Fin-antenna symbol:**
- Central spine `│` = antenna staff + fin leading edge
- Wing spread `╱ ╲` = signal propagation + water wake
- Braille crown `⠊⠉⠑` = transmission node
- Wave base `≈ ≋ ~` = ocean surface + data ripple
- Dual reading: shark fin + broadcast tower

**3D WORDMARK:**
- `▄▀▀▀▄` style letters with extrusion shadow
- 3-char depth: body + 2 shadow rows
- Internal negative space — hollow centers
- 74 cols wide, 8 lines tall

### Attempt 4 (Target — Better)
- Thicker letterforms like CLASH
- More internal negative space per letter
- Stronger extrusion depth (3-4 chars)
- Consider adding `▀ ▄` half-block shading for light source

## Unicode Artifact Pitfalls

| Char | Name | Renders As | Safe? |
|------|------|-----------|-------|
| `▗` | Quadrant upper-right | Gray square artifact | ❌ NO |
| `▖` | Quadrant upper-left | Gray square artifact | ❌ NO |
| `▘` | Quadrant lower-left | Gray square artifact | ❌ NO |
| `▝` | Quadrant lower-right | Gray square artifact | ❌ NO |
| `▚` | Quadrant upper-left/lower-right | Gray square artifact | ❌ NO |
| `▞` | Quadrant upper-right/lower-left | Gray square artifact | ❌ NO |
| `█` | Full block | Solid fill | ✅ YES |
| `░` | Light shade | Gradient step | ✅ YES |
| `▒` | Medium shade | Gradient step | ✅ YES |
| `▓` | Dark shade | Gradient step | ✅ YES |
| `▀` | Upper half block | Light shading | ✅ YES |
| `▄` | Lower half block | Light shading | ✅ YES |
| `│` | Box drawing light vertical | Clean line | ✅ YES |
| `─` | Box drawing light horizontal | Clean line | ✅ YES |
| `╱` | Box drawing diagonal upper-right | Clean diagonal | ✅ YES |
| `╲` | Box drawing diagonal upper-left | Clean diagonal | ✅ YES |
| `┌` | Box drawing light down/right | Corner | ✅ YES |
| `└` | Box drawing light up/right | Corner | ✅ YES |
| `┐` | Box drawing light down/left | Corner | ✅ YES |
| `┘` | Box drawing light up/left | Corner | ✅ YES |

**Rule:** Avoid ALL quadrant block characters (`U+2596-U+259F` range). They render as gray artifacts in many terminals. Stick to full blocks, half-blocks, box drawing, and Braille.

## Layout Principles for TUI Welcome

1. **Hero element dominates** — WORDMARK should be 40-60% of display width
2. **Symbol is secondary** — fin-antenna below or beside, not competing
3. **Version text is tertiary** — small, muted, separate from logo
4. **Tagline below everything** — "Fast. Precise. Hungry." in italic muted
5. **Center everything** — `Alignment::Center` in ratatui

## Sizing Guidelines

| Element | Max Width | Max Height | Notes |
|---------|-----------|------------|-------|
| Full wordmark | 76 cols | 10 lines | Standard terminal |
| Compact wordmark | 60 cols | 6 lines | Small terminal |
| Logo symbol | 30 cols | 12 lines | Secondary accent |
| Inline icon | 10 cols | 6 lines | Sidebar, headers |
| Combined banner | 76 cols | 20 lines | Wordmark + symbol stacked |

## Code Integration (Rust/ratatui)

```rust
// Welcome message as system message in chat history
let welcome = ascii_art::welcome_banner();
app.add_system_message(welcome);

// Render in chat display — system messages use muted_style
// The ASCII art renders with the theme's border_unfocused color
// for the block characters, creating natural theming
```

## Testing Checklist

- [ ] Renders without gray artifacts in target terminal
- [ ] Fits within 80-column terminal without truncation
- [ ] Wordmark is readable at 3+ meters distance
- [ ] Symbol has dual reading (two interpretations)
- [ ] Internal negative space is intentional, not accidental
- [ ] Extrusion depth is consistent across all letters
- [ ] Light source direction is consistent (usually from top-left)
