# Linux Desktop Walker Integration for Flutter Apps

## Overview

Getting a Flutter Linux desktop app to appear in Walker (app launcher) and launch correctly requires three components:
1. `.desktop` file in `~/.local/share/applications/`
2. Icon in `~/.local/share/icons/hicolor/` (XDG standard)
3. Deployed binary + native .so in `~/.local/share/<app>/`

## The Full Deployment Chain

After `flutter build linux --release`:

```bash
# 1. Build native .so (if C++ code changed)
cd native/build && cmake .. && make -j$(nproc)

# 2. Copy native .so into Flutter bundle
cp native/libopenamp_dart_ffi.so build/linux/x64/release/bundle/lib/

# 3. Install icon to hicolor theme
mkdir -p ~/.local/share/icons/hicolor/512x512/apps/
cp assets/icon.png ~/.local/share/icons/hicolor/512x512/apps/open_synth.png

# 4. Update icon cache (may fail with "invalid cache" — harmless)
gtk-update-icon-cache -f ~/.local/share/icons/hicolor/ 2>/dev/null || true

# 5. Create/update .desktop file
cat > ~/.local/share/applications/open_synth.desktop << 'EOF'
[Desktop Entry]
Name=Open Synth
Comment=Software synthesizer with synthwave preset library
Exec=/home/synth/.local/share/open_synth/open_synth
Icon=open_synth
Terminal=false
Type=Application
Categories=Audio;Music;Synthesizer;
StartupNotify=true
EOF
chmod +x ~/.local/share/applications/open_synth.desktop
update-desktop-database ~/.local/share/applications/

# 6. Deploy to system location (MUST kill app first — "Text file busy")
pkill -f "open_synth"
cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/

# 7. Restart walker to pick up new .desktop file
pkill walker && walker --gapplication-service &
```

## Pitfalls

### "Text file busy" when copying over running binary
Linux locks executable pages while a process is running. Always `pkill` first.

### Walker doesn't show the app
1. **Icon cache stale** — `rm -f ~/.local/share/icons/hicolor/.icon-theme.cache`
2. **.desktop file not executable** — `chmod +x ~/.local/share/applications/open_synth.desktop`
3. **Walker cached desktop files at startup** — restart walker

### FFI .so not found when launched from shortcut
When launched from walker, `Directory.current` is the user's home, not the project dir. The `_openLibrary()` function must use `Platform.resolvedExecutable` to find the .so relative to the binary.

## Verification Checklist

```bash
ls -la ~/.local/share/open_synth/open_synth
ls -la ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so
desktop-file-validate ~/.local/share/applications/open_synth.desktop
ls -la ~/.local/share/icons/hicolor/512x512/apps/open_synth.png
```
