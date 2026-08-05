## Git History vs Working Tree Mismatch

The OpenSynth project has been reverted to base commits while retaining untracked files from abandoned feature branches (e.g., sfizz sample engine integration). This produces inconsistent state where:

- `flutter analyze` shows errors in untracked files referencing symbols that don't exist in committed code
- The native `.so` may be newer than the Dart code expecting it
- Files like `lib/ffi/sample_engine.dart` reference `sampleEngineCreate` which doesn't exist in the committed `OpenAmpSynthBindings`

### Fix

```bash
cd /home/synth/projects/open-synth
git stash -u  # stash including untracked files
git checkout c162daf  # known-good commit with 1,453 presets
```

### Known-good commits

| Commit | Description | Presets |
|--------|-------------|---------|
| `c162daf` | "Sync: update from local development session" | 1,453 |
| `5efaf14` | "Grid Expansion" — clean base | 50 |

### Post-checkout fixes

After checking out `c162daf`, run `flutter analyze`. The `Waveform` enum may have expanded with new variants (`wtBrass`, `wtStrings`, `wtWoodwind`, `wtOrgan`, `wtBell`, `wtSynthBass`, `wtSynthLead`, `wtPad`, `wtEPiano`, `pmKarplus`, `pmKarplusBright`, `pmKarplusBass`, `pmModalMallet`, `pmModalVibraphone`, `pmModalSteel`) that need handling in three switch statements:

1. `lib/widgets/oscilloscope.dart` — `_sampleOscillatorPoints()`
2. `lib/widgets/spectrum_analyzer.dart` — `_addSpectrum()`
3. `lib/widgets/preset_waveform_preview.dart` — `_drawWaveform()`

Pattern: add all new waveform variants as fall-through cases to the existing complex wavetable handler.

## FFI Library Loaded But Bindings Report Unavailable

**Symptom:** Settings shows "Audio engine unavailable — FFI library not loaded" AND "Audio device enumeration failed". The app runs but no keys produce sound.

**Diagnosis:**
1. Check the process maps: `cat /proc/$(pgrep open_synth)/maps | grep openamp`
2. If `libopenamp_dart_ffi.so` IS mapped, the library loaded successfully at the OS level
3. The issue is Dart's `DynamicLibrary.open()` path resolution in `_openLibrary()`

**Root cause:** `_openLibrary()` tries:
- `native/libopenamp_dart_ffi.so`
- `./native/libopenamp_dart_ffi.so`
- `${Directory.current.path}/native/libopenamp_dart_ffi.so`
- `libopenamp_dart_ffi.so`

When installed to `~/.local/share/open_synth/` and launched from a different working directory, relative paths fail. The final fallback `libopenamp_dart_ffi.so` relies on `LD_LIBRARY_PATH` or system library paths.

**Fix:** Ensure the `lib/` directory containing `.so` is in `LD_LIBRARY_PATH`:
```bash
export LD_LIBRARY_PATH="$HOME/.local/share/open_synth/lib:$LD_LIBRARY_PATH"
~/.local/share/open_synth/open_synth
```

Or modify `_openLibrary()` to also check `Platform.resolvedExecutable` directory:
```dart
final exeDir = File(Platform.resolvedExecutable).parent.path;
candidates.add('$exeDir/lib/libopenamp_dart_ffi.so');
```

## Library Mapped in Memory But `available` Still Returns False

**Critical insight from 2026-05-31 session:** The `.so` can be successfully loaded into the process (visible in `/proc/PID/maps`) while `OpenAmpAudioStreamBindings.available` or `OpenAmpSynthBindings.available` still returns `false`.

**What this means:** `DynamicLibrary.open()` succeeded at the OS level, but either:
1. A *later* symbol lookup in the bindings constructor fails (e.g., `audio_system_init` not found), OR
2. The bindings class catches an exception during initialization and reports unavailable

**Diagnosis procedure:**
1. Verify OS-level loading: `cat /proc/$(pgrep open_synth)/maps | grep openamp`
2. Verify symbols exist: `nm -D ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so | grep audio_system_init`
3. Add try/catch logging in `_openLibrary()` to see WHICH path succeeded and WHICH exception is thrown
4. Add logging in `OpenAmpAudioStreamBindings` constructor to identify the failing symbol lookup

**Key lesson:** OS-level library mapping ≠ Dart FFI initialization success. Always verify both levels independently.