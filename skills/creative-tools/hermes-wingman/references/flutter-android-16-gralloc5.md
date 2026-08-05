# Flutter + Android 16 gralloc5 Black Screen

## Symptom
Flutter APK installs and launches (process starts, logcat shows Flutter engine initializing), but the screen is completely black. No UI elements, no crash, no Dart exceptions.

## Root Cause
Android 16 introduced changes to the graphics allocator (`gralloc5`) that use pixel format `0x3b` (a HAL-specific format). Flutter's Skia/Impeller engine doesn't recognize this format, causing the surface to render as black.

Logcat smoking gun:
```
E gralloc5: ERROR: Unrecognized and/or unsupported format (<unrecognized format> 0x3b)
    and usage (CPU_READ_NEVER|CPU_WRITE_NEVER|GPU_TEXTURE|GPU_RENDER_TARGET|COMPOSER_OVERLAY 0xb00)
```

## Verification (Critical Step)
Before spending time debugging your widget tree, verify it's an engine issue:

```bash
# Create a brand new Flutter app
cd /tmp && flutter create --platforms=android test_app
cd test_app && flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.example.test_app/.MainActivity
sleep 5
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png /tmp/screen.png
```

If the default counter app is ALSO black → this is a Flutter/Android 16 incompatibility, NOT your code.

## Affected Configurations
- Device: Pixel 8a (observed)
- OS: Android 16 (API 36)
- Flutter: 3.41.9 stable, 3.44.0 stable, 3.45.0-0.1.pre beta — all affected
- Both Impeller (Vulkan) and legacy Skia renderer affected

## Workarounds (None Fully Effective as of 2026-06-01)

### 1. Test on emulator or Android 15 device (MOST RELIABLE)
The issue is specific to Android 16's gralloc5 HAL. Emulators with API 35 or physical devices on Android 15 render correctly. This is the only confirmed working path.

### 2. Disable Impeller (did NOT fix in testing)
In `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableImpeller"
    android:value="false" />
```
Tested on Flutter 3.44.0 stable + 3.45.0-0.1.pre beta with Android 16 — gralloc5 error persists with Skia backend too. The format 0x3b issue is below the renderer layer.

### 3. Upgrade Flutter (did NOT fix in testing)
```bash
flutter upgrade
```
Tested: 3.41.9 → 3.44.0 stable — gralloc5 error unchanged. Also tested 3.45.0-0.1.pre beta — same result. Do not present Flutter upgrade as a likely fix for this issue.

### 4. Use an older Android device for mobile testing
Until Flutter patches gralloc5 format 0x3b support. No ETA from Flutter team as of 2026-06-01.

## What NOT to Do
- Don't rewrite your widget tree thinking it's a layout bug
- Don't remove `Stack`, `AnimatedBackground`, `CustomPaint`, etc. blindly
- Don't spend time on `MaterialApp`/`Scaffold`/`Container` color debugging
- Don't tell the user to upgrade Flutter as a primary fix — it won't work
- **Don't assume gralloc5 error = black screen** — The log message appears for all Flutter apps on Android 16, even ones that render correctly. Always verify with a `flutter create` control test AND a clean reinstall (`adb uninstall && adb install`) before concluding it's an engine bug. Cached APK state can cause black screens that have nothing to do with gralloc5.
- The screenshot will be black (15580 bytes for a 1080x2400 PNG — suspiciously small, indicating uniform color)

## Session References
- 2026-05-31: Initial discovery on Pixel 8a / Android 16 / Flutter 3.41.9
- 2026-06-01: Verified Flutter 3.44.0 stable and 3.45.0-0.1.pre beta also fail. Impeller disabled also fails. **However, clean uninstall/reinstall of the SAME code fixed the black screen — proving gralloc5 log is not always fatal.** The actual issue in that session was cached Android activity state, not gralloc5.
