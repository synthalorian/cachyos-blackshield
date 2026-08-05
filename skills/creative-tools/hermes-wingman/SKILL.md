---
name: hermes-wingman
description: "Hermes Wingman — the definitive GUI for Hermes Agent. Three editions in one monorepo: Flutter desktop/mobile + Rust backend + Rails 8 web dashboard."
version: 1.0.0
---

# Hermes Wingman

The definitive GUI for [Hermes Agent](https://hermes-agent.nousresearch.com) — desktop app, mobile app, and web dashboard. No CLI needed.

## Repository

**Monorepo:** https://github.com/synthalorian/hermes-wingman  
**Release:** https://github.com/synthalorian/hermes-wingman/releases/tag/v1.0.0

## Editions

| Edition | Stack | Location |
|---------|-------|----------|
| Desktop App | Flutter + Rust backend | `lib/`, `backend/` |
| Mobile App | Flutter (Android/iOS) | Same codebase |
| Web Dashboard | Rails 8.1 + Hotwire + Tailwind | `web/` |

## Development

```bash
git clone https://github.com/synthalorian/hermes-wingman.git
cd hermes-wingman

# Rust backend
cd backend && cargo build --release && cd ..

# Flutter desktop
eval "$(mise activate bash)" && flutter run -d linux

# Flutter mobile
JAVA_HOME=/usr/lib/jvm/java-21-openjdk flutter build apk --debug

# Rails web
cd web && bundle install && bin/rails tailwindcss:build && bin/rails server
```

## Key Files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Flutter config, v1.0.0+5 |
| `backend/Cargo.toml` | Rust workspace |
| `backend/src/main.rs` | Axum server entry |
| `backend/openapi.yaml` | API spec |
| `web/Gemfile` | Rails dependencies |
| `web/config/routes.rb` | Rails routes |

## Build Notes

- Android requires JDK 21+: `JAVA_HOME=/usr/lib/jvm/java-21-openjdk`
- Backend binds to `BIND_ADDR` (default `127.0.0.1:9120`, set to `0.0.0.0:9120` for LAN)
- Web expects backend at `HERMES_BACKEND_URL` (default `http://127.0.0.1:9120`)
- `flutter analyze` must be clean (zero issues)
- `cargo check` must pass clean (zero warnings)
- **Web app (`web/`):** `bundle install`, `bin/rails db:migrate`, then `bin/rails server`. No separate `tailwindcss:build` task needed — CSS is pre-built in `app/assets/builds/tailwind.css`
- **Verify Rails controllers exist for all routes:** `bin/rails routes | awk '{print $4}' | sort -u` then `bin/rails runner "puts <Name>Controller"` for each

## Code Quality Standards

### Web (Rails)
- **DRY HTTP service**: Single `request(method, path, body)` dispatcher, not separate `post`/`put`/`delete` methods with duplicate HTTP setup
- **Centralized error handling**: `rescue_from HermesApiService::BackendError` in `ApplicationController`, not per-action rescue blocks
- **Endless method syntax**: Use Ruby 3.1+ `def action = render(json: ...)` for one-liner API actions
- **Shared error partials**: `views/shared/_backend_error.html.erb` for consistent error display

### Flutter
- `flutter analyze` must pass clean (zero issues) before commit
- Every widget accepts `AppColorScheme scheme` parameter for theme consistency
- Provider pattern: use `context.watch<ThemeManager>().currentScheme`

### Rust Backend
- `cargo check` must pass, `cargo fix --allow-dirty` for auto-fixable warnings
- 24 modular files in `src/handlers/`, not a monolithic `main.rs`

## Themes

29 themes: Synthwave '84 (flagship), 20 Greek god pantheon, 5 retro, 2 standard

## Pitfalls

### Mobile (Android)
- **Black screen during adb testing? Check if device is locked first** — Before debugging widget tree or Flutter engine issues, verify `adb shell dumpsys window displays | grep isKeyguardShowing`. If `true`, the device is locked and Android stops the activity (`mStopped=true`). The app will show black because the activity lifecycle is paused. Unlock the device before testing. This is easy to mistake for a rendering bug.
- **Never block `runApp()` on backend connection** — Mobile backends are remote and may be unavailable. Start the backend connection in a `Future` (not `await`ed) and let the UI render immediately with a "connecting" or "disconnected" state. Use `ChangeNotifier` on `BackendService` so UI reacts when state changes.
  ```dart
  // BAD — blocks UI for seconds
  final started = await backend.start(timeout: ...);
  runApp(...);

  // GOOD — UI renders immediately, backend connects in background
  backend.start(timeout: ...).then((started) { ... });
  runApp(...);
  ```
- **Fast-fail localhost on mobile** — `127.0.0.1`/`localhost` on a phone has no Hermes backend. The OS TCP stack will retry for 3-7 seconds before failing, even with short Dart timeouts. Detect localhost upfront and fail instantly with a user-friendly message.
  ```dart
  final host = Uri.parse(baseUrl).host;
  if (host == '127.0.0.1' || host == 'localhost') {
    _state = failed;
    _lastError = 'No backend configured. Tap to set your Hermes server IP.';
    return false;
  }
  ```
- **Skip LAN discovery on mobile** — Scanning private subnets drains battery and adds 10-20s to startup. If the configured backend URL fails, show a configuration prompt instead of auto-scanning.
- **Show a connection banner when backend fails on mobile** — Instead of silently failing, render a tappable banner that opens a host/port config dialog and triggers reconnect.
- **Black screen on mobile? Check OS-level TCP timeouts** — On Android, `Socket.connect(host, port, timeout: Duration(...))` and `HttpClient.connectionTimeout` are advisory only. The OS TCP stack enforces its own retry logic (3-7s for localhost connection refused). If your app does health checks to `127.0.0.1` on mobile, the startup will hang for seconds even with short Dart timeouts. Fix: fast-fail localhost on mobile since there's never a local backend on the phone.
- **`system_tray` package has no Android implementation** — It won't crash (Flutter's plugin registrant skips it), but keep it in `pubspec.yaml` and use conditional Dart imports (`if (dart.linux)` etc.) so desktop gets the real tray and mobile gets the stub.
- **Platform-specific UI must gate platform-specific packages** — `mobile_scanner`, `camera`, `local_auth`, etc. only work on mobile. Always wrap their widgets/buttons in `if (Platform.isAndroid || Platform.isIOS)` so desktop doesn't render a broken action. The package won't crash on desktop (plugin registrant skips it), but pushing a `MobileScanner` route on Linux shows a black screen or no-op. Example:
  ```dart
  final bool _isMobile = Platform.isAndroid || Platform.isIOS;
  // ...
  if (_isMobile)
    IconButton(
      icon: Icon(Icons.qr_code_scanner),
      onPressed: () => Navigator.push(context, QRScannerDialog()),
    ),
  ```
- **NEVER use library-level `final` for platform checks** — Declaring `final bool _isMobile = Platform.isAndroid || Platform.isIOS;` at file scope caches the value at library load time. On some Flutter build configurations (release APK, tree-shaking), this evaluates before `Platform.operatingSystem` is populated, permanently caching `false`. Always compute platform checks inside `build()` or use a getter. See `references/flutter-platform-detection-pitfall.md` for full details.
  ```dart
  // BAD — caches at library load, may be wrong on release builds
  final bool _isMobile = Platform.isAndroid || Platform.isIOS;

  // GOOD — re-evaluates every time, always correct
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  ```
- **Use debug builds for iterative mobile testing** — `flutter build apk --debug` is 2-3x faster than `--release` and includes Dart asserts. Install with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. Only build `--release` for final distribution. Debug builds also show stack traces and allow hot reload if running via `flutter run`.
- **Force-stop before reinstalling** — Android's activity lifecycle can cache the old APK state. Always `adb shell am force-stop com.example.hermes_wingman` before testing a fresh install, or uninstall completely: `adb uninstall com.example.hermes_wingman && adb install ...`
- **Large PNG in splash screen causes black screen on Android** — A 2.6MB PNG loaded via `Image.asset()` in the splash screen widget failed to decode, hanging the render thread and preventing the app from ever rendering. The gralloc5 log message on Android 16 is a **red herring** — it appears for all Flutter apps but does not cause black screens. Fix: replace the image with an `Icon()` widget, compress the PNG, or use SVG. Always check splash screen assets before chasing engine-level errors. See `references/flutter-splash-screen-png-hang.md`.
- **Clean uninstall + reinstall is the FIRST step for any "it was working before" report** — `adb shell am force-stop` does NOT fully clear cached activity state. A full `adb uninstall` followed by `adb install` is required to eliminate cached-state false positives. This should be done BEFORE upgrading Flutter, checking out old commits, or investigating gralloc5. The gralloc5 log message on Android 16 is a **red herring** — it appears for all Flutter apps but does not necessarily cause black screens. See `references/session-2026-06-01-android-16-gralloc5-lan-scan.md` for the full session where a clean reinstall fixed a black screen that was misdiagnosed as gralloc5, Impeller, and Flutter version issues.
- **Non-interactive git rebase when editor hangs** — If `git rebase --continue` opens an interactive editor (nvim/vim) that hangs in terminal-less contexts, use `GIT_EDITOR=true git rebase --continue` to accept the default message and continue without an editor.
- **Flutter + Android 16 black screen = check cached state FIRST, then gralloc5** — If even a brand new `flutter create` app renders black on a physical device, the FIRST step is a clean `adb uninstall && adb install`. If that fixes it, the issue was cached APK state — NOT gralloc5, NOT Impeller, NOT your code. Only if clean reinstall fails should you check logcat for `gralloc5: ERROR: Unrecognized and/or unsupported format`. This is a Flutter engine ↔ Android graphics HAL incompatibility (seen on Pixel 8a / Android 16 with Flutter 3.41.9 through 3.45.0 beta). **Upgrading Flutter and disabling Impeller do NOT fix this.** The only confirmed workaround is testing on an emulator or Android 15 device. NOT a code bug in your app — verify with `flutter create` control test AND clean reinstall before debugging widget tree. See `references/flutter-android-16-gralloc5.md` for full details.
- **`mobile_scanner` package may cause issues on Android 16** — `mobile_scanner: ^7.2.0` native Android code has been observed interacting poorly with Android 16's gralloc5 HAL when the camera preview initializes. **Note: the app may start normally** — the black screen occurs when navigating to the QR scanner route, not at app startup. If you recently added `mobile_scanner` and the app goes black only when opening the scanner, try removing it as a diagnostic step. However, **always do a clean uninstall/reinstall FIRST** before blaming packages — Android's activity lifecycle can cache old APK state and cause black screens that have nothing to do with code changes. The gralloc5 log message is normal on Android 16 and does not indicate a fatal error by itself. See `references/session-2026-06-01-android-16-gralloc5-lan-scan.md` for full session transcript.
- **When the user says "it was working before" — do a clean reinstall FIRST** — Before upgrading Flutter, checking out old commits, disabling Impeller, or blaming gralloc5, always try the simplest fix: `adb uninstall com.example.hermes_wingman && adb install -r app.apk`. Android caches activity state across installs and `force-stop` does not always clear it. A clean reinstall takes 10 seconds and eliminates cached-state false positives. **Also verify the installed APK matches your working tree** — if logcat shows old log messages (e.g., `Saved URL failed — scanning LAN...`) that don't exist in the current source, the device has a stale build. Only after a clean reinstall fails should you investigate code changes, toolchain versions, or engine bugs. The gralloc5 log message on Android 16 is a **red herring** — it appears for all Flutter apps but does not necessarily cause black screens. See `references/session-2026-06-01-android-16-gralloc5-lan-scan.md` for the full session transcript.
- **`mobile_scanner` package triggers gralloc5 black screen on Android 16 when camera preview starts** — The `mobile_scanner: ^7.2.0` package's native Android code causes gralloc5 format 0x3b errors on Android 16 (Pixel 8a). **Crucially, the app may start and render normally** — the crash happens when the `MobileScanner` widget is instantiated and the camera preview initializes, not at app startup. This means you can have `mobile_scanner` in `pubspec.yaml` and the app will launch fine; the black screen only occurs when navigating to the QR scanner route. If the app is black immediately on launch, suspect cached APK state first (see below). If the app launches fine but goes black when opening the scanner, THEN remove `mobile_scanner` from pubspec.yaml as a diagnostic step. Consider alternative QR packages (`qr_code_scanner`, `fast_qr_reader_view`) or implement QR pairing via a different mechanism. See `references/session-2026-06-01-android-16-gralloc5-lan-scan.md` for full session transcript.
- **`mobile_scanner` import won't crash desktop but needs gating** — The `mobile_scanner` package has no Linux/macOS/Windows implementation, but Flutter's plugin registrant silently skips it. Importing `package:mobile_scanner/mobile_scanner.dart` at the top of a shared file is safe. However, actually instantiating `MobileScanner()` on desktop shows a black screen. Always gate the scanner widget/route behind a platform check. The import itself can stay unconditional.
  ```dart
  // Safe: import at top of shared file
  import 'package:mobile_scanner/mobile_scanner.dart';

  // Required: gate the widget
  if (_isMobile) {
    Navigator.push(context, QRScannerRoute());
  }
  ```
- **Mobile bottom nav must include ConfigScreen if QR pairing is needed** — The `_mobileIndexMap` in `main_shell.dart` controls which desktop screens are reachable on mobile. If ConfigScreen (index 12) is not in the map, the QR scanner and connection settings are unreachable. The last tab should be ConfigScreen so mobile users can set their backend IP and scan QR codes:
  ```dart
  // BAD — "Settings" maps to ProfilesScreen (10), ConfigScreen (12) unreachable
  static const _mobileIndexMap = [0, 1, 2, 4, 5, 7, 10];

  // GOOD — last tab is ConfigScreen with QR scanner + connection dialog
  static const _mobileIndexMap = [0, 1, 2, 4, 5, 7, 12];
  ```
  Also update `_mobileNavItems` label to match: `NavItem('Config', Icons.settings_outlined, '')`.
  When the backend is not configured on mobile, navigate to the Config tab (index 12) instead of the desktop Setup Wizard (index 9):
  ```dart
  final targetIdx = _isDesktop ? 9 : 12;
  if (mounted) setState(() => _selectedIndex = targetIdx);
  ```
- **LAN discovery may still be present in code despite skill guidance** — If logcat shows `Saved URL failed — scanning LAN...` on mobile, the LAN scan path was not fully removed. The skill says to skip LAN discovery on mobile, but the actual code may still contain it. Check `BackendService.start()` and ensure mobile does NOT call subnet scanning — show a config prompt immediately instead.

### Desktop / Build
- **Java 25 breaks Gradle** — Flutter Android builds require JDK 21: `JAVA_HOME=/usr/lib/jvm/java-21-openjdk`. Java 25 causes `java.lang.IllegalArgumentException: 25.0.3` in `JavaVersion.parse`.
- **Axum extractors must be `pub`** — When modularizing the Rust backend into `src/handlers/*.rs`, any struct used as an Axum route extractor (e.g. `SwitchModelRequest`, `ProbeRequest`, `FileListQuery`) must be declared `pub struct`, not `struct`. Otherwise you get 22 "type is private" errors.
- **`cargo fix` saves time** — After modularization refactors, `cargo fix --bin <name> --allow-dirty` auto-applies fixable warnings. 33 → 5 warnings in one command.
- **Unreachable pattern in match arms** — In `gateway.rs`, `"curl" | "auto" =>` already matches `"auto"`, so a later `"pip" | "auto" =>` arm is unreachable. Remove the duplicate `"auto"` from subsequent arms.
- **Dead code structs** — Unused Axum extractor structs (`SessionsQuery`, `MemorySearchQuery`, `SkillToggleParams`) that are never constructed should be removed, not left as warnings. Check if they're used in route signatures; if not, delete them.
- **Unused serde imports** — After removing dead structs, clean up `use serde::{Deserialize};` → remove entirely or narrow to only what's used (`Serialize`, `Deserialize`, or neither).
- **Reserved fields need `#[allow(dead_code)]`** — Fields like `auth_urls` in `AppState` that are reserved for future OAuth flows but currently unused should get `#[allow(dead_code)]` to keep the build clean without deleting intentional scaffolding.
- **Rails: Don't shadow `ActionController#session`** — Naming a controller action `session` causes infinite recursion because it shadows the built-in `session` hash accessor. The layout calls `session[:theme]` which recursively hits the action. Always name it `session_detail` or similar.
- **Rails: Missing controller files** — If a route exists but the controller file doesn't, Rails throws `ActionDispatch::MissingController` at runtime (not boot time). Verify all routes have matching controller files with `bin/rails routes | grep <name>` and `bin/rails runner "puts <Name>Controller"`.
- **Rails: Use `image_tag` not raw `<img src>`** — Propshaft (Rails 8 asset pipeline) fingerprints assets. Raw `<img src="/assets/foo.png">` bypasses fingerprinting and 404s in production. Use `<%= image_tag "foo.png", ... %>` instead.
- **Web repo archived** — The old `hermes-wingman-web` standalone repo is deprecated; everything is in the monorepo at `web/`.

### Reference Files
- `references/web-code-patterns.md` — DRY service dispatcher, rescue_from pattern, before/after line counts
- `references/rust-backend-modularization.md` — Axum extractor visibility, quick fix script, affected types
- `references/rust-warning-fixes.md` — Concrete recipes for fixing cargo warnings (unreachable patterns, dead code, unused imports)
- `references/rails-web-bug-fixes.md` — Missing controller files, action shadowing built-ins, asset pipeline gotchas
- `references/rails-dev-server-startup.md` — Background server startup with health check (subprocess.Popen pattern, port cleanup)
- `references/flutter-mobile-black-screen-debug.md` — Diagnostic checklist for Flutter APK black screens: OS TCP timeouts, widget-tree sizing, gralloc5 engine incompatibility on Android 16
- `references/flutter-android-16-gralloc5.md` — Full deep-dive on the Android 16 gralloc5 format 0x3b black screen issue. **Key finding: Flutter upgrades (3.44.0 stable, 3.45.0 beta) and Impeller disable do NOT fix it.** Only workaround is Android 15 device or emulator.
- `references/session-2026-06-01-android-16-gralloc5-lan-scan.md` — Real session transcript: `mobile_scanner` package triggers gralloc5 black screen on Android 16 even when widget is gated. Removing the package fixes rendering. QR pairing disabled on Android 16 until alternative found.
- `references/session-2026-06-01-mobile-diagnostic.md` — Refined understanding: `mobile_scanner` does NOT crash at app startup; the gralloc5 black screen happens when camera preview initializes. Stale APK vs. working tree mismatch detection. Mobile ConfigScreen nav pattern and connection banner.
- `references/flutter-regression-debug.md` — When the user says "it was working before": check git history FIRST, not the toolchain
- `references/flutter-platform-detection-pitfall.md` — Why `final bool _isMobile = Platform.isAndroid` at library scope fails on some builds, and the getter/build-time fix
- `references/flutter-desktop-deployment.md` — Linux desktop deployment: binary + data/ + lib/ layout, XDG directory pitfalls, verification commands
- `references/flutter-splash-screen-png-hang.md` — Large PNG in splash screen causes black screen on Android. 2.6MB image fails to decode, hangs render thread. Replace with Icon() or compress. gralloc5 is a red herring.
- `references/qr-code-pairing.md` — Desktop-to-mobile QR pairing: QrImageView setup, MobileScanner overlay, IP:PORT parsing, backend binding requirements, same-network troubleshooting

Flutter Linux embedders resolve `data/flutter_assets/` relative to the executable path. The binary, `data/`, and `lib/` must be co-located.

**Target layout (Omarchy / Arch):**
```
~/.local/bin/hermes_wingman          # binary
~/.local/bin/data/flutter_assets/    # Flutter assets
~/.local/bin/data/icudtl.dat
~/.local/bin/lib/libapp.so
~/.local/bin/lib/libflutter_linux_gtk.so
~/.local/bin/lib/...                 # other .so files
```

**Deploy after building:**
```bash
# Copy binary
cp build/linux/x64/release/bundle/hermes_wingman ~/.local/bin/hermes_wingman

# Copy data/ and lib/ (Flutter resolves these relative to binary)
cp -r build/linux/x64/release/bundle/data/* ~/.local/bin/data/
cp -r build/linux/x64/release/bundle/lib/* ~/.local/bin/lib/
```

**Pitfall:** Putting `data/` in `~/.local/share/hermes-wingman/` or `lib/` in `~/.local/lib/hermes-wingman/` will NOT work. The embedder looks for `data/` next to the executable, not in XDG directories. The `.desktop` file and wrapper script launch the binary directly from `~/.local/bin/`.

**Verify deployment:**
```bash
diff -rq build/linux/x64/release/bundle/data/flutter_assets/ \
  ~/.local/bin/data/flutter_assets/
cat ~/.local/bin/data/flutter_assets/version.json
```

## Release Workflow

```bash
# 1. Verify everything
flutter analyze
cd backend && cargo check && cargo test && cd ..
cd web && bundle check && bin/rails db:migrate:status && cd ..
flutter test

# 2. Build all targets
flutter build linux --release
JAVA_HOME=/usr/lib/jvm/java-21-openjdk flutter build apk --release
cd backend && cargo build --release && cd ..

# 3. Install APK on connected device
adb install -r build/app/outputs/flutter-apk/app-release.apk

# 4. Deploy desktop binary + data + lib
cp build/linux/x64/release/bundle/hermes_wingman ~/.local/bin/
cp -r build/linux/x64/release/bundle/data/* ~/.local/bin/data/
cp -r build/linux/x64/release/bundle/lib/* ~/.local/bin/lib/

# 5. Verify desktop deployment
ls -la ~/.local/bin/hermes_wingman ~/.local/bin/lib/libapp.so \
  ~/.local/bin/data/flutter_assets/version.json
diff -rq build/linux/x64/release/bundle/data/flutter_assets/ \
  ~/.local/bin/data/flutter_assets/ && echo "SYNCED"

# 6. Commit and tag
git add -A && git commit -m "chore: ship vX.Y.Z"
git tag -d vX.Y.Z 2>/dev/null  # delete local if exists
git push origin :refs/tags/vX.Y.Z 2>/dev/null  # delete remote if exists
git tag -a vX.Y.Z -m "vX.Y.Z: description"
git push origin main --tags

# 7. Create release with APK
gh release delete vX.Y.Z --yes 2>/dev/null
gh release create vX.Y.Z \
  --title "vX.Y.Z — description" \
  --notes-file CHANGELOG.md \
  build/app/outputs/flutter-apk/app-release.apk
```
