# Terminal ASCII Art Quality Methodology

## Problem

Block-character ASCII art in TUIs looks amateur when it uses solid fills, gets truncated by panel edges, or lacks visual hierarchy. The Hermes caduceus demonstrates how to achieve professional quality.

## Quality Principles (from Hermes Analysis)

### 1. Character Selection by Purpose

| Purpose | Characters | Effect |
|---------|-----------|--------|
| Solid fills / gradients | `█ ▓ ▒ ░` | Volume, light-to-dark shading |
| 3D extrusion borders | `═ ║ ╔ ╗ ╚ ╝` | Depth, architectural structure |
| Half-block shading | `▀ ▄` | Light source illusion (top-lit) |
| Organic texture | Braille dots `⠁⠂⠄⠆⠇` | Ethereal, pattern-density without hard edges |
| Sharp edges | `▲ ◢ ◣ ◤ ◥ / \ │` | Silhouette definition |
| Water/surface | `~ ≈ ≋ ▁▂▃▄` | Horizontal disturbance |
| Spray/droplets | `· ∙ ∘ o ° •` | Negative space accents |

### 2. Proportions

- **Height dominance**: Title ~15% of viewport height
- **Letter ratio**: ~5:3 width-to-height per character
- **3D extrusion depth**: 2-3 characters, consistent across all letters
- **Internal structure**: Letters have "walls" and "floors" — not solid blocks

### 3. Symmetry — Dynamic, Not Perfect

- **Overall composition**: Bilaterally balanced around visual center
- **Individual elements**: Deliberately broken symmetry for organic feel
- **Counterweight principle**: Dense geometric text balanced by sparse organic form

### 4. Negative Space Mastery

- **Form defined by surroundings**: Water texture stops at silhouette edge
- **Internal negative space**: Lighter "highlight" stripe down front edge
- **Fade below boundary**: Form dissolves rather than ending abruptly
- **Margins**: Generous padding so art "floats"

### 5. Color/Contrast Strategy

Against deep purple background:

| Element | Color | Density |
|---------|-------|---------|
| Highlight (sun catching) | Cyan/white | Sparse: `░ · ∘` |
| Body | Teal/cyan | Medium: `▒ ▪` |
| Shadow | Deep blue | Dense: `▓ █` |
| Surface line | Bright cyan | Line: `▄ ≈ ~` |
| Spray | White, scattered | Minimal: `· °` |

**Complementary scheme**: Purple ↔ Cyan/Teal (cool, appropriate for aquatic theme)

### 6. Dual Reading

The best terminal art reads as two things simultaneously:
- **Hermes caduceus**: Classical symbol + modern antenna
- **Shark fin**: Organic form + signal tower transmitting from the grid

## Implementation Checklist

- [ ] Art fits within target terminal width (80 cols standard, 64 cols compact)
- [ ] Uses gradient shading (dense → sparse) for volume
- [ ] Has internal structure (not solid blocks)
- [ ] Negative space is intentional, not accidental
- [ ] Form fades at boundaries rather than ending with hard edges
- [ ] Test render in actual TUI to verify no truncation
- [ ] Compact version exists for small terminals

## Session Reference

OpenShark TUI redesign: Replaced blocky pixel text (truncated, amateur) with dorsal fin logo + 3D extruded wordmark. Fin uses Braille water texture, gradient shading, asymmetric wake. Wordmark uses double-line borders, half-block shading, internal architectural structure.
