# Common Flutter Gotchas

## BackdropFilter breaks Material theme inheritance

Every `BackdropFilter` must wrap its child with `Material(type: MaterialType.transparency)` — otherwise `InkWell`, `Material`, and `InkResponse` widgets inside the blurred region crash with:

```
InkResponseStatWidget widgets require a Material widget ancestor
```

```dart
BackdropFilter(
  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
  child: Material(
    type: MaterialType.transparency,  // required for InkWell etc.
    child: Container(
      // your content — InkWell, Material, etc. work here
    ),
  ),
)
```

PITFALL: `ImageFilter.blur` is NOT const — never prefix with `const`. Import `dart:ui` as `ui` and call `ui.ImageFilter.blur()`.
PITFALL: On desktop, `BackdropFilter` requires `ClipRRect` as its parent — without it the blur bleeds outside the border radius.

Applies to: glass sidebars, nav bars, chat bubbles, session pickers, dialog backgrounds — every BackdropFilter that might contain interactive widgets.

## Color hex overflow — 10-digit values

`Color(0xFF0D0A1A80)` has 10 hex digits (5 bytes). Flutter's `Color` constructor takes an `int` but only uses the lower 32 bits as ARGB. The trailing `80` shifts the alpha, creating near-transparent colors.

Always use 8-digit ARGB hex for semi-transparent colors:
```dart
// WRONG — 10 digits, alpha≈5%
Color(0xFF0D0A1A80)

// RIGHT — 8 digits, 50% alpha
Color(0x800D0A1A)
```

Fix all instances in a file with sed:
```bash
sed -i -E 's/0xFF([0-9A-Fa-f]{6})80/0x80\1/g' lib/theme/app_theme.dart
```

Symptoms: sidebar/header appears semi-transparent or shows through to the background regardless of theme color.

## Provider debugCheckInvalidValueType with Listenable subtypes

When providing a `ChangeNotifier` implementation through `Provider<Interface>.value()`, the debug check fires an unhandled exception during initialization:

```dart
// BackendService extends ChangeNotifier implements HermesService
Provider<HermesService>.value(value: backendService)
// ^ throws: "Tried to use Provider with a subtype of Listenable/Stream"
```

This prevents the entire provider tree from initializing. Fix by suppressing the check:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;  // ← add this
  // ...
}
```

Symptoms: app uses default Material theme instead of custom theme, user says "looks the same as before" after visual changes.

## Hardcoded backend URLs break on mobile

When making HTTP requests from the Flutter app to the backend, always use the service's `baseUrl` instead of hardcoding `127.0.0.1:9120`:

```dart
// WRONG — only works when backend is local
final uri = Uri.parse('http://127.0.0.1:9120/chat/stream');

// RIGHT — works on desktop AND mobile
final uri = Uri.parse('${service.baseUrl}/chat/stream');
```

Search your codebase for hardcoded `127.0.0.1:9120` before shipping to mobile.