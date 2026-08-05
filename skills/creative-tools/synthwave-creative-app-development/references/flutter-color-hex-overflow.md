# Flutter Color() Hex Overflow — 10-Digit Hex Bug

> Discovered and fixed during the Hermes Wingman visual overhaul (May 2026).

## The Bug

Theme constants written with 10-digit hex values like `Color(0xFF0D0A1A80)` cause the sidebar and bottom nav to render at ~5% opacity instead of the intended 50%.

**Why:** Dart `Color()` constructor takes a 32-bit `int` interpreted as ARGB (8 hex digits). A 10-digit hex literal like `0xFF0D0A1A80` is a valid 64-bit integer in Dart, but when truncated to 32 bits for the Color constructor, the bits shift:

- Written: `0xFF0D0A1A80` (10 hex digits)
- As 64-bit: `0x000000FF0D0A1A80`
- Truncated to 32 bits: `0x0D0A1A80`
- Interpreted as ARGB: A=13 (5% opacity), R=10, G=26, B=128

The intended color was `0x800D0A1A` — ARGB where 80 = 50% alpha.

## The Fix

One-line sed command that replaces all instances:

```bash
sed -i -E 's/0xFF([0-9A-Fa-f]{6})80/0x80\1/g' lib/theme/app_theme.dart
```

**What it does:** Finds patterns like `0xFF0D0A1A80` and replaces with `0x800D0A1A` by:
1. Grabbing the 6 hex digits between `0xFF` and `80`
2. Replacing `0xFF` with `0x80`
3. Keeping the same 6 hex digits

**Verify:**
```bash
flutter analyze  # should show zero errors
grep -c '0xFF[0-9A-Fa-f]\{6\}80' lib/theme/app_theme.dart  # should be 0
```

## Affected Patterns

Any Flutter `Color()` constructor where:
- Hex value is 10 digits (e.g. `0xFFRRGGBB80`)
- The last 2 digits (`80`) were intended as alpha
- The first 2 digits (`FF`) were full opacity

## Prevention

Always use 8-digit ARGB hex for the Color constructor:
- `0xFFRRGGBB` = fully opaque
- `0x80RRGGBB` = ~50% opacity
- `0x00RRGGBB` = fully transparent

Never use:
- `0xFFRRGGBB00` (wrong: this is 10 digits, colors shift)
- `0xRRGGBB` (wrong: this is 6 digits, Color interprets as ARGB with zero alpha)