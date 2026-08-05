# prefers-reduced-motion Pitfall — Hiding Hero Elements

## Problem

A `@media (prefers-reduced-motion: reduce)` query that sets `display: none` on hero scene elements (`.hero-sun::after`, `.hero-grid-floor`, `.hero-scanlines`, `.hero-palm`) makes those elements completely invisible — even when the user wants to see them and only wants reduced animation speed.

This happened when the user's system/browser had reduced motion enabled (common on Linux with certain accessibility settings, or when the user manually enables it). The sun stripes, grid floor, palm trees, and CRT scanlines all disappeared, making the hero look flat and broken.

## Root Cause

```css
/* BAD — hides elements entirely */
@media (prefers-reduced-motion: reduce) {
  .hero-stars,
  .hero-sun::after,
  .hero-grid-floor,
  .hero-scanlines,
  .hero-palm {
    display: none;
  }
}
```

The intent was to reduce motion for accessibility. But `display: none` removes the elements from the layout entirely — the user sees a static hero with no sun stripes, no grid, no palms, no scanlines. It looks like the animations "didn't deploy" when they actually did.

## Correct Approach

Slow the animations to near-zero duration instead of hiding elements:

```css
/* GOOD — preserves elements, stops motion */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }

  html {
    scroll-behavior: auto;
  }
}
```

This keeps all visual elements visible but stops them from animating — which is the actual accessibility goal of `prefers-reduced-motion`.

## Detection

If a user says "I can't see the grid floor / palm trees / sun stripes / CRT scanlines" after you've confirmed the CSS is correct:

1. Check if their browser has reduced motion enabled:
   - Firefox: `about:config` → `ui.prefersReducedMotion` → `1`
   - Chrome: DevTools → Rendering → "Emulate CSS media feature prefers-reduced-motion"
   - System-level: GNOME Settings → Accessibility → Seeing → Reduce Animation

2. Check the CSS for `display: none` inside `@media (prefers-reduced-motion: reduce)`

3. If found, replace with `animation-duration: 0.01ms` approach

## Applied Fix on synthalorian.github.io

The fix was applied in `css/style.css` by removing the `display: none` block from the reduced-motion query at the bottom of the file. The query now only sets `animation-duration`, `animation-iteration-count`, and `transition-duration` to near-zero values.

## Testing

After applying the fix, test with reduced motion enabled:
```bash
# Firefox (temporary)
firefox --prefers-reduced-motion

# Or use DevTools Rendering panel in any Chromium browser
```

Verify that:
- Sun is visible with static stripes
- Grid floor is visible (not moving)
- Palm trees are visible (not swaying)
- CRT scanlines are visible (not flickering)
- All text and buttons remain fully functional
