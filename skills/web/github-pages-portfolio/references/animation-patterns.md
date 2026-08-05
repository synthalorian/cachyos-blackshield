# Animation Patterns — Synthwave '84 Portfolio

Reference for CSS animations on the portfolio site. All animations are CSS-driven (no JS animation libraries).

## File Location

**CRITICAL:** Animations live in `css/style.css`, NOT `styles.css`. Always verify path before patching.

## Hero Scene Animations

### Sun
- `sunPulse` — combined scale + stripe scroll + glow (user's preferred "full" animation)
  - Scale: `translateX(-50%) scale(1)` → `translateX(-50%) scale(1.08)` (subtle, not distracting)
  - Stripe scroll: horizontal scanlines scroll vertically inside the sun (see Fluid Stripe Scroll pattern below)
  - Glow: box-shadow intensifies with extra spread
  - Duration: 6s ease-in-out infinite alternate
  - Applied to `.hero-sun`

### Fluid Stripe Scroll Pattern

For seamless scrolling stripes inside a masked circular element (sun, CRT, etc.):

```css
.hero-element {
  overflow: hidden;  /* clips the oversized pseudo-element */
}

.hero-element::after {
  content: '';
  position: absolute;
  inset: -50%;        /* overflow on all sides */
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
  100% { background-position: 0 18px; }  /* MUST match repeat cycle */
}
```

**Why this works:** The `repeating-linear-gradient` has a repeat cycle of 18px (transparent 0-10px + stripe 10-18px). The pseudo-element is 200% height with `inset: -50%`, providing a full screen's worth of offscreen buffer above and below. `background-position: 0 18px` shifts the pattern by exactly one cycle, creating a seamless loop. The parent's `overflow: hidden` + `border-radius: 50%` masks the edges.

**Common failure — transform jitter:** Using `transform: translateY()` on a `::after` pseudo-element whose parent has `overflow: hidden` causes subpixel snapping — the stripes appear to "shake" rather than scroll smoothly. The browser rounds the transform to different subpixels each frame. Fix: animate `background-position` instead of `transform`.

**Also avoid:** Using `background-position` on the parent's main gradient instead of a separate pseudo-element. This shifts the entire color wash, creating seams. Always use a dedicated `::after` for stripe scroll, with the base gradient static on the parent.

### Grid Floor
- `gridMove` — background-position scroll for perspective movement + opacity pulse
  - `background-position: 0 0 → 0 160px` over 8s linear infinite
  - Opacity: 0.7 → 1 → 0.7
  - Lines: horizontal `rgba(143, 0, 255, 0.35)`, vertical `rgba(3, 237, 249, 0.25)`
  - Applied to `.hero-grid-floor`

### Palm Trees
- `palmSway` / `palmSwayRight` — gentle ±2deg rotation, 5s ease-in-out infinite alternate
  - Left palm: `animation-delay: 0s`
  - Right palm: `animation-delay: -2.5s`, needs `scaleX(-1)` preserved in keyframe
  - Opacity: 0.35 (was 0.25 — too faint)
  - Applied to `.hero-palm`

### CRT Scanlines
- `crtFlicker` — micro-opacity jitter
  - `opacity: 0.85 → 0.75 → 0.85`, 0.15s infinite
  - Line opacity: `rgba(0, 0, 0, 0.08)` (was 0.04 — too faint in dark mode)
  - Applied to `.hero-scanlines`

## Content Animations

### Hero Badge
- `badgeFloat` — gentle Y translate (-4px), 4s ease-in-out infinite

### Primary Button
- `gradientShift` — background-position sweep across 200% gradient, 5s ease infinite
  - Requires `background-size: 200% 200%` on the element

### Section Labels
- `labelGlow` — text-shadow intensity pulse, 3s alternate

## Hover Animations

### Project Cards
- `.project-card:hover .project-icon` → `iconBounce` — scale 1→1.15→0.95→1, 0.5s

### Stat Cards
- `.stat-card:hover .stat-number` → `numberPulse` — scale 1→1.1→1, 0.6s

### Tech Tags
- `transform: translateY(-2px)` + box-shadow glow on hover

## prefers-reduced-motion Pitfall

**NEVER hide animated elements with `display: none` in `prefers-reduced-motion: reduce`.**

Wrong:
```css
@media (prefers-reduced-motion: reduce) {
  .hero-grid-floor, .hero-palm, .hero-scanlines { display: none; }
}
```

Right:
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

This freezes animations but keeps the elements visible. The user's system may have reduced motion enabled by default — hiding elements makes them think the animations "didn't work."

## Adding New Animations

1. Define `@keyframes` in `css/style.css`
2. Apply with `animation: name duration timing-function iteration`
3. For hover-triggered: use parent `:hover` to target child
4. Prefer `transform` and `opacity` — GPU-composited, no layout thrash
5. Use `animation-fill-mode: both` when entrance animations need to hold final state
6. For seamless loops inside masked shapes, use the Fluid Stripe Scroll pattern (oversized pseudo-element + exact-cycle `background-position`)

## Performance Notes

- All existing animations use only `transform`, `opacity`, `box-shadow`, `background-position`
- Avoid animating `width`, `height`, `top`, `left` — causes layout recalculation
- `will-change: transform` on heavily-animated elements can help but use sparingly
- **Exception:** For stripe scroll inside masked shapes, use `background-position` instead of `transform` to avoid subpixel jitter on pseudo-elements
