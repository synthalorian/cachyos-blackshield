# Session 2026-06-01: Hermes Wingman Mobile Diagnostic

## Problem
User reported Hermes Wingman mobile "isn't working." Device: Pixel 8a / Android 16.

## Diagnostic Process

### Step 1: Locate the project
Project is at `/home/synth/projects/hermes_wingman` (underscore, not hyphen). The `Projects/` and `projects/` directories both exist but only `projects/` has the repo.

### Step 2: Check git state
Working tree had uncommitted changes adding `mobile_scanner: ^7.2.0` and `qr_flutter: ^4.1.0` to pubspec.yaml. The `main.dart` had been updated to not block `runApp()` on backend connection — a correct mobile pattern.

### Step 3: Check installed APK vs. working tree
Logcat from the running app showed:
```
[BackendService] Saved URL failed — scanning LAN...
```
But `grep` for this string in the working tree returned **zero hits**. The installed APK was from older code that still had LAN scanning. The working tree already had the fast-fail localhost logic.

**Lesson: Always check if the installed APK matches the working tree before debugging.** Old log messages that don't exist in current source = stale build.

### Step 4: Clean uninstall/reinstall
```bash
adb uninstall com.example.hermes_wingman
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Fresh build installed successfully. No gralloc5 errors on startup.

### Step 5: Verify app startup
Logcat showed normal Flutter initialization:
```
Using the Impeller rendering backend (Vulkan).
The Dart VM service is listening on http://127.0.0.1:35493/...
[BackendService] Mobile mode — connecting to http://127.0.0.1:9120
WARNING: Backend failed to start: No backend configured. Tap to set your Hermes server IP.
```

**Key finding: `mobile_scanner` in pubspec.yaml did NOT cause gralloc5 errors on app startup.** The app initialized normally. This contradicts the earlier assumption that `mobile_scanner` native code loads at startup and immediately breaks rendering.

## Refined Understanding of `mobile_scanner` + Android 16

The earlier session (documented in `session-2026-06-01-android-16-gralloc5-lan-scan.md`) concluded that `mobile_scanner` causes black screen at app startup. However, this session shows:

1. **App startup is fine** with `mobile_scanner` in pubspec.yaml
2. **The gralloc5 crash likely happens when `MobileScanner` widget is instantiated** and camera preview initializes
3. **The earlier black screen was likely caused by cached APK state**, not `mobile_scanner` alone

**Revised diagnostic:**
- App black immediately on launch? → Clean reinstall first, then check cached state
- App launches fine, goes black when opening QR scanner? → `mobile_scanner` is the culprit

## Mobile Config Screen Pattern

The correct mobile bottom nav should include ConfigScreen (index 12) as the last tab:

```dart
static const _mobileIndexMap = [0, 1, 2, 4, 5, 7, 12];
```

When backend is not configured, navigate mobile users to Config tab instead of desktop Setup Wizard:

```dart
final targetIdx = _isDesktop ? 9 : 12;
if (mounted) setState(() => _selectedIndex = targetIdx);
```

The Config screen should show:
- Backend host/port input fields
- A "Scan" button that opens `QRScannerDialog` (gated to mobile only)
- Theme picker

## Connection Banner Pattern

When backend fails on mobile, show a tappable banner instead of silently failing:

```dart
final showConnectionBanner = state == BackendConnectionState.failed ||
    state == BackendConnectionState.notFound;

// In Scaffold body:
if (showConnectionBanner)
  _MobileConnectionBanner(
    scheme: scheme,
    onTap: () async {
      final ok = await WingmanSettings.showConnectionDialog(ctx);
      if (ok == true && ctx.mounted) {
        final settings = ctx.read<WingmanSettings>();
        final backend = ctx.read<BackendService>();
        backend.setBaseUrl(settings.backendHost, settings.backendPort);
        backend.reconnect();
      }
    },
  ),
```

## Commands Used

```bash
# Check device state
adb shell dumpsys window displays | grep isKeyguardShowing
adb shell dumpsys activity com.example.hermes_wingman | grep -E "mResumed|mStopped"

# Build and install fresh
JAVA_HOME=/usr/lib/jvm/java-21-openjdk flutter build apk --debug
adb uninstall com.example.hermes_wingman
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Check logs
adb logcat -d | grep -iE "gralloc|hermes|flutter|BackendService"
adb logcat -d | grep "mobile.scanner\|MobileScanner"
```
