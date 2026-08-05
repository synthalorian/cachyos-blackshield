# Synthwave84 Theme Color Palette

The canonical color palette for Omarchy's synthwave84 theme. Use these exact values when building or porting apps that need to match the system theme.

## Source Files

Colors extracted from:
- `~/.config/omarchy/themes/synthwave84/waybar.css` — background, foreground
- `~/.config/omarchy/themes/synthwave84/walker.css` — base, border, selected-text, foreground
- `~/.config/omarchy/themes/synthwave84/btop.theme` — full color system
- `~/.config/omarchy/themes/synthwave84/swayosd.css` — border, label, progress

## Color Table

| Role | Hex | Usage |
|------|-----|-------|
| Background (deep) | `#0D0221` | Scaffold, deepest background |
| Surface | `#240037` | Card backgrounds, base surface |
| Surface Alt | `#2D0047` | Slightly lighter surface for variance |
| Background (nav) | `#0A011A` | App bar, sidebar, bottom nav |
| **Primary** | **`#8F00FF`** | Electric purple — main accent, borders, selected states |
| Secondary | `#FF00FF` | Hot pink — complementary accent |
| Accent | `#00FFFF` | Cyan — tertiary accent, data streams |
| Text | `#FFFFFF` | White — primary text |
| Text Dim | `#C0A0D0` | Lighter purple-gray — secondary text |
| Text Muted | `#663388` | Muted purple — hints, placeholders |
| Border | `#8F00FF` | Same as primary — active borders |
| Border Dim | `#4A0068` | Darker purple — subtle borders |
| Success | `#00FF41` | Lime green — positive states |
| Warning | `#FFFF66` | Yellow — caution states, titles |
| Error | `#FF0040` | Red — error states |
| Selected BG | `#3A0055` | Slightly lighter than surface for row selection |
| Title/Yellow | `#FFFF66` | From btop theme `title` — used for section headers |
| Hot Pink | `#FF007F` | From btop — used in gradients |
| Neon Pink | `#FE347E` | From btop `net_box` |
| Bright Purple | `#DF00FF` | From btop `hi_fg` — keyboard shortcuts |

## Related CSS Variable Names

From `btop.theme`:
- `main_bg` = `#240037`
- `main_fg` = `#FFFFFF`
- `title` = `#FFFF66`
- `hi_fg` = `#DF00FF`
- `selected_bg` = `#8F00FF`
- `inactive_fg` = `#8F00FF`
- `proc_box` = `#8F00FF`

## Flutter AppColorScheme — Color Constants Only

Minimal constant set for when you just need the colors:

```dart
const synthwave84 = AppColorScheme(
  background: Color(0xFF0D0221),
  surface: Color(0xFF240037),
  surfaceAlt: Color(0xFF2D0047),
  primary: Color(0xFF8F00FF),
  secondary: Color(0xFFFF00FF),
  accent: Color(0xFF00FFFF),
  text: Color(0xFFFFFFFF),
  textDim: Color(0xFFC0A0D0),
  textMuted: Color(0xFF663388),
  border: Color(0xFF8F00FF),
  borderDim: Color(0xFF4A0068),
  cardBackground: Color(0xFF240037),
  selectedBackground: Color(0xFF3A0055),
  scaffoldBackground: Color(0xFF0D0221),
  appBarBackground: Color(0xFF0A011A),
  bottomNavBackground: Color(0xFF0A011A),
  success: Color(0xFF00FF41),
  warning: Color(0xFFFFFF66),
  error: Color(0xFFFF0040),
);
```

## Flutter Material 3 ThemeData — Full Implementation

Color constants alone are **not enough** for a polished match. The full `ThemeData` below covers all component themes that Material 3 apps need to look native on Omarchy. Key patterns:

- **Nav/app bar uses `#0A011A`** (darker than scaffold `#0D0221`) for visual layering
- **Cards get a subtle border** (`#4A0068` at 0.5px) + purple shadow glow — not just a flat surface color
- **Input fields, dialogs, bottom sheets, switches, chips** all need explicit theming or Material 3 defaults (blue/gray) will leak through
- **`surfaceTintColor: Colors.transparent`** on app bar and dialogs prevents Material 3's default tint overlay

```dart
static ThemeData get synthwave84Theme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: const Color(0xFF8F00FF),
    secondary: const Color(0xFFFF00FF),
    tertiary: const Color(0xFF00FFFF),
    surface: const Color(0xFF240037),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
    outline: const Color(0xFF8F00FF),
    outlineVariant: const Color(0xFF4A0068),
    surfaceContainerHighest: const Color(0xFF2D0047),
  ),
  scaffoldBackgroundColor: const Color(0xFF0D0221),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0A011A),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF240037),
    elevation: 2,
    shadowColor: const Color(0xFF8F00FF).withValues(alpha: 0.3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFF4A0068), width: 0.5),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF0A011A),
    selectedItemColor: Color(0xFF8F00FF),
    unselectedItemColor: Color(0xFF663388),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFF240037),
    selectedColor: const Color(0xFF8F00FF).withValues(alpha: 0.3),
    labelStyle: const TextStyle(color: Colors.white),
    side: const BorderSide(color: Color(0xFF4A0068)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF4A0068)),
  tabBarTheme: const TabBarThemeData(
    labelColor: Color(0xFF8F00FF),
    unselectedLabelColor: Color(0xFFC0A0D0),
    indicatorColor: Color(0xFF8F00FF),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF240037),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF4A0068)),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF240037),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    selectedColor: Colors.white,
    selectedTileColor: Color(0xFF3A0055),
    iconColor: Color(0xFF8F00FF),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return const Color(0xFF8F00FF);
      return const Color(0xFF663388);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return const Color(0xFF8F00FF).withValues(alpha: 0.5);
      return const Color(0xFF4A0068);
    }),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF240037),
    hintStyle: const TextStyle(color: Color(0xFF663388)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF4A0068)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF4A0068)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF8F00FF), width: 1.5),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Color(0xFF8F00FF),
    linearTrackColor: Color(0xFF4A0068),
  ),
);
```

### Pitfalls

- **Don't skip `surfaceTintColor: Colors.transparent`** — Material 3 adds a tinted overlay on app bars and dialogs by default. Without this, surfaces get a blue-ish tint that clashes with the purple palette.
- **Cards need explicit borders** — without `side: BorderSide(color: borderDim)`, cards blend into the scaffold on dark backgrounds and look invisible.
- **`onSecondary: Colors.white`** (not `Colors.black`) — hot pink (`#FF00FF`) text on black is unreadable; white works on both primary purple and secondary pink.
- **Generic "neon" colors are wrong** — the canonical palette is **purple-forward**, not navy or hot-pink-forward. Primary is `#8F00FF` (electric purple), not `#FF2975` (hot pink) or `#1A0A3E` (navy). The secondary `#FF00FF` is complementary, not dominant.

## History

- May 17, 2026: Colors extracted from Omarchy theme files after user noted Hermes Wingman's Synthwave '84 was navy blue instead of purple. Corrected to match system theme.
- May 20, 2026: Added full Flutter Material 3 ThemeData implementation with component themes and pitfalls, after porting theme to Open Bible app.
