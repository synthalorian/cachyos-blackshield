# Provider.debugCheckInvalidValueType — Silent Visual Kill

> Debugged and fixed during the Hermes Wingman visual overhaul (May 2026).
> The #1 reason a user says "looks the same as before" after major Flutter visual changes.

## Root Cause

When using `Provider<T>.value()` where the concrete type of `T` extends `ChangeNotifier` (or any `Listenable`), the Provider library throws an unhandled exception during widget tree initialization:

```
Unhandled Exception: Tried to use Provider with a subtype of Listenable/Stream (HermesService).
```

This happens because `Provider.debugCheckInvalidValueType` checks if the value being provided is a subtype of `Listenable` or `Stream`. If it is, Provider warns that you should use `ListenableProvider` or `ChangeNotifierProvider` instead — because plain `Provider` doesn't know when to rebuild dependents.

**The problem:** This check throws a runtime exception that prevents the entire Provider tree from initializing. All other providers (ThemeManager, ChatManager, etc.) also fail to register. The app falls back to default Material theming with no custom styles at all.

## The Pattern That Triggers It

```dart
// HermesService is an abstract class
abstract class HermesService { ... }

// BackendService implements it AND extends ChangeNotifier
class BackendService extends ChangeNotifier implements HermesService { ... }

// This throws because the runtime type of hermesService is BackendService (a ChangeNotifier)
Provider<HermesService>.value(value: hermesService),
```

## The Fix

**Option A (recommended):** Suppress the debug check at the app entry point:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;  // ← one line, fixes everything
  // ... rest of main
}
```

**Option B:** Use `ListenableProvider<HermesService>` or `ChangeNotifierProvider<HermesService>` instead — but this is technically incorrect since `HermesService` (the abstract type) doesn't extend ChangeNotifier.

**Option C:** Wrap the value in a non-Listenable adapter class — overkill.

## Detection

The error only appears in the `flutter run` console output or stdout of the running binary. It does NOT show as a visible error in the app UI. The app renders but with zero custom theming.

Check for it by:
1. Running `flutter run -d linux` and watching for "Unhandled Exception: Tried to use Provider with a subtype of Listenable/Stream"
2. Checking if the flutter_assets/kernel_blob.bin timestamp is recent
3. Running `flutter analyze` (this won't catch it — it's a runtime check)

## Why It's Not a Compile Error

`Provider.debugCheckInvalidValueType` is a runtime assertion, not a static type check. It runs during `Provider<T>()` or `Provider<T>.value()` construction. The check is there to catch a common mistake (providing a ChangeNotifier through a plain Provider) but it's too aggressive for the "abstract interface + ChangeNotifier implementation" pattern.