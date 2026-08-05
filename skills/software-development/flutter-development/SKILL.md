---
name: flutter-development
description: "Flutter app patterns: offline data, navigation, CustomPainter, theme management, url_launcher, code-generated visuals."
version: 1.10.0
author: synthclaw
platforms: [linux, macos, windows, android, ios]
metadata:
  hermes:
    tags: [flutter, dart, offline, navigation, custom-painter, state-management, crt-effects, android-ndk, rust-bridge, cli-wrapper, terminal-detection, subprocess-chat, web-scraping, reference-data, data-ingestion]
    related_skills: [github-repo-management, omarchy, rust-workspace-troubleshooting, flutter-app-scaffolding]
triggers:
  - "Flutter app"
  - "Dart code"
  - "offline app"
  - "CustomPainter"
  - "InteractiveViewer"
  - "theme management"
  - "url_launcher"
  - "bottom sheet"
  - "navigation"
  - "CRT effect"
  - "synthwave background"
  - "scanlines"
  - "vignette"
  - "multi-theme"
  - "Rust native library"
  - "FlamingoColors.syncFrom"
  - "dynamic theme colors"
  - "const invalid_constant"
  - "Notifier vs StateNotifier"
  - "flutter_rust_bridge Android"
  - "jniLibs"
  - "withOpacity"
  - "ListenableBuilder"
  - "withValues alpha"
  - "JDK version Android"
  - "CLI wrapper service"
  - "HermesClient"
  - "Flutter desktop sidebar"
  - "agent system GUI"
  - "terminal detection"
  - "in-app chat subprocess"
  - "fixed-width CLI parsing"
  - "cross-platform terminal"
  - "oneshot subprocess"
  - "gateway state json"
  - "model favorites persistent"
  - "navigation callback"
  - "system_tray"
  - "PopScope"
  - "close to tray"
  - "desktop window lifecycle"
  - "AppWindow"
  - "window not filling"
  - "shrink-wrap"
  - "root layout fill"
  - "double.infinity"
---

# Flutter Development Patterns

> **References:** `references/flutter-theme-palette-audit.md` — systematic 6-phase checklist for debugging wrong-colors, theme-switch failures, and missing-asset bugs after multi-theme refactors.

Class-level skill for Flutter app patterns that recur across sessions. Not a Flutter tutorial — these are specific solutions to problems that re-emerge.

## 1. URL Launching (url_launcher)

**PITFALL:** `canLaunchUrl()` silently returns `false` on Android 11+ when the app manifest lacks a `<queries>` element for browser URL handling. Without matching queries, `canLaunchUrl` is **always false** and the URL never opens.

**FIX:** Skip `canLaunchUrl` entirely. Just wrap `launchUrl` in try/catch:

```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Browser not available — fail silently
  }
}
```

Use this pattern for FleetYards links, GitHub links, Buy Me a Coffee buttons — everywhere.

## 2. Theme Management — Two Architecture Patterns

This section covers two approaches to Flutter multi-theme management. Both are valid — choose based on your state management layer.

### Approach A — Riverpod Notifier + syncFrom (for apps already using Riverpod)

Best for apps using Riverpod 3.x for state management. Allows any number of themes (not just light/dark).

**Provider setup:**
```dart
class ThemeNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setTheme(int i) { state = i.clamp(0, 3); }
}
final themeIndexProvider = NotifierProvider<ThemeNotifier, int>(ThemeNotifier.new);
final themeDataProvider = Provider<ThemeData>((ref) => AppTheme.get(ref.watch(themeIndexProvider)));
```

**Legacy color bridge (for screens that import FlamingoColors statically):**
```dart
class FlamingoColors {
  static void syncFrom(ColorScheme cs) {
    primary = cs.primary;
    scaffoldBg = cs.surface;
    // ... map every static field to its colorScheme equivalent
  }
}
// Call in App.build before MaterialApp.router
```

**Critical issue:** Once `FlamingoColors` fields become runtime-dynamic (non-const), every `const` widget constructor referencing them breaks:
```dart
const Text('x', style: TextStyle(color: FlamingoColors.muted))
// → invalid_constant error
Text('x', style: TextStyle(color: FlamingoColors.muted))  // ✓
```

### Approach B — ThemeMode.system + light/dark pair (standard Material approach)

Use when you want a theme switcher that works without Riverpod/Bloc — pure Flutter with `ChangeNotifier` + `ListenableBuilder`.

### CRITICAL PITFALL: MaterialApp Dark Theme Slot

**MaterialApp has TWO theme parameters:** `theme` (used in light mode) and `darkTheme` (used in dark mode). When `themeMode: ThemeMode.dark`, Flutter uses `darkTheme` — the `theme` parameter is **completely ignored**.

This means if you pass a custom dark theme as `theme:` and set `themeMode: ThemeMode.dark`, **your custom theme is never rendered** — Flutter silently falls back to the regular `darkTheme`.

```dart
// WRONG — synthwaveTheme is NEVER rendered:
theme = AppTheme.synthwaveTheme;
themeMode = ThemeMode.dark;
// darkTheme: AppTheme.darkTheme (from MaterialApp) — regular dark theme shows instead!

return MaterialApp(
  theme: theme,                            // ← synthwave sits here (ignored in dark mode)
  darkTheme: AppTheme.darkTheme,           // ← regular dark theme renders instead
  themeMode: themeMode,                    // ← ThemeMode.dark uses darkTheme
);

// RIGHT — put custom dark themes in the darkTheme slot:
theme = AppTheme.lightTheme;
darkTheme = AppTheme.synthwaveTheme;
themeMode = ThemeMode.dark;

return MaterialApp(
  theme: theme,                            // ← light theme (unused)
  darkTheme: darkTheme,                    // ← synthwave renders!
  themeMode: themeMode,
);
```

**How to structure multi-theme apps safely:**

Declare BOTH `theme` and `darkTheme` as local variables in the switch/if-else block. Every case must set both. This forces you to think about which slot each theme belongs in:

```dart
final ThemeData theme;
final ThemeData darkTheme;
final ThemeMode themeMode;

switch (settings.readingMode) {
  case ReadingMode.day:
    theme = AppTheme.lightTheme;
    darkTheme = AppTheme.darkTheme;
    themeMode = ThemeMode.light;
    break;
  case ReadingMode.night:
    theme = AppTheme.lightTheme;
    darkTheme = AppTheme.darkTheme;
    themeMode = ThemeMode.dark;
    break;
  case ReadingMode.amoled:
    theme = AppTheme.lightTheme;
    darkTheme = AppTheme.amoledTheme;
    themeMode = ThemeMode.dark;
    break;
  case ReadingMode.synthwave:
    theme = AppTheme.lightTheme;
    darkTheme = AppTheme.synthwaveTheme;
    themeMode = ThemeMode.dark;
    break;
}

return MaterialApp(
  theme: theme,
  darkTheme: darkTheme,
  themeMode: themeMode,
);
```

**Rule of thumb:** `theme` slot = always light themes. `darkTheme` slot = always dark themes. Never put a dark theme in the `theme` slot expecting it to work with `ThemeMode.dark` — it won't.

### CRITICAL PITFALL: Material 3 surfaceTintColor Purge

Material 3 adds a **tinted surface overlay** on app bars, dialogs, bottom sheets, and cards by default. The tint color is derived from the `ColorScheme.primary` — for purple themes (`#8F00FF`), this overlay creates a visible blue-ish/purple haze on top of your carefully-chosen surface colors.

**Every affected component must explicitly declare `surfaceTintColor: Colors.transparent`:**

```dart
appBarTheme: AppBarTheme(
  surfaceTintColor: Colors.transparent,  // ← stops M3 tint overlay
  backgroundColor: Color(0xFF0A011A),
),
dialogTheme: DialogThemeData(
  surfaceTintColor: Colors.transparent,  // ← stops M3 tint overlay on dialogs
  backgroundColor: Color(0xFF240037),
),
```

Without this, the app bar gets a purple veil that clashes with the dark background, and dialogs look muddy. Override it on ANY component that accepts a `surfaceTintColor` parameter when building a custom dark theme.

**Detection:** If your purple/amber/green custom theme looks "washed out" or has a colored haze on surfaces, `surfaceTintColor` is the culprit. Try setting it to `Colors.transparent` and see if the true surface colors snap into place.

### PITFALL: home_widget + AGP Version Tension

`home_widget 0.9.x` depends on `glance-appwidget:1.3.0-alpha01` requiring compileSdk 37 + AGP 9.1.0+. Upgrading AGP to 9.x cascades: remove `kotlin-android` plugin, Gradle 9.3.1+, new DSL issues with Flutter plugin.

**Fix (no AGP upgrade):** Use `home_widget:0.7.0` — depends on `glance-appwidget:1.0.0`, works with AGP 8.11.1 + SDK 36. Also set `android.disableAarMetadataCheck=true` in `android/gradle.properties` as a safety net.

**Detection:** "requires Android Gradle plugin 9.1.0 or higher" or "requires compileSdk 37" in the AAR metadata check.

### CRITICAL: Android 15 RemoteViews Widget Crash — Two Fixes

When widgets crash on Android 15 with "Problem loading widget", two separate issues need fixing:

**Fix 1: `HomeWidgetLaunchIntent.getActivity()` removed API**

`HomeWidgetLaunchIntent.getActivity()` calls `ActivityOptions.pendingIntentBackgroundActivityStartMode`, removed in Android 15 — throws `NoSuchMethodError`. Replace with manual `PendingIntent.getActivity()` in all 4 Kotlin provider files:

```kotlin
// WRONG — crashes on Android 15:
val launchIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

// RIGHT:
val intent = Intent(context, MainActivity::class.java).apply {
    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
}
val pendingIntent = PendingIntent.getActivity(
    context, 0, intent,
    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
)
views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
```

**Fix 2: `<View>` elements banned in RemoteViews**

Android 15 RemoteViews only allows widget-safe classes: `TextView`, `ImageView`, `LinearLayout`, `FrameLayout`, `RelativeLayout`, `Button`, `ImageButton`, `Chronometer`. Plain `<View>` and custom views throw `InflateException`. Replace all `<View>` dividers and fill bars with `<TextView>`:

```xml
<!-- WRONG — crashes Android 15: -->
<View android:layout_width="match_parent" android:layout_height="1dp" android:background="#8F00FF" />

<!-- RIGHT: -->
<TextView android:layout_width="match_parent" android:layout_height="1dp" android:background="#8F00FF" android:text="" />
```

**Detection:** Widget shows "Problem loading widget" toast. Check logcat: `adb logcat -s WidgetProvider | grep -i "RemoteViews\|InflateException\|NoSuchMethod"`.

**Applies to:** All 4 provider files (QuickToggle, XpSummary, StatSnapshot, Challenges) when using `home_widget 0.7.0`.

### Theme-Aware Home Screen Widgets

For widgets that recolor to match the app's selected theme (light/dark/synthwave etc.):

**Architecture:**
1. **Dart side** pushes the current theme name to widget SharedPreferences via `HomeWidget.saveWidgetData()`
2. **Kotlin side** reads the theme from `widgetData.getString("oh_widget_theme", "light")` and applies matching colors
3. **ThemeNotifier.setTheme()** calls `WidgetDataService.pushAll(db, themeName: mode.name)` so widgets update immediately on theme switch
4. **`_pushTheme()`** saves the theme key AND triggers `HomeWidget.updateWidget()` on every widget provider

**WidgetThemeUtils.kt** — centralized color set + background drawable resolver:

```kotlin
object WidgetThemeUtils {
  const val THEME_SYNTHWAVE = "synthwave"
  const val THEME_DARK = "dark"
  const val THEME_LIGHT = "light"

  data class WidgetColors(
    val cardBg: Int, val border: Int, val titleAccent: Int,
    val textPrimary: Int, val textSecondary: Int, val textMuted: Int,
    val dividerLine: Int, val xpBarFill: Int, val xpBarBg: Int,
    val dateText: Int, val completedText: Int,
  )

  fun getColors(themeName: String): WidgetColors {
    return when (themeName) {
      THEME_SYNTHWAVE -> WidgetColors(/* synthwave colors */)
      THEME_DARK -> WidgetColors(/* dark colors */)
      else -> WidgetColors(/* light theme defaults */)
    }
  }

  fun getBackgroundResource(themeName: String): Int = when (themeName) {
    THEME_SYNTHWAVE -> R.drawable.widget_bg_synthwave
    THEME_DARK -> R.drawable.widget_bg_dark
    else -> R.drawable.widget_bg_light
  }

  fun applyCardBackground(views: RemoteViews, containerId: Int, themeName: String) {
    views.setInt(containerId, "setBackgroundResource", getBackgroundResource(themeName))
  }
}
```

**XML layout rules for themeable widgets:**
- Remove `android:background="@drawable/..."` from root containers — set programmatically via `setBackgroundResource`
- Add `android:id` to EVERY element that needs color control: dividers, headers, bar backgrounds, containers
- Set neutral defaults (`#FFFFFFFF` for text, `#33FFFFFF` for dividers) — Kotlin overrides them all
- Layouts must use only widget-safe classes: `TextView`, `LinearLayout`, `FrameLayout`

**Per-theme background drawables** — 3 files, one per theme, each with theme-appropriate fill + border + same corner radius so card shape stays consistent.

**Per-provider invocation pattern (in onUpdate):**
```kotlin
val themeName = widgetData.getString("oh_widget_theme", "light") ?: "light"
val colors = WidgetThemeUtils.getColors(themeName)
val views = RemoteViews(context.packageName, R.layout.widget_xp_summary).apply {
  WidgetThemeUtils.applyCardBackground(this, R.id.widget_xp_container, themeName)
  setTextColor(R.id.xp_level, colors.titleAccent)
  setTextViewText(R.id.xp_progress, "$totalXp / $xpToNext XP")
  setTextColor(R.id.xp_progress, colors.textPrimary)
  setInt(R.id.xp_bar_fill, "setBackgroundColor", colors.xpBarFill)
  setTextColor(R.id.xp_streak, colors.textSecondary)
  // ... for all text, divider, and background elements
}
```

**Dart side wiring:**
```dart
// ThemeNotifier.setTheme(): save + push theme to widgets
Future<void> setTheme(AppThemeMode mode) async {
  state = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode.name);
  final db = LocalDatabaseService();
  await db.init();
  await WidgetDataService.pushAll(db, themeName: mode.name);
}
```

**PITFALL:** The background callback (widget tap → Dart code) also needs to read the saved theme and pass it: `final themeName = prefs.getString('theme_mode'); await pushAll(db, themeName: themeName);`

**PITFALL:** Always default to `"light"` in Kotlin when theme key is missing (first app launch before theme data is pushed).

**PITFALL:** Each theme change needs to update ALL widget providers even if data hasn't changed — the theme push saves the name AND calls `updateWidget()` on each provider.

**PITFALL:** The `_pushTheme()` method is separate from regular data pushes. Regular pushes pass theme name as optional; ThemeNotifier triggers `_pushTheme` which refreshes widgets without re-pushing all data.

**PITFALL:** Passing theme callbacks (`onTapTheme`) through widget trees fails when `AnimatedSwitcher` + `IndexedStack` nesting breaks `Navigator.of(context)` resolution. The callback captures the parent context but the route gets pushed from a disconnected widget subtree.

**FIX:** Make ThemeManager a proper singleton:

```dart
class ThemeManager extends ChangeNotifier {
  static ThemeManager? _instance;
  static ThemeManager get instance {
    _instance ??= ThemeManager._();
    return _instance!;
  }
  
  ThemeManager._() { /* init */ }
  factory ThemeManager() => instance;
  
  Future<void> setTheme(AppThemeType type) async { /* ... */ }
}
```

Then any screen can push the theme selector and apply changes directly:
```dart
void _openThemeSelector(BuildContext context) {
  Navigator.of(context).push<AppThemeType>(
    MaterialPageRoute(builder: (_) => ThemeSelectorScreen(...)),
  ).then((result) {
    if (result != null) ThemeManager.instance.setTheme(result);
  });
}
```

### Pattern B: Riverpod 3.x `Notifier` (Preferred for Riverpod apps)

Use when your app already uses Riverpod — avoids a second state management layer. This pattern uses a **single `theme` parameter** in `MaterialApp` (no `theme`/`darkTheme` slot confusion), with the active theme provided via a Riverpod `Provider<ThemeData>`.

**Architecture:**
- `AppTheme` class: static list of `ThemeData`, each built from a `_buildTheme()` helper that takes all color parameters
- `ThemeNotifier` extends `Notifier<int>` (Riverpod 3.x — NOT `StateNotifier`, which was removed in v3)
- `themeIndexProvider`: `NotifierProvider<ThemeNotifier, int>`
- `themeDataProvider`: derived `Provider<ThemeData>` that watches the index and returns `AppTheme.get(index)`
- **Backward-compatible static colors:** maintain a legacy `FlamingoColors` class whose `static` fields update via `syncFrom(cs)` whenever the theme changes

**CRITICAL: Riverpod 3.x drops `StateNotifier`.** Use `Notifier` + `NotifierProvider` instead:

```dart
class ThemeNotifier extends Notifier<int> {
  @override
  int build() {
    _load();  // async load from SharedPreferences
    return AppTheme.defaultIndex;
  }

  Future<void> setTheme(int index) async {
    state = index.clamp(0, 3);
    _apply(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_key', index);
  }

  void _apply(int index) {
    final cs = AppTheme.get(index).colorScheme;
    FlamingoColors.syncFrom(cs);  // update legacy static colors
  }
}

final themeIndexProvider = NotifierProvider<ThemeNotifier, int>(ThemeNotifier.new);
final themeDataProvider = Provider<ThemeData>((ref) {
  return AppTheme.get(ref.watch(themeIndexProvider));
});
```

**App wiring (no darkTheme slot needed — single theme param):**

```dart
class App extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeDataProvider);
    FlamingoColors.syncFrom(theme.colorScheme);
    return MaterialApp.router(
      theme: theme,           // ← single slot, all themes go here
      routerConfig: router,
    );
  }
}
```

**ThemeData builder pattern (avoids slot confusion):**

```dart
class AppTheme {
  static List<ThemeData> get _themes => [_dark, _light, _synthwave84];
  static ThemeData get(int index) => _themes[index.clamp(0, 2)];

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primaryColor,
    required Color secondaryColor,
    required Color surfaceColor,
    // ... all color parameters
  }) => ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: primaryColor,
      surface: surfaceColor,
      // ...
    ),
    // appBarTheme, cardTheme, textTheme, etc. all set here
  );

  static final ThemeData _dark = _buildTheme(/* dark params */);
  static final ThemeData _light = _buildTheme(/* light params */);
  static final ThemeData _synthwave84 = _buildTheme(/* synthwave params */);
}
```

**PITFALL: FlamingoColors.syncFrom() — backward compat for legacy screens.**

When migrating existing screens that hardcode static colors like `FlamingoColors.scaffoldBg`, don't refactor every file. Instead, keep the static class and call `syncFrom()` on every theme change:

```dart
class FlamingoColors {
  static Color scaffoldBg = const Color(0xFF0A0012); // default (theme 0)
  static Color primary = const Color(0xFFFF69B4);
  // ... all colors as non-const static fields

  static void syncFrom(ColorScheme cs) {
    scaffoldBg = cs.surface;
    primary = cs.primary;
    text = cs.onSurface;
    muted = cs.onSurfaceVariant;
    // ... map every field
  }
}
```

This lets existing screens continue using `FlamingoColors.primary` without changes — the values update reactively when the theme switches. The `App` widget calls `syncFrom` in its build method, which runs every time the theme provider emits a new value.

**PITFALL: `const` keyword breaks when colors become dynamic.**

Once `FlamingoColors.X` goes from `static const` to `static` (non-const), **every `const` widget that references a FlamingoColors field becomes invalid**:

```dart
// WRONG — FlamingoColors.primary is no longer a compile-time constant:
const TextStyle(color: FlamingoColors.primary, fontSize: 16)
const Text('Hello', style: TextStyle(color: FlamingoColors.primary))

// RIGHT — drop the `const` keyword:
TextStyle(color: FlamingoColors.primary, fontSize: 16)
Text('Hello', style: TextStyle(color: FlamingoColors.primary))
```

This cascades to **any widget whose constructor arguments transitively reference FlamingoColors** — `const Padding`, `const SizedBox`, `const Center`, `const Column`, `const Row`, `const Icon`, `const Divider`, `const CircularProgressIndicator`, `const InputDecoration`, etc.

**Batch fix strategy:** Search for `const.*FlamingoColors` across all Dart files and remove the `const` keyword from any widget constructor whose arguments contain a FlamingoColors reference. Regex pattern across 17+ files is faster than file-by-file:

```
const (TextStyle|Text|Icon|Divider|SizedBox|Padding|Center|Column|Row|Expanded|CircularProgressIndicator|DecoratedBox|InputDecoration)\([^)]*FlamingoColors
→ drop the `const ` prefix, keep the rest
```

**PITFALL: Multi-line widget constructors** (like `const Text('LABEL',\n    style: TextStyle(...))`) won't be caught by single-line regex. For those, read the file and fix manually — the const keyword is on the parent widget, but the FlamingoColors reference is in its nested argument tree.

**Verification:** Run `dart analyze` after the batch fix. The `invalid_constant` errors should go to zero. Remaining `info`-level issues (style hints) are acceptable noise.

### Theme-Aware Home Screen Widgets

For full-screen interactive maps (star system maps, floor plans, territory maps):

```dart
InteractiveViewer(
  minScale: 0.5,
  maxScale: 3.0,
  constrained: false,
  boundaryMargin: const EdgeInsets.all(200),
  child: GestureDetector(
    onTapUp: (details) {
      final tapPos = details.localPosition;
      // Hit-test against pre-computed marker positions
      for (final entry in allPositions.entries) {
        if ((tapPos - entry.value).distance <= hitRadius) {
          _showDetail(context, entry.key);
          return;
        }
      }
    },
    child: CustomPaint(
      size: canvasSize,
      painter: MyPainter(stars, positions, ...),
    ),
  ),
)
```

Key points:
- Calculate marker positions ONCE in `build()`, pass them to the painter AND gesture handler
- Use a square canvas (`max(w, h)`) so zoom has room in both axes
- Pre-compute starfield positions with a seeded RNG so they don't flicker on repaint
- `constrained: false + boundaryMargin` lets the user pan freely beyond the canvas edge

## 4. Label Collision Detection for Maps

When placing text labels near markers on a map, nearby locations produce overlapping text. Implement collision detection in the painter:

```dart
final List<Rect> _drawnLabelBounds = [];

void _drawLabel(Canvas canvas, Offset markerPos, String text, ...) {
  // Try positions in order of preference
  final anchors = <Offset>[
    Offset(markerPos.dx - textW / 2, markerPos.dy + offset),  // below
    Offset(markerPos.dx - textW / 2, markerPos.dy - offset - textH),  // above
    Offset(markerPos.dx + offset, markerPos.dy - textH / 2),  // right
    Offset(markerPos.dx - offset - textW, markerPos.dy - textH / 2),  // left
    // ... additional positions
  ];

  Offset? chosen;
  for (final anchor in anchors) {
    final rect = Rect.fromLTWH(anchor.dx - pad, anchor.dy - pad, textW + pad*2, textH + pad*2);
    if (!_drawnLabelBounds.any((r) => r.overlaps(rect))) {
      chosen = anchor;
      break;
    }
  }
  
  chosen ??= anchors.first; // fallback
  _drawnLabelBounds.add(/* rect for chosen */);
  // Paint the text at chosen position
}
```

**Always clear `_drawnLabelBounds` at the start of `paint()`.**

## 5. Code-Generated Visuals (No Asset Images)

For apps that need ship/item visuals without bloating the APK with images, generate visuals from code:

### Entity Avatar (Manufacturer-Colored)
```dart
class EntityAvatar extends StatelessWidget {
  final String entityName;
  
  Widget build(BuildContext context) {
    final style = _manufacturerStyles[entityName.toLowerCase()];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [style.primary, style.secondary]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(style.icon, color: style.primary),
    );
  }
}
```
Each manufacturer gets a distinct color scheme + icon. Map names case-insensitively.

### Component Avatar (Category Icon + Manufacturer Color)
For items that have both a category (weapon/shield/power plant) and a manufacturer, use **two dimensions** of styling:

- **Category** determines the icon: weapon crosshair, shield, bolt, snowflake, speedometer, radar
- **Manufacturer** determines the color scheme (Behring=red, Klaus & Werner=orange, Juno=cyan, etc.)

```dart
class ComponentAvatar extends StatelessWidget {
  final String category;     // 'weapons', 'shieldgenerator', etc.
  final String manufacturer; // 'Behring', 'Juno Starwerk', etc.
  
  Widget build(BuildContext context) {
    final catIcon = _categoryIcons[category] ?? Icons.build;
    final mfrColor = _manufacturerColor(manufacturer) ?? Colors.grey;
    // Render colored container with category icon
  }
}
```

This dual-axis approach gives every item a unique, recognizable visual without any image files.

### Hero Banner
Full-width gradient banner for detail screens with entity name + type badge + price. When actual photos are available (e.g., downloaded ship thumbnails), the hero can show the photo with a dark overlay gradient instead of the gradient, while keeping the info overlay consistent.

## 6. Offline Persistence with SharedPreferences (ChangeNotifier Pattern)

For apps that need fully offline persistence without a server or SQLite, use `SharedPreferences` + a `ChangeNotifier` service:

```dart
class LocalDataService extends ChangeNotifier {
  static final LocalDataService _instance = LocalDataService._();
  factory LocalDataService() => _instance;
  LocalDataService._();

  List<ItemData> _items = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('my_key');
    if (raw != null) {
      _items = (json.decode(raw) as List)
          .map((e) => ItemData.fromJson(e))
          .toList();
    }
  }

  Future<void> _persist(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
  }

  /// PITFALL: removeWhere returns void, not bool.
  Future<bool> deleteItem(String id) async {
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length < before) {
      await _persist('my_key', _items.map((e) => e.toJson()).toList());
      notifyListeners();
      return true;
    }
    return false;
  }
}
```

### Provider Wrapper Pattern

```dart
class MyNotifier extends Notifier<MyData> {
  final _db = LocalDataService();

  @override
  MyData build() {
    _initDb();
    return state;
  }

  Future<void> _initDb() async {
    await _db.init();
    _db.addListener(_onDbChanged);
    _refreshFromDb();
  }

  void _onDbChanged() => _refreshFromDb();

  void _refreshFromDb() {
    state = MyData(
      items: _db.items.map(_toUiModel).toList(),
      isLoading: false,
    );
  }
}
```

### HTTP-to-Offline Migration

When converting an app from HTTP-server-dependent to fully offline:

1. **Identify the API surface** — List every endpoint the app calls.
2. **Create local service** — Same method signatures as the old API client, same model structure.
3. **Build the engine** — Implement XP/streak/achievement/level logic in pure Dart.
4. **Swap the provider** — Call `_localService.init()` and subscribe via `addListener()`.
5. **Remove HTTP dependency** — Delete `http` from pubspec.yaml, remove old API imports.
6. **Migrate dialogs** — Stateful dialogs that created ApiClient() directly should call the local service singleton instead. No WidgetRef needed.
7. **Reset pattern** — For clean-slate: clear all SharedPreferences keys, reinit with defaults, notify.

**Key gotchas:**
- **Completion models differ** — Old HTTP response had flat fields (achievementXp). New model has lists (newAchievements). Use `.fold()` to sum.
- **`removeWhere` returns void** — Compare `.length` before/after.
- **`ChangeNotifier` needs listeners** — Provider must subscribe or it won't react.
- **Reset owned by DB service** — Let the DB service own reset logic, not the provider.

## 7. Bundling Reference Data as JSON Assets

For fully offline apps, bundle reference data as JSON files in `assets/data/`:

1. Scrape/download data from API → save as JSON
2. Register in `pubspec.yaml` under `flutter:` → `assets:`
3. Load at app startup via a singleton service
4. Reference data never changes — no refresh logic needed

```dart
class ReferenceDatabase {
  static final _instance = ReferenceDatabase._();
  factory ReferenceDatabase() => _instance;
  
  List<Map<String, dynamic>> _items = [];
  
  Future<void> load() async {
    final json = await rootBundle.loadString('assets/data/myfile.json');
    _items = List<Map<String, dynamic>>.from(json.decode(json));
  }
}
```

Preload in app initState alongside other services.

### Data-Driven Encyclopedia / Codex Pattern

For features with **multiple categories of entries** (encyclopedias, game codexes, species databases, historical compendiums), use a universal entry model + hub/category/detail page architecture:

**JSON Generation Technique (Large Content Sets)**

When the content is too large to write by hand or generate directly as raw JSON, use Python via `execute_code` to script the generation. This is the preferred workflow for 50+ entry datasets:

1. **Write Python scripts** using `hermes_tools` (it can call `write_file`) or write directly with Python's `json.dump()` to generate valid JSON
2. **Split into part files** when content exceeds ~80K per script — each script writes a `partN.json`
3. **Merge with a final script** that reads all parts and writes a single `index.json`
4. **Structure matters:** `json.dump(part, output_file, indent=2, ensure_ascii=False)` guarantees valid output

```python
from hermes_tools import write_file
import json, os

categories = [
    { "id": "cat1", "title": "Category 1", "icon": "star",
      "entries": [ /* 40+ detailed entries */ ] }
]

with open('assets/data/myproject/part1.json', 'w') as f:
    json.dump({"categories": categories}, f, indent=2, ensure_ascii=False)

# Later, merge:
merged = {"categories": []}
for p in ['part1.json', 'part2.json', ...]:
    with open(f'assets/data/myproject/{p}') as f:
        merged['categories'].extend(json.load(f)['categories'])

with open('assets/data/myproject/index.json', 'w') as f:
    json.dump(merged, f, indent=2, ensure_ascii=False)
```

**PITFALL:** JSON has no trailing commas. Python's `json.dump()` handles this automatically — always use it rather than `f.write()` with template strings.
**PITFALL:** Escape special characters in descriptions. `json.dump(ensure_ascii=False)` preserves Unicode but escapes control characters.
**PITFALL:** When descriptions contain multi-paragraph text with quotes and apostrophes, JSON requires escaping — Python `json.dump()` handles this. Never write JSON manually for >10 entries.

**Architecture:**
```

lib/features/my_encyclopedia/
│   └── my_encyclopedia_models.dart  (Category + Entry models)
└── presentation/
    ├── pages/
    │   ├── encyclopedia_hub_page.dart     (GridView of categories)
    │   ├── encyclopedia_category_page.dart (Searchable list of entries)
    │   └── encyclopedia_detail_page.dart   (Scrollable detail view)
    └── widgets/
        └── category_card.dart
```

**Universal Entry Model** — one model for ALL categories, with optional fields that only apply to certain entry types (foundedBy for organizations, crossType for symbols, etc.). This avoids a proliferation of models:

```dart
class EncyclopediaEntry {
  final String id, title, subtitle, description, category;
  final String? imageUrl, period, location;      // universal
  final String? foundedBy, yearFounded, headquarters, adherents;  // orgs/denominations
  final String? crossType, origin;                // symbols/crosses
  final List<String> keyFigures, keyEvents, tags;
  // fromJson / toJson with null-safe parsing
}
```

**JSON Structure** — single file or split files merged at load time:
```json
{
  "categories": [
    { "id": "cat1", "title": "...", "icon": "star", "entries": [...] }
  ]
}
```

**Hub Page** — 2-column GridView of category cards, each showing icon, title, entry count. Taps navigate to category page.

**Category Page** — takes a Category object, shows SearchBar filtering by title/subtitle/tags, ListView of entries with period badges.

**Detail Page** — takes an Entry, conditionally shows denomination fields, cross fields, key figures (chips), key events (bullets), tags (wrap chips). Uses `Theme.of(context)` throughout — no hardcoded colors.

**Pitfalls:**
- **JSON can be huge** (100K+ entries). Split into multiple files if needed and merge in the `load()` method.
- **`rootBundle.loadString` is synchronous on the main isolate** — for very large JSON, consider `compute()` to parse off-thread.
- **Icon mapping** — use a helper function mapping string names to `IconData` rather than storing icon data in JSON.
- **Image quality standard — EVERY entry gets its own dedicated image.** The user will notice and call out shared placeholder images (e.g., 45 entries sharing the same 4KB `latin_cross.jpg`). Each entry needs a unique, real image. Minimum viable is 8KB — smaller files are icons, not photos. Fall back to a category-level image via file copy if no dedicated image can be sourced.

## 8. Retro CRT Visual Effects with CustomPainter (No Shaders)

For synthwave/CRT aesthetics that appear across multiple projects (GridOS, SC Synthesis, open_habit), use a `CustomPainter` with **zero custom shaders** — some GPU backends crash on `RadialGradient` shaders on Android. Build effects from plain `Canvas` ops.

### Safe CRT Painter Pattern

```dart
class CrtBackgroundPainter extends CustomPainter {
  final Color accent;
  final Color accent2;
  final Color bgColor;
  final double scanlineDensity;
  final double glowIntensity;
  final double vignetteStrength;
  final double time;  // from AnimationController.value * 10

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pulse = math.sin(time * 1.8) * 0.15 + 0.85; // breathing animation

    // 1. Deep background
    canvas.drawRect(rect, Paint()..color = bgColor);

    // 2. Horizontal scanlines with pulse
    final step = (scanlineDensity * 1.5).round().clamp(1, 20);
    for (double y = rect.top; y < rect.bottom; y += step) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y),
        Paint()..color = accent.withValues(alpha: 0.12 * glowIntensity * pulse));
    }

    // 3. Vertical grid (subtle)
    if (scanlineDensity > 1.5) {
      for (double x = rect.left; x < rect.right; x += 90) {
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom),
          Paint()..color = accent2.withValues(alpha: 0.05));
      }
    }

    // 4. Vignette — concentric circles (SAFE, no RadialGradient shader)
    final center = Offset(size.width / 2, size.height / 2);
    final maxDist = size.width > size.height ? size.width * 0.5 : size.height * 0.5;
    final layers = (8.0 * vignetteStrength).round().clamp(1, 20);
    for (int i = 0; i < layers; i++) {
      final t = i / layers;
      final alpha = (40.0 * (1.0 - t) * vignetteStrength).round().clamp(0, 255);
      canvas.drawCircle(center, maxDist * (0.6 + t * 0.4),
        Paint()..color = Colors.black.withValues(alpha: alpha / 255.0));
    }

    // 5. Chrome borders (chromatic aberration edge effect)
    canvas.drawRect(rect.deflate(1.0),
      Paint()..color = const Color(0xFFFF2850)..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawRect(rect.inflate(1.5),
      Paint()..color = const Color(0xFF00DCFF)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 6. Neon border with breathing
    final ba = (200.0 * glowIntensity * pulse).round().clamp(0, 255);
    canvas.drawRect(rect,
      Paint()..color = accent.withValues(alpha: ba / 255.0)..style = PaintingStyle.stroke..strokeWidth = 3.0);
  }
}
```

**Key rules:**
- **No `RadialGradient` shader** — crashes on some Android GPU combos. Use concentric `drawCircle` calls for vignette.
- **No custom `Shader` objects** — not guaranteed across devices.
- **`math.sin()` not `double.sin()`** — extension method may not be in scope. Import `dart:math` and use `math.sin()` explicitly.
- **Animate via `ListenableBuilder`** — see animation pattern below.
- **Clamp scanline step** with `.clamp(1, 20)` to prevent divide-by-zero or invisible lines.
- **Use `withValues(alpha:)`** instead of deprecated `withOpacity()`.

### Animation Pattern (Flutter 3.41+)

```dart
// In State with TickerProviderStateMixin:
late AnimationController _crtAnimCtrl;

@override
void initState() {
  super.initState();
  _crtAnimCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();
}

// Use ListenableBuilder (NOT AnimatedBuilder):
home: ListenableBuilder(
  listenable: _crtAnimCtrl,
  builder: (context, _) {
    return MyScreen(crtTime: _crtAnimCtrl.value * 10.0);
  },
)
```

**PITFALL:** `AnimatedBuilder` was added in Flutter 3.22 but deprecated in 3.41 in favour of `ListenableBuilder`. `ListenableBuilder` has been available since earlier versions and is cross-version-safe.

### Deprecation Migration Table

| Deprecated | Replacement |
|---|---|
| `color.withOpacity(x)` | `color.withValues(alpha: x)` |
| `DropdownButtonFormField(value: ...)` | `DropdownButtonFormField(initialValue: ...)` |
| `AnimatedBuilder(listenable: ...)` | `ListenableBuilder(listenable: ...)` |
| `double.sin()` / `double.cos()` | `math.sin(double)` / `math.cos(double)` (import `dart:math`) |
| `Switch(activeColor:)` | `Switch(activeThumbColor:)` |

## 9. flutter_rust_bridge Android Native Library Setup

When a Flutter app uses flutter_rust_bridge v2, the Rust core must be cross-compiled to Android shared libraries and placed in the correct JNI directory. The generated `ioDirectory` in `frb_generated.dart` (`../rust/core/target/release/`) is for desktop dev only — Android loads from `lib/<abi>/` inside the APK.

### Prerequisites

```bash
# Install Android Rust targets (one-time)
rustup target add aarch64-linux-android armv7-linux-androideabi

# Install cargo-ndk (one-time)
cargo install cargo-ndk
```

The Android NDK must be installed (via Android Studio SDK Manager or sdkmanager). NDK path is auto-detected from `local.properties` generated by `flutter build`.

### Cargo.toml — Enable cdylib

The Rust core crate **must** produce a shared library:

```toml
[lib]
crate-type = ["lib", "cdylib"]
```

Without `cdylib`, `cargo-ndk` produces nothing and `cargo ndk` errors with "No usable artifacts produced by cargo".

### Build Native Libraries

```bash
cd rust/core
export ANDROID_NDK_HOME=/path/to/ndk/28.x.xxxxxx

cargo ndk \
  -t arm64-v8a \
  -t armeabi-v7a \
  -o ../mobile/android/app/src/main/jniLibs \
  build --release
```

This produces:
- `jniLibs/arm64-v8a/libgridos_core.so`
- `jniLibs/armeabi-v7a/libgridos_core.so`

### JDK Version Constraint

AGP 8.11.1 + Gradle 8.14 does NOT work with JDK 26 or JDK 25. Use **JDK 21**:

```bash
export JAVA_HOME=/path/to/jdk-21
flutter build apk --release
```

Signs of JDK mismatch: Gradle fails instantly (<500ms) with the error message being just the JDK version number (e.g. `26.0.1` or `25.0.3`). No stack trace, no explanation.

### Verify Library is in APK

```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep gridos_core
```

Expected output:
```
lib/arm64-v8a/libgridos_core.so
lib/armeabi-v7a/libgridos_core.so
```

## 10. Fixed-Width CLI Table Parsing

CLI tools often output tables with fixed-width columns and no JSON flag. Parse them by measuring column positions from the header line:

```dart
List<HermesSession> _parseSessionList(String output) {
  final lines = output.split('\n');
  
  // Column positions measured from header:
  // "Title                            Preview       Last Active   ID"
  //  0                             33              74           88
  const titleEnd = 32;
  
  for (final line in lines) {
    final trimmed = line.trimRight();
    if (trimmed.startsWith('Title')) continue;                    // skip header
    if (trimmed.startsWith('─') || trimmed.startsWith('-')) continue; // skip separator
    
    final title = trimmed.substring(0, titleEnd + 1).trim();
    final id = trimmed.substring(88).trim();
    sessions.add(HermesSession(id: id, title: title, ...));
  }
}
```

**PITFALL:** Splitting on `\s{2,}` (double spaces) seems smart but breaks when content within a column has consecutive spaces. Fixed-width substring extraction by position is the only reliable approach for CLI tables.

**PITFALL:** Don't call `.trim()` on the full line before extracting columns — that destroys positional alignment. Use `.trimRight()` to keep left alignment but drop trailing whitespace.

**PITFALL:** The separator line (dashes/em-dashes) is always the full page width, not individual column widths. Use the header line to measure column positions, not the separator.

## 11. Cross-Platform Terminal Detection

For launching a terminal emulator across platforms, build a `TerminalDetector` that checks common terminals in order:

```dart
class TerminalDetector {
  static Future<List<String>?> detect() async {
    if (Platform.isLinux) return _detectLinux();
    if (Platform.isMacOS) return _detectMacOS();
    if (Platform.isWindows) return _detectWindows();
    return null;
  }

  static Future<List<String>?> _detectLinux() async {
    // Check TERMINAL env var first (user preference)
    final termEnv = Platform.environment['TERMINAL'];
    if (termEnv != null) {
      final which = await _which(termEnv);
      if (which != null) return [which, '-e'];
    }
    
    // Ordered by preference — each terminal uses a different flag:
    // alacritty: -e, kitty: no flag, gnome-terminal: --, konsole: -e
    // foot: no flag, xfce4-terminal: -e, lxterminal: -e, xterm: -e
  }

  static Future<bool> launchInTerminal(List<String> command) async {
    final terminal = await detect();
    if (terminal == null) return false;
    // terminal = ['alacritty', '-e'], append command: ['alacritty', '-e', 'hermes']
    await Process.run(terminal[0], [...terminal.sublist(1), ...command]);
    return true;
  }
}
```

Platform-specific behavior:
- **Linux**: checks `$TERMINAL` env var, then common terminals via `which`, falls back to `x-terminal-emulator`
- **macOS**: checks iTerm2, Warp, falls back to `open -a Terminal`
- **Windows**: checks Windows Terminal (wt.exe), PowerShell (pwsh.exe), falls back to cmd.exe
- Uses `which` on Linux/macOS, `where` on Windows for binary discovery
- Returns null if no terminal found — caller should show a snackbar with the command to run manually

## 12. Desktop Window Lifecycle (PopScope + Close-to-Tray)

For Flutter desktop apps that should minimize to the system tray instead of quitting:

### Window Close Interception with PopScope

```dart
return PopScope(
  canPop: false,  // never allow normal back-navigation to close
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop) {
      trayService.hideWindow();  // minimize to tray
    }
  },
  child: Scaffold(
    // ... normal app body ...
  ),
);
```

**PITFALL: Launcher shortcuts cache the binary path.** After deploying a new build to `~/.local/bin/`, launcher shortcuts (Walker, Rofi, dmenu) may still show/launch the old version because they cache the `.desktop` file entries in memory. Run `pkill walker` (or the equivalent for your launcher) to force a cache refresh — Hyprland auto-restarts Walker on kill. Touching the `.desktop` file's mtime is NOT sufficient; the process must restart.

**PITFALL: Can't overwrite a running backend binary.** If the Rust backend is managed by systemd (`systemctl --user start hermes-wingman.service`), `cp` to `~/.local/bin/` fails with "Text file busy" because the OS locks the in-use ELF. Stop the service first, copy, then restart:

```bash
systemctl --user stop hermes-wingman.service
sleep 1
cp backend/target/release/hermes-wingman-backend ~/.local/bin/
systemctl --user start hermes-wingman.service
## Mobile Porting Patterns

When porting a desktop Flutter app (Hermes Wingman, agent GUIs, development tools) to mobile (Android/iOS), these patterns handle the platform differences.

### Architecture: Remote Backend Connection

On mobile, the Rust backend can't run locally. The app connects to a backend running on a desktop/server over the LAN:

```
Mobile App ──HTTP──→ Desktop Backend (port 9120)
```

**BackendService refactor:** Make the `_baseUrl` configurable. On mobile, `start()` just pings the remote — no process spawning, binary discovery, or port checking:

```dart
class BackendService extends ChangeNotifier implements HermesService {
  String _baseUrl = 'http://127.0.0.1:9120';
  bool _isRemote = Platform.isAndroid || Platform.isIOS;

  void setBaseUrl(String host, int port) { _baseUrl = 'http://$host:$port'; }

  Future<bool> start({Duration timeout = const Duration(seconds: 8)}) async {
    if (_isMobile) {
      // Mobile: just try to connect to the configured backend
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (await _checkHealth()) {
          setState(BackendConnectionState.connected);
          return true;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      setState(BackendConnectionState.failed);
      return false;
    }
    // Desktop: spawn binary, health-check, etc.
  }
}
```

### Conditional Platform Imports (system_tray Stub Pattern)

The `system_tray` package is desktop-only and will fail to compile on Android/iOS. Use Flutter's conditional import system to swap between a real implementation and a no-op stub:

**Stub file** `tray_service_stub.dart`:
```dart
import 'dart:ui' show VoidCallback;

class TrayService {
  VoidCallback? onShow, onQuit, onSetupWizard;
  Future<void> init() async {}
  void setTooltip(String tip) {}
  Future<void> hideWindow() async {}
  Future<void> showWindow() async {}
  Future<void> destroy() async {}
}
```

**In main.dart**, use Flutter's `if` directive per platform:
```dart
import 'services/tray_service_stub.dart'
  if (dart.linux) 'services/tray_service.dart'
  if (dart.macos) 'services/tray_service.dart'
  if (dart.windows) 'services/tray_service.dart';
```

The stub is the default. On desktop platforms, the real implementation replaces it at compile time. No runtime checks needed — the compiler picks the right file.

### Cross-Platform Settings Storage

Desktop apps typically use `Platform.environment['HOME']` for config files. On mobile, use `path_provider`:

```dart
static Future<String> get _settingsPath async {
  if (_isMobile) {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/wingman_settings.json';
  }
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
  return '$home/.hermes/wingman_settings.json';
}
```

**PITFALL:** `Platform.environment['HOME']` is null on Android/iOS in release mode. Always use `getApplicationDocumentsDirectory()` on mobile.

### Responsive Layout: Sidebar ↔ Bottom Nav

On mobile, a 68px sidebar with 10 vertical icon buttons doesn't fit. Use a `BottomNavigationBar` with a subset of tabs instead:

```dart
// Mobile shows a subset of navigation items
static const _mobileNavItems = <_NavItem>[
  _NavItem('Dashboard', Icons.dashboard, ''),
  _NavItem('Chat', Icons.chat, ''),
  _NavItem('Models', Icons.memory_outlined, ''),
  _NavItem('Sessions', Icons.chat_bubble_outline, ''),
  _NavItem('Settings', Icons.settings_outlined, ''),
];

// Map mobile nav indices to full screen indices
static const _mobileIndexMap = [0, 1, 2, 4, 5];
```

Use `IndexedStack` to preserve screen state across tab switches:
```dart
body: IndexedStack(
  index: effectiveIdx,
  children: _mobileIndexMap.map((i) => _screens[i]).toList(),
),
bottomNavigationBar: BottomNavigationBar(
  currentIndex: effectiveIdx,
  onTap: (i) => setState(() => _selectedIndex = _mobileIndexMap[i]),
  items: _mobileNavItems.map((item) => BottomNavigationBarItem(
    icon: Icon(item.icon, size: 20),
    label: item.label,
  )).toList(),
),
```

### Android Network Permissions

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application
    android:usesCleartextTraffic="true"  <!-- needed for HTTP (not HTTPS) backends -->
    ...>
```

Without `INTERNET` permission, all HTTP calls fail silently. Without `usesCleartextTraffic`, cleartext HTTP to local IPs is blocked by default on Android 9+.

### JDK Version Constraint for Android Builds

**CRITICAL:** Gradle 8.14 does NOT support JDK 25 or 26. Use **JDK 21**:

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
flutter build apk --release
```

Signs of JDK mismatch: Gradle fails instantly (<500ms) with the error message being just the JDK version number (`26.0.1` or `25.0.3`). No stack trace — just a bare version string. This cryptic format makes it look like a Flutter/Gradle config issue but the cause is always JDK version.

Check active JDK: `java -version`. Install JDK 21:
```bash
# Arch
sudo pacman -S jdk21-openjdk
# macOS (Homebrew)
brew install openjdk@21
# Ubuntu/Debian
sudo apt install openjdk-21-jdk
```

### Mobile Build Output

```bash
# Debug (141MB — includes symbols)
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
flutter build apk --debug

# Release (50MB — tree-shaken)
flutter build apk --release
```

Release builds tree-shake Material icons (99.5% reduction) and strip debug symbols. The release APK is the one to distribute.

### When to Use

| Scenario | Desktop-native | Mobile-remote |
|----------|---------------|---------------|
| Local development, no backend needed | Both work | Mobile connects to your dev machine |
| App needs local file/CLI access | ✓ Full | ❌ Backend must provide API endpoints |
| User has a server running 24/7 | Both work | ✓ Mobile connects from anywhere on LAN |
| App is a developer tool for own use | ✓ | ✓ Mobile is secondary convenience |

## System Tray Integration (Close-to-Tray)

For Flutter desktop apps that should **minimize to system tray instead of quitting**, use the `system_tray` package. The tray icon doubles as a background agent indicator — green when backend is healthy, shows tooltip with current model.

**On mobile, system_tray is unavailable.** Use the conditional import pattern (see Mobile Porting Patterns above) to provide a no-op stub.

### Dependencies

```yaml
dependencies:
  system_tray: ^2.0.3
```

The `SystemTray` class manages the tray icon and context menu. The `AppWindow` class controls the native window (show/hide/close). Initialize both early:

```dart
final tray = SystemTray();
final window = AppWindow();

await tray.initSystemTray(
  iconPath: 'assets/icons/app.png',
  toolTip: 'My App',
);
```

### Icon Path Resolution

The icon file must be resolvable at runtime — this is NOT a Flutter asset that gets archived. The file must exist on disk at the given relative or absolute path. Use a search pattern to handle different environments:

```dart
Future<String> _findIcon() async {
  final candidates = [
    'assets/icons/app.png',       // flutter run (project root)
    'usr/bin/assets/icons/app.png', // from AppRun cwd
    '../icons/app.png',            // macOS .app bundle
    '/usr/share/icons/hicolor/256x256/apps/app.png', // system install
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return File(path).absolute.path;
  }
  return '';  // no icon found — tray may not appear
}
```

### When to Use

- **Apps that run in the background** (agent UIs, monitoring tools, music players) — close should minimize, not exit
- **Apps whose backend keeps running** — killing the Flutter window shouldn't orphan a background server process
- **AppImage / portable apps** — the user may keep the app open for quick re-access

### When NOT to Use

- **Single-window productivity apps** (calculators, note-takers) — close should exit cleanly
- **Apps with complex state** that must be properly cleaned up on exit — add an "Exit" confirmation flow instead

### Root Layout: Filling the Entire Window

When wrapping a sidebar + content layout in a `Container(color: ...)` → `Row([sidebar, Expanded(content)])`, the Container with only `color` set does NOT force full-window fill. In Flutter desktop (especially under tiling WMs like Hyprland), the `Container` sizes to its child's natural dimensions — the `Row` sizes to its children, and if nothing explicitly demands full height, the content area shrink-wraps rather than filling the window.

**Fix: Add `width: double.infinity, height: double.infinity` to the root Container:**

```dart
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop) trayService.hideWindow();
  },
  child: Container(
    color: scheme.scaffoldBackground,
    width: double.infinity,
    height: double.infinity,  // <-- force full-window fill
    child: Row(
      children: [
        Container(width: 68, /* sidebar */),
        Expanded(child: _screens[_selectedIndex]),
      ],
    ),
  ),
)
```

**Why this works:** `double.infinity` tells Flutter "be as big as possible given parent constraints." The parent (`PopScope`) passes down the full window constraints from the `MaterialApp` route, so the Container resolves to the full window size. The `Row` + `Expanded` inside then distributes correctly: fixed-width sidebar, remaining space to content.

**PITFALL:** Without this fix, the window renders correctly on some platforms (macOS) but fails on others (Linux/tiling WMs). Always verify root layout fill on Linux desktop — a `Container(color: ...)` with no explicit size is a latent bug wherever the window manager doesn't force-fill child windows.

**Verification pattern:** Add explicit size constraints to the root Container. If the content already fills the window without them, the fix is a no-op. If not, this is the only change needed.

## 13. In-App Chat via Subprocess (hermes --oneshot)

For embedding a CLI agent's chat directly in a Flutter app (no PTY needed), use `Process.run` with the tool's single-query flag:

```dart
Future<void> _sendMessage(String text) async {
  setState(() => _sending = true);

  final args = ['--oneshot', text.trim()];
  if (_lastSessionId != null) {
    args.insertAll(0, ['--resume', _lastSessionId!]);  // continue conversation
  }

  try {
    final result = await Process.run('hermes', args);  // NO runInShell — breaks --oneshot
    final response = (result.stdout as String).trim();
    
    setState(() {
      _messages.add(ChatMessage(text: response, isUser: false));
      _sending = false;
    });
  } catch (e) {
    setState(() => /* show error */);
  }
}
```

**Chat bubble architecture:**
- User messages: right-aligned, primary-tinted bubble, "U" avatar
- AI messages: left-aligned, surface/card bubble, "H" avatar
- Error/system messages: left-aligned with error styling or italic muted
- Auto-scroll to bottom on new messages via `ScrollController.animateTo()`
- Session tracking: extract session ID from stderr via regex, store for `--resume`
- Input bar: TextField with auto-expand (maxLines: 5), send on Enter or button tap, disabled while sending

**PITFALL:** `Process.run` has no `timeout` parameter — long-running model responses will block. Set a Dart Timer if you need timeout behavior.

**PITFALL:** `--oneshot` sends a single turn. The model has limited or no tool access in this mode — responses are text-only. For full tool-calling, launch the CLI in a terminal instead.

## 13. Persistent User Preferences (Local JSON File)

For persisting lightweight user preferences (model favorites, theme choice, recent items), use a local JSON file in the app's data directory:

```dart
class FavoritesStore {
  static Future<String> _getPath() async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/.app/favorites.json';
  }

  static Future<void> save(List<String> items) async {
    final path = await _getPath();
    await File(path).writeAsString(jsonEncode({
      'favorites': items.take(5).toList(),  // cap at 5
      'updated_at': DateTime.now().toIso8601String(),
    }));
  }
  
  static Future<List<String>> load() async {
    // Parse JSON, return list, gracefully handle missing file/corrupt JSON
  }
  
  static Future<void> toggle(String item) async {
    // If already a favorite, remove. If not, add (capped at 5).
    // Oldest favorite is evicted first when cap is reached.
  }
}
```

**PITFALL:** Always wrap file operations in try/catch — the file may not exist on first launch, or the JSON could be corrupted.

**PITFALL:** Cap the favorites list so the UI doesn't overflow and the file stays small. 5 is a good default.

## 14. Navigation Callback for Cross-Screen Navigation

When a screen needs to trigger navigation to another tab in a sidebar/menu layout, pass a callback instead of using `findAncestorStateOfType`:

```dart
class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});
}

// In parent (MainShell with sidebar):
_screens = [
  DashboardScreen(onNavigate: (i) => setState(() => _selectedIndex = i)),
  const ChatScreen(),
  const ModelsScreen(),
  // ...
];

// In DashboardScreen:
widget.onNavigate?.call(4);  // jump to tab index 4
```

**PITFALL:** `findAncestorStateOfType<_PrivateState>()` breaks because private types in one file can't be referenced from another. Always use callbacks for cross-screen navigation.

**PITFALL:** Tab indices shift when screens are added/removed. Keep a comment mapping indices to screen names wherever callbacks are used.

## 15. Android Platform Channel: Dart ↔ Native Bridges

When a Flutter feature needs Android-only hardware access (battery sensors, ringtones, camera zoom), the only path is a `MethodChannel` bridge *inside `MainActivity.kt`*, called from Dart via `const MethodChannel('name').invokeMethod('method')`. Default Flutter/Dart has zero access to Android system APIs; relying on pub.dev packages alone will leave gaps in sensor exposure.

### Channel Declaration (Kotlin, `MainActivity.kt`)

```kotlin
private val BATTERY_CHANNEL = "battery_thermometer/temp"
private val TIMER_SOUND_CHANNEL = "timer_sound_player"

override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Battery temperature
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
        .setMethodCallHandler { call, result ->
            if (call.method == "getTemp") {
                val temp = getBatteryTemperatureC()
                if (temp != null) result.success((temp * 100).toInt())
                else result.error("unavailable", "Sensor not supported", null)
            } else result.notImplemented()
        }

    // Timer sound playback
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIMER_SOUND_CHANNEL)
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlarm"  -> { stopCurrent(); _mediaPlayer = createPlayer(RingtoneManager.TYPE_ALARM); _mediaPlayer?.start(); result.success(null) }
                "playNotif"  -> { stopCurrent(); _mediaPlayer = createPlayer(RingtoneManager.TYPE_NOTIFICATION); _mediaPlayer?.start(); result.success(null) }
                "stop"       -> { stopCurrent(); result.success(null) }
                else         -> result.notImplemented()
            }
        }
}

private fun createPlayer(type: Int): MediaPlayer {
    val uri = RingtoneManager.getDefaultUri(type) ?: Settings.System.DEFAULT_NOTIFICATION_URI
    return MediaPlayer.create(this, uri)
}

private fun stopCurrent() {
    _mediaPlayer?.release()
    _mediaPlayer = null
}

   // Battery temperature via BATTERY_PROPERTY_TEMPERATURE
    private fun getBatteryTemperatureC(): Double? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val tenths = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_TEMPERATURE)
            tenths.takeIf { it != Int.MIN_VALUE }?.toDouble()?.div(10.0)
        } else null
    }
```

**CRITICAL PITFALL: Kotlin `BatteryManager` import required**

`BatteryManager` is NOT imported automatically in `MainActivity.kt`. The import must be added explicitly:

```kotlin
import android.os.BatteryManager
```

Without this import, the Kotlin compiler fails with:
```
Unresolved reference 'BatteryManager'
Cannot infer type for type parameter 'T'.
```

This is a common trap because `BatteryManager` is used via `getSystemService(Context.BATTERY_SERVICE)` which returns a generic `Object` — but the `as BatteryManager` cast requires the class to be imported. The compiler doesn't auto-resolve it from `android.os.*`.

**Build verification:** After adding the import, verify with `flutter build apk --debug` — the Kotlin compile step runs first and will catch this immediately.
```

### Dart Side (battery temperature via MethodChannel)

```dart
import 'package:flutter/services.dart';

class BatteryChannel {
  static const _ch = MethodChannel('battery_thermometer/temp');

  static Future<double?> getTemperatureC() async {
    try {
      final val = await _ch.invokeMethod<int>('getTemp');
      return val?.toDouble()?.div(100);
    } catch (_) { return null; }
  }
}
```

### Dart Side (timer sound via MethodChannel)

```dart
import 'package:flutter/services.dart';

const String _timerSoundChannel = 'timer_sound_player';

Future<void> _onComplete() async {
  Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 300]);
  try {
    if (_sound == TimerSound.notification)
      await const MethodChannel(_timerSoundChannel).invokeMethod<void>('playNotif');
    else if (_sound == TimerSound.alarm)
      await const MethodChannel(_timerSoundChannel).invokeMethod<void>('playAlarm');
  } catch (_) { /* graceful degrade: sound channel missing → vibration only */ }
}
```

**PREFER `audioplayers` OVER MethodChannels for simple sound playback.** The MethodChannel approach requires Kotlin code in `MainActivity.kt` (see above) and breaks on any platform where that code isn't present (CI, test, iOS if not implemented). The `audioplayers` package works on all platforms from pure Dart:

```dart
// Instead of MethodChannel, use audioplayers with asset sounds:
import 'package:audioplayers/audioplayers.dart';

class TimerSoundPlayer {
  final _player = AudioPlayer();

  Future<void> playNotif() => _player.play(AssetSource('sounds/click.wav'));
  Future<void> playAlarm()  => _player.play(AssetSource('sounds/alarm.wav'));
  Future<void> stop()       => _player.stop();

  void dispose() => _player.dispose();
}
```

**Advantages:** No Kotlin code, works on all Flutter platforms, uses the app's own assets, no system ringtone dependency. Use MethodChannels only for hardware APIs that have NO existing pub.dev package (battery temperature, custom sensors). For sound effects, timers, and alarms — `audioplayers` is strictly better.
```

**AndroidManifest permissions required for these channels:**
```xml
<!-- Battery temperature (BATTERY_PROPERTY_TEMPERATURE) -->
<!-- No explicit permission needed on Android — BatteryManager is public API -->

<!-- Timer: play system ringtone/alarm -->
<!-- No explicit permission needed — RingtoneManager is public API -->
```

### PITFALL: `shared_preferences` flutter_local_notifications version lock

`flutter_local_notifications` v18.x uses a completely different API than v19.x. When the skill was first written (v17.x / v18.x), the platform-channels and initialization behavior has shifted across major bumps. Always verify which version is actually resolved in `pubspec.lock` before copying API patterns — `Platform.isAndroid` checks, `NotificationChannel` IDs, and initialization callbacks are rarely backward-compatible across minor bumps. Pin exact versions in `pubspec.yaml` when stability matters.

## 16. Camera HostLens Zoom API: `setZoomScale()` → `setZoomLevel()`

`camera` package v0.12.0+1 renamed the zoom setter from `CameraController.setZoomScale()` to `CameraController.setZoomLevel()`. Library docs still advertise the old name — callers migrating from v0.11.x will hit `undefined_method` immediately.

**Signature:** `Future<void> setZoomLevel(double zoom)` — accepts a multiplier (1.0 = normal, 2.0 = 2× zoom), bounds enforced by camera hardware (check `getMaxZoomLevel()` / `getMinZoomLevel()`).

```dart
// WRONG — camera package v0.12.0+1
await _ctrl!.setZoomScale(zoom);

// RIGHT — v0.12.0+1
await _ctrl!.setZoomLevel(zoom);
```

When a property like `minZoomLevel` / `maxZoomLevel` is documented in the controller footer, verify via `grep` in the pub cache before trusting the rename.

---

## 17. Sensor Smoothing: EMA + Deadzone for Compass / Magnetometer

Raw magnetometer data is noisy — phone orientation, metal cases, and magnetic interference produce ±10–30° jitter at 50–100 Hz. A rolling average, exponential moving average (EMA), and/or software deadzone is needed before the value is meaningful.

```dart
// EMA accumulator
final _smoothFactor = 0.25;  // higher = more reactive, lower = smoother

void _onSensor(MagnetometerEvent e) {
  double raw = atan2(e.y, e.x) * 180 / pi;    // polar bearing
  if (raw < 0) raw += 360;

  // Wrap-aware delta (359° → 2° is a 3° backward hop, not 357°)
  double delta = raw - _filtered;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  _filtered += delta * _smoothFactor;
  _filtered = (_filtered + 360) % 360;

  // Deadzone: only repaint if motion exceeds threshold
  final change = (_filtered - _heading + 360) % 360;
  if (change > 180) change = 360 - change;
  if (change < _deadZone) return;   // ignore tiny jitter

  setState(() => _heading = _locked ? _lockedAt : _filtered);
}
```

**Rule of thumb:** `_smoothFactor` between 0.15 and 0.3 feels responsive without jitter. Deadzone between 1.0° and 2.0° prevents micro-jitters on a perfectly still phone from redrawing at 50 Hz.

### Encapsulating Sensor Stream (Magnetometer)

The `sensors_plus` package's `magnetometerEventStream()` returns raw `MagnetometerEvent` values with x, y, z axis readings. Use only the x and y axes for compass heading — ignore z (it measures perpendicular magnetic field which corresponds to vertical tilt, not heading).

---

## 18. CustomPainter Naming on Screen Screens

When a CustomPainter is *embedded* inside a `Scaffold + AppBar` layout (not in its own library or painted on a static widget), give the screen *and* the inner painter distinct class names to avoid ambiguity:

```dart
// BAD — only one level, harder to grep:
class _CompassPainter extends CustomPainter { ... }

// GOOD — screen + painter named distinctly:
class _BatteryGaugePainter extends CustomPainter { ... }   // used inside BatteryThermometerScreen
```

Keep the `_NeedlePainter` parallel (single responsibility: needle arcs only).

---

## 19. Analyzer Warning Triage — Fix Zero-Information Messages

Table 8.2 below groups analyzer warnings by what they *actually require you to fix*, grouped by type, broken down into code and hosts.

- **PILOT REGIONS** has no company associated with the company, requiring additional_handler from factory grids.

---

| Pattern | Action | Scope | Why It Matters |
|---------|--------|-------|----------------|
| `analysis_options.yaml` sets all constraints below, handled by `dart analyze --no-fatal-infos`. | Accept result codes | Passed to `:;` | Clean compile signal in intent-coded mode. |
| `error • method 'setZoomScale' not defined` | Replace with `setZoomLevel` (v0.12.0+1 API) | Single file | Camera package renamed this method in v0.12 — `setZoomScale` is a地向 without forward path. |
| `error • body might complete normally, causing 'null' to be returned` (non-nullable return type) | Add return type or insert `throw` for unreachable target | Single method | Not wrapping `dispose` in `@override` yields implicit `void` return, blocking the build | Error persists until fixed |
| `error • method isn't defined` | Search pub cache for correct API name | One method | Package docs are stale on version bumps — check source headers (`grep -n "method" <path>`) |
| `body_might_complete_normally` | ReturnStatement → returned affects build literally via `@override` and `@override`-annotated wrong type → build guards off. |
| `unused_element` / `unused_local_variable` | Either remove the declaration or reference it | Single variable | Keeps analyzer happy and prevents stale code accumulation |
| `unnecessary_cast` | Remove the `as Widget` cast (expression already typed Widget) | One line | Dart 3.11 infers `Widget` from `Padding → child` return; manual casts bypass type promotion |
| `no_leading_underscores_for_local_identifiers` | Prefix underscores (`_tmp` → might be confused with private method) | One identifier | trailing underscore (`as`) now preferred |
| `annotate_overrides` | Must annotate method to clear lint | One annotation | Warnings leak into CI coverage |

### Triage Flow (When `flutter analyze --no-fatal-infos` is the Rust handler anchor)

1. **EXIT rc==1 = errors present** → errors WON'T pass `--no-fatal-infos`. Treat like a show-run, not a warning.
2. **If the error signal is actually an unresolved method** → search pub cache with `grep -n "method" <path>/camera_controller.dart`
3. **If it's `body_might_complete_normally`** → method body must either return the correct nullability type or explicitly throw; check dependent.
4. **Once all errors are clean** → only warnings+informational remain. Code compiles and works — warnings are style preferences.

### Repository lock file anchors (camera package paths)

When checking API names or versions in pub cache in a local-dev environment, the path structure is always:

```
~/.pub-cache/hosted/pub.dev/camera-<version>/lib/src/camera_controller.dart
```

Package names may vary; verify via `pubspec.lock`.

---

## Supporting Files

- Flutter Provider → data binding (Android #Android #Flutter #Provider #dataBinding)

### Silent Provider Failure: `debugCheckInvalidValueType`

When providing a `ChangeNotifier`/`Listenable` subtype through `Provider<T>.value()`, the Provider library throws a debug-only exception that silently prevents the entire widget tree from accessing the provided state. Fix: `Provider.debugCheckInvalidValueType = null;` in `main()`.

**Full guide:** `references/provider-debug-silent-failures.md`

## References
- `references/hermes-client-cli-wrapper.md`

- `github-repo-management` skill for GitHub release creation workflow
- `references/fleetyards-api.md` — FleetYards API endpoints, pagination, image download, component data structure, store data patterns
- `references/hermes-client-cli-wrapper.md` — CLI wrapper service pattern for Flutter desktop apps that wrap local tools (HermesClient)
- `references/wikipedia-image-sourcing.md` — Downloading public domain images from Wikipedia via REST API, Flutter pubspec asset subdirectory declaration pitfall, rootBundle.load() + Image.memory() pattern, image quality standard
- `references/flutter-android-linux-build.md` — Android release builds on Linux: JDK version, keystore generation, gradle.properties, common build failures
- `references/flamingo-code-review.md` — Code review framework for multi-tool Flutter apps: build verification, file-by-file checklist, Kotlin bridge pitfalls, verdict scale

When screens in a sidebar layout need to retain state across tab switches, storing state in the widget's own `State` does NOT work — Flutter destroys/recreates the widget tree when an `IndexedStack` index changes or when switching between children in a `Row`.

**Fix:** Lift state into a `ChangeNotifier` provided at the app level via `MultiProvider`. The screen reads from the provider; the provider survives navigation because it lives above the navigation point.

### Pattern: ChatManager for Tabbed Conversations

```dart
// services/chat_manager.dart
class ChatManager extends ChangeNotifier {
  List<ChatSession> _sessions = [];
  int _activeIndex = 0;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession get activeSession => _sessions[_activeIndex];
  List<ChatMessage> get activeMessages => activeSession.messages;

  void createSession() { /* add + switch */ _save(); notifyListeners(); }
  void switchTo(int index) { _activeIndex = index; notifyListeners(); }
  void deleteSession(int index) { /* remove, don't delete last */ _save(); notifyListeners(); }
  void addMessage(String id, ChatMessage msg) { /* find session, add */ _save(); notifyListeners(); }
  void updateLastMessage(String id, ChatMessage msg) { /* replace last */ notifyListeners(); }
}

// In main.dart:
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ChatManager()),
    // ... other providers
  ],
  child: const App(),
)

// In screen:
final mgr = context.watch<ChatManager>();  // react to changes
final msgs = mgr.activeMessages;  // always current
```

### Key rules:
- **Use `context.watch<T>()`** (not `read`) in `build()` methods to subscribe to changes
- **Use `context.read<T>()`** in callbacks (`onPressed`, `onTap`) — never `watch` in callbacks
- **Persist to disk** via JSON file in `~/.app/` so state survives app restart
- **Last-session rule:** never delete the only remaining session — clear its messages instead
- **Tab-bar UX:** place session tabs in `AppBar.bottom` via `PreferredSize`, not crammed in the title area (which causes layout overflow that shifts content rightward on some Linux desktop backends)

### Tab-bar UX

| Situation | Pattern |
|-----------|---------|
| Tabbed chat with multiple conversations | ChatManager as above |
| Form wizard with steps | Step state in ChangeNotifier |
| Sidebar + content (10+ nav items) | Each screen reads from shared providers |
| Any screen that should "remember" after navigating away | ChangeNotifier at app level |

### Tab Bar Placement: AppBar.bottom, NOT Crammed in Title

When adding a tab bar to a Flutter desktop app, **always use `AppBar.bottom` with `PreferredSize`** — never cram the tabs into the AppBar title area with `titleSpacing: 0` and a compressed `Row + Expanded + ListView.builder`.

**WRONG** (causes layout overflow on Linux):
```dart
AppBar(
  titleSpacing: 0,
  title: SizedBox(
    height: 36,
    child: Row(children: [
      Expanded(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: sessions.length,
          itemBuilder: (_, i) => _buildTab(i),
        ),
      ),
    ]),
  ),
  actions: [versionBadge, resumeButton],
)
```
This forces the title area to share space with `actions` while also containing a horizontally-scrollable ListView. On some Linux desktop backends, this creates a layout overflow that shifts the ENTIRE content area rightward by the overflow amount. The right side of the window becomes invisible.

**RIGHT** (stable on all platforms):
```dart
AppBar(
  title: Text('Chat'),
  actions: [versionBadge, resumeButton],
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(32),
    child: Container(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sessions.length + 1,
        itemBuilder: (_, i) => _buildTab(i),
      ),
    ),
  ),
)
```
The tab bar lives below the AppBar in a dedicated 32px strip. The title area and actions get their own space. No sharing, no overflow, no right-shift.

### Pitfalls

- **`context.watch` must be called in `build()`**, not in `initState()` or callbacks. Use `context.read` for callbacks.
- **Getters that access providers** (like `String? get _resumedSessionId => context.read<ChatManager>().resumeSessionId`) are READ-ONLY — they can't be used as lvalues. Use the provider's setter method instead.
- **Don't set state on a getter** — `setState(() { _myGetter = value; })` fails silently because the getter isn't a real field.
- **Persist frequency:** Save on every mutation (add/delete/rename) to avoid data loss. Use `_save()` as the last line of every mutating method.
- **File location:** Use `Platform.environment['HOME']` (or `USERPROFILE` on Windows, fallback to `/tmp`). Never hardcode paths.

## 18. SSE Chat Streaming via HTTP Backend

For real-time chat streaming from a local or remote backend, use Dart's `HttpClient` to consume SSE (Server-Sent Events) instead of spawning a CLI subprocess:

```dart
Future<void> _streamChat(String message) async {
  final uri = Uri.parse('http://127.0.0.1:9120/chat/stream')
      .replace(queryParameters: {'message': message, 'session_id': resumeId});
  final client = HttpClient();
  final request = await client.getUrl(uri);
  final response = await request.close();

  final buffer = StringBuffer();
  String line = '';

  await for (final chunk in response.transform(utf8.decoder)) {
    for (var i = 0; i < chunk.length; i++) {
      final c = chunk[i];
      if (c == '\n') {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') { /* finalize */ return; }
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final content = json['content'] as String? ?? '';
            if (content.isNotEmpty) {
              buffer.write(content);
              // update placeholder message in real-time
            }
          } catch (_) {}
        }
        line = '';
      } else {
        line += c;
      }
    }
  }
}
```

### Pattern
1. Send message -> add user ChatMessage to manager
2. Add a placeholder ChatMessage('...') for the streaming response
3. Stream SSE chunks, updating the placeholder's text as chunks arrive
4. On `[DONE]` or stream end, finalize the placeholder with the full response
5. Auto-scroll on each chunk via `ScrollController.animateTo()`

### Pitfalls

- **`HttpClient` is DART's low-level client** — not `http` package, not `dio`. It handles streaming natively via `response.transform(utf8.decoder)`.
- **SSE lines** are `data: <json>\n`. `data: [DONE]\n` signals end. Everything else is raw byte chunks — accumulate in a line buffer.
- **`jsonDecode(data.substring(6))`** is fragile — use `data.startsWith('data: ')` check first, then `data.substring(6)`.
- **Replace placeholder by index**, not by reconstruction — `_messages[idx] = updatedMessage` is O(1) and doesn't shift scroll position.
- **Don't use `http` package's `Client().send()`** for SSE — it buffers the entire response before yielding control. `HttpClient` streams chunk-by-chunk.

### When to Use SSE vs Subprocess

| Approach | Use When |
|----------|----------|
| SSE via backend | Backend already exists, need real-time streaming, provider API access |
| `Process.run` subprocess | Simple one-shot queries, no streaming needed, no backend available |
| `Process.start` + stdout | Tool has its own streaming output (e.g. `hermes chat` with PTY) |

### Session Resume Bottom Sheet Pickers

When the chat app should let users resume Hermes CLI sessions (via `--resume <session_id>`), provide a bottom sheet picker that lists recent sessions from the backend.

**Pattern:**
1. A history icon (Icons.history) in the AppBar actions opens a modal bottom sheet
2. The sheet fetches recent sessions from `GET /sessions?limit=30` (via the HermesService interface)
3. Each session row shows: status dot, title, truncated ID, message count
4. Tapping a session sets the resume context on the ChatManager
5. A badge appears in the AppBar showing the resumed session title
6. Subsequent SSE stream requests include `session_id=<resumed_id>` as a query parameter
7. The backend forwards this to `hermes --resume <session_id> -z "message"` (on the CLI fallback path)

**Key state management:**
- The resumed session ID lives on the ChatManager (ChangeNotifier), not local State — survives tab switches
- Use `context.read<ChatManager>().setResumeSession(id, title: title)` in callbacks
- Use `context.read<ChatManager>().clearResumeSession()` to clear
- Read via getters: `_resumedSessionId => context.read<ChatManager>().resumeSessionId`

**CRITICAL PITFALL:** When a property moves from local State to a ChangeNotifier getter, ALL references must be updated — setters (`setState(() { _myVar = val })`) become invalid and the compiler error says "setter not defined for type." Replace every setState assignment with the ChangeNotifier's corresponding method call. The getters are READ-ONLY — you cannot assign through them.

**Bottom sheet widget structure:**
- `showModalBottomSheet` with `DraggableScrollableSheet`
- Header: title + "Clear Resume" button (if a session is already set) + loading spinner
- Body: ListView of `_SessionResumeRow` widgets showing title, truncated ID, message count
- Selection: check-circle icon on the selected session

**SSE query parameter inclusion:**
```dart
final queryParams = <String, String>{'message': message};
if (resumeSessionId != null && resumeSessionId.isNotEmpty) {
  queryParams['session_id'] = resumeSessionId;
}
final uri = Uri.parse('http://127.0.0.1:9120/chat/stream')
    .replace(queryParameters: queryParams);
```

**Backend handling (Rust):** The `chat_stream_handler` accepts an optional `session_id` query parameter. When set and when the provider has no `base_url` (CLI fallback path), it runs `hermes --resume <sid> -z <message>` instead of `hermes -z <message>.` For the provider streaming path, session_id is currently not used — sessions are managed by Hermes CLI server-side.

## 19. Unified Error/Loading/Empty States for Data Screens

Every screen that fetches data should handle all four states consistently:

```dart
// In build():
if (_loading && _data == null) {
  return const Center(child: CircularProgressIndicator());
}

if (_error != null && _data == null) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 48, color: errorColor),
          const SizedBox(height: 16),
          Text('Could not load data', style: ...),
          Text(_error!, style: ...),
          const SizedBox(height: 24),
          MaterialButton(onPressed: _reload, child: Text('Retry')),
        ],
      ),
    ),
  );
}

// Empty state (data loaded but empty):
if (_data.isEmpty) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.inbox_outlined, size: 40, color: ...),
        Text('No items found', style: ...),
        Text('Contextual hint about how to add data', style: ...),
      ],
    ),
  );
}

// Data state: return the actual content
return ListView.builder(...);
```

**Key rule:** Only show loading/error if there's NO cached data. If you have stale data, show it with a subtle loading indicator, not a full-screen spinner.

## 16. CLI State File Reading (Instead of Output Parsing)

Some CLI tools emit formatted output (systemd status, JSON tables) that's hard to parse reliably. Check if the tool writes a state file — reading JSON directly is always more reliable than parsing CLI output.

### Pattern: Find the State File

```dart
final stateFile = File('${await hermesHome}/gateway_state.json');
if (await stateFile.exists()) {
  final json = jsonDecode(await stateFile.readAsString());
  // json['gateway_state'] — 'running' or 'stopped'
  // json['platforms']['discord']['state'] — 'connected', 'retrying', etc.
}
```

### When to Use

| Signal | CLI Parsing | State File |
|--------|-------------|------------|
| Output format | Systemd unit status (variable-width) | JSON (stable schema) |
| Example | `hermes gateway status` | `~/.hermes/gateway_state.json` |
| Reliability | Changes with systemd version | Changes with tool version |
| Platform info | Not present in output | Has per-platform state |

### Strategy

1. **Try state file first** — fast, reliable, structured
2. **Fall back to CLI output** — for data not in the state file
3. **Never parse systemd output** for application state — it's formatted for humans, not programs

### API Discovery Pattern

For discovering runtime data (like available models), query local services directly instead of parsing config:

```dart
// Instead of parsing config.yaml for model names:
final result = await Process.run('curl', ['-s', 'http://127.0.0.1:8080/v1/models']);
final body = jsonDecode(result.stdout as String);
final models = (body['data'] as List).map((m) => m['id']);
```

**PITFALL:** The config lists what a user HAS configured, not what's actually available. The API tells you what's ready to use right now. Always prefer API discovery over config parsing for dynamic state.

## 20. Cross-Platform App Icon Replacement

When replacing a Flutter app's branding icon — new logo, redesign, brand refresh — update icons for ALL platforms. The source icon lives in `assets/icon/icon.png` (1024×1024 PNG recommended).

### Quick Reference: All Icon Sizes

| Platform | Directory / File | Sizes | Source |
|----------|-----------------|-------|--------|
| **Android** | `android/app/src/main/res/mipmap-{density}/ic_launcher.png` | 48, 72, 96, 144, 192 px | 1024×1024 |
| **iOS** | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{size}.png` | 20, 29, 40, 60, 76, 83.5, 1024 (×2×3 multipliers) | 1024×1024 |
| **README** | `assets/icons/icon.png` | 256×256 display | 1024×1024 |

### Replace Android Mipmap Icons

Android requires 5 density buckets. Regenerate with ImageMagick:

```bash
SRC="assets/icon/icon.png"
convert "$SRC" -resize 48x48   android/app/src/main/res/mipmap-mdpi/ic_launcher.png
convert "$SRC" -resize 72x72   android/app/src/main/res/mipmap-hdpi/ic_launcher.png
convert "$SRC" -resize 96x96   android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
convert "$SRC" -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
convert "$SRC" -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
```

**PITFALL:** Flutter does NOT auto-generate mipmap icons from your source image. The default `flutter create` puts default Flutter icons in every mipmap dir. You must replace them manually per density.

**PITFALL:** ImageMagick deprecation warning (`WARNING: convert is deprecated in IMv7`) is harmless — the command works. Use `magick` instead of `convert` if preferred.

### Replace iOS AppIcon Asset Catalog

iOS has 15 icon files at exact sizes:

```bash
SRC="assets/icon/icon.png"
IOS="ios/Runner/Assets.xcassets/AppIcon.appiconset"

# 20pt icons
convert "$SRC" -resize 20x20   "$IOS/Icon-App-20x20@1x.png"
convert "$SRC" -resize 40x40   "$IOS/Icon-App-20x20@2x.png"
convert "$SRC" -resize 60x60   "$IOS/Icon-App-20x20@3x.png"
# 29pt icons
convert "$SRC" -resize 29x29   "$IOS/Icon-App-29x29@1x.png"
convert "$SRC" -resize 58x58   "$IOS/Icon-App-29x29@2x.png"
convert "$SRC" -resize 87x87   "$IOS/Icon-App-29x29@3x.png"
# 40pt icons
convert "$SRC" -resize 40x40   "$IOS/Icon-App-40x40@1x.png"
convert "$SRC" -resize 80x80   "$IOS/Icon-App-40x40@2x.png"
convert "$SRC" -resize 120x120 "$IOS/Icon-App-40x40@3x.png"
# 60pt (iPhone)
convert "$SRC" -resize 120x120 "$IOS/Icon-App-60x60@2x.png"
convert "$SRC" -resize 180x180 "$IOS/Icon-App-60x60@3x.png"
# 76pt (iPad)
convert "$SRC" -resize 76x76   "$IOS/Icon-App-76x76@1x.png"
convert "$SRC" -resize 152x152 "$IOS/Icon-App-76x76@2x.png"
convert "$SRC" -resize 167x167 "$IOS/Icon-App-83.5x83.5@2x.png"
# App Store
convert "$SRC" -resize 1024x1024 "$IOS/Icon-App-1024x1024@1x.png"
```

**PITFALL:** `Contents.json` in the AppIcon.appiconset dir is auto-generated by Flutter/Xcode and does NOT need editing — it already declares all expected sizes. Only edit it if adding/removing icon sizes entirely.

### Rebuild After Icon Update

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
flutter build apk --release     # Android
flutter build linux --release   # Linux desktop
```

### Update README Icon Display

```markdown
<p align="center">
  <img src="assets/icons/icon.png" width="256" height="256" alt="App Name">
</p>
```

**PITFALL:** README paths must resolve relative to the repo root on GitHub. Use a relative path, not absolute or base64-embedded.

### GitHub Release Update (Icon-Only Changes)

When replacing builds with new icons at the same version:

```bash
# Package builds
cp build/app/outputs/flutter-apk/app-release.apk dist/AppName-vX.Y.Z.apk
tar czf dist/AppName-vX.Y.Z-linux.tar.gz -C build/linux/x64/release/bundle .

# Delete old release + tag
gh release delete vX.Y.Z --repo owner/repo --yes
git push --delete origin vX.Y.Z

# Re-tag and create fresh release
git tag -f vX.Y.Z && git push origin vX.Y.Z
gh release create vX.Y.Z \
  --repo owner/repo \
  --title "App vX.Y.Z" \
  --notes "## Notes\n\n- Icon update: new branding" \
  dist/AppName-vX.Y.Z.apk \
  dist/AppName-vX.Y.Z-linux.tar.gz
```

**PITFALL:** `gh release upload --clobber` keeps the original timestamp — users see "X days ago" even with a fresh APK. Delete+recreate gives a clean timestamp.

### Image Quality Standard — EVERY Entry Gets Its Own Image

When building an encyclopedia/codex/content feature with images, **every single entry must have its own dedicated image.** Shared placeholder images (e.g., 45 entries sharing the same 4KB `latin_cross.jpg`) will be called out as a quality issue. The standard is:

- **Minimum 8KB per image** — smaller files are icons/thumbnails, not usable photos
- **Each entry ID maps to a unique file** — `entry_id.jpg`, not a shared pool
- **Fall back to a category-level image** only after exhausting all Wikipedia sources
- **Never use the same generic image** (cross, logo, icon) for more than 3 entries
- **Verify in the APK** after build: `unzip -l app-release.apk | grep yourproject/images/`

The `references/wikipedia-image-sourcing.md` reference documents the full batch-download workflow.

## 21. Swipeable Gallery Pattern (PageView)

For content features where the user should browse entries/items by swiping (instead of tapping back after each one), use a `PageView.builder` with an AppBar position tracker.

### Architecture

```
Category List → Gallery Page (PageView) → multiple detail pages
```

The gallery receives the **full filtered list** + the **starting index** of the tapped item. The user swipes left/right through ALL items in the current filtered set.

### Gallery Page (HistoryGalleryPage example)

```dart
class GalleryPage extends StatefulWidget {
  final List<Entry> entries;
  final int initialIndex;
  final String categoryTitle;

  const GalleryPage({
    super.key,
    required this.entries,
    required this.categoryTitle,
    this.initialIndex = 0,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entries[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${entry.title} (${_currentIndex + 1}/${widget.entries.length})',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_currentIndex > 0)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            ),
          if (_currentIndex < widget.entries.length - 1)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.entries.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: EntryDetailBody(entry: widget.entries[index]),
          );
        },
      ),
    );
  }
}
```

### Navigation from List

```dart
// In the category/list page:
void _openGallery(int index) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GalleryPage(
        entries: _filteredEntries,   // ← current filtered list
        categoryTitle: widget.title,
        initialIndex: index,         // ← the entry the user tapped
      ),
    ),
  );
}
```

### Reusable Detail Body Extraction

The content body (image + title + badges + key figures + description + tags) should be extracted into a **standalone widget** reused by both the single-detail page AND the gallery page. StatefulWidget for image loading:

```dart
class EntryDetailBody extends StatefulWidget {
  final Entry entry;
  const EntryDetailBody({super.key, required this.entry});

  @override
  State<EntryDetailBody> createState() => _EntryDetailBodyState();
}

class _EntryDetailBodyState extends State<EntryDetailBody> {
  ImageProvider? _image;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(EntryDetailBody old) {
    super.didUpdateWidget(old);
    if (old.entry.imageUrl != widget.entry.imageUrl) {
      _image = null;
      _imageError = null;
      _loadImage();  // reload when switching pages
    }
  }
  // ... Image loading via rootBundle.load() + MemoryImage
}
```

**`didUpdateWidget` is critical** — without it, the image doesn't reload when the user swipes to a new page. The widget is reused by the PageView, so `initState` only fires once. `didUpdateWidget` detects the new entry and triggers a fresh image load.

### Key Rules

- **Position tracker** in AppBar: `'Title (3/15)'` — shows context and progress
- **Arrow buttons** in AppBar actions let the user navigate by tapping (not just swiping)
- **5 items or fewer** → consider removing arrows and relying on swipe only
- **`PageView.builder`** (not `PageView`) — lazy-builds pages for performance with 100+ entries
- **Extract body content** into a reusable widget — don't duplicate the detail layout
- **Image loading must work across page changes** — `didUpdateWidget` or an observer pattern

### When to Use vs Single Detail

| Scenario | Gallery (PageView) | Single Detail |
|----------|-------------------|---------------|
| Encyclopedia/codex browsing | ✓ Let them swipe through entries | × Tap back after each |
| Photo gallery | ✓ Swipe is expected UX | × |
| Form detail | × Swipe would lose form state | ✓ One at a time |
| 3-5 entries | × Gallery is overkill | ✓ Simple list |
| 10+ entries with search filter | ✓ Gallery of filtered results | × Too much back-navigation |

## 22. Nested GestureDetector Resolution (HitTestBehavior.translucent)

When a parent `GestureDetector` wraps a child that also has `GestureDetector`s (e.g., an ebook reader where the content area has verse-action handlers AND should toggle the app bar), the child's detector wins the gesture arena — the parent's `onTap` **never fires**.

The fix is `HitTestBehavior.translucent` on the inner (or outer) detector:

```dart
// CHILD: VerseWidget has its own onTap for highlighting/bookmarks
// PARENT: Wraps the scroll view, should toggle controls

// WRONG — parent tap never fires because child wins arena:
GestureDetector(
  behavior: HitTestBehavior.opaque,  // ← claims events, blocks propagation
  onTap: () => setState(() => _showControls = !_showControls),
  child: SingleChildScrollView(
    child: Column(
      children: verses.map((v) => VerseWidget(/* has own GestureDetector */)),
    ),
  ),
)

// RIGHT — both parent and child handlers fire:
GestureDetector(
  behavior: HitTestBehavior.translucent,  // ← observes + passes through
  onTap: () => setState(() => _showControls = !_showControls),
  child: SingleChildScrollView(
    child: Column(
      children: verses.map((v) => VerseWidget(/* still handles taps fine */)),
    ),
  ),
)
```

### HitTestBehavior Decision Table

| Value | Parent fires? | Child fires? | Use when |
|-------|--------------|--------------|----------|
| `deferToChild` (default) | Only if child doesn't claim it | Normal | Independent gesture regions |
| `opaque` | Yes, but blocks children | ❌ Blocked | Overlay absorbs all touches |
| `translucent` | Yes, even if child claims it | Normal | Toggle chrome behind interactive content |

### When to Use

- **Ebook/reader controls toggle** — tap the reading area to show/hide the app bar, while verse actions (highlight, footnote, bookmark) still work
- **Overlay dismiss + content interaction** — tap outside a modal to dismiss it, while the modal content still handles its own taps
- **Info panels over maps** — tap on an info card to navigate, while the map behind-panel still handles its own gestures

### Pitfalls

- **`didUpdateWidget` required for StatefulWidget body reuse** — When displaying detail content inside a `PageView`, the widget's `initState` fires once. To reload content (especially images) when the user swipes, implement `didUpdateWidget` to detect the new entry and trigger a fresh load. Without this, the page shows stale data after a swipe.
- **`translucent` fires BOTH handlers** — Make sure the child handler doesn't conflict with the parent toggle. For example, if the child opens a bottom sheet and the parent toggles controls, both happen on one tap. Usually this is fine (desired UX), but be aware.
- **Don't use `opaque` on a parent that wraps interactive children** — unless you specifically want to block all child interactions (e.g., a disabled overlay). `opaque` is for absorption, not coexistence.

## Supporting Files

- Flutter Provider → data binding (Android #Android #Flutter #Provider #dataBinding)

### Silent Provider Failure: `debugCheckInvalidValueType`

When providing a `ChangeNotifier`/`Listenable` subtype through `Provider<T>.value()`, the Provider library throws a debug-only exception that silently prevents the entire widget tree from accessing the provided state. Fix: `Provider.debugCheckInvalidValueType = null;` in `main()`.

**Full guide:** `references/provider-debug-silent-failures.md`

## References
- `references/hermes-client-cli-wrapper.md`

- `github-repo-management` skill for GitHub release creation workflow
- `references/fleetyards-api.md` — FleetYards API endpoints, pagination, image download, component data structure, store data patterns
- `references/hermes-client-cli-wrapper.md` — CLI wrapper service pattern for Flutter desktop apps that wrap local tools (HermesClient)
- `references/wikipedia-image-sourcing.md` — Downloading public domain images from Wikipedia via REST API, Flutter pubspec asset subdirectory declaration pitfall, rootBundle.load() + Image.memory() pattern, image quality standard
- `references/flutter-android-linux-build.md` — Android release builds on Linux: JDK version, keystore generation, gradle.properties, common build failures
