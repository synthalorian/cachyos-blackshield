# FFI Debugging Procedure — When Audio Engine Reports Unavailable

## Quick Checklist

When Settings shows "Audio engine unavailable — FFI library not loaded" or "Audio device enumeration failed":

1. **Verify the deployed binary is running:**
   ```bash
   pgrep -a open_synth
   ```

2. **Check OS-level library loading:**
   ```bash
   cat /proc/$(pgrep open_synth)/maps | grep openamp
   ```
   - If NO output → `.so` never loaded → path resolution failure in `_openLibrary()`
   - If output shows `.so` mapped → OS loaded it, but Dart bindings may still fail

3. **Verify symbols are exported:**
   ```bash
   nm -D ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so | grep -E "audio_system_init|audio_stream_create|synth_engine_create"
   ```

4. **Check audio backend libraries:**
   ```bash
   cat /proc/$(pgrep open_synth)/maps | grep -E "portaudio|asound|pipewire|jack"
   ```

## The Two-Level Failure Pattern

**Level 1 — OS loading:** `DynamicLibrary.open()` succeeds, library appears in `/proc/PID/maps`.
**Level 2 — Dart bindings initialization:** `OpenAmpSynthBindings()` or `OpenAmpAudioStreamBindings()` constructor looks up symbols. If ANY symbol is missing, the constructor may catch the exception and set `available = false`.

**Critical insight:** Level 1 success does NOT guarantee Level 2 success. Always verify both.

## Symbol Lookup Failure Scenarios

| Symptom | Cause | Fix |
|---------|-------|-----|
| `.so` mapped, `available = false` | Symbol renamed/removed in C++ but Dart still references old name | Sync Dart bindings with C++ exports |
| `.so` mapped, `available = false` | Constructor catches generic exception, masks real error | Add detailed try/catch logging in bindings constructor |
| `.so` NOT mapped | Path resolution failure | Fix `_openLibrary()` candidate paths |
| `.so` NOT mapped | `LD_LIBRARY_PATH` missing | Export correct path before launch |

## Adding Debug Logging

In `lib/ffi/openamp_synth.dart`, `_openLibrary()`:
```dart
for (final path in candidates) {
  try {
    final lib = DynamicLibrary.open(path);
    _library = lib;
    print('[OpenSynth] SUCCESS: Loaded native library from: $path');
    return lib;
  } catch (e) {
    print('[OpenSynth] FAILED: $path — $e');
  }
}
```

In `lib/ffi/openamp_audio_stream.dart`, constructor:
```dart
OpenAmpAudioStreamBindings._() {
  try {
    final lib = OpenAmpSynthBindings.instance.library;
    print('[OpenSynth] AudioStream: got library = $lib');
    _audioSystemInit = lib.lookup<...>('audio_system_init');
    print('[OpenSynth] AudioStream: audio_system_init resolved');
    // ... lookup other symbols with print after each ...
    _available = true;
  } catch (e, stack) {
    print('[OpenSynth] AudioStream init FAILED: $e');
    print(stack);
    _available = false;
  }
}
```

## Path Resolution Order (Production)

After fixes from 2026-05-31:

1. `$exeDir/lib/libopenamp_dart_ffi.so` — deployed bundle
2. `$exeDir/../lib/libopenamp_dart_ffi.so` — alternative bundle layout
3. `native/libopenamp_dart_ffi.so` — dev mode, project-relative
4. `./native/libopenamp_dart_ffi.so` — dev mode, explicit relative
5. `${Directory.current.path}/native/libopenamp_dart_ffi.so` — dev mode, absolute
6. `libopenamp_dart_ffi.so` — system library search (LD_LIBRARY_PATH, /etc/ld.so.conf)

Where `exeDir = File(Platform.resolvedExecutable).parent.path`.

## Deployment Verification

After `flutter build linux --release` and copy to `~/.local/share/open_synth/`:

```bash
ls -la ~/.local/share/open_synth/lib/
# Should show: libopenamp_dart_ffi.so, libportaudio.so, etc.

~/.local/share/open_synth/open_synth 2>&1 | grep -i "opensynth"
# Should show success/failure messages from print statements
```
