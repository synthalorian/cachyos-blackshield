# Flutter Platform Detection Pitfall — Library-Level Constants

## Problem

Declaring a platform check as a top-level `final` variable in a Dart library can cache the wrong value, especially during hot reload or certain APK build configurations. The variable evaluates once at library load time, not at widget build time.

## Symptom

Code like this appears correct but the mobile-only UI (e.g. QR scanner button) does not render on Android:

```dart
// At top of file, outside any class — BAD
final bool _isMobile = Platform.isAndroid || Platform.isIOS;

class ConfigScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isMobile) _buildConnectionSection(),  // Never shows on some builds
      ],
    );
  }
}
```

## Root Cause

`Platform.isAndroid` is backed by `dart:io`'s `Platform.operatingSystem`, which reads from environment variables. On some Flutter build paths (release APK with tree-shaking, certain Gradle plugin versions), the library may be initialized in a context where these values are not yet populated, causing `_isMobile` to cache `false` permanently.

## Fix

Move the platform check inside the widget's `build()` method or use a getter so it re-evaluates every frame:

```dart
class ConfigScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;  // GOOD
    return Column(
      children: [
        if (isMobile) _buildConnectionSection(),
      ],
    );
  }
}
```

Or use a getter on the state class:

```dart
class _ConfigScreenState extends State<ConfigScreen> {
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  // ...
}
```

## Verification

After fixing, build a fresh APK and verify on device:

```bash
flutter clean
JAVA_HOME=/usr/lib/jvm/java-21-openjdk flutter build apk --release
adb uninstall com.example.hermes_wingman
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Related

- `references/qr-code-pairing.md` — The QR scanning feature that triggered this discovery
- `references/flutter-desktop-deployment.md` — Linux desktop binary layout
