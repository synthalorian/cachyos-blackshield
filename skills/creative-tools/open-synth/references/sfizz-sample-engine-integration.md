# sfizz Sample Engine Integration

Integration of the sfizz SFZ sample playback engine into OpenSynth's native C++ audio engine.

## Architecture

```
Flutter (Riverpod) ──FFI──> SampleEngine (C++ wrapper) ──> sfizz::Sfizz
                                    │
                                    ├── SFZ file loading (control thread)
                                    ├── Note on/off/CC (audio thread)
                                    └── renderBlock() → stereo float buffer
```

`SampleEngine` is a simplified wrapper around `sfz::Sfizz` that exposes only the operations OpenSynth needs. It lives alongside `SynthEngine` — both render into the audio callback and their outputs are mixed.

## Files Added

| File | Purpose |
|------|---------|
| `native/include/sample_engine.h` | C++ wrapper class declaration |
| `native/src/sample_engine.cpp` | C++ wrapper implementation |
| `native/src/sample_engine_ffi.cpp` | C FFI exports for Dart binding |
| `lib/ffi/sample_engine.dart` | High-level Dart wrapper |
| `lib/models/sample_preset.dart` | SamplePreset data model |
| `lib/providers/sample_engine_provider.dart` | Riverpod providers |
| `lib/widgets/sample_instrument_panel.dart` | UI panel for browsing SFZ presets |
| `lib/data/sample_presets.dart` | Bundled VSCO 2 CE preset definitions |

## Thread Safety

sfizz has strict thread-safety constraints:
- **Control thread (CT)**: `loadSfzFile()`, `loadSfzString()`, `setSampleRate()`, `setSamplesPerBlock()`, `setNumVoices()`
- **Audio thread (RT)**: `noteOn()`, `noteOff()`, `cc()`, `pitchWheel()`, `renderBlock()`
- **Never call CT functions from RT thread** — will deadlock or corrupt state

OpenSynth's `SampleEngine` wrapper enforces this by design:
- Loading happens from Dart's main thread (NOT the audio callback)
- Note events are called from the audio callback (PortAudio/Oboe thread)
- The audio callback path: `onAudioReady()` → `SampleEngine::render()` → stereo interleaved output

## sfizz CMake Integration

sfizz is added as a git submodule at `native/sfizz/` and built as a static library via `add_subdirectory()`.

Key CMake options (all disabled to minimize build size):
```cmake
set(SFIZZ_SHARED OFF CACHE BOOL "" FORCE)
set(SFIZZ_JACK OFF CACHE BOOL "" FORCE)
set(SFIZZ_RENDER OFF CACHE BOOL "" FORCE)
set(SFIZZ_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(SFIZZ_TESTS OFF CACHE BOOL "" FORCE)
set(SFIZZ_DEMOS OFF CACHE BOOL "" FORCE)
set(SFIZZ_DEVTOOLS OFF CACHE BOOL "" FORCE)
set(SFIZZ_USE_SNDFILE OFF CACHE BOOL "" FORCE)
set(SFIZZ_USE_SYSTEM_* OFF CACHE BOOL "" FORCE)  # all system deps
set(SFIZZ_GIT_SUBMODULE_CHECK OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
```

Link target: `sfizz::sfizz` (static library, ~1.9MB added to final .so)

## FFI Symbol Exports

21 C functions exported from `sample_engine_ffi.cpp`:

**Lifecycle**: `sample_engine_create`, `sample_engine_destroy`
**Loading**: `sample_engine_load_file`, `sample_engine_load_string`
**Config**: `sample_engine_set_sample_rate`, `sample_engine_set_block_size`, `sample_engine_set_volume`, `sample_engine_get_volume`
**MIDI**: `sample_engine_note_on`, `sample_engine_note_off`, `sample_engine_cc`, `sample_engine_pitch_wheel`, `sample_engine_aftertouch`
**Render**: `sample_engine_render`
**State**: `sample_engine_get_num_active_voices`, `sample_engine_get_num_voices`, `sample_engine_set_num_voices`, `sample_engine_get_num_regions`, `sample_engine_get_num_preloaded_samples`, `sample_engine_is_loaded`, `sample_engine_all_sound_off`

## Dart FFI Binding Pattern

```dart
// In OpenAmpSynthBindings constructor:
sampleEngineCreate = lib.lookupFunction<
  Pointer<Void> Function(),           // native: returns opaque pointer
  Pointer<Void> Function()            // Dart: same signature, primitive types
>('sample_engine_create');

// Field declaration in bindings class:
final Pointer<Void> Function() sampleEngineCreate;
```

**Critical**: Dart-side typedefs use primitives (`int`, `double`, `void`), NOT `dart:ffi` types (`Int32`, `Float`, `Void`). The `lookupFunction` generic maps native FFI types to Dart primitives automatically.

## Sample Libraries

### VSCO 2 CE (Orchestral)
- **Source**: Versilian Studios Community Edition
- **License**: CC0 (public domain)
- **Size**: 2.1GB zip → 3.1GB extracted, 75 SFZ files
- **Location**: `assets/samples/VSCO-2-CE-1.1.0/`
- **Download**: `curl -L -o vsco-2-ce.zip "https://www.dropbox.com/s/p2p6whunwekb9s1/VSCO-2-CE-1.1.0.zip?dl=1"`
  (GitHub release asset returns 404 — use Dropbox mirror)

### Salamander Grand Piano (Piano)
- **Source**: archive.org (CC0)
- **License**: CC0 (public domain)
- **Size**: 1.4GB tar.bz2 → 1.9GB extracted, 641 WAV files with velocity layers
- **Location**: `assets/samples/SalamanderGrandPianoV3_48khz24bit/`
- **Download**: `curl -L -o salamander.tar.bz2 "https://archive.org/download/SalamanderGrandPianoV3/SalamanderGrandPianoV3_48khz24bit.tar.bz2"`
- **SFZ**: `SalamanderGrandPianoV3.sfz` (or `SalamanderGrandPianoV3Retuned.sfz`)

### Curated Presets (31 instruments)

| Category | Instruments |
|----------|-------------|
| Piano | Upright Piano, VS Upright, **Salamander Grand Piano** |
| Organ | Pipe Organ Loud, Pipe Organ Quiet |
| Strings | Solo Violin (vib/pizz/trem), Violin/Viola/Cello/Bass Ensembles |
| Brass | Trumpet (sus/stac), Trombone, French Horn, Tuba |
| Woodwind | Flute (sus/stac), Clarinet, Oboe, Bassoon |
| Percussion | Timpani, Glockenspiel, Marimba, Xylophone, Tubular Bells, Harp |
| GM Kit | GM-Style Percussion Kit |

## Audio Stream Architecture

The sample engine uses a **separate audio stream** from the synth engine:

```
┌─────────────────┐     ┌─────────────────┐
│  SynthEngine    │────▶│  audio_stream   │──▶ PortAudio/Oboe ──▶ speakers
│  (subtractive)  │     │  _create_for_   │
└─────────────────┘     │  synth()        │
                        └─────────────────┘
┌─────────────────┐     ┌─────────────────┐
│  SampleEngine   │────▶│  audio_stream   │──▶ PortAudio/Oboe ──▶ speakers
│  (sfizz SFZ)    │     │  _create_for_   │
└─────────────────┘     │  sample_engine()│
                        └─────────────────┘
```

This is simpler than mixing inside `SynthEnginePair` and avoids real-time thread contention. Both streams run at the same sample rate (48kHz) and buffer size.

**Dart provider chain**:
1. `sampleEngineProvider` — creates `SampleEngine` instance, sets sample rate/block size
2. `samplePresetProvider` — holds the currently selected `SamplePreset` (null = none)
3. `sampleAudioStreamProvider` — watches engine + preset, loads SFZ, creates stream, starts audio

When `samplePresetProvider` changes to a new preset:
- `sampleAudioStreamProvider` rebuilds
- Calls `engine.loadSfzFile(preset.sfzPath)` on the control thread
- Creates `OpenAmpSynthAudioStream.forSampleEngine()` binding the engine to PortAudio/Oboe
- Starts the stream

When `samplePresetProvider` changes to null:
- `sampleAudioStreamProvider` disposes (stream stops + destroys)
- Sample engine goes silent

## Note Routing

Both `ComputerKeyboardListener` and `KeyboardWidget` route notes based on whether a sample preset is active:

```dart
final samplePreset = ref.read(samplePresetProvider);
final split = ref.read(keyboardSplitProvider);

if (samplePreset != null) {
  // Route to sample engine
  final sampleEngine = ref.read(sampleEngineProvider);
  if (split.enabled) {
    // Respect split mode — route to appropriate zones
    final zones = split.zonesForNote(midiNote);
    for (final zone in zones) {
      final shiftedNote = split.shiftedNote(midiNote, zone);
      sampleEngine?.noteOn(0, shiftedNote, velocity);
    }
  } else {
    sampleEngine?.noteOn(0, midiNote, velocity);
  }
} else {
  // Route to synth engine via NoteRouter
  ref.read(noteRouterProvider).noteOn(midiNote);
}
```

**Critical**: When split is enabled AND a sample preset is active, the code must still respect the split configuration. The original implementation bypassed split mode entirely for sample instruments — this was a bug. Always check `split.enabled` and use `split.zonesForNote()` / `split.shiftedNote()` regardless of which engine is active.

## SFZ Path Resolution

The `bundledSamplePresets` use `assets/samples/...` paths. These work for Flutter asset bundling on mobile, but on desktop the app must resolve them relative to the executable working directory.

**Desktop path resolution strategy**:
```dart
String resolveSfzPath(String assetPath) {
  if (Platform.isAndroid || Platform.isIOS) {
    // Flutter assets are extracted to app data directory
    return assetPath;
  }
  // Desktop: resolve relative to executable
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return path.join(exeDir, assetPath);
}
```

**Alternative**: Copy the `assets/samples/` directory next to the desktop executable during deployment and use relative paths.

## Resolved Integration Work

1. **~~SFZ path resolution for desktop~~** ✓ FIXED: `resolveSamplePath()` utility tries exe-relative, flutter_assets, and project-root strategies. `scripts/deploy-desktop.sh` copies samples next to executable. See `references/desktop-sfz-path-resolution.md`.
2. **~~Volume balancing~~** ✓ FIXED: `globalMixSyncProvider` unifies master volume across synth, sample, and pair engines. See `references/global-mix-provider-pattern.md`.
3. **Loading progress indicator**: Added polling-based progress via `samplePresetLoadProgressProvider` with Circular + Linear indicators.

## Remaining Integration Work

1. **Mobile asset bundling**: VSCO 2 CE is 3.1GB — too large to bundle in APK. Need asset download/management system for mobile
2. **Disk streaming config**: sfizz's `setPreloadSize()` should be tuned for mobile RAM constraints (default is aggressive preload)
3. **MIDI input routing**: External MIDI devices currently route through `noteRouterProvider`; may need sample engine routing for MIDI input when sample preset active

## Build Verification

```bash
cd native/build && cmake .. && make -j$(nproc)
# Verify symbols:
nm -D libopenamp_dart_ffi.so | grep sample_engine
# Should show all 21 symbols as T (text/code)
# Verify no external sfizz dependency:
ldd libopenamp_dart_ffi.so | grep sfizz
# Should show nothing (statically linked)
```

## Post-Build Deployment

After `flutter build linux --release`, copy the updated FFI library:
```bash
cp native/libopenamp_dart_ffi.so build/linux/x64/release/bundle/lib/
```

The Flutter build regenerates `libapp.so` but does NOT rebuild the native FFI library — manual copy is required after every native code change.
