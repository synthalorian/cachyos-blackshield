# Packaging & Distribution

Pattern: Building a self-contained Linux distribution archive (AppDir + .tar.gz) with systemd integration for a Rust HTTP backend + Flutter app.

## AppDir Structure

```
AppDir/
├── AppRun                              # Entry point — starts backend, then Flutter
├── hermes-wingman.desktop              # Desktop entry for app launchers
├── hermes-wingman.png                  # App icon (converted from SVG)
└── usr/bin/
    ├── hermes_wingman                  # Flutter release binary
    ├── hermes-wingman-backend          # Rust backend binary
    ├── data/
    │   ├── flutter_assets/             # Flutter asset bundle
    │   └── icudtl.dat                  # ICU data for Flutter
    └── lib/
        ├── libapp.so                   # Flutter app DSO
        ├── libdartjni.so               # Dart JNI bridge
        └── libflutter_linux_gtk.so     # Flutter engine
```

## AppRun Entry Point

The AppRun starts the backend in the background, waits for it to become healthy, then launches the Flutter app:

```bash
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="$HERE/usr/bin:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:$LD_LIBRARY_PATH"

# Start backend in background
"$HERE/usr/bin/hermes-wingman-backend" &
BACKEND_PID=$!

# Wait for backend to be ready (up to 6 seconds)
for i in $(seq 1 20); do
  if curl -s http://127.0.0.1:9120/health > /dev/null 2>&1; then
    break
  fi
  sleep 0.3
done

# Launch the Flutter app
cd "$HERE/usr/bin"
exec ./hermes_wingman "$@"
```

**PITFALL:** The backend and Flutter app both try to bind if started simultaneously. The AppRun starts the backend first, waits for health, then launches Flutter. The Flutter `BackendService.start()` detects the running backend via port probe and connects instead of starting a duplicate.

**PITFALL:** The Flutter app uses `dart:io` `Process` for subprocess management. When the AppRun already started the backend, `Process.start()` is never called — `BackendService` finds port 9120 open and skips binary discovery.

## Development Build → Instant Launcher Pickup

When iterating on development builds, add a deploy step to your build script that copies the full bundle to `~/.local/bin/` after every build. This makes desktop launchers (Walker, Rofi, dmenu) always pick up the latest binary without manual copy steps.

### The Chain

```
build.sh → copies full bundle to ~/.local/bin/ → wrapper script → desktop launcher finds it
```

### What to Deploy

The Flutter bundle on Linux is more than just the executable — it requires shared libraries (`lib/`) and assets (`data/`) at runtime. Copy the entire bundle:

```bash
# After flutter build linux --release:
echo "  ▸ Deploying to ~/.local/bin/..."
mkdir -p "$HOME/.local/bin" "$HOME/.local/bin/lib"

# Main Flutter executable
cp build/linux/x64/release/bundle/hermes_wingman "$HOME/.local/bin/"

# Shared libraries (libapp.so, libflutter_linux_gtk.so, plugin .so files)
cp -r build/linux/x64/release/bundle/lib/* "$HOME/.local/bin/lib/"

# Backend binary (if applicable)
cp backend/target/release/hermes-wingman-backend "$HOME/.local/bin/"

chmod +x "$HOME/.local/bin/hermes_wingman" "$HOME/.local/bin/hermes-wingman-backend"
echo "  ✓ Deployed — launcher shortcut will pick up the latest build"
```

### Why This Works

- The `.desktop` file (`~/.local/share/applications/hermes-wingman.desktop`) points to a wrapper script at `~/.local/bin/hermes-wingman-wrapper`
- The wrapper sets `LD_LIBRARY_PATH` to `~/.local/bin/lib` and execs `~/.local/bin/hermes_wingman`
- The systemd service (if used for a backend) also points to `~/.local/bin/hermes-wingman-backend`
- Every `./build.sh linux` replaces all three — new binary, new libs, new backend

### Wrapper Script Pattern

```bash
#!/bin/bash
LIB_DIR="$HOME/.local/bin/lib"
export LD_LIBRARY_PATH="$LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HOME/.local/bin/hermes_wingman" "$@"
```

### Desktop File (Absolute Path Required)

Desktop launchers do NOT inherit the user's shell `$PATH`. Use an absolute path:

```ini
[Desktop Entry]
Exec=/home/user/.local/bin/hermes-wingman-wrapper
Icon=hermes-wingman
```

### Pitfalls

- **Backend binary in use**: If the backend is running (via systemd), `cp` fails with "Text file busy". Stop the service first: `systemctl --user stop hermes-wingman.service`, copy, then restart.
- **Full bundle required**: Copying only `hermes_wingman` without `lib/libapp.so` and `data/flutter_assets/` causes "Failed to create AOT data" at startup. Always copy the entire `lib/` directory.
- **`LD_LIBRARY_PATH` must be set**: Without it, `libapp.so` and plugin .so files aren't found at runtime. The wrapper handles this.
- **Embedded backend**: If the Flutter app spawns the backend subprocess, the backend binary must be in the same directory as the Flutter binary (or discoverable through `Platform.resolvedExecutable`). Deploy both together.
- **Self-updating binaries**: If the user runs the app while a build is in progress, the old binary stays in memory. Only the NEXT launch picks up the fresh copy.

## System Install: Full Bundle Required

When installing a Flutter Linux app system-wide (not via AppImage), you MUST copy the ENTIRE bundle structure alongside the binary. The Flutter engine requires `data/flutter_assets/` and `lib/libapp.so` at runtime. **Copying only the executable crashes with 'Failed to create AOT data'.**

### WRONG (app crashes)
```bash
cp build/linux/x64/release/bundle/hermes_wingman ~/.local/bin/
# hermes_wingman runs → "Invalid ELF path specified" → crash
# Missing: data/flutter_assets/, lib/libapp.so
```

### RIGHT (full bundle copy)
```bash
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# 1. Main executable
cp build/linux/x64/release/bundle/hermes_wingman "$BIN_DIR/"

# 2. data/ directory — flutter_assets + icudtl.dat
cp -r build/linux/x64/release/bundle/data "$BIN_DIR/"

# 3. All shared libraries (libapp.so is critical, plus plugin .so files)
mkdir -p "$BIN_DIR/lib"
cp build/linux/x64/release/bundle/lib/*.so "$BIN_DIR/lib/"

# 4. Backend binary
cp backend/target/release/hermes-wingman-backend "$BIN_DIR/"
```

### Full installed layout
```
~/.local/bin/
├── hermes_wingman              # Flutter executable
├── hermes-wingman-backend      # Backend binary
├── data/
│   ├── flutter_assets/         # REQUIRED — Flutter asset bundle
│   └── icudtl.dat              # REQUIRED — ICU data
├── lib/
│   ├── libapp.so               # REQUIRED — AOT-compiled Dart code
│   ├── libflutter_linux_gtk.so # REQUIRED — Flutter engine
│   └── libsystem_tray_plugin.so # Plugin libs
└── hermes-wingman-wrapper      # Launcher wrapper (sets LD_LIBRARY_PATH)
```

### Wrapper Script

Flutter plugin shared libraries are NOT in the system library path. A wrapper script must set `LD_LIBRARY_PATH`:

```bash
#!/bin/bash
LIB_DIR="$HOME/.local/bin/lib"
export LD_LIBRARY_PATH="$LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HOME/.local/bin/hermes_wingman" "$@"
```

### Desktop File with Absolute Path

Walker, Rofi, and other launchers do NOT inherit the user's shell PATH. Use an absolute path:

```ini
[Desktop Entry]
Exec=/home/user/.local/bin/hermes-wingman-wrapper
```

**PITFALL:** The `Exec=` path in the .desktop file must be an absolute path. `~/.local/bin/` is NOT in the PATH that desktop launchers inherit. They only get the default system PATH (/usr/bin, /bin).

### Verification
```bash
# Check that all shared libraries resolve
ldd ~/.local/bin/hermes_wingman | grep "not found"
# Should return empty — all libs found

# Test launch from clean CWD
cd /tmp && ~/.local/bin/hermes-wingman-wrapper
# Watch for "Failed to create AOT data" — if present, data/ or lib/ is missing
```

## Systemd User Service

Place at `~/.config/systemd/user/hermes-wingman.service`:

```ini
[Unit]
Description=Hermes Wingman Backend
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/hermes-wingman-backend
Restart=on-failure
RestartSec=3
Environment=PAGER=cat

[Install]
WantedBy=default.target
```

Activate:
```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-wingman
```

This keeps the backend running persistently (survives app restarts, starts on login).

**PITFALL:** The systemd service should manage ONLY the Rust backend, NOT the Flutter GUI. The GUI is launched independently from the desktop entry or terminal. systemd user services are meant for daemons, not for interactive GUI apps.

## Packaging Script

The `dist/package.sh` script:
1. Builds Rust backend (`cargo build --release`)
2. Builds Flutter app (`flutter build linux --release`)
3. Copies fresh binaries + assets into AppDir
4. Generates PNG icon from SVG (uses `rsvg-convert` or `convert`)
5. Writes AppRun with backend lifecycle logic
6. Writes .desktop file with version
7. Creates `.tar.gz` archive

```bash
# Usage
bash dist/package.sh          # full build + package
bash dist/package.sh --skip-build  # package only (reuse existing build)
```

## System-Wide Install Script

The `dist/install.sh` script:
1. Copies Flutter binary to `$PREFIX/bin/`
2. Copies backend binary to `$PREFIX/bin/`
3. Copies data/ and lib/ directory (full bundle) to `$PREFIX/bin/`
4. Installs desktop entry to `$PREFIX/share/applications/`
5. Installs icon to `$PREFIX/share/icons/hicolor/256x256/apps/`
6. Creates and enables systemd user service

```bash
# Install to ~/.local
bash dist/install.sh

# Install to custom prefix
bash dist/install.sh /opt/hermes-wingman
```

## Build Scripts (Per-Platform)

**IMPORTANT:** Rust+Flutter desktop apps targeting macOS or Windows MUST be built on their respective platforms. Cross-compilation from Linux is not practical for Flutter desktop (macOS requires Xcode, Windows requires MSVC toolchain). Each platform has its own build script:

### Linux — `./build.sh linux`
```bash
./build.sh linux       # Full build + tar.gz packaging
```
1. `cargo build --release` (backend)
2. `flutter build linux --release`
3. Copies backend into `build/linux/x64/release/bundle/`
4. Runs `dist/package.sh --skip-build` to create AppDir + tar.gz

### macOS — `./build_macos.sh`
```bash
./build_macos.sh       # Full build + .app bundle + zip
```
1. `cargo build --release` (backend)
2. `flutter build macos --release`
3. Copies backend into `.app/Contents/MacOS/` bundle
4. Generates `.icns` icon from SVG (via `rsvg-convert` + `iconutil`)
5. Creates distributable `hermes-wingman-macos.zip`

**macOS .icns icon generation pattern:**
```bash
# Requires librsvg (rsvg-convert) + Apple iconutil
mkdir -p /tmp/icon.iconset
for size in 16 32 64 128 256 512; do
    rsvg-convert -w $size -h $size assets/icons/app-icon.svg \
        -o "/tmp/icon.iconset/icon_${size}x${size}.png"
    # Also generate @2x variants for Retina
    if [ $size -lt 512 ]; then
        rsvg-convert -w $((size*2)) -h $((size*2)) assets/icons/app-icon.svg \
            -o "/tmp/icon.iconset/icon_${size}x${size}@2x.png"
    fi
done
iconutil -c icns /tmp/icon.iconset -o "$APP_PATH/Contents/Resources/app-icon.icns"
rm -rf /tmp/icon.iconset
# Set the icon in Info.plist
plutil -replace CFBundleIconFile -string "app-icon" "$APP_PATH/Contents/Info.plist"
```

**PITFALL:** `iconutil` is part of Xcode command line tools (`xcode-select --install`). `rsvg-convert` must be installed separately (`brew install librsvg`). Without both, skip icon generation — the .app will use the default Flutter icon.

**PITFALL:** The `.iconset` directory MUST follow Apple's naming convention exactly: `icon_16x16.png`, `icon_32x32.png`, `icon_128x128.png`, `icon_256x256.png`, `icon_512x512.png`, plus `@2x` variants at `icon_16x16@2x.png` (= 32px), `icon_32x32@2x.png` (= 64px), etc. Missing sizes or misnamed files cause `iconutil` to fail silently and produce an empty `.icns`.

Requires: Xcode command line tools, Rust macOS target, Flutter macOS SDK.

### Windows — `.\build_windows.ps1`
```powershell
.\build_windows.ps1    # Full build + .exe directory
```
1. `cargo build --release` (backend)
2. `flutter build windows --release`
3. Copies `hermes-wingman-backend.exe` into the release directory
4. App icon stored alongside the binary for shortcut creation

Requires: Visual Studio Build Tools, Rust Windows MSVC target, Flutter Windows SDK.

**PITFALL:** The Windows build script is PowerShell (`.ps1`), not bash. On Windows, run it from PowerShell or integrate into CI using `pwsh` on GitHub Actions Windows runners.

## CI Workflow Pattern

For GitHub Actions or similar:
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rust-lang/setup-rust-toolchain@v1
      - uses: subosito/flutter-action@v2
      - run: bash dist/package.sh
      - uses: actions/upload-artifact@v4
        with:
          name: hermes-wingman
          path: dist/hermes-wingman-*.tar.gz
```
