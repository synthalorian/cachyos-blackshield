# FFI Library Path Resolution — "App Launches But Nothing Works"

## Symptom

App launches to the synth screen, but:
- No audio plays (silence)
- On-screen keyboard keys don't light up when pressed
- Computer keyboard keybindings don't work
- Right side of keyboard (second octave) is completely dead
- No errors visible in UI

## Root Cause

`_openLibrary()` in `lib/ffi/openamp_synth.dart` fails to load `libopenamp_dart_ffi.so` because `Directory.current` is wrong when launched from desktop shortcuts.

When launched via walker, `.desktop` entry, or terminal from home directory:
- `Directory.current.path` = `/home/synth` (or `/`)
- Candidate paths like `./native/libopenamp_dart_ffi.so` don't exist there
- `DynamicLibrary.open()` throws, gets caught, returns null
- `OpenAmpSynthBindings.available` = false
- `synthEngineProvider` returns null
- `PlaybackStateNotifier` has no engine → noteOn/noteOff are no-ops
- `playbackStateProvider` never updates → keyboard keys never light up
- No audio stream starts → silence

## Diagnosis Path

1. Check if `.so` loads: add `print('SO loaded from: $path')` in `_openLibrary()` success path
2. Check `synthEngineProvider` value: add `print('Engine: $engine')` in `PlaybackStateNotifier`
3. Run app from terminal: `~/.local/share/open_synth/open_synth 2>&1 | grep -i "so\|engine\|error"`
4. Verify `.so` exists at deployed location: `ls -la ~/.local/share/open_synth/lib/`
5. Check `Platform.resolvedExecutable` vs `Directory.current.path`

## The Fix

In `lib/ffi/openamp_synth.dart`, `_openLibrary()`:

```dart
static DynamicLibrary? _openLibrary() {
  if (_library != null) return _library;

  final candidates = <String>[];

  // 1. Deployed bundle paths (production) — MUST be first
  try {
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    candidates.add('$exeDir/lib/libopenamp_dart_ffi.so');
    candidates.add('$exeDir/../lib/libopenamp_dart_ffi.so');
  } catch (_) {}

  // 2. Dev mode paths (running from project directory)
  candidates.add('native/libopenamp_dart_ffi.so');
  candidates.add('./native/libopenamp_dart_ffi.so');
  candidates.add('${Directory.current.path}/native/libopenamp_dart_ffi.so');

  // 3. System library search
  candidates.add('libopenamp_dart_ffi.so');

  for (final path in candidates) {
    try {
      final lib = DynamicLibrary.open(path);
      _library = lib;
      print('[OpenSynth] Loaded native library from: $path');
      return lib;
    } catch (_) {
      // Try next candidate
    }
  }

  print('[OpenSynth] FAILED to load native library from any path:');
  for (final path in candidates) {
    print('  - $path');
  }
  return null;
}
```

## Key Insight

`Platform.resolvedExecutable` gives the actual binary path regardless of how the app was launched. `Directory.current` only works when running `flutter run` from the project directory. For deployed desktop apps, ALWAYS use `Platform.resolvedExecutable` to find bundled resources.

## Prevention

- Always include `Platform.resolvedExecutable`-based paths in `_openLibrary()`
- Log the loaded path and all failed paths for debugging
- Verify deployment with `ls -la` on the actual installed binary and `.so`
- Test by launching from walker/shortcut, not just `flutter run`
