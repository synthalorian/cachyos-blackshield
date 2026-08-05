# Flutter Glass Morphism & Premium Visual Patterns

> Concrete widget implementations from the Hermes Wingman visual overhaul (May 2026).
> All patterns are theme-aware via `AppColorScheme` and designed for cross-platform Flutter.

---

## GlassCard — Reusable Frosted Glass Container

**Source:** `lib/theme/glass_card.dart`

The workhorse of glass UIs. Wraps any child in a BackdropFilter with configurable blur, tint, border, and glow.

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final AppColorScheme scheme;
  final double blurSigma;       // default 12 — higher = more frosted
  final double borderRadius;    // default 10
  final Color? tintColor;       // defaults to scheme.surface.withAlpha(160)
  final Color? borderColor;     // defaults to scheme.borderDim.withAlpha(60)
  final Color? glowColor;       // defaults to scheme.primary
  final double glowRadius;      // 0 = no glow
  final EdgeInsetsGeometry? padding;

  // ...
}
```

**Critical gotcha:** `ImageFilter.blur()` is NOT a const constructor. Never use `const ImageFilter.blur(...)`. Always import `dart:ui` and call as `ImageFilter.blur(...)` or use `ui.ImageFilter.blur(...)` if dart:ui is aliased.

## AccentGlassCard — Glass Card with Glowing Top Edge

For stat cards and dashboard tiles. Adds a 1px colored border on top via `foregroundDecoration`.

```dart
// Subtle glow shadow on the card body
boxShadow: [
  BoxShadow(color: accentColor.withAlpha(25), blurRadius: 12, spreadRadius: 0.5),
],
// Glowing top accent edge
foregroundDecoration: BoxDecoration(
  borderRadius: BorderRadius.circular(10),
  border: Border(top: BorderSide(color: accentColor.withAlpha(80), width: 1.0)),
),
```

## glowShadow() Utility

```dart
List<BoxShadow> glowShadow(AppColorScheme scheme,
    {double radius = 8, double opacity = 0.12}) {
  return [
    BoxShadow(
      color: scheme.primary.withAlpha((opacity * 255).round()),
      blurRadius: radius, spreadRadius: 0.5,
    ),
    BoxShadow(
      color: scheme.accent.withAlpha((opacity * 128).round()),
      blurRadius: radius * 1.5, spreadRadius: 0,
    ),
  ];
}
```

## Animated Starfield Background

**Source:** `lib/theme/animated_background.dart`

A `CustomPainter` driven by a 60-second repeat `AnimationController`. 80 seeded stars with individual twinkle phases, plus 2 constellation groups.

**Pattern:**
- Ticker: `SingleTickerProviderStateMixin` with `AnimationController(duration: 60s)..repeat()`
- Stars generated once in `initState` with `Random(42)` for deterministic layout
- Each star has: x, y (0-1 normalized), size, opacity, twinkleSpeed, phase
- Star alpha = `opacity * (0.4 + sin(time * twinkleSpeed + phase) * 0.6)`
- Constellation lines connect 3-6 random stars with ~0.05 opacity
- Wrap in `Positioned.fill` in a Stack below the UI layer

```dart
Stack(
  children: [
    Positioned.fill(child: AnimatedBackground(...)),
    // UI layer on top
  ],
)
```

## Animated Sidebar Icon (Pulse)

**Source:** `lib/main.dart` — `_AnimatedSidebarIcon`

```dart
// 3-second reverse-repeat animation
_pulseController = AnimationController(vsync: this, duration: Duration(seconds: 3))
  ..repeat(reverse: true);
_pulse = Tween<double>(begin: 0.92, end: 1.0)
  .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine));
```

## Glass Input Bar with Pulsing Glow

**Source:** `lib/screens/chat/chat_screen.dart` — `_GlassInputBar`

```dart
// 2-second reverse-repeat animation for border glow
_glowAnim = Tween<double>(begin: 0.4, end: 1.0)
  .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine));

// In build: lerp border alpha and shadow based on glowAnim.value
border: Border.all(
  color: scheme.primary.withAlpha((20 * _glowAnim.value).round()),
  width: 1.0,
),
boxShadow: [
  BoxShadow(
    color: scheme.primary.withAlpha((8 * _glowAnim.value).round()),
    blurRadius: 8,
    spreadRadius: 0.5,
  ),
],
```

## Animated Splash Screen

**Source:** `lib/theme/hermes_splash.dart`

A 2200ms animated intro with three staggered phases:

| Phase | Interval | What Happens |
|-------|----------|-------------|
| Logo reveal | 0-50% | Scale 0.6→1.0 (`easeOutBack`), fade 0→1 |
| Glow bloom | 20-60% | Radial glow radius expands 0→40px |
| Tagline | 50-80% | Slides up 12px, fades in |

The parent app swaps `MaterialApp` instances when `_showSplash` toggles. The splash runs its own minimal ThemeData (no Provider dependencies needed).

## Hermetic Page Transitions

**Source:** `lib/theme/page_transitions.dart`

```dart
// Slide from 6% right offset, fade in over first 35%
SlideTransition(
  position: Tween<Offset>(begin: Offset(0.06, 0), end: Offset.zero)
    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
  child: FadeTransition(
    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Interval(0.0, 0.35, curve: Curves.easeOut)),
    ),
    child: child,
  ),
);
```

Wire into ThemeData:
```dart
theme: themeData.copyWith(
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: HermesTransitionBuilder(),
      TargetPlatform.iOS: HermesTransitionBuilder(),
      TargetPlatform.linux: HermesTransitionBuilder(),
      TargetPlatform.macOS: HermesTransitionBuilder(),
      TargetPlatform.windows: HermesTransitionBuilder(),
    },
  ),
)
```

For non-route screen swaps (sidebar/footer navigation), use `AnimatedSwitcher`:

```dart
AnimatedSwitcher(
  duration: Duration(milliseconds: 200),
  transitionBuilder: (child, anim) => SlideTransition(
    position: Tween(begin: Offset(0.04, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child),
  ),
  child: KeyedSubtree(key: ValueKey(screenIndex), child: screens[screenIndex]),
)
```

## Theme-Aware Wingman Icon

**Source:** `lib/widgets/wingman_icon.dart`

The icon accepts optional `primary`, `secondary`, `accent` colors. If none provided, it tries to read from Provider at runtime. If no Provider ancestor exists, falls back to synthwave '84 defaults.

```dart
// Usage with explicit colors from theme:
WingmanIcon.fromScheme(scheme: currentScheme, size: 40)

// Or let it auto-discover from context:
WingmanIcon(size: 40)
```

The `fromScheme` factory is preferred in production code — it avoids the Provider dependency at paint time.

## Glass Sidebar (Desktop)

**Source:** `lib/main.dart`

The sidebar uses a `ClipRRect` + `BackdropFilter` stack to achieve rounded glass edges:

```dart
ClipRRect(
  borderRadius: BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      width: 68,
      decoration: BoxDecoration(
        color: scheme.appBarBackground.withAlpha(180),
        border: Border(right: BorderSide(color: scheme.borderDim.withAlpha(50))),
      ),
      // sidebar contents
    ),
  ),
)
```

## Mobile Glass Nav Bar

Same pattern applied to the mobile bottom nav bar:
```dart
ClipRRect(
  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: BottomNavigationBar(
      backgroundColor: scheme.bottomNavBackground.withAlpha(200),
      // ...
    ),
  ),
)
```

## Known Pitfalls

### 1. `const ImageFilter.blur` — Will NOT compile
Never use `const` with `ImageFilter.blur()`. Import `dart:ui` (aliased or not) and call `ImageFilter.blur()` without `const`.

### 2. BackdropFilter without ClipRRect
On desktop (linux/windows), the blur effect bleeds outside the rounded corners. Always pair: `ClipRRect` → `BackdropFilter` → content.

### 3. Performance
Glass cards with BackdropFilter are more expensive than flat containers. Use sparingly — key locations only (sidebar, dashboard cards, dialog overlays). Don't wrap every list tile in glass.

### 4. AnimationControllers — Must be disposed
Use `SingleTickerProviderStateMixin` for one controller, `TickerProviderStateMixin` for multiple. Always dispose controllers in `dispose()`.

### 5. Theme defaults
`Hermes` is the default theme for Hermes Wingman. When creating new screens, assume the Hermes color scheme is the baseline.

### 6. 🚨 Provider debugCheckInvalidValueType — Silent Visual Killer

**This is the #1 reason visual changes don't appear.** When providing a `ChangeNotifier` subclass through a plain `Provider<T>.value()` (e.g. `Provider<HermesService>.value(value: backendService)` where `BackendService extends ChangeNotifier`), the Provider debug check throws an unhandled exception during widget tree initialization. This silently prevents your entire app state (ThemeManager, HermesService, etc.) from being available to widgets.

Symptoms:
- User says "looks the same as before" after visual overhaul
- No custom theme colors visible
- App uses default MaterialDesign theme
- Provider.inheritedFrom is null for provided types
- Error only visible in `flutter run` console, not in app window

Fix:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;  // ← prevents silent failure
  // ...
}
```

Full debugging path documented in `flutter-development` skill reference: `references/provider-debug-silent-failures.md`.

### 7. BackdropFilter + Material Theme Inheritance — Mandatory `Material(type: MaterialType.transparency)`

Every `BackdropFilter` in the widget tree **breaks Material theme inheritance**. All `InkWell`, `Material`, `InkResponse`, `TextButton`, `ElevatedButton`, etc. widgets inside the BackdropFilter subtree will crash with:

```
InkResponseStatWidget widgets require a Material widget ancestor
```

**The fix is to wrap the BackdropFilter's child with `Material(type: MaterialType.transparency)`:**

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Material(
      type: MaterialType.transparency,  // ← REQUIRED for InkWell/Material children
      child: Container(
        // sidebar with InkWell buttons, nav items, etc.
      ),
    ),
  ),
)
```

**Widgets that need this fix** (any BackdropFilter whose subtree contains):
- InkWell, InkResponse, Ink
- Material (even with type: MaterialType.transparency deeper in the tree)
- ElevatedButton, TextButton, OutlinedButton, IconButton
- BottomNavigationBar (the nav items have InkWell internally)
- ListTile, Checkbox, Radio, Switch
- Any widget from the Material library that has interactive states

**Widgets that DON'T need this fix** (safe without Material wrapper):
- Text, Icon, Container with no ink effects
- Row, Column, Padding, SizedBox
- CustomPaint, Image
- Any widget tree that contains NO Material library interactive widgets

**When adding a new BackdropFilter, ASK: "does this blur wrap any interactive widgets?"** If yes, add the Material wrapper. If no, skip it. The error is a runtime crash, not a compile-time error — you won't know until the widget renders.