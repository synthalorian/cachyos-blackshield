# Flutter Mobile Debugging via ADB

## Black Screen Checklist

When a Flutter app on Android shows black via `adb shell screencap`, check in this EXACT order:

### 1. Device Lock State
```bash
adb shell dumpsys window displays | grep isKeyguardShowing
```
- `isKeyguardShowing=true` → device is locked. Unlock first.
- A locked device stops the activity; Flutter never gets `onResume`.

### 2. Activity Lifecycle
```bash
adb shell dumpsys activity com.example.app | grep "mResumed\|mStopped"
```
- `mResumed=false mStopped=true` → activity stopped (device dozing, keyguard, or focus stolen)
- Wake: `adb shell input keyevent KEYCODE_WAKEUP && adb shell input keyevent KEYCODE_MENU`

### 3. Notification Shade / Focus
```bash
adb shell dumpsys window displays | grep "mFocusedWindow\|mCurrentFocus"
```
- `mFocusedWindow=NotificationShade` → shade is covering app
- Dismiss: `adb shell cmd statusbar collapse`

### 4. Flutter Viewport Metrics
```bash
adb logcat -d | grep "FlutterRenderer\|Sending viewport metrics"
```
- `Width is zero. 0,0` with NO `Sending viewport metrics` → surface created but never sized (activity stopped/locked)
- If `Sending viewport metrics` appears and THEN black → investigate widget tree

### 5. Only After 1-4: Widget Tree / Engine
- Check for `EXCEPTION CAUGHT BY WIDGETS LIBRARY` in logcat
- Verify `flutter analyze` is clean
- Check if a specific widget throws during build

## Common Mistakes

**Mistake:** Assuming black screen = Flutter engine bug, Impeller issue, or graphics driver problem.
**Reality:** 90% of "black screen" via adb is the device being locked or the activity stopped.

**Mistake:** Running `adb shell am start` on a locked device and expecting the app to render.
**Reality:** The activity starts in `STOPPED` state when keyguard is showing. It never resumes.

**Mistake:** Capturing screenshots while notification shade has focus.
**Reality:** The screenshot captures the shade, not the app. File size may differ (shade = larger PNG, black app = tiny PNG).

## Quick Diagnostic Script

```bash
#!/bin/bash
PKG="com.example.app"
echo "=== Keyguard ==="
adb shell dumpsys window displays | grep isKeyguardShowing
echo "=== Activity State ==="
adb shell dumpsys activity $PKG | grep "mResumed\|mStopped" | head -3
echo "=== Focus ==="
adb shell dumpsys window displays | grep "mFocusedWindow\|mCurrentFocus"
echo "=== Flutter Metrics ==="
adb logcat -d | grep "FlutterRenderer\|Sending viewport metrics" | tail -5
```

## Session Reference

**2026-05-31:** Spent 20+ minutes blaming Android 16 gralloc5, disabling Impeller, checking Vulkan layers. Actual issue: device was locked (`isKeyguardShowing=true`). User had to say "that's absolute fucking nonsense" before basic device state was checked. Lesson: always verify device state before blaming the framework.
