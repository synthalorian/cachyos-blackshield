# ASCII Art Quality Bar — Reference

## Standard
Hermes caduceus / CLASH block letters — the user holds ASCII art to this level.

## What Makes Hermes Quality
- **Symbolic depth:** dual reading (caduceus + antenna), every pixel means something
- **Internal structure:** not solid blocks, but walls/floors/hollow centers
- **Gradient/shading:** light source from above, vertical density variation
- **Dynamic symmetry:** balanced but not rigid, organic curves
- **Negative space mastery:** form defined by surroundings, not just filled area

## What Fails
- Solid gradient triangles with no internal structure
- Garbled letters (half-block chars `▀▄█` rendering wrong in terminal fonts)
- Characters that artifact as gray squares (`▗▖▘▝` quadrant chars)
- Left-aligned when the panel has width for centering
- Truncated because width wasn't checked against terminal

## Working Character Sets for Terminal ASCII Art
| Safe | Unsafe | Texture |
|------|--------|---------|
| `┌─┐│└┘━` (box drawing) | `▀▄` (half-blocks render inconsistently) | Braille dots `⠁⠂⠄` for organic density |
| `█` (full block) | `▗▖▘▝` (quadrants artifact as gray squares) | |
| `≈~` (waves) | | |

## Workflow for ASCII Art
1. Analyze reference quality (Hermes, CLASH, etc.) — character choice, proportions, shading
2. Design with ONLY safe characters
3. Center in available frame width
4. Test render before committing
5. User will reject anything below reference quality — iterate until it matches

## Session Example: OpenShark Welcome Banner

**Attempt 1:** Gradient triangle fin + blocky pixel text — rejected. "we can do much much better on the fin."

**Attempt 2:** Fin-antenna with `╱│╲` spine + Braille crown — partially accepted but:
- `▀▄` half-blocks garbled "OPENSHARK" into "OEATNAEANAE"
- `▗` quadrant char artifacted as gray square at fin top
- Waves didn't span full width
- Everything left-aligned instead of centered

**Fix:**
- Switched to `┌─┐│└┘━` box drawing for letters (clean, consistent)
- Removed ALL quadrant/half-block chars
- Added `center()` function for frame-width centering
- Made wave bar 80 chars full-width
- Connected fin top with solid `███`

**User approval:** "the fin is perfect"
