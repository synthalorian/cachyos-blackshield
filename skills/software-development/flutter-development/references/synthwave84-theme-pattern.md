# Synthwave '84 Flutter Theme Pattern

## Palette (matches Omarchy system)

```dart
sw84Background = Color(0xFF240037)   // Deep purple-black
sw84Surface    = Color(0xFF1A002A)   // Darker surface
sw84Card       = Color(0xFF2D0045)   // Card background
sw84Elevated   = Color(0xFF3A0058)   // Elevated surface
sw84Purple     = Color(0xFF8F00FF)   // Primary accent
sw84Yellow     = Color(0xFFF3E70F)   // Secondary accent (golden yellow)
sw84YellowBrt  = Color(0xFFFFFF66)   // Bright yellow (Omarchy warning)
sw84Pink       = Color(0xFFFF00FF)   // Tertiary accent
sw84PinkSoft   = Color(0xFFFF7EDB)   // Soft pink
sw84Cyan       = Color(0xFF03EDF9)   // Cyan accent
sw84Blue       = Color(0xFF0080FF)   // Blue accent
sw84Red        = Color(0xFFFF0040)   // Error/danger
sw84Text       = Color(0xFFFFFFFF)   // Primary text
sw84TextDim    = Color(0xFFB0A0C0)   // Dim text
```

## DarkColorScheme Mapping

| ColorScheme slot | sw84 constant |
|---|---|
| `primary` | `sw84Purple` |
| `onPrimary` | `sw84Text` |
| `secondary` | `sw84Yellow` |
| `onSecondary` | `sw84Background` |
| `tertiary` | `sw84Pink` |
| `surface` | `sw84Surface` |
| `error` | `sw84Red` |
| `outline` | `sw84Purple.withAlpha(51)` |
| `outlineVariant` | `sw84TextDim` |

## Component Color Overrides (dark theme only)

Replace `AppColors.neonPink` → `AppColors.sw84Purple` and `AppColors.textPrimary` → `AppColors.sw84Text` in the dark theme section of app_theme.dart. Bulk-edit approach via execute_code works well (read lines, replace within dark theme boundaries, write back).

## Sw84 Gradient

```dart
static const LinearGradient sw84Gradient = LinearGradient(
  colors: [sw84Purple, sw84Pink, sw84Cyan],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
```

Apply to SliverAppBar flexible background in dashboard screens.
