# Android Build Configuration for Flutter+Rust Apps

When packaging a Flutter+Rust FFI app for Android, these standard Flutter build tasks complement the Rust cross-compilation pipeline managed by cargokit.

## App Icon

Use `flutter_launcher_icons` to generate platform-specific icons from a single source image.

### Setup

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon.png"
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/icon.png"
```

### Generate

```bash
flutter pub get
dart run flutter_launcher_icons
```

This creates:
- Android: all mipmap densities (mdpi → xxxhdpi)
- Android: adaptive icon XML + foreground PNGs
- iOS: all AppIcon sizes (20px × 1024px)

The source image should be square (1024×1024 or larger) with transparent or solid background.

## App Display Name

The Android launcher name is set in `android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:label="My App Name"    <!-- ← This is what shows on the home screen -->
    ...
>
```

Default is the package name (e.g., `sc_synthesis`). Change it to a human-readable name.

## App Version

Version is set in `pubspec.yaml`:

```yaml
version: 0.2.0+1
```

- `0.2.0` — versionName (shown to users)
- `1` — versionCode (integer, incremented for each build)

Update the display string in your settings/about screen separately — there's no automatic sync from pubspec.yaml to Dart code.

## APK Build

```bash
# Debug (fast, large)
flutter build apk --debug

# Release (optimized, code-shaken, smaller)
flutter build apk --release
```

Release builds:
- Tree-shake Material icons (99%+ reduction)
- Remove debug code
- Compress and optimize
- Sign with release key (debug builds use debug keystore)

The Rust .so files for all 4 Android ABIs will be bundled via cargokit:
- `arm64-v8a` (most modern devices)
- `armeabi-v7a` (older devices)
- `x86_64` (emulator)
- `x86` (emulator, older)

## AppBar and UI Titles

The app's display names in the UI are separate from the Android manifest label:
- MaterialApp title (app.dart)
- Each Scaffold's AppBar title
- Dialog titles
- These must be updated independently

## Quick Reference

| Task | Command / Location |
|------|-------------------|
| Change icon | Place `assets/icon.png`, update `pubspec.yaml`, run `dart run flutter_launcher_icons` |
| Change launcher name | `android/app/src/main/AndroidManifest.xml` → `android:label` |
| Change version | `pubspec.yaml` → `version:` field |
| Debug APK | `flutter build apk --debug` |
| Release APK | `flutter build apk --release` |
| Update UI title | Change `title:` in MaterialApp + each Scaffold AppBar |

## External Links: `url_launcher` on Android 11+

If your app opens external URLs (FleetYards, GitHub, Buy Me a Coffee, etc.), the `canLaunchUrl()` → `launchUrl()` pattern **silently fails on Android 11+** (API 30+).

### Root Cause

Android 11 restricts package visibility. `canLaunchUrl()` queries the system for apps that can handle an intent — without a `<queries>` element in the manifest, it returns `false` for HTTPS URLs, and `launchUrl()` is never called. The button appears dead.

### Fix

**Skip `canLaunchUrl` entirely.** Just try `launchUrl` and catch any error:

```dart
Future<void> openLink() async {
  final uri = Uri.parse('https://example.com');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No browser available — fail silently
  }
}
```

Apply this to every URL-launching function in the app. Tested pattern in `fleetyards_link.dart`, `buy_me_a_coffee.dart`, and `settings_screen.dart`.

### Verification

1. Install the built APK on a physical Android device (emulators may not reproduce this)
2. Tap each link button
3. The default browser should open with the target URL
4. If nothing happens, check that `canLaunchUrl` was removed and try/catch is in place