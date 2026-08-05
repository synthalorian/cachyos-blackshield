---
name: synthwave-creative-app-development
description: Building multi-platform creative workspace applications with synthwave '84 aesthetic — Rust + Flutter, Rails/Tailwind web, synthesis engines, encrypted storage, and CSS custom property theme engines.
---

# Synthwave Creative App Development

**Class**: Building multi-platform creative workspace applications with strong retro-futurist (synthwave '84) aesthetic — Rust backend + Flutter/egui frontends, Rails web apps with Tailwind, synthesis engines, encrypted local storage, agent systems, and CSS-driven theme engines.

## Core Principles
- Local-first, privacy-focused architecture
- Synthesis engine that connects creative domains (games, music, notes, faith/creative work)
- Heavy emphasis on visual aesthetic (CRT, neon, chrome, gradients)
- Production-ready code and infrastructure before deep feature work
- Direct, technical communication style

## Key Patterns
- Rust core with Argon2id + AES-GCM storage
- egui desktop with custom painter for CRT/scanline effects
- Flutter mobile with matching visual language and theme system
- flutter_rust_bridge for cross-platform logic sharing
- **CSS Custom Property Theme Engine** — zero-JS, browser-native theming via `data-theme` attribute + CSS variables (see `references/css-custom-property-theme-engine.md`)
- Theme system with multiple synthwave variants + light/dark, stored as model-backed color palettes (JSONB)

## When to Use
- User wants ambitious, potentially sellable creative tools
- Projects involving game dev tooling, music/creative companions, or personal synthesis engines
- **Rails/Tailwind web-based creative hubs** needing synthwave aesthetic
- Strong preference for 1984 retro-futurist visual identity across ALL platforms (not just native apps)

## Key Techniques

### Cross-Platform Theme Synchronization (Flutter → Rails)

When the same app runs on both Flutter (mobile/desktop) and Rails/Tailwind (web), **themes must be defined once and replicated** — never maintained separately. The Hermes Wingman project maintains 30 themes in exact visual parity across both platforms.

**The source of truth is the Flutter `AppColorScheme`** — defined in `lib/theme/app_theme.dart`. Each theme is a 19-color palette:

```dart
const synthwave84 = AppColorScheme(
  background: Color(0xFF0D0221),
  surface: Color(0xFF240037),
  primary: Color(0xFF8F00FF),
  secondary: Color(0xFFFF00FF),
  accent: Color(0xFF00FFFF),
  text: Color(0xFFFFFFFF),
  textDim: Color(0xFFC0A0D0),
  textMuted: Color(0xFF663388),
  border: Color(0xFF8F00FF),
  borderDim: Color(0xFF4A0068),
  success: Color(0xFF00FF41),
  warning: Color(0xFFFFFF66),
  error: Color(0xFFFF0040),
  // ... scaffold, appBar, bottomNav, card, selected backgrounds
);
```

**The webapp replicates each theme as a `[data-theme="name"]` CSS block** in `app/assets/tailwind/application.css`. Every hex value is copied exactly from the Flutter Dart source.

**How to maintain parity:**
1. Add/change a theme in Flutter `app_theme.dart` first (it's the canonical source)
2. Copy all hex values into a new `[data-theme="name"]` block in the Rails CSS
3. Add the theme to the Rails theme picker dialog (list of `[theme_id, icon, name]` tuples)
4. Add the theme name to the Rails `ThemeController::VALID_THEMES` list
5. Verify the webapp picks up the theme instantly via the `data-theme` attribute

The webapp uses ZERO JavaScript for theming — CSS custom properties cascade from `data-theme` on `<html>` down to all descendants. Theme switching is a form POST that updates the session cookie.

**PITFALL: Drift** — When the Flutter and Rails theme files diverge (e.g. colors look slightly different on one platform), update both files in the same commit. Never "fix it later" on one platform. BATCH updates to both files or use a script to generate one from the other.

### Dual-Service Architecture (Flutter)

Flutter apps that need to work both with and without a backend server should use an **abstract service interface with two implementations**:

```
HermesService (abstract)          ← dart interface
├── BackendService (HTTP)         ← talks to Rust via HTTP
└── HermesClient (CLI + FS)       ← talks to hermes CLI + local filesystem
```

**When to use each:**
- `BackendService` — primary path when the backend is running (connected indicator shows green)
- `HermesClient` — fallback when backend is unreachable (desktop only — CLI not available on mobile)

**PITFALL: Backend process PATH** — When `BackendService` starts the Rust backend via `Process.start()`, the subprocess inherits a minimal environment (`runInShell: false`). If the Rust backend shells out to a CLI tool (e.g. `hermes`), that tool won't be on the subprocess's PATH even if it's on the user's shell PATH. Fix by explicitly passing the `PATH` environment variable:

```dart
_process = await Process.start(binary, [],
  runInShell: false,
  environment: {
    'HOME': Platform.environment['HOME'] ?? '/tmp',
    'PATH': Platform.environment['PATH'] ?? '/usr/local/bin:/usr/bin:/bin',
  },
);
```

Symptoms of missing PATH: health endpoint returns `hermes_installed: false` even though `which hermes` succeeds in the terminal, skills/memory/skills/setup tabs show "Could not load" errors, CLI fallback features silently fail.

**Adding a new cross-platform feature:**

1. Add model classes in `lib/models/hermes_models.dart` (e.g. `SkillEntry`, `MemoryEntry`, `FileListing`)
2. Add abstract method to `HermesService` interface
3. Implement in `BackendService` via HTTP call to Rust endpoint
4. Implement in `HermesClient` via CLI command or direct filesystem access
5. Create the Flutter screen widget
6. Add to nav bar in `main.dart`
7. Add to Rails webapp controller + view
8. Add Rust backend endpoint if needed (for features that need CLI access)

**Flutter Nav Bar Expansion** — When adding screens:
1. Add `_NavItem` to `_navItems` list (desktop sidebar)
2. Add to `_mobileNavItems` if needed (mobile bottom nav — shows subset)
3. Update `_mobileIndexMap` to map mobile indices to screen indices
4. Add screen widget to `_screens` list in `initState`
5. Import the new screen module

Keep `_navItems`, `_mobileIndexMap`, and `_screens` in index-sync — they're three parallel arrays that must stay ordered together.

### Multi-Screen State Pattern

For screens that manage local data (missions, profiles), use JSON file persistence:

```dart
String get _path => '${Platform.environment['HOME'] ?? '/tmp'}/.hermes/wingman_missions.json';

void _load() {
  final file = File(_path);
  if (file.existsSync()) {
    final data = jsonDecode(file.readAsStringSync()) as List;
    _entries = data.cast<Map<String, dynamic>>();
  }
}

void _save() {
  final dir = Directory(_path).parent;
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File(_path).writeAsStringSync(jsonEncode(_entries));
}
```

This pattern avoids database dependencies and keeps user data in `~/.hermes` alongside the main Hermes config — consistent with the local-first philosophy.

### CSS Custom Property Theme Engine — Two Approaches

| Approach | When to Use | Framework |
|---|---|---|
| **`data-theme` attribute** (see `references/css-custom-property-theme-engine.md`) | Server-rendered apps where JS runtime is optional (Rails, Astro, static sites) | Rails/Tailwind |
| **CSS class swap via React Context** (see `references/react-css-theme-engine.md`) | React/SPA apps where theme is managed client-side | React/Vite |

### Webapp Theme CSS — [data-theme] Block Requirement

When adding themes to the Rails/Tailwind webapp, EACH theme needs a `[data-theme="name"]` CSS block in `app/assets/tailwind/application.css`. Without these blocks, the theme picker dialog changes the `data-theme` attribute on `<html>` but nothing happens visually because no CSS rules match.

**PITFALL: Empty theme selector** — If the theme picker shows all 29 themes but switching does nothing, the `[data-theme]` CSS blocks are missing. The `:root` block only provides the default theme. Every selectable theme needs its own block.

**Build step:** After editing `app/assets/tailwind/application.css`, run:
```
bin/tailwindcss -i app/assets/tailwind/application.css -o app/assets/builds/tailwind.css
```
(or use the project's tailwindcss binary from mise/ruby)

**Launcher/wrapper:** Update `~/.local/bin/hermes_wingman` to point to the latest build after a clean rebuild.

### Variable Contract & Backward-Compat Aliases

When building multi-theme systems, define a **shared variable contract** (all themes define the same set of CSS custom properties). When migrating from old variable names to standardized ones, add aliases in each theme file:

```css
--accent-purple: var(--accent-primary);   /* old → new */
--glow-purple: var(--glow-primary);       /* old → new */
```

This lets existing component CSS continue working while new code uses canonical names. The aliases stay forever as documentation; components can migrate to the canonical names at their own pace.

### Flutter Premium Visual Techniques (Glass Morphism + Animations)

For Flutter UIs that need a god-tier visual identity (frosted glass, animated backgrounds, custom transitions), use these composable patterns. Every technique is theme-aware — colors come from the active `AppColorScheme`.

**Glass Card Pattern** — Frosted backdrop blur around any widget:

```dart
// Import: import 'dart:ui' as ui;  (ImageFilter is NOT const)
ClipRRect(
  borderRadius: BorderRadius.circular(10),
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: Container(
      decoration: BoxDecoration(
        color: scheme.surface.withAlpha(180),  // translucent tint
        border: Border.all(color: scheme.borderDim.withAlpha(50), width: 0.5),
        boxShadow: [
          BoxShadow(color: scheme.primary.withAlpha(25), blurRadius: 12),
        ],
      ),
      child: child,
    ),
  ),
);
```

PITFALL: `ImageFilter.blur` is NOT a const constructor — never prefix with `const`. Use `dart:ui` import (aliased as `ui`) and call `ui.ImageFilter.blur()`.

PITFALL: `BackdropFilter` requires `ClipRRect` parent on desktop — without it the blur bleeds outside border-radius. Stack order: ClipRRect → BackdropFilter → Container with decoration.

PITFALL: **BackdropFilter breaks Material theme inheritance** — Any `InkWell`, `Material`, or `InkResponse` widget inside a `BackdropFilter` subtree will crash with "InkResponseStatWidget widgets require a Material widget ancestor" because `BackdropFilter` doesn't propagate the Material theme. Fix by wrapping the BackdropFilter's child with `Material(type: MaterialType.transparency)`:

```dart
BackdropFilter(
  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
  child: Material(
    type: MaterialType.transparency,  // ← provides Material ancestor for all children
    child: Container(
      // your content — InkWell, Material, etc. work here
    ),
  ),
)
```

This applies to EVERY BackdropFilter, not just the sidebar. Check: glass cards, glass nav bars, chat bubbles, session pickers, and any dialog with blur.

**Debugging Tip: No Visual Changes After Rebuild?** — If the user says the app "looks the same" after you made visual changes, don't trust incremental builds. The Flutter build system may skip recompilation if it thinks nothing changed. Force a clean rebuild:

```bash
flutter clean && flutter build linux --debug
```

Also check the running process — `pkill -f "appname$"` the old one before relaunching. The binary timestamp (`stat --format="%y" build/linux/.../app`) confirms whether a new build actually landed.

**PITFALL: Provider debugCheckInvalidValueType — Silent Visual Killer** — When providing a `ChangeNotifier` subclass through a plain `Provider<T>.value()` (e.g. `Provider<HermesService>.value(value: backendService)` where `BackendService extends ChangeNotifier`), the Provider debug check throws an unhandled exception during widget tree initialization. This silently prevents the entire app state (ThemeManager, HermesService, etc.) from being available to widgets.

Symptoms: user says "looks the same as before", no custom theme colors visible, app uses default Material theme. Fix:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;  // ← prevents silent failure
  // ...
}
```

**PITFALL: Flutter Color() hex overflow** — Using 10-digit hex values like `Color(0xFF0D0A1A80)` in theme constants causes the Color constructor to take overflow bits as alpha. The trailing `80` was intended as 50% alpha but the 10-digit value exceeds 32 bits. To Flutter, `0xFF0D0A1A80` truncated to 32 bits becomes `0x0D0A1A80` which has alpha=13 (~5%), making the sidebar/header nearly invisible.

Fix with sed (replaces `0xFF` + 6 hex + `80` with `0x80` + same 6 hex):

```bash
sed -i -E 's/0xFF([0-9A-Fa-f]{6})80/0x80\1/g' lib/theme/app_theme.dart
```

The correct pattern for 50% alpha in 8-digit ARGB is `0x80RRGGBB`. Test with `flutter analyze` after applying.

**Accent Edge Card** — Glass card with a glowing colored top edge for stat cards:

```dart
// Uses foregroundDecoration for the glowing edge border
foregroundDecoration: BoxDecoration(
  borderRadius: BorderRadius.circular(10),
  border: Border(
    top: BorderSide(color: accentColor.withAlpha(80), width: 1.0),
  ),
),
```

**Animated Starfield Background** — CustomPainter with slow-twinkling particles:

```dart
// Pattern: Controller.repeat() at 60s duration for subtle drift
// Generate 60-80 stars with seeded Random for stable layout
// Each star: position, size, opacity, twinkleSpeed, phase
// Constellation lines connect 3-6 stars for subtle depth
// Visibility: behind everything via Positioned.fill in a Stack
```

Use cases: dashboard backgrounds, splash screens, any full-screen canvas. The star colors inherit from the theme's primary/accent to stay cohesive.

**Animated Page Transitions** — Slide + fade for route changes:

```dart
// Configure in ThemeData:
pageTransitionsTheme: PageTransitionsTheme(
  builders: {
    TargetPlatform.android: HermesTransitionBuilder(),
    // ... all platforms
  },
)

// Slide in from 6% offset, fade in over first 35% of animation
SlideTransition(
  position: Tween<Offset>(
    begin: const Offset(0.06, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
)
```

For screen swaps within a shell (not routes), use `AnimatedSwitcher` with `KeyedSubtree(key: ValueKey(index))`:

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  transitionBuilder: (child, anim) => SlideTransition(
    position: Tween(begin: Offset(0.04, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child),
  ),
  child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _screens[_selectedIndex]),
)
```

**Animated Splash Screen** — A separate MaterialApp shown before the real app:

```dart
// In the root StatefulWidget, toggle _showSplash between two MaterialApp instances
if (_showSplash) {
  return MaterialApp(
    home: SplashScreen(onComplete: () => setState(() => _showSplash = false)),
  );
}
return MaterialApp(
  theme: themeManager.themeData.copyWith(pageTransitionsTheme: hermeticTransitions),
  home: MainShell(...),
);
```

Splash screen animation pattern: staggered `Interval` animations on `AnimationController` (2-2.5s total) — logo scale+fade (0-50%), glow reveal (20-60%), tagline slide+fade (50-80%). Use `easeOutBack` for the logo scale for a satisfying bounce.

**Theme-Aware Widget Pattern** — Widget that reads `AppColorScheme` from Provider with fallback:

```dart
@override
Widget build(BuildContext context) {
  AppColorScheme? scheme;
  try {
    scheme = context.watch<AppColorScheme>();
  } catch (_) {}
  final primary = explicitPrimary ?? scheme?.primary ?? defaultColor;
  // ...
}
```

PITFALL: `context.watch<AppColorScheme>()` works because `AppColorScheme` is exposed through `context.watch<ThemeManager>().currentScheme`. Actually, `AppColorScheme` itself is NOT a provider — you must either pass colors explicitly or watch `ThemeManager` and extract `.currentScheme`. The try/catch pattern is a safe guard for unit tests and contexts where no provider ancestor exists.

**Input Bar Glow Animation** — Pulsing border glow on focused input fields:

```dart
// AnimatedBuilder with a 2-second reverse-repeat AnimationController
// Lerp the alpha of the border color and box shadow
// Uses Tween<double>(begin: 0.4, end: 1.0) on the glow intensity
```

This pattern elevates input bars from flat to premium with minimal cost.

### Flutter Theme System: ThemeExtension vs Custom Class

There are two canonical approaches for multi-theme Flutter apps. Choose based on project maturity and complexity:

**Approach A: Custom `AppColorScheme` Provider (smaller apps, fewer views)**
- Define a plain Dart class with all color fields (the `AppColorScheme` documented above)
- Expose via `Provider<AppColorScheme>` (Riverpod) or `InheritedWidget`
- Each widget reads via `context.watch<AppColorScheme>()`
- Pros: Simple, no Flutter API dependency, easy to test
- Cons: Doesn't integrate with Material `Theme.of(context)`, manual propagation needed

**Approach B: `ThemeExtension<AppColors>` + Riverpod (larger apps, 25+ views)**
- Define `AppColors extends ThemeExtension<AppColors>` with semantic color fields + required `copyWith`/`lerp`
- Build 4+ `ThemeData` in a static `AppTheme` class, each including `extensions: [appColorsInstance]`
- Expose via Riverpod `StateNotifier<AppThemeType>` (persisted to Hive/SharedPrefs)
- Derive `themeDataProvider` and `appColorsProvider` from the notifier
- Each widget reads via `Theme.of(context).extension<AppColors>()!`
- Pros: Native Material integration, automatic dark/light switching, zero prop-drilling
- Cons: Requires `copyWith`/`lerp` boilerplate, `extension<>()` call at every usage

**ThemeExtension Implementation Pattern:**
```dart
class AppColors extends ThemeExtension<AppColors> {
  final Color surface;
  final Color card;
  final Color accent;
  final Color accentSecondary;
  final Color accentTertiary;
  final Color textDim;
  // ... 12+ semantic colors

  @override
  ThemeExtension<AppColors> copyWith({...}) => AppColors(...);
  @override
  ThemeExtension<AppColors> lerp(covariant ThemeExtension<AppColors>? other, double t) {
    // Color.lerp each field
  }
}

// In ThemeData builder:
static ThemeData _buildSynthwave84() {
  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF8F00FF),
    scaffoldBackgroundColor: const Color(0xFF240037),
    extensions: [const AppColors(/* sw84 palette */)],
    appBarTheme: AppBarTheme(/* uses primaryColor */),
    // ...
  );
}
```

**PITFALL: `DialogThemeData` name** — In ThemeData, the dialog property is `dialogTheme` which accepts `DialogThemeData(...)`, not `DialogTheme(...)`. The latter is a widget for wrapping subtrees. Using the wrong one causes `argument_type_not_assignable`.

**PITFALL: `Theme.of(context).extension<AppColors>()!` crashes if no theme is loaded** — The `!` force-unwrap is safe when the theme is always set via `MaterialApp(theme:)`. For widgets that might render outside the app tree (overlays, search delegates), wrap with a null check:
```dart
final appColors = Theme.of(context).extension<AppColors>() ?? fallbackColors;
```

**PITFALL: `const Divider(color: appColors.x, ...)` breaks** — `const` constructors can't use runtime values. `appColors.accent` is a runtime expression. Always use non-const constructors when the value comes from a theme extension:\n```dart\nDivider(color: appColors.accent, thickness: 0.5)  // NOT const Divider\n```\n\n**PITFALL: `withValues(alpha:)` in const contexts** — `Color.withValues()` is NOT a const method. It cannot be used inside `const` constructors (like `const ColorScheme(...)` or `const LinearGradient(...)`). Use `Color.withAlpha(int)` instead — that IS const-compatible:\n\n```dart\n// BROKEN (compiler error: 'withValues is not a const method'):\nconst ColorScheme(\n  outline: sw84Purple.withValues(alpha: 0.2),  // ❌\n);\n\n// WORKS:\nconst ColorScheme(\n  outline: sw84Purple.withAlpha(51),  // ✅ 51 = ~20% of 255\n);\n```\n\nAlpha value conversion: `withAlpha` takes 0-255. `withValues(alpha: X)` takes 0.0-1.0. Formula: `alpha_int = (X * 255).round()`. Common values: 0.2→51, 0.3→77, 0.5→128, 0.8→204.

**PITFALL: `const TextStyle(color: appColors.x)` breaks** — Same issue. Any `const` constructor using a theme-derived value fails at compile time with `Invalid constant value`. Remove `const` from the constructor call.

**PITFALL: `ConsumerStatelessWidget` vs `ConsumerWidget`** — In flutter_riverpod 2.x, the stateless Riverpod widget is `ConsumerWidget`. `ConsumerStatelessWidget` was an older name. Using the wrong class name causes `extends_non_class`.

**When to add a new theme:**
1. Add `AppThemeType` enum value (e.g. `retroWave`)
2. Build the `ThemeData` in `AppTheme._buildRetroWave()` with full palette
3. Add the case to `AppTheme.build()` switch
4. Add the theme option in settings view (the inline selector iterates `AppThemeType.values`)
5. The palette must match any corresponding desktop theme (e.g. omarchy synthwave84 palette)

**Palette parity with omarchy Synthwave '84:**
```dart
const Color sw84Background = Color(0xFF240037);
const Color sw84Surface = Color(0xFF1A002A);
const Color sw84Card = Color(0xFF2D0045);
const Color sw84Purple = Color(0xFF8F00FF);
const Color sw84Yellow = Color(0xFFF3E70F);
const Color sw84YellowBright = Color(0xFFFFFF66);
const Color sw84Pink = Color(0xFFFF00FF);
const Color sw84PinkSoft = Color(0xFFFF7EDB);
const Color sw84Cyan = Color(0xFF03EDF9);
const Color sw84Blue = Color(0xFF0080FF);
const Color sw84Red = Color(0xFFFF0040);
const Color sw84RedBright = Color(0xFFFE5442);
```

## References
- See `references/gridos-architecture.md` for specific project patterns
- See `references/synthwave-ui-techniques.md` for visual implementation details (Flutter/egui)
- See `references/flutter-glass-morphism-patterns.md` for concrete widget code and session-specific patterns from visual overhauls
- See `references/hermes-backend-integration.md` for Hermes backend patterns (chat streaming, mobile LAN discovery, provider management)
- See `references/css-custom-property-theme-engine.md` for web-based CSS theme engine (Rails/Tailwind)
- See `references/react-css-theme-engine.md` for React-based CSS theme engine with Context API
- See `references/rust-cli-ascii-art-pitfalls.md` for terminal ASCII art rendering pitfalls in Rust TUI apps (ratatui, block character widths, monospace assumptions)
- See `references/ai-image-generation-pixel-art-assets.md` for AI image generation workflow for retro pixel-art title screens and visual identity assets
- See `references/pixel-font-legibility.md` for HTML Canvas pixel font design — diagonal stroke thickness, scale-aware legibility, and 5x7 matrix techniques

## Related Skills
- omarchy (for desktop customization)
- flutter-development
- rust-workspace-troubleshooting
- system-design (for boot/login/theme consistency)
- open-synth (for the synthesizer keyboard app — C++ DSP engine, PortAudio, FFI patterns)