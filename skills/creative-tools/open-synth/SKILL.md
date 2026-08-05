---
name: open-synth
description: Open Synth — open-source synthesizer (JUCE 8 + C++20 since v2.0.0; Flutter era retired). DSP engine, sample ROMpler, build/test/release workflow.
triggers:
  - open-synth
  - opensynth
  - synthesizer app
  - synth engine
  - DSP engine
  - audio engine
  - JUCE
  - Juno-Di
  - arpeggiator
  - wavetable
  - SFZ
  - SoundFont
  - sample playback
  - ROMpler
  - instrument realism
tags:
  - flutter
  - cpp
  - ffi
  - portaudio
  - dsp
  - synthesizer
  - audio
  - riverpod
  - arpeggiator
---

> READ FIRST: references/current-state-v2.md — v2.0.0 (2026-07-25) replaced Flutter/FFI with native JUCE 8 + C++20. Flutter-era sections below are historical.

# Open Synth

Open-source software synthesizer keyboard app — Flutter + native C++ DSP engine via FFI.
Vision: world's first open-source, fully functional synth keyboard matching Roland Juno-Di feature set and beyond.

**Fully standalone project.** OpenSynth has its own setup wizard, config management, and tooling pipeline. No Hermes integration.

## Architecture

```
Flutter (Riverpod) ──FFI──> C++ Native Engine
   |                            |
   |-- Providers                |-- SynthEngine (oscillators, filters, envelopes, LFOs)
   |-- Preset models            |-- VoiceAllocator (64 voices, unison x8)
   |-- UI widgets               |-- Arpeggiator (5 patterns, swing, hold/latch, step viz)
   |-- MIDI I/O                 |-- DrumKit (16 drum types, 10 kits, GM2 mapping, block-processed)
   |                            |-- WavetableOscillator (cubic interpolation, 3 built-in wavetables)
   |                            |-- ParamQueue (lock-free SPSC ring buffer)
   |                            |-- AudioStream (PortAudio OR Oboe — same FFI symbols)
   |                            |-- AudioSystem (PortAudio singleton) or Oboe stubs
   |                            `-- Effects (chorus, delay, reverb, phaser, flanger, drive, compressor, EQ, limiter, rotary, tremolo)
   |-- Desktop: MainShell (bottom nav)     ── PortAudio audio_system.h/.cpp
   |-- Mobile:  MobileShell (hamburger)    ── Oboe oboe_audio_stream.h/.cpp
   `-- Hive (preset persistence)
```

## Project Structure

```
/home/synth/projects/open-synth/
├── lib/
│   ├── ffi/                     # FFI bindings to native .so
│   │   ├── openamp_synth.dart       # SynthEngine bindings + ParamId constants
│   │   ├── openamp_audio_stream.dart # AudioSystem + AudioStream bindings
│   │   └── audio_platform.dart      # Platform detection (isMobile, isAndroid, audioBackendName)
│   ├── models/                  # Dart data models
│   │   ├── synth_preset.dart        # Preset model (JSON serializable)
│   │   ├── drum_kit_config.dart     # DrumKitConfig — kit index 0-9, level, 10 kit names
│   │   ├── oscillator.dart          # Waveform enum + osc config
│   │   ├── oscillator.dart          # Waveform enum + osc config (now includes wt_piano/guitar/choir)
│   │   ├── envelope.dart            # ADSR envelope config
│   │   ├── filter_config.dart       # Filter type + params
│   │   ├── lfo_config.dart          # LFO config
│   │   ├── fx_config.dart           # All FX configs (chorus, delay, reverb, etc.)
│   │   └── ...
│   ├── providers/
│   │   ├── synth_providers.dart     # Riverpod providers (engine, stream, presets)
│   │   ├── drum_providers.dart      # DrumKit config + native bridge + drum pad grid layout
│   │   └── ...
│   ├── data/
│   │   └── factory_presets.dart     # 1,415 factory presets across 8 categories
│   ├── screens/                 # App screens
│   │   ├── main_shell.dart          # Desktop shell (bottom nav) — redirects to MobileShell on mobile
│   │   ├── mobile_shell.dart        # Mobile shell (hamburger drawer nav)
│   │   ├── mobile_synth_screen.dart # Mobile synth (split-view landscape, collapsible panels)
│   │   ├── synth_screen.dart        # Desktop synth (full panel layout) — redirects to mobile on mobile
│   │   └── ...
│   ├── widgets/                 # UI widgets (keyboard, knobs, panels)
│   │   ├── collapsible_section.dart # Reusable collapsible panel (ExpansionTile + synthwave theme)
│   │   ├── drum_pad_grid.dart       # 4×4 drum pad grid — color-coded, position-based velocity, Listener touch
│   │   ├── drum_panel.dart          # Drum kit panel: kit selector, level slider, pad grid
│   │   └── ...
│   └── theme/
├── native/
│   ├── include/                 # C++ headers
│   │   ├── synth_engine.h           # Main engine class (owns DrumKit member)
│   │   ├── drum_synth.h             # DrumKit engine — 16 drum types, 32-voice poly
│   │   ├── drum_kit_mapping.h       # GM2 note→drum mapping + 10 kit presets
│   │   ├── param_queue.h            # Lock-free SPSC ring buffer (includes DRUM_* params)
│   │   ├── arpeggiator.h            # Arpeggiator engine
│   │   ├── wavetable_oscillator.h   # WavetableOscillator + Wavetable struct (2048-sample)
│   │   ├── wavetable_bank.h         # getBuiltinWavetable(int type) — piano/guitar/choir
│   │   ├── audio_system.h           # PortAudio lifecycle singleton
│   │   ├── audio_stream.h           # Audio output stream
│   │   └── ...
│   ├── src/                     # C++ implementations
│   │   ├── drum_synth.cpp           # 16 drum synthesis algorithms (~650 lines)
│   │   ├── drum_kit_mapping.cpp     # GM2 mapping + 10 kit preset definitions
│   │   ├── drum_ffi.cpp             # Standalone DrumKit FFI (unused — DrumKit embedded in SynthEngine)
│   │   ├── wavetable_oscillator.cpp # Cubic hermite interpolation
│   │   ├── wavetable_data.cpp       # 3 synthesized wavetables (piano/guitar/choir, 2048 each)
│   │   ├── wavetable_bank.cpp       # Stub for future custom wavetable loading
│   │   └── ...
│   └── CMakeLists.txt           # Native build config
├── PLAN.md                      # Master feature roadmap
├── build.sh                     # Full build script (desktop)
└── build/                       # Flutter build output
    └── app/outputs/flutter-apk/ # Android APK output
        └── app-debug.apk        # Debug APK (~153MB)
```

## Standalone Setup System

OpenSynth has its own setup and configuration pipeline — completely independent from Hermes Agent.

### CLI Commands

```bash
opensynth setup              # Interactive setup wizard
opensynth doctor             # Check dependencies and config health
opensynth config             # View current config
opensynth config edit        # Open config in $EDITOR
opensynth config set KEY VAL # Set a config value
opensynth config path        # Print config file path
```

### Setup Flow

```
1. DETECT  → 2. INSTALL DEPS (if needed)  → 3. AUTO-CONFIGURE  → 4. TEST  → 5. DONE
```

**Step 1 — Detect:** Check Flutter SDK, native toolchain, PortAudio/Android NDK, existing config.

**Step 2 — Install:** Flutter SDK, PortAudio headers, CMake 3.22+, Android SDK/NDK (if mobile).

**Step 3 — Auto-Configure:** Write `~/.config/opensynth/config.yaml`, create data dirs, generate `.desktop` entry.

**Step 4 — Test:** Build native library, probe audio devices, test MIDI enumeration.

**Step 5 — Done:** Summary, quick-start commands, offer to launch.

### Config File (`~/.config/opensynth/config.yaml`)

```yaml
audio:
  backend: auto              # portaudio | oboe | auto
  sample_rate: 48000
  buffer_size: 256
  device_index: null
  input_device_index: null

ui:
  theme: synthwave
  show_spectrum: true
  show_oscilloscope: true
  keyboard_size: medium
  default_octave: 4

midi:
  enabled: true
  input_device: null
  channel: 0

presets:
  factory_path: ~/.local/share/opensynth/presets
  user_path: ~/.local/share/opensynth/user_presets
  favorites_path: ~/.local/share/opensynth/favorites.json

paths:
  recordings: ~/.local/share/opensynth/recordings
  wavetables: ~/.local/share/opensynth/wavetables
  drum_kits: ~/.local/share/opensynth/drum_kits
```

## Build Process

### Desktop (PortAudio)

```bash
# Build native .so (outputs to native/libopenamp_dart_ffi.so)
cd /home/synth/projects/open-synth/native/build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)

# Full release build + install
bash /home/synth/projects/open-synth/build.sh

# Flutter analyze
cd /home/synth/projects/open-synth && flutter analyze
```

### Android APK

```bash
# Prerequisites
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk   # Java 25 BREAKS Gradle — must use 21
export ANDROID_HOME=/home/synth/Android/Sdk
export PATH="/home/synth/flutter/bin:$PATH"      # Flutter 3.44.0+

# Resolve deps
cd /home/synth/projects/open-synth && flutter pub get

# Verify no analysis errors
flutter analyze

# Build debug APK (outputs to build/app/outputs/flutter-apk/app-debug.apk)
# Gradle runs CMake automatically via externalNativeBuild in build.gradle.kts
# Native .so compiled for arm64-v8a, armeabi-v7a, x86_64
flutter build apk --debug

# Verify ARM64 native lib is present
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libopenamp

# Install on connected device
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Vendored Oboe

Oboe v1.8.0 is vendored at `native/oboe/` (git clone --depth 1 --branch 1.8.0).
Do NOT use FetchContent — it fails in NDK CMake context.
CMakeLists.txt uses `file(GLOB_RECURSE)` over `oboe/src/{aaudio,common,fifo,flowgraph,opensles}/*.cpp`.
To update Oboe: `cd native && rm -rf oboe && git clone --depth 1 --branch X.Y.Z https://github.com/google/oboe.git oboe`

### GitHub Release

```bash
# Tag + push
git tag v0.1.0-alpha && git push origin v0.1.0-alpha

# Create release with APK (153MB+ — use long timeout)
gh release create v0.1.0-alpha \
  build/app/outputs/flutter-apk/app-debug.apk \
  --title "Open Synth vX.Y.Z — Title" \
  --notes "Release notes here"
```

### Android SDK Requirements
- NDK: 28.x (tested with 28.2.13676358)
- Platforms: 34-37
- Build-tools: 34 or 35
- Licenses: `yes | sdkmanager --licenses`

## Critical Patterns

### AudioSystem Singleton (PortAudio Lifecycle)
- `AudioSystem::instance()` owns Pa_Initialize/Pa_Terminate
- Ref-counted: safe to call init() multiple times
- Device list cached after first init — enumeration never calls Pa_Init/Term
- Dart side: `synthEngineProvider` calls init on create, shutdown on dispose
- NEVER call Pa_Initialize/Pa_Terminate from anywhere else

### Lock-Free Parameter Queue (Thread Safety)
- UI thread enqueues via `ParamQueue::enqueue/enqueueInt/enqueueNoteOn/enqueueNoteOff`
- Audio callback drains at block boundaries in `SynthEngine::process()`
- 1024-entry SPSC ring buffer, cache-line aligned (64-byte)
- All Dart setters in `OpenAmpSynth` route through the queue via `ParamId` constants
- Direct FFI setters still exist (backward compat) but should NOT be used during audio playback
- Adding new params: add to `ParamQueue::ParamId` enum → add `applyParam` case in `synth_engine.cpp` → add Dart ParamId constant → add setter on `OpenAmpSynth`. No new FFI C symbols needed for queue-based params.

### Arpeggiator Engine
- Lives in `Arpeggiator` class (`arpeggiator.h`/`arpeggiator.cpp`)
- 5 patterns: `UP`, `DOWN`, `UP_DOWN`, `RANDOM`, `CHORD` (enum in header)
- 4 resolutions: quarter, eighth, sixteenth, thirty-second
- Controlled via param queue (ParamIds 150-155): ARP_ENABLED, ARP_TEMPO, ARP_PATTERN, ARP_OCTAVE_RANGE, ARP_GATE, ARP_RESOLUTION
- **Note routing**: `SynthEngine::noteOn()`/`noteOff()` feed the arpeggiator always. When arp is enabled, direct allocator calls are SKIPPED — the arp generates its own note events at block boundaries via `arpeggiator_.process()` in the audio callback.
- `arpeggiator_.process()` is called in `SynthEngine::process()` right after `drainQueue()` and before LFO update.
- The arp tracks held notes in `std::vector<int> heldNotes_` sorted by pitch.
- Gate determines what fraction of each step the note is held (0.0-1.0).
- Octave range determines how many octaves the pattern cycles through.
- CHORD pattern plays all held notes simultaneously (not arpeggiated).
- `fastRand()` uses a simple LCG (`randomState_ * 1103515245 + 12345`) — declared `const` because it only touches `mutable randomState_`.

### Rhythm Pattern Player
- Lives in `RhythmPatternPlayer` class (`rhythm_pattern_player.h`/`rhythm_pattern_player.cpp`)
- 24+ preset patterns across 9 categories: Rock, Pop, Funk, Jazz, Latin, Electronic, World, Synthwave, Fills
- Pattern variations: Intro, MainA, MainB, FillA, FillB, Ending — with song mode auto-advance
- Each pattern has 16-64 steps, supports 16th notes, triplets, 32nds
- Per-hit: probability, timing shift, accent level
- **Audio thread integration**: `rhythmPlayer_.process(drumKit_, numFrames, sampleRate)` called in `SynthEngine::process()` after arpeggiator, before voice processing. Advances step counter and triggers drum hits via `DrumKit::noteOn()`.
- **Param queue control** (ParamIds 270-276): RHYTHM_PATTERN, RHYTHM_PLAY, RHYTHM_STOP, RHYTHM_TEMPO, RHYTHM_VOLUME, RHYTHM_VARIATION, RHYTHM_SONG_MODE
- **FFI exports**: `synth_engine_rhythm_play/stop/set_pattern/set_tempo/set_volume/set_variation/set_song_mode`, `synth_engine_get_rhythm_current_step/total_steps`
- **Dart UI**: `RhythmPanel` widget with transport, pattern browser, tempo/volume knobs, variation selector, live step LED indicator, song mode toggle
- **Adding new patterns**: Add a `makePatternName()` function in `rhythm_pattern_player.cpp`, register it in `buildPatternLibrary()`, add entry to `kRhythmPatterns` in Dart.

### DrumKit Engine
- Lives in `DrumKit` class (`drum_synth.h`/`drum_synth.cpp`), **embedded inside SynthEngine** as `drumKit_` member — NOT a standalone FFI object.
- 16 drum types (KICK, SNARE, CLOSED_HH, OPEN_HH, TOM_H/M/L, CRASH, RIDE, CLAP, RIMSHOT, COWBELL, SHAKER, CONGA_H/L).
- Each drum sound uses a dedicated synthesis algorithm (not generic oscillators). Kick: sine+pitch envelope+noise click. Snare: triangle BPF + noise HPF. Hats: noise→HPF with choke groups. Cymbals: 3× parallel BPF noise. Clap: 3-peak burst pattern.
- 32-voice pool — voice stealing reuses oldest active voice.
- 10 kit presets (Standard, Room, Power, TR-808, TR-909, Electronic, Jazz, Brush, Orchestra, SFX) defined in `drum_kit_mapping.cpp`.
- GM2 percussion mapping (MIDI notes 35-64) in `gm2NoteToDrumType()`.
- Block-processed in `SynthEngine::process()` via stack-allocated temp buffers (2048-sample max), mixed into output AFTER synth voices with tanh soft clip. No heap allocation on the audio thread.
- Controlled via param queue: `DRUM_KIT_PRESET(260)`, `DRUM_LEVEL(261)`, `DRUM_NOTE_ON(262)`, `DRUM_NOTE_OFF(263)`.
- `allNotesOff()` silences all drum voices — called from `SynthEngine::reset()`.
- Drum note encoding in applyParam: `DRUM_NOTE_ON` float = `midiNote + velocity` (int part = note, fractional = velocity). Velocity defaults to 0.8 if ≤ 0.

### Wavetable Engine
- `WavetableOscillator` class (`wavetable_oscillator.h/.cpp`) — plays single-cycle waveforms with cubic hermite interpolation (4-point with wraparound).
- `Wavetable` struct: owns a 2048-sample `float*` buffer + name. Move-only.
- Three built-in wavetables in `wavetable_data.cpp` — generated at runtime via additive synthesis (8 harmonics each):
  - **Piano**: decreasing amplitudes [1.0, 0.5, 0.33, 0.2, 0.15, 0.1, 0.07, 0.05]
  - **Guitar**: asymmetric even-harmonic emphasis [1.0, 0.6, 0.25, 0.3, 0.15, 0.12, 0.08, 0.04]
  - **Choir**: formant emphasis on 2nd/4th [0.7, 1.0, 0.5, 0.8, 0.3, 0.4, 0.15, 0.2]
- Lazy initialization via `ensureWavetablesInitialized()` — first use triggers generation, stored as process-lifetime globals.
- `getBuiltinWavetable(int type)` in `wavetable_bank.h` returns the right table (0=piano, 1=guitar, 2=choir).
- **Dart-to-C++ waveform mapping fix**: `Oscillator::setWaveform()` uses a `dartToInternal[]` lookup table. Dart enum: sine(0)→SINE(3), saw(1)→SAW(0), square(2)→SQUARE(1), triangle(3)→TRIANGLE(2), noise(4)→NOISE(4), wavetable(5)→PULSE(5), wt_piano(6)→WT_PIANO(6), wt_guitar(7)→WT_GUITAR(7), wt_choir(8)→WT_CHOIR(8). The old code had Dart sine(0) mapping to C++ SAW(0) — **all presets had wrong oscillator shapes** before this fix.
- Wavetable types (6-8) configure `wtOsc_` with `getBuiltinWavetable()` in `setWaveform()`.
- `generateWaveform()` calls `wtOsc_.getSampleAtPhase(phase)` for wavetable types — produces actual audio instead of silence.
### DSP Safety

- NaN/inf guard on every output frame (zeroes corrupt values)
- **Soft clipper (tanh)** on output — smoothly saturates, never produces DC flatlines
  - NEVER use `clamp(x, -1, 1)` as the final output stage — it produces a flat DC signal at full scale when clipping, which kills PipeWire and all system audio until the stream closes
- All feedback delay buffer WRITES clamped to [-2, +2] (delay, reverb, flanger, phaser)
- All feedback delay buffer READS clamped to [-2, +2] before use
- Reverb delay lengths clamped to buffer size
- Phaser `tan()` coeff clamped to 10.0 to prevent explosion at high freq/sampleRate ratios
- Flanger uses separate L/R delay lines (not shared mono buffer)
- DrumKit output is mixed into the already-processed synth output with a second tanh pass — drums and synth are independently nan/inf-guarded before mixing.

## Key Technical Decisions

1. **C++ FFI over Dart-only audio**: Dart's GC makes realtime audio unreliable. The C++ engine runs on PortAudio's callback thread with zero Dart involvement.
2. **Riverpod for state**: All synth state flows through providers. `livePresetSyncProvider` pushes preset changes to native engine.
3. **Hive for persistence**: Presets stored as JSON in Hive box `open_synth`.
4. **ParamQueue over mutexes**: Lock-free SPSC avoids priority inversion on the audio thread.
5. **Arpeggiator in C++ (not Dart)**: Sample-accurate timing requires the arp to run on the audio callback thread. Dart timers jitter too much for rhythmic note generation.

## Current State

### Phase 0 — Audio stability: COMPLETE ✓
- PortAudio lifecycle fixed (singleton, cached enumeration)
- Thread-safe param queue implemented
- Provider lifecycle hardened
- DSP bug fixes (flanger stereo, compressor gain, tanh clipper, buffer clamps)

### Phase 0.5 — Bugfix sprint: COMPLETE ✓
1. Envelope sustain=0 → IDLE (pluck presets now work)
2. Preset switching calls allNotesOff + reset before applying params
3. reset() clears flanger/chorus/phaser/compressor state too

### Phase 1.1 — Polyphony: COMPLETE ✓
- `VoiceAllocator::MAX_VOICES` bumped from 16 to 64
- Voice stealing is basic round-robin (steals oldest voice or first RELEASE voice)
- Priority modes and dynamic stealing not yet implemented

### Phase 2 — Rhythm Pattern Player: COMPLETE ✓
- 24 preset patterns across 9 categories (Rock, Pop, Funk, Jazz, Latin, Electronic, World, Synthwave, Fills)
- Pattern variations: Intro, MainA, MainB, FillA, FillB, Ending with song mode auto-advance
- Per-hit probability, timing shift, accent infrastructure
- Thread-safe audio callback integration — triggers drum hits on step boundaries
- Param queue control (ParamIds 270-276)
- Dart UI: `RhythmPanel` widget with transport, pattern browser, tempo/volume knobs, step indicator
- See `references/rhythm-pattern-player.md` for full architecture

### Phase 6 — Physical Modeling Synthesis: COMPLETE ✓
- **Karplus-Strong plucked string**: delay-line feedback with lowpass filter, brightness-controlled decay
- **Karplus-Strong plucked string**: delay-line feedback with lowpass filter, brightness-controlled decay
  - 3 variants: Normal (brightness 0.5), Bright (0.75, clavinet/harpsichord), Bass (0.25, acoustic bass)
  - Pre-filled delay line with noise for immediate sound
  - Exponential pitch envelope for realistic string tension
- **Modal synthesis**: 4-8 parallel resonant bandpass filters per voice
  - Marimba (wood bar, 4 modes, fast decay)
  - Vibraphone (metal bar, 4 modes, slow decay)
  - Steel drum (membrane, 6 modes, complex inharmonic)
- **Integration pattern**: PhysicalModelVoice added to Voice struct, initialized in VoiceAllocator constructor
  - SynthEngine::noteOn() checks oscillator waveform — if PM type (18-23), sets PhysicalModelType and triggers noteOn
  - SynthEngine::noteOff() calls physicalModel.noteOff() for release decay acceleration
  - process() loop renders PM output instead of oscillator when waveform is PM type
  - No unison for PM voices (single voice per note)
- **Dart waveform enum**: pmKarplus(18), pmKarplusBright(19), pmKarplusBass(20), pmModalMallet(21), pmModalVibraphone(22), pmModalSteel(23)
- Added to `dartToInternal[]` mapping and `_waveformToInt()` helper

### Phase 4.1 — Arpeggiator engine (C++ core): COMPLETE ✓
- 5 patterns, tempo 20-300 BPM, gate 0-100%, octave range 1-4, 4 resolutions
- Note routing through arp when enabled
- Thread-safe param queue integration
- Dart API setters on `OpenAmpSynth`
- **Swing timing**: even/odd step delay (0-100%, C++ realtime-safe)
- **Hold/Latch mode**: notes persist after key release; allNotesOff() is the escape hatch
- **currentStep/totalSteps FFI getters**: polled at 50ms for live LED display
- **UI**: live step LED indicator, BPM display (hardware LCD feel), swing knob, hold toggle
- **Missing**: rhythm patterns, chord memory

### Phase 5.1 — Preset expansion: COMPLETE ✓
- Expanded from 36 to **1,415 presets** across all 25 categories
- Pads: 50+ (Blade Runner, Vangelis Strings, Dreamscape, Dark Matter, etc.)
- Leads: 50+ (Neon, Laser, Acid, Supersaw, Moog Voyager, Hardstyle, etc.)
- Bass: 40+ (Sub, Reese, Wobble, 808, FM, Neuro, PWM, etc.)
- Keys: 35+ (DX7 Bells, Electric Piano, Clavinet, Harpsichord, etc.)
- Arps: 30+ (Outrun Arp, Crystal, Marimba, Trance Gate, etc.)
- FX: 25+ (Sweep Riser, Impact, Laser, Explosion, Space Drone, etc.)
- Synthwave: 25+ (Retrowave, Miami Lights, Night Rider, Darksynth, etc.)
- Custom: 15+ (Init Patch, Weather Report, Rain Dance, Deep Space, etc.)
- Plus categories: Piano, Organ, Guitar, Strings, Brass, Choir, Percussion

### Phase 1 — Drum Synthesis Engine (ROADMAP Phase 1): COMPLETE ✓
- 16 drum sound types: KICK, SNARE, CLOSED_HH, OPEN_HH, TOM_H/M/L, CRASH, RIDE, CLAP, RIMSHOT, COWBELL, SHAKER, CONGA_H/L
- **Quality-pass algorithms** (May 2026) — physical modeling principles:
  - **Kick**: sub-boom + body + shell resonance + beater click + knock transient. Exponential pitch envelope.
  - **Snare**: shell (fundamental + overtone) + 4 parallel wire resonators on pink noise + strike transient + rimshot edge
  - **Hi-hats**: 6 inharmonic sine partials + pink noise HPF. Closed=tight, open=long shimmer.
  - **Toms**: fundamental + drumhead overtone (1.59x) + shell resonance + stick click
  - **Crash**: 8 metallic partials with freq-dependent decay + pink noise BPF + bell attack
  - **Ride**: bell ping with 3 inharmonic overtones + pink noise shimmer
  - **Clap**: 4-pulse burst + room ambience tail
  - **Cowbell**: LP-style 853Hz + 1130Hz with triangle waves
  - **Shaker**: pink noise with amplitude modulation
  - **Congas**: main tone + slap overtone + hand noise
  - All drums use **pink noise** (Paul Kellet's method) instead of white noise
  - Stereo panning for cymbals (crash left, ride right)
- 32-voice drum polyphony with voice stealing (steals oldest by envelope phase)
- 10 kit presets (Standard, Room, Power, TR-808, TR-909, Electronic, Jazz, Brush, Orchestra, SFX)
- GM2 percussion mapping (MIDI notes 35-64)
- Hi-hat choke groups (closed HH mutes open HH)
- Block-processed inside SynthEngine — no standalone FFI needed
- Controlled via param queue: DRUM_KIT_PRESET, DRUM_LEVEL, DRUM_NOTE_ON, DRUM_NOTE_OFF
- Dart model: `DrumKitConfig` with kit index 0-9 and 10 kit names

### Phase 3 — Wavetable Engine (ROADMAP Phase 3): COMPLETE ✓
- WavetableOscillator with cubic hermite interpolation (4-point with wraparound)
- **12 built-in wavetable types** with velocity layers (soft/medium/hard):
  - Piano, Guitar, Choir, Brass, Strings, Woodwind, Organ, Bell, Synth Bass, Synth Lead, Pad, Electric Piano
  - Bell uses inharmonic partials (tubular bell ratios: 1.0, 2.76, 5.40, 8.93...)
  - Soft layer: fewer harmonics + lowpass filter. Hard layer: boosted highs.
- `getBuiltinWavetableWithVelocity(int type, float velocity)` selects layer based on velocity
- `getBuiltinWavetableCount()` / `getBuiltinWavetableName()` for UI enumeration
- Dart-to-C++ waveform mapping via `dartToInternal[]` lookup table — 18 waveform values (0-17)
- Wavetable position mapping: piano=0.08, guitar=0.16, choir=0.24, brass=0.32, strings=0.40, woodwind=0.48, organ=0.56, bell=0.64, bass=0.72, lead=0.80, pad=0.88, epiano=0.96
- WavetableBank for future custom wavetable loading

### Phase 7 — Multitimbral 16-Part Engine: COMPLETE ✓
- `SynthPart` struct containing per-timbre osc1, osc2, filter, envelopes, LFOs
- `std::array<SynthPart, 16> parts_` in SynthEngine
- Backward compatibility: legacy setters route to `parts_[0]`
- Voice allocator tags each voice with `partIndex`
- MIDI channel routing: `channelToPart()` maps ch 0-15 to parts
- Per-part volume, pan, mute, solo with `anySolo_` mix bus logic
- OMNI mode support per part

### Phase 8 — Recording Engine: COMPLETE ✓
- `WavWriter` class: 16/24/32-bit WAV output, proper RIFF headers
- `Recorder` class: transport state machine (STOPPED/RECORDING)
- Integrated into `SynthEngine::process()` — captures stereo mix before drums
- FFI exports: `startRecording(path)`, `stopRecording()`, `isRecording()`, `recordedSeconds()`

### Phase 9 — MIDI File I/O: COMPLETE ✓
- `MidiFileReader` / `MidiFileWriter` for Standard MIDI Files (SMF)
- Format 0/1 support, variable-length quantities, meta events, SysEx, running status
- `MidiEvent` struct with tick, status, data1, data2
- `iterateMidiEvents()` for time-ordered playback scheduling
- FFI exports for load/save/event enumeration

### Current Capabilities
- 64-voice polyphony, dual oscillators with unison (up to 8 voices each)
- **24 waveforms**: sine, saw, square, triangle, noise, pulse, **12 wavetables** (piano, guitar, choir, brass, strings, woodwind, organ, bell, synth bass, lead, pad, e.piano), **6 physical models** (plucked, bright pluck, bass pluck, mallet, vibraphone, steel drum)
- **Drum synthesis engine**: 16 drum types, 10 kit presets, GM2 mapping, block-processed inside SynthEngine
- **Rhythm Pattern Player**: 24 patterns, 9 categories, 6 variations, song mode, swing
- **Multitimbral engine**: 16 parts, MIDI channel routing, per-part volume/pan/mute/solo
- **Recording**: WAV export 16/24/32-bit stereo
- **MIDI file I/O**: SMF import/export
- Resonant SVF filter (LP/HP/BP) + filter drive, key tracking
- 2 ADSR envelopes (amp + filter) with delay/hold stages and curve shaping, + pitch envelope
- 2 LFOs with S&H, random walk, fade-in, tempo sync, per-voice mode
- 11 FX types: chorus, delay, reverb, phaser, flanger, drive, compressor, EQ, limiter, rotary, tremolo
- 1,415 factory presets across 25 categories
- Arpeggiator with 5 patterns, swing, hold/latch, 4 resolutions, live step LEDs
- Keyboard split & layer with dual engine routing
- 16-step sequencer, mod matrix, macro controls, preset morphing
- Favorites system with named setlists
- Desktop (PortAudio) + Android (Oboe) audio backends
- Synthwave-themed UI with oscilloscope + spectrum analyzer
- Mobile UX: hamburger drawer, landscape split-view, collapsible panels
- **Standalone setup system**: `opensynth setup`, `opensynth doctor`, `opensynth config` — independent from Hermes and OpenShark

### Phase 6 — Android port (Oboe audio backend): APK BUILT ✓
- **Architecture**: Same FFI symbol names, different backend. Dart calls `audio_stream_create_for_synth()` etc. regardless of platform. On Android these resolve to Oboe; on desktop to PortAudio. Zero Dart code changes needed.
- **Oboe backend**: `oboe_audio_stream.h/.cpp` — LowLatency, Exclusive sharing, Float stereo, AudioStreamDataCallback
- **Oboe FFI**: `oboe_audio_ffi.cpp` — exports identical C symbols as `audio_stream_ffi.cpp`. System lifecycle = no-ops. Device enumeration = single "Default" device stub.
- **Oboe builder API**: v1.8.0 returns raw pointers from `.setFoo()` — use `->` for chaining after the first call. See pitfalls section.
- **CMake**: `if(ANDROID)` branch compiles vendored Oboe from `native/oboe/` (GLOB_RECURSE over src dirs), links `oboe` + `log` + `OpenSLES`. `else()` branch preserves PortAudio unchanged. Common sources in `COMMON_SOURCES`. `LIBRARY_OUTPUT_DIRECTORY` must NOT be set for Android — Gradle controls .so placement.
- **Gradle**: `android/app/build.gradle.kts` has `externalNativeBuild { cmake { path = file("../../native/CMakeLists.txt"); version = "3.22.1" } }` with `cppFlags += "-std=c++17"` and `ANDROID_STL=c++_shared`.
- **Dart platform abstraction**: `lib/ffi/audio_platform.dart` — `isAndroid`, `isMobile`, `hasAudioDeviceEnumeration`. Settings screen conditionally hides device picker on mobile.
- **Mobile UX**: IMPLEMENTED. Hamburger drawer navigation, Column-based synth screen: compact top bar (preset name tap-to-cycle, octave buttons, master volume slider, panic), scrollable collapsible panels in middle, full-width keyboard spanning entire bottom (200dp landscape / 250dp portrait — up from 160/180 after touch testing). Keys are NOT in a side panel — they get the full screen width.
- **APK**: Debug build (~153MB) with ARM64 native engine. Target device: Pixel 8a. GitHub release `v0.1.0-alpha`.
- **iOS**: Not started. Will use Audio Toolbox / Core Audio (AUAudioUnit). Same FFI-symbol-matching pattern.
- See `references/android-port-architecture.md` for full details.
- **Remaining after first device test**: touch keyboard glide/multitouch (partial — pointer tracking added, glide not yet), buffer sizing for Android latency

### Phase 10 — SFZ Sample Engine (sfizz integration): COMPLETE ✓
- **sfizz** (BSD-2) selected for SFZ sample playback — statically linked, adds ~1.9MB to .so
- **Sample libraries**: VSCO 2 CE (orchestral, 3.1GB) + Salamander Grand Piano (CC0, 1.9GB)
- **Desktop path resolution**: `resolveSamplePath()` utility handles exe-relative, flutter_assets, and dev-mode paths. `scripts/deploy-desktop.sh` copies samples next to executable.
- **Audio stream architecture**: UNIFIED single-stream architecture. `SynthEnginePair` optionally embeds a `SampleEngine*` and mixes all sources (engine A + engine B + sample) in ONE `Pa_OpenStream` callback. See `references/unified-audio-stream-architecture.md`.
- **Split keyboard with samples**: Notes route correctly via `NoteRouter` respecting `split.enabled` and `zonesForNote()` for both synth and sample engines. Zone A preset sync fixed.
- **Loading progress**: Poll-based progress indicator for large SFZ parse (sfizz has no native progress callbacks).

### Mobile Keyboard Touch Handling
- Switched from `GestureDetector.onTapDown/Up` to raw `Listener` with `HitTestBehavior.opaque` for reliable tap registration on mobile.
- `ConsumerStatefulWidget` tracks `_pointerToNote` and `_noteRefCount` maps — proper multi-touch support (multiple simultaneous notes).
- `_noteRefCount` handles the case where the same MIDI note gets triggered by two pointers — note-off only fires when refcount drops to zero.
- Stuck notes cleaned up in `dispose()` — all active notes released on widget teardown.
- Black key height is 62% of white key height (dynamic via `LayoutBuilder`) — old code hardcoded 60dp.
- Keys fill 100% of the allocated `SizedBox` height, no wasted space for octave controls (those live in the mobile top bar).
- Glide/slide-across-keys not yet implemented — `Listener` fires `onPointerMove` but the current code doesn't translate pointer movement into slide-to-adjacent-key note transitions.

## Feature Gap vs Juno-Di

See `references/juno-di-research.md` for full specs. Major remaining gaps:
- Polyphony: 64 vs 128
- Presets: 1,415 vs 1,338 (exceeds Juno-Di) ✓
- FX types: 11 vs 79+ (EQ, limiter, rotary, tremolo added since last count)
- Drum synthesis: 16 sounds with 10 kits ✓ (vs Juno-Di 0 — this is a superset feature)
- Rhythm patterns: 24 patterns, 9 categories ✓ (vs Juno-Di 0 — superset)
- **Multitimbral: 16-part engine ✓** (was a gap, now complete)
- **Recording: WAV export ✓** (was a gap, now complete)
- **MIDI file I/O: SMF import/export ✓** (was a gap, now complete)
- No PCM sample engine (wavetable only, no real samples) — **RESEARCHED**: sfizz (BSD-2) selected for SFZ sample playback, see `references/pcm-sample-engine-research.md`
- No favorites system (100 slots) — COMPLETE ✓ (favorites + setlists implemented)
- Arpeggiator patterns: 5 vs 128+
- Wavetable engine: 12 instruments via synthesized single-cycles ✓ (no real samples yet)

## Known Good Baselines

The project has a history of over-engineering destroying working builds. When debugging "everything is broken", check these baselines first:

| Commit | Description | State |
|--------|-------------|-------|
| `fa3a61d` | Initial Grid Snapshot | Basic synth, 36 presets, working FFI |
| `5efaf14` | Grid Expansion — 50 presets, FX, pulseWidth, production UI | Stable base, 50 presets |
| `dbdb006d` | Icons, factory presets, arp engine, FFI bindings | Working, added arpeggiator |
| `a285005` | Arpeggiator overhaul + multi-FX + expanded presets | Working, more FX types |
| `8eac2b5` | Android Oboe backend + platform abstraction | Working, mobile backend added |
| `26fd20b` | Mobile UX — hamburger drawer, landscape split-view, collapsible panels | Working, mobile UI added |
| `d3e2f90` | Dart analysis fixes for Android build | Working, analysis clean |
| `862ed5b` | Roadmap docs added | Working, docs only |
| `253903f` | Rebrand: synthclaw → synthclaw | Working, rebrand only |
| `cfa9273` | Rebrand continued | Working, rebrand only |
| `c162daf` | Sync: update from local development session | **1,453 presets, FULL FEATURE SET, works after minor fixes** |
| `bce64a8` | Revert: reset to Grid Expansion | **DESTRUCTIVE REVERT — threw away 1,453 presets, back to 50** |
| `1fff4ca` | Rebrand on clean Grid Expansion base | Current HEAD — 50 presets only |

**Recovery procedure**: `git checkout c162daf` gets you the 1,453-preset version with full synthesis engine, arpeggiator, FX, keyboard split, sequencer, mod matrix, etc. It needs 3 minor switch-statement fixes for new Waveform enum values (see pitfall 66). `git checkout 5efaf14` gets the minimal 50-preset stable base.

### The "bce64a8" Trap

Commit `bce64a8` ("revert: reset to Grid Expansion") is the actual destructive commit — it threw away 1,453 presets and all advanced features, returning to the 50-preset `5efaf14` base. The author created this revert because the working tree had become polluted with broken sample engine files from May 30-31 experiments.

**Lesson**: When `git status` shows many `??` untracked files that conflict with committed code, the problem is working tree pollution — NOT the committed state. Use `git stash -u` to save untracked files, then `git checkout <commit>` to get to a clean state. Do NOT assume the commit itself is broken.

### The "Working Tree Pollution" Problem

When `git status` shows many `??` untracked files:
- They may be from abandoned experiments
- They may conflict with committed files
- They may reference methods that don't exist in the committed code

**Check**: `flutter analyze` — if untracked files cause errors, they're harmful.

**Fix**: `git stash -u` saves ALL untracked files, then `git checkout <commit>` gives you a clean state. If you need the stashed files back later, `git stash pop` restores them.

```bash
git stash -u              # save tracked + untracked files
git checkout c162daf      # check out the good commit
flutter analyze            # verify it's clean
# ... do work ...
git checkout -             # go back to previous branch
git stash pop              # restore stashed files if needed
```

### The "Working Tree Pollution" Problem

When `git status` shows many `??` untracked files:
- They may be from abandoned experiments
- They may conflict with committed files
- They may reference methods that don't exist in the committed code

**Check**: `flutter analyze` — if untracked files cause errors, they're harmful.

**Fix**: `git stash -u` saves ALL untracked files, then `git checkout <commit>` gives you a clean state. If you need the stashed files back later, `git stash pop` restores them.

```bash
git stash -u              # save tracked + untracked files
git checkout c162daf      # check out the good commit
flutter analyze            # verify it's clean
# ... do work ...
git checkout -             # go back to previous branch
git stash pop              # restore stashed files if needed
```

## Git Archaeology for Recovery

When a project is "fucked" and you need to find when it last worked:

```bash
# 1. See recent commits with dates
git log --oneline -20

# 2. Find scope creep — what changed since the good commit
git diff <good-commit>..HEAD --stat | tail -20
# If you see 200+ files and 60k+ lines added, you found the problem.

# 3. Inspect a file from the good commit without checking out
git show <commit>:path/to/file.dart | head -50

# 4. Check preset count (OpenSynth-specific health indicator)
git show <commit>:lib/data/factory_presets.dart | grep -c "SynthPreset("

# 5. Check if the good commit actually builds (without modifying working tree)
git stash -u                    # save ALL files including untracked
git checkout <commit>           # detached HEAD at target commit
flutter analyze                 # verify it's clean
git checkout -                  # go back to previous branch
git stash pop                   # restore stashed files

# 6. Switch to the good commit for real work
git stash -u
git checkout <commit>
# ... do work, build, test ...

# 7. Create a branch to preserve the good state
git checkout -b working-<date> <commit>
```

**Key technique**: `git stash -u` (stash including untracked files) is essential when the working tree has broken experimental files. Without `-u`, untracked files remain and may conflict with the checked-out commit's files.

## Pitfalls

1. **PortAudio init/terminate warfare**: Device enumeration must use AudioSystem cache, never call Pa_Init/Term independently. This was the #1 audio crash cause.
2. **Cross-thread parameter mutation**: Never call direct FFI setters (setOsc1Waveform etc.) while audio is running — use the ParamQueue instead.
3. **Flanger mono buffer**: The flanger used one shared delay buffer for L+R, causing channel bleed. Fixed with separate L/R buffers.
4. **Compressor makeup gain**: Was adding raw signal (doubling amplitude) instead of multiplying. Fixed to `signal * (1.0 + makeupGain)`.
5. **Provider disposal order**: Audio stream must stop+dispose BEFORE synth engine dispose.
6. **LSP include path errors**: C++ LSP will show errors for includes — false positives if `make` succeeds.
7. **Feedback loop runaway**: Delay-based effects need clamped buffer writes/reads to [-2, +2] and tanh output clipper. Hard clamp kills PipeWire.
8. **Phaser tan() explosion**: Always `std::min(static_cast<float>(std::tan(...)), 10.0f)` — never omit the `static_cast<float>`.
9. **std::min type mismatch**: When mixing `double` and `float`, always cast to float first.
10. **Adding new native params**: Must update 4 places: `ParamQueue::ParamId` enum, `SynthEngine::applyParam` case, Dart `ParamId` constants, Dart `OpenAmpSynth` setter. The enqueue_float/enqueue_int FFI symbols are generic — no new C symbols needed for queue-based params.
11. **Arpeggiator const correctness**: `noteFromPattern()` is `const` but calls `fastRand()` which modifies `randomState_`. Make `randomState_` `mutable` and `fastRand()` `const` to satisfy.
12. **Subagent preset generation timeout**: Spawning a subagent to generate 200+ presets will time out after 600s. Use a Python script on `execute_code` or write presets directly instead. The subagent also produces broken Dart syntax if not explicitly instructed on Dart's named parameter style (`required this.param` with `=` for defaults).
13. **Cross-platform audio FFI pattern**: On Android, the native .so exports the SAME C symbol names as desktop (e.g. `audio_stream_create_for_synth`). Dart FFI bindings don't need platform-specific code — just platform-specific CMake compilation. Never create separate Dart binding files for different audio backends.
14. **Build artifacts in git**: `native/build/` must be in `.gitignore`. Build artifacts (.o, .o.d, CMakeCache, Makefiles) should never be tracked. If they end up tracked, use `git rm -r --cached native/build/` to remove from index without deleting files.
15. **Flutter SDK on headless servers**: Flutter and Dart SDKs won't be available on headless Linux. C++ can be verified via cmake/make. Dart syntax must be verified by the user on their desktop. Never assume `flutter analyze` will work.
16. **CMake platform branching for audio backends**: Extract common source files into a `COMMON_SOURCES` CMake variable. Use `if(ANDROID)` / `else()` to add platform-specific audio files + dependencies. Never duplicate the full source list between branches.
17. **Mobile platform-conditional widgets**: Use `isMobile` from `audio_platform.dart` as an early return at the TOP of `build()` in `MainShell` and `SynthScreen`. Do NOT create separate `main_mobile.dart` entry points — the existing shells redirect cleanly. Both shells share `mainShellIndexProvider` and the same `IndexedStack` of screens, so tab state persists across drawer/bottom-nav navigation.
18. **Collapsible panels for mobile**: Use `CollapsibleSection` widget (wraps `ExpansionTile`) for mobile synth panels. Each section has an `accentColor` that glows when expanded. Default to collapsed (`initiallyExpanded: false`) to maximize playable screen area. Side-by-side panel pairs (OSC 1+2, Filter+Amp) use `Row` with `Expanded` children inside the collapsible body.
19. **Java version for Flutter Android builds**: Java 25 causes Gradle build failures. Must use Java 21 (`JAVA_HOME=/usr/lib/jvm/java-21-openjdk`). Default Arch Java may be newer — always verify.
20. **Flutter `const` with runtime theme values**: `SynthTheme.of(context).*` returns runtime objects — cannot be used in `const` constructors or `const` gradients. Remove `const` from widget calls and gradient literals that reference theme data.
21. **Dart constructor initializer list syntax**: A `;` instead of `,` between initializer entries causes subsequent methods to be parsed as top-level declarations, producing cryptic "methods aren't defined" errors. Check initializer separators when methods mysteriously vanish.
22. **Large file uploads via `gh release create`**: APKs are 150MB+. The upload takes significant time — use a long timeout (300s+) or the command will appear to hang. Do not assume failure on slow uploads.
23. **Flutter unused import cascade**: After major refactors (adding mobile shells, platform abstraction), run `flutter analyze` to catch unused imports. These are warnings, not errors, but cleaning them prevents noise in future analysis.
24. **Oboe FetchContent fails in NDK CMake**: `FetchContent_Declare` with `GIT_REPOSITORY` does NOT work inside Android NDK CMake context — the git clone silently fails, leaving `_deps/oboe-src/` empty and CMake configure errors with missing source files. **Fix**: Vendor Oboe directly into `native/oboe/` (git clone --depth 1 --branch 1.8.0) and use `file(GLOB_RECURSE)` over its src directories. This is deterministic and works offline.
25. **Oboe 1.8.0 builder chaining API**: `AudioStreamBuilder().setDirection(...)` returns `AudioStreamBuilder*` (pointer), not a reference. Subsequent calls must use `->` not `.`. Create builder on stack first: `oboe::AudioStreamBuilder builder; builder.setDirection(...)->setPerformanceMode(...)->...`. The first call uses `.` (member access on object), all subsequent use `->` (member access on returned pointer).
26. **Android OpenSLES link required**: Oboe's OpenSL ES backend needs `-lOpenSLES`. Without it you get linker errors like `undefined symbol: SL_IID_ENGINE`. Add `OpenSLES` to `target_link_libraries` on Android.
27. **CMake LIBRARY_OUTPUT_DIRECTORY vs Android Gradle**: Setting `LIBRARY_OUTPUT_DIRECTORY` on a shared library target conflicts with Android Gradle plugin's native build system — Gradle controls where the .so goes. Wrap the property in `if(NOT ANDROID)` to only set it for desktop builds.
28. **Stale jniLibs break Android builds**: A manually placed `.so` in `android/app/src/main/jniLibs/` (e.g. a desktop x86_64 build) gets packaged even when Gradle's `externalNativeBuild` is properly configured. This creates an APK with native libs for wrong architectures. **Always delete jniLibs** when migrating to Gradle-managed native builds. The correct flow is: CMake compiles for each ABI → Gradle merges into APK automatically.
29. **Verifying ARM64 native lib in APK**: After building, always verify with `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libopenamp`. You should see `lib/arm64-v8a/libopenamp_dart_ffi.so` (not just x86_64). If ARM64 is missing, the native build isn't wired into Gradle correctly — check `externalNativeBuild` in `build.gradle.kts`.
30. **Mobile keyboard layout — full width at bottom**: The mobile synth screen must have the keyboard spanning the ENTIRE bottom of the screen with controls above. Do NOT use a side-by-side split (60/40 Row). Structure: Column with (1) compact top bar ~48dp, (2) expanded scrollable panels, (3) full-width KeyboardWidget at bottom with fixed height (200dp landscape / 250dp portrait — tested optimal for Pixel 8a at 412dp width). See pitfall 34 for the LayoutBuilder constraint requirement.
31. **~~Waveform enum gap~~ — FIXED (May 2026)**: The C++ `OscWaveform` now has WT_PIANO(6), WT_GUITAR(7), WT_CHOIR(8) with full wavetable synthesis. Dart-to-C++ mapping corrected via `dartToInternal[]` table. No more silence.

32. **~~Piano presets via subtractive synthesis~~ — FIXED (May 2026)**: Piano/guitar/choir presets now use actual wavetables via `WavetableOscillator` with cubic interpolation. The subtractive fallback is no longer needed.
33. **Desktop binary update after preset/engine changes**: When factory presets or engine code change, rebuild with `flutter build linux --release` and copy `build/linux/x64/release/bundle/{open_synth,lib/*.so,data/*}` to `~/.local/share/open_synth/`. **Cannot overwrite while running** — `cp` returns "Text file busy". Close the app first, then copy. The symlink at `~/.local/bin/open_synth` points to the binary.

34. **KeyboardWidget uses LayoutBuilder — needs constrained height**: After the mobile rewrite, `KeyboardWidget` uses `LayoutBuilder` to fill available height dynamically. Every screen that includes it MUST wrap it in a `SizedBox(height: N)`. Without a constraint, `LayoutBuilder` gets infinite height and crashes. Desktop screens use `SizedBox(height: 120)`, mobile uses 200/250dp.

35. **Mobile keyboard — Listener vs GestureDetector**: `GestureDetector.onTapDown/Up` fails on tiny mobile keys because it requires a stationary finger. `Listener` + `HitTestBehavior.opaque` fires `onPointerDown` the instant any touch enters the key bounds — no finger-lift required. For slide-across-keys, you'd also need `onPointerMove`/`onPointerEnter` handling (not yet implemented).

36. **Waveform enum mapping — Dart→C++ translation layer**: Dart `Waveform` enum values do NOT match C++ `OscWaveform` values. The fix is a `dartToInternal[]` lookup table inside `Oscillator::setWaveform()`. The old code had Dart sine(0) silently playing C++ SAW(0). Every preset was using the wrong waveform — this was a systemic bug since project inception. When adding any new waveform type, always check the Dart→C++ mapping.

37. **DrumKit is embedded in SynthEngine, not standalone FFI**: The `drum_ffi.cpp` exports exist for potential standalone use, but the actual integration is `DrumKit drumKit_` as a SynthEngine member. Drum control goes through the param queue (DRUM_KIT_PRESET, DRUM_LEVEL, DRUM_NOTE_ON/DRUM_NOTE_OFF) — same pattern as all other synth params. No separate Dart FFI bindings needed.

38. **Drum note-on encoding in float param queue**: The param queue carries one `float` per entry. For `DRUM_NOTE_ON`, the encoding is `midiNote + velocity` (int part = note, fractional = velocity). Velocity defaults to 0.8 if the fractional part is ≤ 0. This packing avoids needing a separate int+float param pair.

39. **Wavetable data generation on first use**: Wavetables are 2048-sample float arrays generated at runtime via `ensureWavetablesInitialized()`. They're 2048 × 4 bytes × 3 tables = 24KB — negligible memory. Do NOT hardcode 2048-sample arrays as compile-time constants (would be ~50KB of source). The runtime generation takes microseconds on first call.

40. **DrumKit block processing — stack allocation, not heap**: `drumKit_.process()` takes flat `float*` buffers. The SynthEngine integration uses a stack-allocated `float drumLeft[2048]` / `float drumRight[2048]` — zero heap allocation on the audio thread. The 2048-sample maximum matches the maximum realistic PortAudio block size (~42ms at 48kHz).

41. **Drum pad velocity from tap position**: On mobile, there's no pressure sensor. Use vertical tap position within the pad: `velocity = 1.0 - (localPosition.dy / size.height) * 0.7` (range 0.3–1.0). Bottom of pad = hardest hit. This is encoded in `_DrumPadState._velocityFromPosition()`.

42. **CollapsibleSection with ConsumerWidget — const gotcha**: `CollapsibleSection` has a `const` constructor, so `const CollapsibleSection(...)` works. But if the `child` is a `ConsumerWidget` or `ConsumerStatefulWidget`, the child MUST also be `const`. All Riverpod widgets (ConsumerWidget, ConsumerStatefulWidget) support const constructors — just add `const` before the child widget name in the CollapsibleSection.

43. **Drum provider bridge pattern**: The `drumKitNativeBridgeProvider` follows the same pattern as `arpeggiatorNativeBridgeProvider` — it's a `Provider<void>` that `ref.watch`es both the synth engine and the drum config, pushing changes through the param queue on every config change. Consumers just `ref.watch(drumKitNativeBridgeProvider)` to keep the binding alive. The drum config state lives in a `StateNotifierProvider<DrumKitConfigNotifier, DrumKitConfig>`.

44. **NEVER use execute_code + write_file for Dart source files**: `read_file` inside `execute_code` returns content with line number prefixes (e.g. `     1|import '...'`). Writing this back via `write_file` bakes the line numbers INTO the file content — corrupting the Dart source with triplicated line numbers like `     1|     1|     1|import`. The file becomes unparseable and must be restored with `git checkout`. For bulk edits to Dart files, use `sed` in the terminal (with `-i` for in-place) or the `patch` tool. See pitfall 45 for the sed technique.

45. **Surgical sed for category-specific preset edits**: When changing waveforms across an entire preset category (e.g., all 52 piano presets from saw→wt_piano), use line-number-targeted `sed`:
   ```
   sed -i 'LINE1s/Waveform\.saw/Waveform.wt_piano/; LINE2s/...' file
   ```
   First get the category line numbers with `search_files(pattern="category: PresetCategory\.piano")`, sort them, then build sed commands targeting `line+1` (osc1) and `line+2` (osc2). Never use context-based sed (`/piano/,/^  \)/s/...`) — it's too aggressive and leaks into adjacent categories. Never use regex-based search-replace across the whole file — it will hit non-piano presets.

46. **Hive preset cache staleness — factory version bust**: When factory presets are updated (new presets, waveform changes, new categories), the Hive cache returns stale old data because `_load()` prefers stored presets over factory. Fix: add a `factoryPresetVersion` constant (int, bump on each change). In `_load()`, check `_box?.get('factoryPresetVersion')` against the constant. If version changed or null, reload from `factoryPresets`, save the new version, and persist. This one-time bust on next launch fixes the "no presets found" symptom for newly-added categories.

48. **Keyboard split note routing must use NoteRouter everywhere**: Both `ComputerKeyboardListener` and `KeyboardWidget` MUST route all notes through `NoteRouter` — never call `playbackStateProvider` or `zoneBPlaybackProvider` directly for noteOn/noteOff. The `NoteRouter` tracks which zones each note was sent to so note-off always hits the same engine(s) even if split config changes mid-hold. Panic (`\` key) and dispose cleanup must call `noteRouterProvider.allNotesOff()`, NOT `playbackStateProvider.allNotesOff()` — the latter only hits zone A and strands zone B notes.

49. **Split keyboard with sample instruments — zone routing bug**: When a sample preset is active, the keyboard/touch note routing bypassed the split system entirely. The fix: always check `split.enabled` and use `split.zonesForNote()` / `split.shiftedNote()` regardless of which engine (synth or sample) is active. The sample engine receives the same zone-shifted notes as the synth engine. This applies to both `KeyboardWidget._noteOn/_noteOff` and `ComputerKeyboardListener._handleKey`.

50. **Split keyboard audio stream architecture — the "only right side works" bug**: When split mode is active, there are TWO audio paths: (1) single-engine `synthAudioStreamProvider` bound to `synthEngineProvider`, and (2) pair-engine `synthPairAudioStreamProvider` bound to `synthPairProvider`. The bug: Zone B notes go to the pair's engine B but the pair audio stream was never started because nothing `ref.watch`ed `synthPairAudioStreamProvider`. Zone A notes went to the single engine stream which WAS running. **Fix requires 4 changes**:
   - UI screens must `ref.watch(synthPairAudioStreamProvider)` (not just `synthPairProvider`) to start the pair stream
   - UI screens must also `ref.watch(zoneBMixSyncProvider)` to keep volume sync alive
   - `PlaybackStateNotifier._engine` getter must route through `pair.engineA` when split is enabled: `OpenAmpSynth.fromHandle(pair.engineA)` — uses the non-owning wrapper so dispose doesn't double-free
   - `PlaybackStateNotifier._ensureAudioRunning()` must start the pair stream when split is active, single stream otherwise
   - Panic buttons must call `noteRouterProvider.allNotesOff()` (not `playbackStateProvider`) to kill both zones
   - See `references/split-keyboard-bug-fix.md` for full reproduction + fix details.

51. **Rhythm Pattern Player integration pipeline**: Adding a new audio-thread sequencer feature follows this exact pipeline:
   1. C++ header (`native/include/rhythm_pattern_player.h`) — define data structures + class interface
   2. C++ implementation (`native/src/rhythm_pattern_player.cpp`) — build pattern library, process() method
   3. Add `ParamQueue::ParamId` entries in `param_queue.h` for UI→engine control
   4. Add member to `SynthEngine` + call `process()` in `SynthEngine::process()` at block boundaries
   5. Add `applyParam()` cases in `synth_engine.cpp` for queue-based control
   6. Add FFI exports in `synth_ffi.cpp` (C functions that call engine methods)
   7. Add Dart FFI bindings in `lib/ffi/openamp_synth.dart` (lookupFunction + field declarations)
   8. Add Dart `ParamId` constants + wrapper methods on `OpenAmpSynth`
   9. Dart model (`lib/models/rhythm_pattern.dart`) — pattern metadata
   10. Dart provider (`lib/providers/rhythm_provider.dart`) — state management + engine bridge
   11. Dart UI widget (`lib/widgets/rhythm_panel.dart`) — user interface
   12. Add source file to `native/CMakeLists.txt` `COMMON_SOURCES`
   13. Build native: `cd native/build && cmake .. && make -j$(nproc)`

49. **`var` is a Dart keyword — never use as parameter name**: `PatternVariation var` causes parser errors. Use `variation` or `patternVar` instead. This applies to any identifier that collides with Dart reserved words (`var`, `class`, `final`, `const`, `void`, etc.).

50. **Physical model integration pattern — per-voice state in Voice struct**: Physical modeling needs per-voice state (delay lines, resonators) that can't live in the global Oscillator. Add `PhysicalModelVoice physicalModel` to `Voice` struct, initialize in `VoiceAllocator` constructor with `init(sampleRate, maxDelaySamples)`. In `SynthEngine::noteOn()`, after `allocator_.noteOn()`, check `osc1_.waveform()` — if it's a PM type (18-23), call `voice->physicalModel.setType()` and `voice->physicalModel.noteOn(freq, velocity)`. In `noteOff()`, find the voice by midiNote and call `physicalModel.noteOff()`. In the process loop, when rendering unison voices, skip normal oscillator processing for PM waveforms and call `voice->physicalModel.process()` instead. PM voices don't support unison — only render on `uv == 0`.

51. **Wavetable velocity layer generation**: Use `generateVelocityLayers()` helper that creates soft/medium/hard variants. Soft: roll off higher harmonics + apply lowpass. Hard: boost higher harmonics. Bell (inharmonic) shares the same wavetable across all layers — bells don't change timbre much with velocity. Store layers in `WavetableEntry { soft, medium, hard }`.

52. **Pink noise filter states in DrumVoice**: Paul Kellet's pink noise needs 7 filter state variables (`pinkB0..pinkB6`). Add these to `DrumVoice` struct. Reset all to 0 on voice allocation. The `pinkNoise()` free function takes these by reference.

53. **Multi-mode oscillator for cymbals/hats**: Metallic instruments need multiple sine waves at inharmonic ratios. Use `modePhases[8]` array in `DrumVoice` to track up to 8 partials. Each partial has its own decay rate (higher = faster). Initialize all phases to 0 in `configureVoice()`.

54. **Exponential pitch envelope for kicks/toms**: Real drums don't have linear pitch drops. Use `pitchEnvelope(phase, startFreq, endFreq, sweepTime, totalDecay)` with `pow(0.7, sweepPhase * 10.0)` curve — fast initial drop, then settles.

55. **Project boundary: standalone means no runtime Hermes bridges**: When user says "standalone" they mean own setup, own config, own doctor, no runtime dependencies on other tools. BUT preserve setup/config transfer logic — import from Hermes/OpenShark during setup is fine. Remove runtime bridges (mod hermes, shell-outs) while keeping config fields and setup wizard questions. Always clarify source vs destination for any migration. OpenShark native implementations preferred over bridges.

56. **Multitimbral engine retrofit pattern — backward-compatible part-based architecture**: To add multitimbral support to an existing monotimbral engine without breaking everything, create a `SynthPart` struct containing all per-timbre parameters (osc1, osc2, filter, envelopes, LFOs). The engine gets `std::array<SynthPart, 16> parts_`. Legacy parameter setters (called from FFI and preset load) route to `parts_[0]`. New multitimbral features use `parts_[partIndex]`. The voice allocator tags each voice with `partIndex` (added to `Voice` struct). MIDI channel routing: `channelToPart()` maps MIDI ch 0-15 to part indices. Solo/mute logic: track `anySolo_` flag, silence non-solo parts when any solo is active. This preserves ALL existing behavior for single-timbre use while adding 16-part capability.

57. **C++ member-move cascade — systematic refactoring when moving engine members into nested structs**: When refactoring a monolithic class by moving its member variables into a nested struct (e.g., `osc1_` → `parts_[0].osc1`), EVERY reference site breaks simultaneously. The fix is systematic search-replace across these categories:
   - **Constructor init list**: `osc1_(...)` → `parts_[0].osc1(...)` (or remove if struct has default ctor)
   - **Reset method**: `osc1_.reset()` → `parts_[0].osc1.reset()`
   - **Param queue handler** (`applyParam`): `osc1_.setWaveform(...)` → `parts_[0].osc1.setWaveform(...)`
   - **Preset save** (`savePreset`): `osc1_.waveform()` → `parts_[0].osc1.waveform()`
   - **Preset load** (`loadPreset`): same pattern
   - **Voice processing loop**: `osc1_.waveform()` → `parts_[0].osc1.waveform()` (or better, use `parts_[voice->partIndex]`)
   - **Physical model setup in noteOn**: `osc1_.waveform()` → `part.osc1.waveform()` where `part = parts_[partIdx]`
   - **LFO processing**: `lfo1_.process()` → `parts_[0].lfo1.process()`
   Use `search_files` to find all occurrences of each old member name, then patch systematically. Don't try to fix one-by-one — you'll miss sites.

58. **Variable name collision with accessor methods**: If a class has a method named `part()` (or any common noun), NEVER use `part` as a local variable name — the compiler interprets `part.osc1` as "call method `part()` then access member `osc1`" which fails with "invalid use of member function". Use `voicePart`, `targetPart`, or `partRef` instead.

59. **FFI integration pipeline for new engine modules**: Adding any new C++ engine feature that needs Dart control follows this exact 13-step pipeline:
   1. C++ header (`native/include/<feature>.h`) — define data structures + class interface
   2. C++ implementation (`native/src/<feature>.cpp`) — core algorithm
   3. Add `ParamQueue::ParamId` entries in `param_queue.h` for UI→engine control
   4. Add member to `SynthEngine` + call `process()` in `SynthEngine::process()` at block boundaries
   5. Add `applyParam()` cases in `synth_engine.cpp` for queue-based control
   6. Add FFI exports in `synth_ffi.cpp` (C functions that call engine methods)
   7. Add Dart FFI bindings in `lib/ffi/openamp_synth.dart` (lookupFunction + field declarations)
   8. Add Dart `ParamId` constants + wrapper methods on `OpenAmpSynth`
   9. Dart model (`lib/models/<feature>.dart`) — data structures
   10. Dart provider (`lib/providers/<feature>_provider.dart`) — state management + engine bridge
   11. Dart UI widget (`lib/widgets/<feature>_panel.dart`) — user interface
   12. Add source file to `native/CMakeLists.txt` `COMMON_SOURCES`
   13. Build native: `cd native/build && cmake .. && make -j$(nproc)`
   This pattern was validated with RhythmPatternPlayer, Recorder, and MidiFileReader/Writer.

60. **Recording engine integration — capture before drum mix**: The recorder should capture the synth voice output BEFORE drums are mixed in. In `SynthEngine::process()`, after the per-frame voice loop writes to `output.data[]`, check `recorder_.state()` and extract from `output.data[]` into temp buffers, then call `recorder_.process(left, right, numFrames)`. After recording, proceed to drumKit processing and final mix. This keeps drums optional in the recording (can be recorded separately or mixed in later).

61. **WAV file writer — 16/24/32-bit with proper headers**: Use RIFF/WAVE format with PCM (16/24-bit) or IEEE float (32-bit) fmt chunk. Write placeholder sizes, then `finalizeHeader()` on close by seeking back to update RIFF chunk size and data chunk size. For 24-bit, pack 3 bytes per sample manually. For 16-bit, convert float [-1,1] to int16. For 32-bit, write IEEE floats directly. Always clamp input to [-1,1] before conversion.

63. **Linux desktop deployment — copy .so after rebuild**: The Flutter desktop binary at `~/.local/share/open_synth/open_synth` loads `libopenamp_dart_ffi.so` from `~/.local/share/open_synth/lib/`, NOT from the project directory. After `make` in `native/build`, ALWAYS copy: `cp /home/synth/projects/open-synth/native/libopenamp_dart_ffi.so ~/.local/share/open_synth/lib/`. The walker shortcut and `.desktop` entry point to the deployed location. Forgetting this copy is the #1 "my changes didn't take effect" bug.

64. **"Text file busy" on copy while app is running**: Cannot overwrite the running binary or its `.so` on Linux. Close the app first, then copy. The error looks like a permission issue but is actually the kernel locking mapped executable pages.

65. **Dart FFI `lookupFunction` type mapping — Dart side uses primitives, NOT FFI types**: When declaring the Dart-side typedef in `lookupFunction<NativeTypedef, DartTypedef>`, the Dart typedef MUST use primitive types (`int`, `double`, `void`), NOT `dart:ffi` types (`Int32`, `Float`, `Void`). The native side uses FFI types; the Dart side uses primitives. Example:
   ```dart
   // CORRECT — Dart side uses primitives
   final int Function(Pointer<Void>) getActiveVoices = lib.lookupFunction<
     Int32 Function(Pointer<Void>),   // native side: FFI types
     int Function(Pointer<Void>)      // Dart side: primitives
   >('synth_engine_get_active_voices');
   
   // WRONG — Dart side uses FFI types (causes compile error)
   final Int32 Function(Pointer<Void>) getActiveVoices = lib.lookupFunction<
     Int32 Function(Pointer<Void>),
     Int32 Function(Pointer<Void>)     // ERROR: can't assign int Function to Int32 Function
   >('...');
   ```
   This applies to ALL sample engine FFI bindings and any new FFI functions added. The field declarations in the bindings class must also use primitives: `final int Function(Pointer<Void>) foo;` not `final Int32 Function(Pointer<Void>) foo;`.

66. **Waveform enum exhaustiveness — add new values → update ALL switch statements**: The `Waveform` enum is used in switch statements across at least 3 widgets: `oscilloscope.dart`, `spectrum_analyzer.dart`, `preset_waveform_preview.dart`. When adding a new waveform variant, EVERY switch statement must be updated or the build fails with "not exhaustively matched". Use `search_files` to find all `switch (.*waveform)` patterns, then patch each one. The pattern is: add the new case to the existing fall-through group (e.g., `case Waveform.wtBrass:` before `case Waveform.random:`).

    **Quick fix for missing cases**: When `flutter analyze` reports `non_exhaustive_switch_statement` for Waveform, add ALL missing waveform cases to the fall-through group. The full list of waveform variants that may need adding:
    ```dart
    case Waveform.wtBrass:
    case Waveform.wtStrings:
    case Waveform.wtWoodwind:
    case Waveform.wtOrgan:
    case Waveform.wtBell:
    case Waveform.wtSynthBass:
    case Waveform.wtSynthLead:
    case Waveform.wtPad:
    case Waveform.wtEPiano:
    case Waveform.pmKarplus:
    case Waveform.pmKarplusBright:
    case Waveform.pmKarplusBass:
    case Waveform.pmModalMallet:
    case Waveform.pmModalVibraphone:
    case Waveform.pmModalSteel:
    case Waveform.random:
    ```
    These all fall through to the same "complex wavetable" or "sine harmonics blend" implementation.

67. **sfizz CMake integration — disable everything unnecessary**: sfizz has many optional features that bloat the build. Use these CMake cache variable overrides BEFORE `add_subdirectory(sfizz)`:
   ```cmake
   set(SFIZZ_SHARED OFF CACHE BOOL "" FORCE)
   set(SFIZZ_JACK OFF CACHE BOOL "" FORCE)
   set(SFIZZ_RENDER OFF CACHE BOOL "" FORCE)
   set(SFIZZ_BENCHMARKS OFF CACHE BOOL "" FORCE)
   set(SFIZZ_TESTS OFF CACHE BOOL "" FORCE)
   set(SFIZZ_DEMOS OFF CACHE BOOL "" FORCE)
   set(SFIZZ_DEVTOOLS OFF CACHE BOOL "" FORCE)
   set(SFIZZ_USE_SNDFILE OFF CACHE BOOL "" FORCE)
   set(SFIZZ_USE_SYSTEM_ABSEIL OFF CACHE BOOL "" FORCE)
   set(SFIZZ_USE_SYSTEM_GHC_FS OFF CACHE BOOL "" FORCE)
   set(SFIZZ_USE_SYSTEM_SIMDE OFF CACHE BOOL "" FORCE)
   set(SFIZZ_USE_SYSTEM_KISS_FFT OFF CACHE BOOL "" FORCE)
   set(SFIZZ_USE_SYSTEM_PUGIXML OFF CACHE BOOL "" FORCE)
   set(SFIZZ_USE_SYSTEM_CXXOPTS OFF CACHE BOOL "" FORCE)
   set(SFIZZ_USE_SYSTEM_CATCH OFF CACHE BOOL "" FORCE)
   set(SFIZZ_GIT_SUBMODULE_CHECK OFF CACHE BOOL "" FORCE)
   set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
   ```
   Then link with `sfizz::sfizz` target. The static library is ~22MB source, builds in ~2 minutes on a modern machine. The resulting `libopenamp_dart_ffi.so` grows by ~1.9MB (sfizz + dependencies statically linked).

68. **VSCO 2 CE sample library download**: The GitHub release asset URL (`https://github.com/sgossner/VSCO-2-CE/releases/download/1.1.0/VSCO-2-CE-1.1.0.zip`) returns 404. Use the Dropbox mirror instead: `curl -L -o vsco-2-ce.zip "https://www.dropbox.com/s/p2p6whunwekb9s1/VSCO-2-CE-1.1.0.zip?dl=1"`. The zip is 2.1GB, extracts to 3.1GB with 75 SFZ files. License: CC0 (public domain, no attribution required).

69. **Sample engine audio stream — separate stream from synth**: The sample engine uses its own `audio_stream_create_for_sample_engine()` rather than mixing into `SynthEnginePair`. This is simpler than real-time mixing and avoids thread contention. The Dart side creates `OpenAmpSynthAudioStream.forSampleEngine()` with the sample engine's native handle. Both streams run at 48kHz/256 samples.

70. **Sample preset provider chain**: Three Riverpod providers work together:
   - `sampleEngineProvider` — creates `SampleEngine` instance lazily
   - `samplePresetProvider` — holds selected `SamplePreset` (null = none active)
   - `sampleAudioStreamProvider` — watches both, loads SFZ, creates/starts stream
   When preset changes, the stream provider auto-rebuilds, loads the new SFZ, and starts audio.

71. **SFZ path resolution — desktop vs mobile**: `bundledSamplePresets` use `assets/samples/...` paths. On mobile Flutter extracts assets automatically. On desktop, the executable runs from `build/linux/x64/release/bundle/` and must resolve paths relative to itself. Use `Platform.resolvedExecutable` to find the exe directory, then join with the asset path. Or copy `assets/samples/` next to the executable during deployment.

72. **Post-build copy required**: After `flutter build linux --release`, ALWAYS copy the native .so:
   ```bash
   cp native/libopenamp_dart_ffi.so build/linux/x64/release/bundle/lib/
   ```
   The Flutter build regenerates `libapp.so` but does NOT rebuild or copy `libopenamp_dart_ffi.so`. Forgetting this is the #1 "my native changes didn't take effect" bug.

73. **Sample instrument panel height constraint**: On desktop `SynthScreen`, `SampleInstrumentPanel` must be wrapped in a `Container` with explicit `height` (e.g., 200). The panel uses `Expanded` internally for its preset list, which crashes without a parent constraint. Mobile uses `CollapsibleSection` which provides its own constraint.

74. **Available sample presets initialization**: `availableSamplePresetsProvider` must be initialized with `bundledSamplePresets` from `lib/data/sample_presets.dart`, not an empty list. Otherwise the instrument panel shows "No sample instruments available" even when VSCO 2 CE is present.

81. **Multiple PortAudio streams on the same device DO NOT WORK**: The current architecture creates separate `AudioStream` instances for synth (`audio_stream_create_for_synth`), pair (`audio_stream_create_for_pair`), and sample (`audio_stream_create_for_sample_engine`). Each calls `Pa_OpenStream()` on the same device index. PortAudio does NOT support multiple concurrent output streams on the same device — whichever opens last wins, or they conflict, causing silence or corruption. **Fix**: `SynthEnginePair` must optionally own a `SampleEngine*` pointer and mix sample output into its `process()` callback. There should be ONE audio stream total. The Dart side removes `sampleAudioStreamProvider` entirely — samples are just another engine inside the pair. See `references/unified-audio-stream-architecture.md` for full implementation.

82. **Unified audio stream provider pattern**: After fixing the multiple-streams bug, create a single `unifiedAudioStreamProvider` that switches between single-engine and pair-engine streams based on `split.enabled`. When split is on, bind to `synthPairProvider` (which now mixes engine A + engine B + sample). When split is off, bind to `synthEngineProvider`. Delete both `synthAudioStreamProvider` and `synthPairAudioStreamProvider`. All screens watch `unifiedAudioStreamProvider` instead. The `PlaybackStateNotifier` routes notes to both synth AND sample engines simultaneously via `_routeSampleNoteOn/Off`.

83. **SynthEnginePair sample mixing in C++**: Add `SampleEngine* sampleEngine_` and `float sampleVolumeDb_` to `SynthEnginePair`. In `process()`, after mixing engine A + B into the output buffer, check if `sampleEngine_` is set. If so, render sample engine output into a temp buffer, convert dB to linear gain (`powf(10.0f, sampleVolumeDb_ / 20.0f)`), and mix into the pair's output. Add FFI exports: `synth_pair_set_sample_engine(pair, sampleHandle)` and `synth_pair_set_sample_volume(pair, db)`. Dart `OpenAmpSynthPair` gets `setSampleEngine()` and `setSampleVolumeDb()` methods.

84. **Split keyboard "only right side works" — missing zone A preset sync**: The `SynthEnginePair` has engine A and engine B. `zoneBPresetSyncProvider` syncs preset B to engine B, but there was NO `zoneAPresetSyncProvider` syncing preset A to engine A. Zone A notes routed correctly to `pair.engineA` but it had no preset loaded — played default init patch. **Fix**: Add `zoneAPresetSyncProvider` that watches `synthPairProvider` + `keyboardSplitProvider` and calls `applyPresetToSynth(engineA, split.presetA)`. All screens (synth, mobile, split) must watch it. See `references/split-keyboard-bug-fix.md` for the full pattern.

85. **Global master volume across multiple audio engines**: When synth and sample engines run on separate audio streams, each has independent volume. Users need a single master control. **Fix**: Create `globalMasterVolumeProvider` (StateProvider<double>) + `globalMixSyncProvider` (side-effect Provider<void>) that scales all engines:
   - Synth: `synth.masterVolume = globalVol` (linear 0-1)
   - Sample: `sampleEngine.volumeDb = 20*log10(globalVol)` (convert to dB, clamp -60..+6)
   - Split pair: `pair.setMixA(globalVol); pair.setMixB(globalVol)`
   Watch `globalMixSyncProvider` on every screen with audio output.

86. **Sample SFZ loading progress without native callbacks**: sfizz doesn't expose parse-progress callbacks. For large libraries (3.1GB VSCO 2 CE), loading can take seconds with no UI feedback. **Fix**: Poll `sampleEngine.isLoaded` every 100ms after setting the preset. Update a `samplePresetLoadProgressProvider` (0.0-0.95 while polling, 1.0 when `isLoaded` becomes true). Show both CircularProgressIndicator and LinearProgressIndicator in the panel header. Timeout after 30 seconds and clear the preset on failure.

87. **Desktop deployment script pattern**: After `flutter build linux --release`, ALWAYS run a deploy script that:
   1. Copies `native/libopenamp_dart_ffi.so` → `build/linux/x64/release/bundle/lib/`
   2. `rsync -a --delete assets/samples/` → `build/linux/x64/release/bundle/assets/samples/`
   3. Reports total samples size
   Without this, native changes don't take effect and sample instruments fail to load.

88. **System install after deployment**: The walker shortcut `~/.local/bin/open_synth` points to `~/.local/share/open_synth/open_synth`. After building and deploying to the bundle directory, copy the entire bundle to the system location:
   ```bash
   pkill -f "open_synth"  # Must kill first or "Text file busy"
   cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/
   ```
   Forgetting this step means the walker-launched app is stale even though the build bundle is fresh.

89. **Retro hardware synth UI pattern — custom painted widgets**: For a hardware synth aesthetic (Juno-106, Nord, etc.), build custom painted widgets instead of Flutter defaults:
   - **RetroKnob**: `CustomPainter` with tick mark ring, amber indicator line, bakelite body, drag-to-adjust via `GestureDetector.onVerticalDragUpdate`
   - **RetroLcd**: Container with `ClipRRect` + `CustomPainter` scanlines + amber phosphor text with `Shadow` glow
   - **RetroButton**: Container with gradient, LED circle (glows when active), recessed shadow when pressed
   - **RetroRackModule**: Expandable panel with corner screws, header LED, depth shadows, `AnimatedCrossFade` body
   - **RetroKeyboard**: `Listener` + `HitTestBehavior.opaque` for reliable touch, aged ivory white keys, warm black keys, amber LED note indicators
   Key techniques: use `LinearGradient` for panel depth, `BoxShadow` for raised/recessed effects, `CustomPainter` for hardware details (tick marks, scanlines), `GestureDetector`/`Listener` for drag interactions.

90. **Single-page synth layout — no more navigation shells**: Replace multi-screen navigation (bottom nav, drawer, separate screens) with a single `Scaffold` containing:
   - Top bar: LCD display + preset navigation + master controls
   - Scrollable column of `RetroRackModule` widgets (OSC, FILTER, ENVELOPES, LFO, FX, SAMPLES)
   - Fixed-height keyboard at bottom
   All state lives in Riverpod providers. No `IndexedStack`, no `Navigator`, no shell widgets. The app launches directly into the synth screen. This works on both desktop and mobile — mobile just scrolls more.

91. **User preference — full-send execution style**: synth wants AI that decides without asking, EXCEPT for UI/design decisions. When given a numbered list of options, he prefers "let's go with 1, 2, then 3" — sequential execution over deliberation. For technical/architecture decisions, execute immediately. For visual/aesthetic choices, present options and wait for direction.

81. **Multiple PortAudio streams on the same device DO NOT WORK**: The current architecture creates separate `AudioStream` instances for synth (`audio_stream_create_for_synth`), pair (`audio_stream_create_for_pair`), and sample (`audio_stream_create_for_sample_engine`). Each calls `Pa_OpenStream()` on the same device index. PortAudio does NOT support multiple concurrent output streams on the same device — whichever opens last wins, or they conflict, causing silence or corruption. **Fix**: `SynthEnginePair` must optionally own a `SampleEngine*` pointer and mix sample output into its `process()` callback. There should be ONE audio stream total. The Dart side removes `sampleAudioStreamProvider` entirely — samples are just another engine inside the pair. See `references/unified-audio-stream-architecture.md` for full implementation.

82. **Unified audio stream provider pattern**: After fixing the multiple-streams bug, create a single `unifiedAudioStreamProvider` that switches between single-engine and pair-engine streams based on `split.enabled`. When split is on, bind to `synthPairProvider` (which now mixes engine A + engine B + sample). When split is off, bind to `synthEngineProvider`. Delete both `synthAudioStreamProvider` and `synthPairAudioStreamProvider`. All screens watch `unifiedAudioStreamProvider` instead. The `PlaybackStateNotifier` routes notes to both synth AND sample engines simultaneously via `_routeSampleNoteOn/Off`.

83. **SynthEnginePair sample mixing in C++**: Add `SampleEngine* sampleEngine_` and `float sampleVolumeDb_` to `SynthEnginePair`. In `process()`, after mixing engine A + B into the output buffer, check if `sampleEngine_` is set. If so, render sample engine output into a temp buffer, convert dB to linear gain (`powf(10.0f, sampleVolumeDb_ / 20.0f)`), and mix into the pair's output. Add FFI exports: `synth_pair_set_sample_engine(pair, sampleHandle)` and `synth_pair_set_sample_volume(pair, db)`. Dart `OpenAmpSynthPair` gets `setSampleEngine()` and `setSampleVolumeDb()` methods.

84. **Split keyboard "only right side works" — missing zone A preset sync**: The `SynthEnginePair` has engine A and engine B. `zoneBPresetSyncProvider` syncs preset B to engine B, but there was NO `zoneAPresetSyncProvider` syncing preset A to engine A. Zone A notes routed correctly to `pair.engineA` but it had no preset loaded — played default init patch. **Fix**: Add `zoneAPresetSyncProvider` that watches `synthPairProvider` + `keyboardSplitProvider` and calls `applyPresetToSynth(engineA, split.presetA)`. All screens (synth, mobile, split) must watch it. See `references/split-keyboard-bug-fix.md` for the full pattern.

85. **Global master volume across multiple audio engines**: When synth and sample engines run on separate audio streams, each has independent volume. Users need a single master control. **Fix**: Create `globalMasterVolumeProvider` (StateProvider<double>) + `globalMixSyncProvider` (side-effect Provider<void>) that scales all engines:
   - Synth: `synth.masterVolume = globalVol` (linear 0-1)
   - Sample: `sampleEngine.volumeDb = 20*log10(globalVol)` (convert to dB, clamp -60..+6)
   - Split pair: `pair.setMixA(globalVol); pair.setMixB(globalVol)`
   Watch `globalMixSyncProvider` on every screen with audio output.

86. **Sample SFZ loading progress without native callbacks**: sfizz doesn't expose parse-progress callbacks. For large libraries (3.1GB VSCO 2 CE), loading can take seconds with no UI feedback. **Fix**: Poll `sampleEngine.isLoaded` every 100ms after setting the preset. Update a `samplePresetLoadProgressProvider` (0.0-0.95 while polling, 1.0 when `isLoaded` becomes true). Show both CircularProgressIndicator and LinearProgressIndicator in the panel header. Timeout after 30 seconds and clear the preset on failure.

87. **Desktop deployment script pattern**: After `flutter build linux --release`, ALWAYS run a deploy script that:
   1. Copies `native/libopenamp_dart_ffi.so` → `build/linux/x64/release/bundle/lib/`
   2. `rsync -a --delete assets/samples/` → `build/linux/x64/release/bundle/assets/samples/`
   3. Reports total samples size
   Without this, native changes don't take effect and sample instruments fail to load.

88. **System install after deployment**: The walker shortcut `~/.local/bin/open_synth` points to `~/.local/share/open_synth/open_synth`. After building and deploying to the bundle directory, copy the entire bundle to the system location:
   ```bash
   pkill -f "open_synth"  # Must kill first or "Text file busy"
   cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/
   ```
   Forgetting this step means the walker-launched app is stale even though the build bundle is fresh.

89. **Retro hardware synth UI pattern — custom painted widgets**: For a hardware synth aesthetic (Juno-106, Nord, etc.), build custom painted widgets instead of Flutter defaults:
   - **RetroKnob**: `CustomPainter` with tick mark ring, amber indicator line, bakelite body, drag-to-adjust via `GestureDetector.onVerticalDragUpdate`
   - **RetroLcd**: Container with `ClipRRect` + `CustomPainter` scanlines + amber phosphor text with `Shadow` glow
   - **RetroButton**: Container with gradient, LED circle (glows when active), recessed shadow when pressed
   - **RetroRackModule**: Expandable panel with corner screws, header LED, depth shadows, `AnimatedCrossFade` body
   - **RetroKeyboard**: `Listener` + `HitTestBehavior.opaque` for reliable touch, aged ivory white keys, warm black keys, amber LED note indicators
   Key techniques: use `LinearGradient` for panel depth, `BoxShadow` for raised/recessed effects, `CustomPainter` for hardware details (tick marks, scanlines), `GestureDetector`/`Listener` for drag interactions.

90. **Single-page synth layout — no more navigation shells**: Replace multi-screen navigation (bottom nav, drawer, separate screens) with a single `Scaffold` containing:
   - Top bar: LCD display + preset navigation + master controls
   - Scrollable column of `RetroRackModule` widgets (OSC, FILTER, ENVELOPES, LFO, FX, SAMPLES)
   - Fixed-height keyboard at bottom
   All state lives in Riverpod providers. No `IndexedStack`, no `Navigator`, no shell widgets. The app launches directly into the synth screen. This works on both desktop and mobile — mobile just scrolls more.

91. **User preference — full-send execution style**: synth wants AI that decides without asking, EXCEPT for UI/design decisions. When given a numbered list of options, he prefers "let's go with 1, 2, then 3" — sequential execution over deliberation. For technical/architecture decisions, execute immediately. For visual/aesthetic choices, present options and wait for direction.

92. **"Everything is still the same" — deployed binary is stale**: After `flutter build linux --release` AND `make` in `native/build`, the binary at `~/.local/share/open_synth/open_synth` is NOT automatically updated. The walker shortcut points there. ALWAYS copy the entire bundle after build:
   ```bash
   pkill -f "open_synth"  # MUST kill first — "Text file busy" on Linux
   cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/
   ```
   This includes: the Flutter binary, `lib/libopenamp_dart_ffi.so`, `data/flutter_assets/`, and `assets/samples/`. Forgetting ANY of these causes "my changes didn't take effect". Verify with `ls -la ~/.local/share/open_synth/open_synth` — timestamp should match build time.

93. **Multiple PortAudio streams on the same device DO NOT WORK — unified single-stream architecture**: Creating separate `AudioStream` instances for synth, pair, and sample engines — each calling `Pa_OpenStream()` on the same device — causes silence or corruption. PortAudio does not support concurrent output streams. **Fix**: `SynthEnginePair` must optionally own a `SampleEngine*` and mix all sources (engine A + engine B + samples) in ONE `process()` callback. There is exactly ONE `Pa_OpenStream` call. The Dart side:
   - Deletes `synthAudioStreamProvider` and `synthPairAudioStreamProvider`
   - Creates `unifiedAudioStreamProvider` that binds to either single engine (normal mode) or pair (split mode)
   - Deletes `sampleAudioStreamProvider` entirely — samples mix through the pair
   - `PlaybackStateNotifier` routes notes to BOTH synth and sample engines simultaneously
   - `synthPairProvider` auto-attaches the sample engine when a sample preset is loaded
   See `references/unified-audio-stream-architecture.md` for full C++ and Dart implementation.

94. **Sample engine provider must be lazy — not always-on**: The old `sampleEngineProvider` created a `SampleEngine` unconditionally on app startup. With unified architecture, the sample engine should only be created when a sample preset is selected. Otherwise it wastes memory and creates dangling sfizz instances. Make `sampleEngineProvider` return `null` when `samplePresetProvider` is null, or create a separate `sampleEngineForPresetProvider` that only builds when needed.

95. **Synthwave '84 color palette — user preference for retro UI**: synth wants deep purples, purples, pink and yellows — NOT amber/olive CRT colors. The correct palette:
   - Background: `#240037` (deep purple)
   - Primary accent: `#8f00ff` (electric purple)
   - Secondary accent: `#ff7edb` (hot pink)
   - Highlight: `#ff00ff` (magenta)
   - Warning/LED: `#f3e70f` (neon yellow)
   - Text primary: `#E8E0FF` (warm white)
   - Text secondary: `#8A84B8` (muted lavender)
   - Panel: `#1A0A2E` (dark purple)
   - Shadow: `#0F001A` (near-black purple)
   This replaces the amber/cyan CRT palette in `retro_theme.dart`. See `references/retro-hardware-synth-ui-pattern.md` for widget implementation patterns.

96. **Retro hardware synth UI — custom painted widgets over Flutter defaults**: For a Juno-106 reimagined aesthetic, build custom widgets:
   - **RetroKnob**: `CustomPainter` with tick mark ring, indicator line, drag-to-adjust via `GestureDetector.onVerticalDragUpdate`
   - **RetroLcd**: Container with `ClipRRect` + `CustomPainter` scanlines + phosphor glow text with `Shadow`
   - **RetroButton**: Container with gradient, LED circle (glows when active), recessed shadow when pressed
   - **RetroRackModule**: Expandable panel with corner screws, header LED, depth shadows, `AnimatedCrossFade` body
   - **RetroKeyboard**: `Listener` + `HitTestBehavior.opaque` for reliable touch, colored keys, LED note indicators
   Key techniques: `LinearGradient` for panel depth, `BoxShadow` for raised/recessed effects, `CustomPainter` for hardware details, `GestureDetector`/`Listener` for drag interactions.

97. **Single-page synth layout — no navigation shells**: Replace multi-screen navigation with a single `Scaffold`:
   - Top bar: LCD display + preset navigation + master controls
   - Scrollable column of `RetroRackModule` widgets (OSC, FILTER, ENVELOPES, LFO, FX, SAMPLES)
   - Fixed-height keyboard at bottom
   All state in Riverpod providers. No `IndexedStack`, `Navigator`, or shell widgets. App launches directly into synth screen. Works on desktop and mobile — mobile scrolls more.

98. **C++ debug logging in audio callback — verify output without audio hardware**: When audio is silent but no errors appear, add `std::fprintf(stderr, ...)` debug output to the PortAudio callback and `SynthEnginePair::process()`. Log: callback count, frame count, peak output level, whether sample engine is attached/loaded. Run the app from terminal and grep stderr: `open_synth 2>&1 | grep "\[OpenSynth\]"`. If peak stays at 0.0, the engine isn't generating sound. If callbacks don't fire at all, PortAudio stream failed to start. Remove debug logging before release builds.

99. **Flutter build + native build + system install — three-step deployment**: After ANY code change (Dart OR C++), the full deployment chain is:
   1. `cd native/build && cmake .. && make -j$(nproc)` — rebuild native .so
   2. `cd /project && flutter build linux --release` — rebuild Flutter app
   3. `bash scripts/deploy-desktop.sh release` — copy .so + samples into bundle
   4. `pkill -f open_synth && cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/` — install system-wide
   Skipping ANY step causes "my changes didn't take effect". The walker shortcut points to `~/.local/share/open_synth/`, not the build directory.

100. **NaN debugging in DSP engines — per-section tracing**: When the synth engine produces NaN/infinity output (peak shows garbage values like `959892362019182527582872065277952.000000`), add `checkNaN()` calls after every major DSP stage in `SynthEngine::process()`: envelopes, oscillators, filter, FX, master volume. Use a static location tracker to print the FIRST NaN source per block. Common causes: zero attack time (division by zero in envelope rate), uninitialized `oscMix` (0.0f instead of 0.5f), uninitialized `masterVolume_` (0.0f instead of 0.8f), filter with zero cutoff. See `references/nan-debugging-dsp.md` for full technique and minimal test harness.

101. **Verify build artifacts before claiming deployment is done**: After `flutter build` and `make`, ALWAYS verify timestamps on BOTH the binary and the .so before telling the user it's ready:
   ```bash
   ls -la ~/.local/share/open_synth/open_synth ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so
   ```
   The executable timestamp MUST match the build time. If it doesn't, `flutter build` didn't rebuild the binary (cached) or the copy step failed. Also verify with `strings` that new C++ symbols are present:
   ```bash
   strings ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so | grep "new_feature_string"
   ```
   Never claim "built and deployed" without running these checks. The user will test and find it's still the old version, leading to frustration.

102. **FFI library path resolution — `Directory.current` changes when launched from shortcuts**: The `_openLibrary()` function in `lib/ffi/openamp_synth.dart` loads the native `.so` via `DynamicLibrary.open()`. When the app is launched from a desktop shortcut, walker, or `.desktop` entry, `Directory.current` is NOT the project directory — it's the user's home directory or `/`. Candidate paths like `'${Directory.current.path}/native/libopenamp_dart_ffi.so'` will fail silently. **The .so MUST be found or the entire app is dead** — `OpenAmpSynthBindings.available` returns `false`, `synthEngineProvider` returns `null`, no audio stream starts, keyboard inputs are no-ops, keys never light up. **Fix**: Add `Platform.resolvedExecutable`-based path resolution to `_openLibrary()`:
   ```dart
   final exeDir = File(Platform.resolvedExecutable).parent.path;
   candidates.add('$exeDir/lib/libopenamp_dart_ffi.so');  // deployed bundle
   candidates.add('$exeDir/native/libopenamp_dart_ffi.so'); // dev mode
   ```
   102. **FFI library path resolution — `Directory.current` changes when launched from shortcuts**: The `_openLibrary()` function in `lib/ffi/openamp_synth.dart` loads the native `.so` via `DynamicLibrary.open()`. When the app is launched from a desktop shortcut, walker, or `.desktop` entry, `Directory.current` is NOT the project directory — it's the user's home directory or `/`. Candidate paths like `'${Directory.current.path}/native/libopenamp_dart_ffi.so'` will fail silently. **The .so MUST be found or the entire app is dead** — `OpenAmpSynthBindings.available` returns `false`, `synthEngineProvider` returns `null`, no audio stream starts, keyboard inputs are no-ops, keys never light up. **Fix**: Add `Platform.resolvedExecutable`-based path resolution to `_openLibrary()`. See `references/ffi-library-path-resolution.md`.

   103. **Rebrand commit pattern — find all instances, replace atomically**: When rebranding (e.g., synthclaw → synthclaw, 🦞 → 🦞), search across ALL file types — not just Dart. Use `grep -rn "old_name\|old_emoji" .` with `--include` for each extension, or use `grep -rn` without filters to catch everything (README, config files, comments, preset tags). In this session, the old branding survived in:
   - `README.md` — title and credits
   - `lib/data/factory_presets.dart` — preset tag `['synthclaw', 'grid', 'neon', 'ultimate']`
   Fix: `sed -i 's/synthclaw/synthclaw/g; s/🦞/🦞/g' README.md lib/data/factory_presets.dart`
   Always verify with a second `grep` to confirm zero matches remain.

104. **Feature creep destroys working code — the 60k-line trap**: Open Synth went from a working synthesizer (`5efaf14`, 12 Dart files, clean analysis, sound output) to a broken mess (`c162daf`, 252 files changed, 62k lines added, duplicate UI systems, 69 analysis issues) by adding arpeggiators, drum engines, physical models, wavetables, sequencers, recorders, sample engines, and multiple UI rewrites BEFORE fixing the known gap (split keyboard). **Rule**: When a user says "get it back to working", check `git log` for the last clean commit and offer `git reset --hard`. Do NOT try to incrementally fix a codebase that has been over-engineered into oblivion. See `references/git-recovery-from-scope-creep.md` for the full case study and recovery technique (including staged-revert when hard reset is blocked).

105. **Duplicate UI systems — `synth_screen.dart` vs `retro_synth_screen.dart`**: When a refactor introduces a new UI paradigm (e.g., retro hardware aesthetic) without deleting the old one, both systems coexist and diverge. Maintenance becomes impossible because fixes must be applied in two places. **Rule**: When introducing a new UI system, either (a) migrate all screens atomically in one commit, or (b) keep the old system as the default and make the new one opt-in via a flag. Never land a half-migrated state where both systems are active but neither is complete.

106. **User preference — the 1,453-preset version is "the best one"**: When synth says "get it back to where it was working", don't assume the smallest/oldest commit is the target. Ask which version they mean, or check `git log` for commits with high preset counts. The `c162daf` commit (1,453 presets) is the feature-rich working state — NOT `5efaf14` (50 presets) which was a stripped-down revert. The recovery path is `git stash -u && git checkout c162daf`, not `git reset --hard 5efaf14`.

107. **Background process launch on Linux — `bash -c` wrapper**: The terminal tool blocks shell backgrounding (`&`, `nohup`, `disown`). To launch a GUI app and check if it's running, use `bash -c` with a subshell:
   ```bash
   bash -c '~/.local/share/open_synth/open_synth 2> /tmp/synth_run.log &
   echo "PID: $!"
   sleep 3
   ps aux | grep open_synth | grep -v grep || echo "No process"
   cat /tmp/synth_run.log 2>/dev/null || echo "No log"'
   ```
   This runs the backgrounding inside a bash subprocess, which the terminal tool allows. The outer command finishes (returning PID and process status), while the app continues running in the background.

108. **Commit `bce64a8` was the destructive revert, not `c162daf`**: The skill previously misidentified `c162daf` as "FUBAR" when it was actually `bce64a8` ("revert: reset to Grid Expansion") that destroyed the 1,453-preset version. `c162daf` works fine after fixing 3 minor `Waveform` enum exhaustiveness errors. Always verify a commit actually builds before labeling it broken in the skill.

   - `references/mobile-ux-shell.md` — Mobile UX shell architecture: drawer nav, split-view synth, collapsible panels, responsive layout
   - `references/standalone-setup-spec.md` — Standalone setup system implementation spec: CLI interface, config transfer, migration scripts
   - `references/rhythm-pattern-player.md` — Rhythm Pattern Player engine: pattern data structures, 24 preset patterns, audio thread integration, song mode
   - `references/drum-synthesis-algorithms.md` — Drum synthesis quality pass: pink noise, multi-layer kicks, wire resonators, metallic partials, envelope curves
   - `references/physical-modeling-integration.md` — Physical modeling integration: Karplus-Strong, modal synthesis, per-voice state architecture
   - `references/multitimbral-engine.md` — Multitimbral engine retrofit: SynthPart struct, backward-compatible routing, voice part tags, MIDI channel routing
   - `references/linux-desktop-deployment.md` — Linux desktop deployment: where the native .so lives, how to copy it after rebuild, "Text file busy" pitfall
   - `references/split-keyboard-bug-fix.md` — The "only right side works" split keyboard bug: root cause, fix, and prevention
   - `references/instrument-realism-vs-juno-di.md` — Acoustic instrument realism gap analysis and improvement roadmap
   - `references/pcm-sample-engine-research.md` — PCM sample engine research: sfizz vs FluidSynth vs custom, free sample libraries, integration architecture
   - `references/sfizz-sample-engine-integration.md` — sfizz integration: CMake setup, FFI exports, Dart bindings, VSCO 2 CE + Salamander Grand Piano sample libraries, audio stream architecture, note routing, SFZ path resolution, remaining work
   - `references/split-keyboard-zone-a-sync.md` — Zone A preset sync bug: root cause and fix for "only right side works" in split mode
   - `references/global-mix-provider-pattern.md` — Unified master volume across multiple concurrent audio engines
   - `references/desktop-sfz-path-resolution.md` — Desktop asset bundling gap: SFZ sample path resolution and deployment script
   - `references/unified-audio-stream-architecture.md` — Unified single-stream audio architecture: mixing sample+synth in one PortAudio stream
   - `references/retro-hardware-synth-ui-pattern.md` — Retro hardware synth UI: synthwave palette, custom painted widgets, single-page layout
   - `references/nan-debugging-dsp.md` — NaN debugging in DSP audio engines: tracing technique, minimal C++ test harness, common fixes
   - `references/cpp-build-verification.md` — C++ build verification checklist: timestamps, symbol checks, full clean rebuild procedure
   - `references/ffi-library-path-resolution.md` — FFI library path resolution when launched from desktop shortcuts
   - `references/git-recovery-last-known-good.md` — Technique for finding and checking out the last known working commit when a project is broken (preset count verification, git forensics, working tree cleanup)
   - `references/session-recovery-1453-presets.md` — Session learnings: recovery to 1,453-preset version, git stash -u technique, waveform enum exhaustiveness fix, bash -c background launch
   - `references/git-recovery-from-scope-creep.md` — Case study: recovering from 60k lines of feature creep by resetting to last known-good commit (includes staged-revert technique when `git reset --hard` is blocked)
   - `references/linux-desktop-walker-integration.md` — Linux desktop deployment: .desktop file, icon cache, walker restart, "Text file busy" pitfall
