# Linux Desktop Deployment — Flutter + Native FFI

## The Problem

Flutter desktop apps on Linux build the native FFI library into the project directory (`native/libopenamp_dart_ffi.so`), but the actual runnable binary lives elsewhere (e.g., `~/.local/share/open_synth/`). The `.desktop` entry and walker shortcut point to the deployed location, NOT the project build output.

## Directory Layout

```
Project build output:
  /home/synth/projects/open-synth/native/libopenamp_dart_ffi.so

Deployed application:
  ~/.local/share/open_synth/
  ├── open_synth                    # Flutter binary
  ├── lib/
  │   ├── libopenamp_dart_ffi.so  # <-- THIS is what runs
  │   ├── libapp.so
  │   └── libflutter_linux_gtk.so
  └── data/                         # Flutter assets

Desktop entry:
  ~/.local/share/applications/open_synth.desktop
  Exec=/home/synth/.local/share/open_synth/open_synth

Walker shortcut:
  Launches via the .desktop entry
```

## The Fix

After rebuilding the native library, copy it to the deployed location:

```bash
cp /home/synth/projects/open-synth/native/libopenamp_dart_ffi.so \
   /home/synth/.local/share/open_synth/lib/libopenamp_dart_ffi.so
```

## Full Rebuild + Deploy Pipeline

```bash
cd /home/synth/projects/open-synth

# 1. Build native library
cd native/build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)
cd ../..

# 2. Build Flutter release
flutter build linux --release

# 3. Copy to deployed location (close app first — "Text file busy" if running)
cp native/libopenamp_dart_ffi.so ~/.local/share/open_synth/lib/
cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/

# 4. Launch from walker or:
~/.local/share/open_synth/open_synth
```

## Pitfalls

1. **"Text file busy" on copy**: Cannot overwrite `open_synth` binary or `.so` while the app is running. Close it first.
2. **Forgetting the .so copy**: The most common mistake — build succeeds, launch from walker, old engine runs. Always copy the .so.
3. **Flutter build doesn't rebuild native**: `flutter build` only triggers CMake if `CMakeLists.txt` changed. If you edited `.cpp` files, run `make` in `native/build` first, THEN `flutter build`.
4. **Symlink in PATH**: `~/.local/bin/open_synth` is typically a symlink to `~/.local/share/open_synth/open_synth`. The binary resolves `.so` paths relative to its own location, so the symlink works fine.
