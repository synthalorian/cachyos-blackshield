# Multi-Theme Architecture (ThemeExtension + StateNotifier)

> Class: Flutter theming — 3+ themes with semantic color slots
> Applies to: Any Flutter app needing Dark/Light/Synthwave/other theme families
> Pattern source: Open Veterinarian theme overhaul (v1.7.1)

## Architecture Overview

A 4-layer approach to multi-theme Flutter apps:

```
ThemeExtension<AppColors>  →  Semantic color slots (12+)
        ↓
ThemeData builders         →  _baseTheme() template + per-theme overrides
        ↓
StateNotifier<AppThemeType> →  Hive-persisted theme state
        ↓
Provider tree              →  themeDataProvider, appColorsProvider
```

## 1. ThemeExtension — Semantic Color Slots

Define an `AppColors` extension with 12+ semantic slots — NOT raw color names:

```dart
class AppColors extends ThemeExtension<AppColors> {
  final Color surface;      // scaffold background / main canvas
  final Color card;         // card / dialog / surface background
  final Color accent;       // primary interactive color
  final Color accentSecondary; // secondary accent (labels, highlights)
  final Color accentTertiary;  // tertiary accent (special cases)
  final Color gridColor;    // background grid / pattern
  final Color textDim;      // muted text (subtitles, hints)
  final Color success;      // green states
  final Color warning;      // amber/yellow states
  final Color danger;       // error / destructive
  final Color glowColor;    // default card glow
  final Color sectionHeader; // section titles
}
```

REQUIRED overrides: `copyWith()` and `lerp()` — Flutter calls these during theme transitions.

## 2. ThemeData Builder Pattern

Use a `_baseTheme()` template method, then per-theme builders:

```dart
class AppTheme {
  static ThemeData build(AppThemeType type) {
    switch (type) { ... }
  }

  static ThemeData _baseTheme({
    required Brightness brightness,
    required Color scaffoldBg,
    required Color primaryColor,
    // ... all common settings
    required AppColors appColors,
  }) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: primaryColor,
      extensions: [appColors],   // ← inject AppColors here
      appBarTheme: AppBarTheme(...),
      inputDecorationTheme: InputDecorationTheme(...),
      chipTheme: ChipThemeData(...),
      snackBarTheme: SnackBarThemeData(...),
      dialogTheme: DialogThemeData(...),
    );
  }
}
```

Each theme calls `_baseTheme()` with its palette:
```dart
static ThemeData _buildSynthwave84() {
  return _baseTheme(
    brightness: Brightness.dark,
    scaffoldBg: const Color(0xFF240037),
    primaryColor: const Color(0xFF8F00FF),
    appColors: const AppColors(
      surface: Color(0xFF240037),
      card: Color(0xFF2D0045),
      accent: Color(0xFF8F00FF),
      accentSecondary: Color(0xFFF3E70F),
      accentTertiary: Color(0xFFFF00FF),
      // ...
    ),
  );
}
```

## 3. StateNotifier Theme Provider

Avoid `@riverpod` annotation (requires build_runner). Use plain StateNotifier:

```dart
class ThemeNotifier extends StateNotifier<AppThemeType> {
  ThemeNotifier() : super(_load());

  static AppThemeType _load() {
    final stored = DatabaseService.getThemeBox().getAt(0);
    return stored != null ? AppThemeType.values[stored] : AppThemeType.dark;
  }

  void setTheme(AppThemeType theme) {
    state = theme;
    DatabaseService.getThemeBox().putAt(0, theme.index);
  }

  ThemeData get currentTheme => AppTheme.build(state);
}
```

Three Riverpod providers:
```dart
final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, AppThemeType>(...);
final themeDataProvider = Provider<ThemeData>(...);     // for MaterialApp
final appColorsProvider = Provider<AppColors>(...);     // for per-widget colors
```

## 4. In Widgets

In `build()` methods, fetch colors via ThemeExtension:
```dart
final appColors = Theme.of(context).extension<AppColors>()!;
```

Then use semantically: `appColors.accent`, `appColors.textDim`, `appColors.danger`, etc.

In the MaterialApp, use the provider:
```dart
class App extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeDataProvider);
    return MaterialApp(theme: theme, ...);
  }
}
```

## Color Mapping Reference (migrating from hardcoded)

| Hardcoded Flutter Color | Semantic Slot |
|---|---|
| `Colors.cyanAccent` / `Colors.purpleAccent` | `appColors.accent` |
| `Colors.blueAccent` / `Colors.tealAccent` | `appColors.accentSecondary` |
| `Colors.pinkAccent` / `Colors.yellowAccent` | `appColors.accentTertiary` |
| `Colors.greenAccent` | `appColors.success` |
| `Colors.orangeAccent` / `Colors.amber` | `appColors.warning` |
| `Colors.redAccent` | `appColors.danger` |
| `Colors.black` / `Color(0xFF020202)` | `appColors.surface` |
| `Colors.white10` / `Colors.white.withOpacity(0.05)` | `appColors.card` or `appColors.accent.withAlpha(25/12)` |
| `Colors.white70` | `appColors.sectionHeader` |
| `Colors.grey` / `Colors.grey[400]` | `appColors.textDim` |
| `Colors.white` (text/icons) | `appColors.accent.withAlpha(204)` |

## Synthwave '84 Palette (omarchy match)

```
Background:  #240037  (deep dark purple)
Surface:     #1A002A  (darker purple)
Card:        #2D0045  (medium purple)
Purple:      #8F00FF  (primary accent)
Yellow:      #F3E70F  (secondary)
Yellow brt:  #FFFF66
Pink:        #FF00FF  (tertiary)
Pink soft:   #FF7EDB
Blue:        #0080FF  (accent blue)
Cyan:        #03EDF9
Red:         #FF0040
Red bright:  #FE5442
Text:        #FFFFFF
Text dim:    #B0A0C0
```

## Pitfalls

- **`DialogThemeData` vs `DialogTheme`**: `ThemeData.dialogTheme` accepts `DialogThemeData` (the data class), not `DialogTheme` (the widget). Common mistake.
- **`ConsumerWidget` vs `ConsumerStatelessWidget`**: In flutter_riverpod 2.x, the class is `ConsumerWidget`. `ConsumerStatelessWidget` was removed.
- **`const` on runtime TextStyle**: When using `appColors.accent` (runtime value), don't use `const TextStyle(...)` — use `TextStyle(...)`.
- **`const Divider(color: ...)` breakage**: When `color` comes from `appColors`, drop `const` — `Divider(color: appColors.accent)`.
- **Don't use `@riverpod` annotation for theme**: Requires build_runner. Use `StateNotifierProvider` directly.
- **Hive box for ints**: `await Hive.openBox<int>('box_name')` — standard Hive, no need for adapter registration if only storing `int`.
