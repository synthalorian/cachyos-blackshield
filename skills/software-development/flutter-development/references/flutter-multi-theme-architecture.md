# Multi-Theme Architecture: ThemeConfig + ThemePalette Pattern

For apps needing 3+ complete theme palettes (e.g. Synthwave '84, Midnight Calm, Rose Dawn, Forest Zen, Classic), use the ThemeConfig + ThemePalette pattern backed by Riverpod.

## File Structure

```
core/theme/
├── theme_config.dart      # ThemeConfig model + all theme definitions
├── theme_provider.dart     # ThemeState/ThemeNotifier + palette providers
└── app_theme.dart          # Builds Material3 ThemeData from a palette
```

## ThemeConfig Model

```dart
class ThemeConfig {
  final String id;            // 'synthwave84'
  final String displayName;   // "Synthwave '84"
  final String description;
  final ThemePalette palette; // all colors for this theme
  final IconData icon;        // for theme selector UI
  
  static const synthwave84 = ThemeConfig(
    id: 'synthwave84',
    displayName: "Synthwave '84",
    description: 'Deep purples, neon pinks, and yellow glows.',
    icon: Icons.sunny,
    palette: ThemePalette(
      background: Color(0xFF0D0221),
      surface: Color(0xFF10002B),
      card: Color(0xFF240037),
      primary: Color(0xFF8F00FF),
      primaryLight: Color(0xFFC77DFF),
      secondary: Color(0xFFFF00FF),
      accent: Color(0xFF00FFFF),
      // ... all colors
    ),
  );
  
  static const all = [synthwave84, midnightCalm, roseDawn, forestZen, classic];
  static ThemeConfig fromId(String id) => all.firstWhere((t) => t.id == id, orElse: () => synthwave84);
}
```

## ThemePalette — Full Color Specification

```dart
class ThemePalette {
  // Backgrounds
  final Color background, backgroundLight, surface, surfaceVariant, card, elevated;
  // Accents
  final Color primary, primaryLight, primaryDark, secondary, secondaryLight, secondaryDark, accent, accentLight;
  // Text
  final Color textPrimary, textSecondary, textTertiary;
  // Status
  final Color success, warning, error, info;
  // Mood
  final Color moodHappy, moodNeutral, moodSad, moodAnxious, moodTerrible;
  // Category colors (Map<String, Color>)
  final Map<String, Color> categoryColors;
  // Light mode overrides
  final Color? lightBackground, lightSurface, lightCard;
  
  // Gradient helpers — derive from palette colors
  LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, secondary],
  );
}
```

## Riverpod Providers

```dart
// Full theme state: config + mode
final themeStateProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

// Derived — provides current palette for screens
final currentPaletteProvider = Provider<ThemePalette>((ref) {
  return ref.watch(themeStateProvider).config.palette;
});

// Available themes list (for selector UI)
final allThemesProvider = Provider<List<ThemeConfig>>((ref) => ThemeConfig.all);

class ThemeState {
  final ThemeConfig config;
  final ThemeMode mode;  // dark/light/system
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  Future<void> setTheme(ThemeConfig config) async { /* persist to prefs */ }
  Future<void> setMode(ThemeMode mode) async { /* persist to prefs */ }
}
```

## AppTheme.build Factory

```dart
class AppTheme {
  static ThemeData build(ThemeConfig config, Brightness brightness) {
    final palette = config.palette;
    final isDark = brightness == Brightness.dark;
    
    final backgroundColor = isDark ? palette.background : (palette.lightBackground ?? fallback);
    final textPrimary = isDark ? palette.textPrimary : darkTextForLightMode;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        primary: palette.primary,
        secondary: palette.secondary,
        tertiary: palette.accent,
        surface: surfaceColor,
        error: palette.error,
      ),
      // Component themes: card, appBar, bottomNav, FAB, buttons, inputs,
      // chips, sliders, switches, dialogs, snackbars, bottomSheet, progress
      textTheme: TextTheme(
        // All using GoogleFonts.comfortaa with textPrimary/textSecondary/textTertiary
      ),
    );
  }
}
```

## Wiring in app.dart

```dart
class OpenAssuranceApp extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeStateProvider);
    return MaterialApp.router(
      theme: AppTheme.build(themeState.config, Brightness.light),
      darkTheme: AppTheme.build(themeState.config, Brightness.dark),
      themeMode: themeState.mode,
    );
  }
}
```

## Usage in Screens

```dart
// In any ConsumerWidget or ConsumerStatefulWidget:
final palette = ref.watch(currentPaletteProvider);

// Then use palette colors directly:
Container(color: palette.card)
Text('hello', style: TextStyle(color: palette.textSecondary))
```

## Backward Compatibility

Keep `AppColors` delegating to the default theme's palette via getters:

```dart
class AppColors {
  static final ThemePalette _default = ThemeConfig.synthwave84.palette;
  static Color get primary => _default.primary;
  static Color get backgroundCard => _default.card;
  static Color get textSecondary => _default.textSecondary;
  // ... all existing static getters delegate through
}
```

This lets existing screens that reference `AppColors.primary` continue working without migration. New screens should use `currentPaletteProvider` instead.

## Theme Selector UI

In Settings or preferences, render a horizontal scroll of theme cards:

```dart
SizedBox(
  height: 100,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: allThemes.length,
    itemBuilder: (context, index) {
      final theme = allThemes[index];
      final isActive = theme.id == currentConfig.id;
      return GestureDetector(
        onTap: () => ref.read(themeStateProvider.notifier).setTheme(theme),
        child: AnimatedContainer(
          width: 90,
          decoration: BoxDecoration(
            color: theme.palette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? theme.palette.primaryLight : Colors.transparent,
              width: 2,
            ),
            boxShadow: isActive ? [BoxShadow(color: theme.palette.primary.withAlpha(77), blurRadius: 12)] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(theme.icon, color: theme.palette.primary, size: 28),
              Text(theme.displayName, style: TextStyle(fontSize: 10, ...)),
            ],
          ),
        ),
      );
    },
  ),
)
```

## PITFALLS

### `const` + Dynamic Getters = `invalid_constant`

When switching `AppColors` from `static const` fields to getters, every `const Icon(..., color: AppColors.xxx)` or `const TextStyle(color: AppColors.xxx)` will produce "Invalid constant value" errors.

**Fix:** Remove `const` from the widget constructor when any parameter uses `AppColors.xxx`:
- `const Icon(..., color: AppColors.xxx)` → `Icon(..., color: AppColors.xxx)`
- `const TextStyle(color: AppColors.xxx)` → `TextStyle(color: AppColors.xxx)`

The `const` keyword applies to the entire constructor call — any non-const argument makes the whole call non-const. Affected constructors: `Icon`, `TextStyle`, `Padding`, `EdgeInsets`, `SizedBox`, `Container`.

**Batch fix pattern:** The `const` and `AppColors` reference may be on different lines. Search for `const Icon(` or `const TextStyle(` then look ahead 5-8 lines for `AppColors.`:

```python
for each line in file:
    if 'const Icon(' in line:
        look ahead 6 lines for 'AppColors.'
        if found: replace 'const Icon(' with 'Icon(' on the current line
```

### Theme Independence

Screens using static `AppColors` will NOT dynamically switch themes when the user changes theme. Migration path: wrap each screen in `ConsumerWidget` (or use `Consumer`), call `ref.watch(currentPaletteProvider)`, and use the returned palette for all color references. This lets the theme change propagate instantly.

### StateNotifier vs Notifier

`StateNotifier` (Riverpod 2.x) is used above for `ThemeNotifier`. In Riverpod 3.x, prefer `Notifier` with `NotifierProvider`. The pattern is the same — holds a state object, exposes mutation methods, persists to SharedPreferences.

### Gradient Consistency

Gradients must be derived from palette colors, not hardcoded. Define them as `get` accessors on `ThemePalette` so they automatically reflect the active theme:

```dart
class ThemePalette {
  LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, secondary],
  );
  LinearGradient get sunsetGradient => LinearGradient(
    colors: [elevated, primaryDark, primary, secondary, warning],
  );
}
```