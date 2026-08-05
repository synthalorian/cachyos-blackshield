# Flutter Splash Screen PNG Hang on Android

## Problem
2.6MB PNG (`assets/icons/hermes-wingman.png`, 1254x1254) loaded via `Image.asset()` in a splash screen widget caused the app to render black on Android 16.

## Root Cause
Large PNG decoding can hang the Flutter render thread during splash screen initialization. The `Image.asset()` widget loads and decodes the image synchronously on the UI thread. A 2.6MB image at splash time blocks rendering before `runApp()` completes.

## Symptoms
- App launches (process starts, logcat shows Flutter engine init)
- Screen is completely black
- No crash, no Dart exceptions
- `flutter create` counter app works fine (proves engine is OK)
- gralloc5 errors in logcat are a **red herring**

## Fix Options

### Option 1: Replace with Icon widget (fastest)
```dart
// BEFORE — hangs on large PNG decode
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: Image.asset(
    'assets/icons/hermes-wingman.png',
    width: 96,
    height: 96,
    fit: BoxFit.cover,
  ),
)

// AFTER — no image loading, instant render
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: Icon(
    Icons.bolt,
    size: 64,
    color: const Color(0xFF8BA888),
  ),
)
```

### Option 2: Compress the PNG
```bash
# Use pngquant or similar
pngquant --quality=65-80 --output assets/icons/hermes-wingman-small.png assets/icons/hermes-wingman.png
```
Target <100KB for splash screen assets.

### Option 3: Use SVG
```yaml
# pubspec.yaml
dependencies:
  flutter_svg: ^2.0.0
```
```dart
import 'package:flutter_svg/flutter_svg.dart';

SvgPicture.asset(
  'assets/icons/hermes-wingman.svg',
  width: 96,
  height: 96,
)
```

### Option 4: Pre-cache image before splash
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-load image before showing splash
  await precacheImage(
    AssetImage('assets/icons/hermes-wingman.png'),
    WidgetsBinding.instance.rootElement!,
  );
  runApp(MyApp());
}
```

## Prevention
- Keep splash screen assets under 100KB
- Use SVG for logos/icons when possible
- Test splash screen on physical devices, not just emulator
- If app is black, check splash screen assets BEFORE chasing engine errors

## Related
- `references/session-2026-06-01-android-16-gralloc5-lan-scan.md` — Full session where this was discovered
- `references/flutter-android-16-gralloc5.md` — gralloc5 red herring explanation
