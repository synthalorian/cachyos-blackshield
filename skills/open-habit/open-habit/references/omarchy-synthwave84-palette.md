# Omarchy Synthwave84 → App Palette Mapping

The app's `SynthwaveColors` class matches the Omarchy synthwave84 desktop theme exactly.

## Source Theme (Omarchy synthwave84)

```
Background:     #0d0221   (deep space purple-black)
Surface:        #240037   (raised dark purple)
Primary accent: #8F00FF   (electric neon purple — used for active borders in Hyprland)
Foreground:     #FFFF66   (warm amber-yellow — used for waybar text)
Magenta:        #df00ff   (secondary accent — used in walker/mako)
Pure pink:      #ff00ff   (tertiary accent)
```

## App Mapping

| SynthwaveColors constant | Value | Omarchy Source |
|---|---|---|
| `bgPrimary` | `0xFF0d0221` | `background` |
| `bgSecondary` | `0xFF1a0030` | slightly lighter variant |
| `bgSurface` | `0xFF240037` | `surface` |
| `bgElevated` | `0xFF2d004d` | elevated variant |
| `neonPurple` | `0xFF8F00FF` | `primary` / Hyprland `col.active_border` |
| `neonMagenta` | `0xFFdf00ff` | mako accent |
| `neonPink` | `0xFFff00ff` | walker accent |
| `neonYellow` | `0xFFFFFF66` | `foreground` / waybar text |
| `textPrimary` | `0xFFFFFF66` | `foreground` |
| `textSecondary` | `0xFFCCAA44` | muted gold variant |
| `textMuted` | `0xFF663388` | muted purple variant |

## Key Implementation Details

- `neon_widgets.dart` line 21 checks `theme.colorScheme.primary.toARGB32() == 0xFF8F00FF` to detect synthwave mode for the `GradientBackground` widget
- `GradientBackground` defaults: start `#0d0221` → end `#240037`
- Card borders use `SynthwaveColors.neonPurple` (1.5px, was formerly `neonCoral`)
- Button backgrounds use `SynthwaveColors.neonPurple` (was formerly `neonCoral`)
- XP bar gradient: secondary (`neonMagenta` / `#df00ff`) → primary (`neonPurple` / `#8F00FF`)
- All deprecated `withOpacity()` calls replaced with `withValues(alpha:)`

## When Updating Theme

1. Change the 5 `SynthwaveColors` constants in `app_theme.dart`
2. Update `GradientBackground` default colors in `neon_widgets.dart` (lines 27-28)
3. Update the `isSynthwave` detection check in `neon_widgets.dart` (line 21) — compare against `SynthwaveColors.neonPurple.toARGB32()`
4. Verify category colors in `habit_categories.dart` still look good against the new palette
5. Rebuild and deploy: `flutter build apk --release && flutter install --release`
