# Fluid Stripe Scroll Pattern

## Problem

Animating horizontal stripes inside a masked circular element (sun, CRT scanlines) with `transform: translateY()` causes visible subpixel jitter/shaking. The pseudo-element's transform fights with the parent's `overflow: hidden` + `border-radius` mask, creating a wobbly edge effect.

## Solution

Use `background-position` animation on an oversized pseudo-element instead.

### Why this works

- `background-position` shifts the gradient pattern itself, not the element box — no subpixel rounding issues
- Oversized pseudo-element (`inset: -50%; width: 200%; height: 200%`) provides offscreen buffer so the mask never clips the gradient edge
- The translate distance must exactly match the repeat cycle of `repeating-linear-gradient`

### Pattern

```css
.element {
  position: relative;
  overflow: hidden;
  /* mask, border-radius, etc. */
}

.element::after {
  content: '';
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  background: repeating-linear-gradient(
    0deg,
    transparent 0px,
    transparent 10px,
    rgba(13, 2, 33, 0.7) 10px,
    rgba(13, 2, 33, 0.7) 18px
  );
  animation: stripeScroll 2s linear infinite;
}

@keyframes stripeScroll {
  0% { background-position: 0 0; }
  100% { background-position: 0 18px; } /* matches repeat cycle */
}
```

### Repeat cycle math

For `repeating-linear-gradient(0deg, transparent A, transparent B, color C, color D)`:
- Repeat cycle = D - A (the distance before the pattern repeats)
- `background-position` translate must equal this exact distance for seamless loop

Example: `transparent 0px, transparent 10px, rgba(...) 10px, rgba(...) 18px`
- Cycle = 18px - 0px = 18px
- `background-position: 0 18px` at 100%

### Anti-pattern (what NOT to do)

```css
/* BAD — causes jitter/shaking */
.element::after {
  animation: badScroll 2s linear infinite;
}
@keyframes badScroll {
  0% { transform: translateY(0); }
  100% { transform: translateY(18px); }
}
```

### When to use transform instead

`transform: translateY()` is fine when:
- The element is NOT inside an `overflow: hidden` + `border-radius` parent
- You're animating the whole element, not a pattern inside a mask
- Subpixel precision doesn't matter (large movements, not fine stripes)

### Applied on synthalorian.github.io

Used for:
- **Sun stripes** (`css/style.css` `.hero-sun::after`) — dark horizontal lines scrolling down the sun
- **CRT scanlines** (`css/style.css` `.hero-scanlines`) — could use same pattern for smoother flicker
- **Grid floor** (`css/style.css` `.hero-grid-floor`) — already uses `background-position` for perspective grid movement

### Color contrast tip

If stripes are hard to see against the gradient background, increase opacity:
- Start with `rgba(13, 2, 33, 0.5)` (subtle)
- Bump to `0.7` if invisible
- Use `0.85` for high-contrast CRT effect

The parent gradient colors (purple/pink/red for sun) determine what opacity reads well. Dark stripes on bright gradient need higher opacity.