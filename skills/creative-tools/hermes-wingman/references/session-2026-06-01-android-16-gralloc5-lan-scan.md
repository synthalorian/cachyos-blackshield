# Session 2026-06-01: Android 16 gralloc5 + mobile_scanner Black Screen

## Problem
Hermes Wingman APK rendered black screen on Pixel 8a / Android 16. User reported "it was working before."

## False Leads (all wrong)
1. **Device locked** — `isKeyguardShowing=false`, device was unlocked
2. **gralloc5 format 0x3b** — Logcat showed `ERROR: Unrecognized and/or unsupported format (0x3b)`. This is a **red herring** — it appears for ALL Flutter apps on Android 16 including working `flutter create` counter apps.
3. **Flutter version** — Upgraded 3.41.9 → 3.44.0 stable → 3.45.0 beta. No change.
4. **Impeller disable** — Added `EnableImpeller=false` to AndroidManifest.xml. No change.
5. **Old commits** — Checked out `fc767c7` (v1.0.0) and `d3d6555` (pre-v1.0). Still black.
6. **Splash screen PNG** — Replaced 2.6MB PNG with `Icon()`. No change.

## Root Cause
`mobile_scanner: ^7.2.0` package added in commit `5bca3ff` for QR code pairing. Its native Android code triggers a black screen on Android 16 that persists even when:
- The `MobileScanner` widget is gated behind `if (_isMobile)`
- The package is only imported, never instantiated
- The app is built from commits BEFORE the QR feature

The key: **Android caches APK state across installs.** `adb shell am force-stop` does NOT clear it. Only `adb uninstall` does.

## Verification
1. Brand new `flutter create` app → WORKS (proves engine is fine)
2. `adb uninstall com.example.hermes_wingman && adb install -r app.apk` → **FIXED** the black screen
3. Removing `mobile_scanner` from pubspec.yaml → also fixed rendering on fresh installs

## Key Commands
```bash
# The fix that actually worked
adb uninstall com.example.hermes_wingman
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Verify gralloc5 is a red herring (appears even for working apps)
adb logcat -d | grep gralloc5

# Verify with control test
flutter create --platforms=android /tmp/test_app
cd /tmp/test_app && flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Lesson
**When user says "it was working before" — ALWAYS do clean uninstall/reinstall FIRST.**
`adb shell am force-stop` is NOT enough. Android caches activity state, native libraries, and plugin registrant state across installs. A clean reinstall takes 10 seconds and eliminates the #1 source of "mysterious" black screens.

Only AFTER a clean reinstall fails should you investigate:
- Code changes (git bisect)
- Flutter version changes
- New packages (mobile_scanner, camera, etc.)
- Engine bugs (gralloc5 is a red herring on Android 16)

## Open Issue
`mobile_scanner: ^7.2.0` is incompatible with Android 16 / Pixel 8a. Need to find alternative QR scanner package or implement pairing without camera.
