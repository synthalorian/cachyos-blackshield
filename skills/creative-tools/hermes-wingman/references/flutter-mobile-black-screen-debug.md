# Flutter Mobile Black Screen Debug Checklist

Session: 2026-05-31 — Hermes Wingman APK loaded to black screen on Pixel Android device.

## Symptom
APK installs and launches (process starts, logcat shows Flutter engine init), but screen is completely black. No crash, no exception in logs.

## Diagnostic Path

### 1. Check if the device is locked (MOST COMMON FALSE POSITIVE)
```bash
adb shell dumpsys window displays | grep isKeyguardShowing
```
If `isKeyguardShowing=true`, the device is locked. Android stops the activity (`mStopped=true`) and Flutter cannot render. **This looks exactly like a black screen bug but is just the lock screen.**

Also verify:
```bash
adb shell dumpsys power | grep mWakefulness
```
If `mWakefulness=Dozing`, the device is dozing — wake it with:
```bash
adb shell input keyevent KEYCODE_WAKEUP
adb shell input keyevent KEYCODE_MENU
```

**Always unlock the device before concluding there's a rendering bug.**

### 2. Verify the app isn't crashing silently
```bash
adb logcat -d | grep -i "AndroidRuntime\|flutter\|FATAL"
```
If no crash → rendering issue, not a startup exception.

### 3. Check Flutter renderer backend
Look for:
```
Using the Impeller rendering backend (Vulkan).
```
If Vulkan Impeller is active, try disabling it:
```bash
flutter build apk --debug --no-enable-impeller
```

### 4. Check for `FlutterRenderer: Width is zero`
```
D FlutterRenderer: Width is zero. 0,0
```
This is normal during early startup but should resolve. If it persists:
- Check if `FlutterJNI: Sending viewport metrics to the engine` ever appears
- If metrics are never sent, the window isn't properly attached (activity may be stopped/locked)

### 5. Simplify the widget tree to isolate
Replace `home:` with the simplest possible widget:
```dart
home: Scaffold(body: Container(color: Colors.red, child: Center(child: Text('TEST')))),
```
If this renders → problem is in your shell/layout widgets. If still black → check device lock state (step 1) or engine issue (step 6).

### 6. Check for cached APK state BEFORE blaming gralloc5
**This is the most common cause of "it was working before" black screens.** Android caches activity state across installs. `force-stop` does NOT clear it. Do a clean reinstall FIRST:
```bash
adb uninstall com.example.hermes_wingman
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
If the app renders after clean reinstall → the black screen was cached state, NOT a code or engine bug. Only proceed to gralloc5 checks if clean reinstall fails.

### 7. Check for `gralloc5` engine-level black screen (Android 16)
If even a brand new `flutter create` app renders black after clean reinstall, check logcat:
```bash
adb logcat -d | grep gralloc5
```
If you see `ERROR: Unrecognized and/or unsupported format (0x3b)`, this may be a **Flutter engine ↔ Android 16 incompatibility** — but the gralloc5 log message appears for ALL Flutter apps on Android 16, even ones that render correctly. It is a **red herring** unless confirmed with a `flutter create` control test. See `references/flutter-android-16-gralloc5.md` for full diagnosis and workarounds.

### 7. Common widget-tree causes of black screens

| Cause | Fix |
|-------|-----|
| `Stack` child without `Positioned` gets zero size | Wrap in `Positioned.fill(child: ...)` |
| `Scaffold` inside `Stack` with transparent background | Give Scaffold an opaque `backgroundColor` |
| `CustomPaint` with `Size.infinite` inside unconstrained parent | Wrap in `SizedBox.expand` or give explicit size |
| `IndexedStack` with all children building heavy async content | Ensure at least one child renders synchronously |
| `Image.asset` failing to load (corrupted or too large) | Check asset is in APK: `unzip -l app.apk \| grep asset` |
| `SingleTickerProviderStateMixin` with animation controller never starting | Verify `_controller.forward()` is called |

### 8. Check asset bundling
```bash
unzip -l build/app/outputs/flutter-apk/app.apk | grep assets/
```
Missing assets won't throw at runtime — they'll just fail to render.

### 9. Screenshot verification loop
```bash
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png /tmp/screen.png
```
Faster than waiting for UI to appear on device.

## Session-Specific Findings

For Hermes Wingman specifically, the black screen was caused by a **cascade of issues**:

1. **Backend start blocked UI for 16s** — LAN scanning 57 hosts at 300ms each
2. **OS TCP timeout on Android** — `127.0.0.1:9120` connection refused took 7s per attempt despite Dart timeouts
3. **Device was locked during adb testing** — `isKeyguardShowing=true`, activity stopped, Flutter couldn't render. This was mistaken for a rendering bug for a significant portion of the session.
4. **Splash screen had heavy `Image.asset` (2.6MB PNG)** — may have failed silently on some devices
5. **`Stack` + `AnimatedBackground` + `Scaffold` combination** — potential sizing issue with `Colors.transparent` scaffold on top of custom paint

Fixes applied:
- Fast-fail localhost on mobile (instant instead of 7s)
- Removed LAN scanning from mobile path
- Made `backend.start()` non-blocking in `main()`
- Simplified splash screen to remove image dependency
- Removed `Stack` wrapper around `MainShell` body
- Added mobile connection banner for disconnected state

## Reference
- Flutter issue: Android `Socket.connect` timeout is not respected for localhost connections
- Dart `HttpClient.connectionTimeout` is advisory; OS TCP retry logic dominates
