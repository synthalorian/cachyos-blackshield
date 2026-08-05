# CSS Positioning — Absolute Overlap Debugging

## Problem
The `.scroll-indicator` (mouse icon + "SCROLL TO EXPLORE" text) was clipping with the GitHub Profile button in the hero section.

## Initial Wrong Assumption
The overlap was assumed to be horizontal — the scroll indicator was centered at `left: 50%` and thought to be colliding with the button to its left. Multiple attempts to shift it right (`translateX(-40%)`, `translateX(-20%)`, `translateX(0)`) produced no visible change.

## Root Cause
The overlap was **vertical**, not horizontal. The `.scroll-indicator` is `position: absolute` at `bottom: 36px`. The `.hero-cta` (button row) has no bottom margin, so the scroll indicator sits directly on top of the button area, clipping into it.

## Correct Fix
Add `margin-bottom: 80px` to `.hero-cta` to push the button row up, creating a gap between the buttons and the absolutely-positioned scroll indicator below.

```css
.hero-cta {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
  margin-bottom: 80px;  /* pushes scroll indicator clear */
}
```

## Lesson
When an absolutely-positioned element at `bottom: N` appears to "clip" with another element, check **vertical spacing first** (margin/padding on the element above it) before assuming horizontal collision. `transform: translateX()` only affects horizontal position and won't solve vertical overlap.
