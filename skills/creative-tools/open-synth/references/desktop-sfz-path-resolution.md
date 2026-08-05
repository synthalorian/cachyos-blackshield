# Desktop SFZ Path Resolution

Flutter desktop builds do NOT bundle arbitrary assets into the release bundle. The `assets/samples/` directory must be resolved at runtime.

## The Problem

`bundledSamplePresets` use paths like `assets/samples/VSCO-2-CE-1.1.0/UprightPiano.sfz`. On mobile, Flutter's asset system extracts these automatically. On desktop (`linux`, `macos`, `windows`), `flutter build` only bundles assets declared in `pubspec.yaml`'s `flutter.assets` list into `data/flutter_assets/` — but large directories (3.1GB+ of samples) are NOT copied.

## Solution: Multi-Strategy Path Resolver

File: `lib/utils/sample_path_resolver.dart`

Tries strategies in order:
1. **Direct path** — if `File(assetPath).existsSync()`, use as-is
2. **Executable-relative** — `path.join(File(Platform.resolvedExecutable).parent.path, assetPath)`
3. **Parent of executable** — one level up (some build layouts)
4. **flutter_assets** — `path.join(exeDir, 'data', 'flutter_assets', assetPath)`
5. **Development mode** — walk up from `Directory.current` to find `pubspec.yaml`, then resolve relative to project root

Fallback returns the exe-relative path even if it doesn't exist (caller handles failure).

## Deployment Script

File: `scripts/deploy-desktop.sh`

After `flutter build linux --release`, run:
```bash
bash scripts/deploy-desktop.sh release
```

This:
1. Copies `native/libopenamp_dart_ffi.so` → `build/linux/x64/release/bundle/lib/`
2. `rsync -a --delete assets/samples/` → `build/linux/x64/release/bundle/assets/samples/`
3. Reports total samples size

## System Install

The walker shortcut points to `~/.local/share/open_synth/`. After deployment:
```bash
pkill -f "open_synth"  # Must kill first or "Text file busy"
cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/
```

## Provider Integration

`sampleAudioStreamProvider` calls `resolveSamplePath(preset.sfzPath)` before `engine.loadSfzFile()`:
```dart
final sfzPath = resolveSamplePath(preset.sfzPath);
final loaded = engine.loadSfzFile(sfzPath);
```

`availableSamplePresetsProvider` filters based on `samplesAvailable` (checks if `assets/samples/` exists at runtime) so the UI shows "No instruments" rather than errors when samples aren't deployed.
