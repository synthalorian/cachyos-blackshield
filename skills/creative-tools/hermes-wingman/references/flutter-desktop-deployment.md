# Flutter Linux Desktop Deployment — Binary + Data + Lib Layout

## Target Layout

Flutter Linux embedders resolve `data/flutter_assets/` relative to the executable path. The binary, `data/`, and `lib/` must be co-located.

**Correct layout (Omarchy / Arch):**
```
~/.local/bin/hermes_wingman          # binary
~/.local/bin/data/flutter_assets/    # Flutter assets
~/.local/bin/data/icudtl.dat
~/.local/bin/lib/libapp.so
~/.local/bin/lib/libflutter_linux_gtk.so
~/.local/bin/lib/...                 # other .so files
```

## Deploy After Building

```bash
# Build
flutter build linux --release

# Copy binary
cp build/linux/x64/release/bundle/hermes_wingman ~/.local/bin/hermes_wingman

# Copy data/ and lib/ (Flutter resolves these relative to binary)
cp -r build/linux/x64/release/bundle/data/* ~/.local/bin/data/
cp -r build/linux/x64/release/bundle/lib/* ~/.local/bin/lib/
```

## Critical Pitfall: XDG Directories

Putting `data/` in `~/.local/share/hermes-wingman/` or `lib/` in `~/.local/lib/hermes-wingman/` will **NOT** work. The embedder looks for `data/` next to the executable, not in XDG directories.

The `.desktop` file and wrapper script launch the binary directly from `~/.local/bin/`, so the runtime working directory is irrelevant — what matters is the executable's path.

## Verification Commands

```bash
# Check binary timestamp
ls -la ~/.local/bin/hermes_wingman

# Verify flutter_assets match the build
diff -rq build/linux/x64/release/bundle/data/flutter_assets/ \
  ~/.local/bin/data/flutter_assets/ && echo "SYNCED"

# Check version.json
cat ~/.local/bin/data/flutter_assets/version.json

# Verify all .so files present
ls -la ~/.local/bin/lib/libapp.so ~/.local/bin/lib/libflutter_linux_gtk.so
```

## Wrapper Script

The launcher at `~/.local/bin/hermes-wingman-wrapper` sets `LD_LIBRARY_PATH`:

```bash
#!/bin/bash
LIB_DIR="$HOME/.local/bin/lib"
export LD_LIBRARY_PATH="$LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HOME/.local/bin/hermes_wingman" "$@"
```

The `.desktop` file points `Exec=` to the binary directly, but the wrapper is available for terminal launches.

## Desktop Entry

```
~/.local/share/applications/hermes-wingman.desktop:
Exec=/home/synth/.local/bin/hermes_wingman
```

## Common Mistakes

1. **Copying only the binary** — Desktop app launches but crashes with "Unable to load assets" or missing ICU data
2. **Updating binary but not data/** — Old assets cached, new features/UI not visible
3. **Updating data/ but not lib/** — Mismatched `libapp.so` version causes ABI crashes
4. **Forgetting to restart the app** — Flutter desktop app caches loaded assets in memory

## Full Deploy Script

```bash
#!/bin/bash
set -e
BUNDLE="build/linux/x64/release/bundle"
BIN="$HOME/.local/bin"

cp "$BUNDLE/hermes_wingman" "$BIN/"
cp -r "$BUNDLE/data/"* "$BIN/data/"
cp -r "$BUNDLE/lib/"* "$BIN/lib/"

echo "Deployed:"
ls -la "$BIN/hermes_wingman"
ls -la "$BIN/lib/libapp.so"
cat "$BIN/data/flutter_assets/version.json"
```
