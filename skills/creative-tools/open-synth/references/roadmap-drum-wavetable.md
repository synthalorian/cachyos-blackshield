# Open Synth — Roadmap Summary (May 2026)

> Full version lives at `/home/synth/projects/open-synth/ROADMAP.md`
> OpenSynth is a fully standalone project. No Hermes integration.

## 8-Phase Plan for Juno-Di Parity

| Phase | Feature | Days | Dependency |
|-------|---------|------|-----------|
| **0** | Standalone Setup System | 2-3 | None |
| **1** | Drum Synthesis Engine | 3-4 | None |
| **2** | Rhythm Pattern Player | 2-3 | Phase 1 |
| **3** | Wavetable Engine | 5-7 | None (parallel with 1-2) |
| **4** | Keyboard Split + Drum Zone | 1-2 | Phase 1 |
| **5** | Drum Pad UI + Mobile | 2-3 | Phase 1 |
| **6** | Sound Design Polish | 3-5 | Phase 3 |
| **7** | Pro Features | Ongoing | All above |

**Phases 0, 1, and 3 can run in parallel.** Total for Juno-Di parity (0-5): ~18-22 days.

---

## Phase 0: Standalone Setup System

OpenSynth has its own setup and configuration pipeline — completely independent from Hermes Agent and OpenShark.

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

---

## Phase 1: Drum Synthesis Engine

Each drum sound gets a dedicated algorithm — NOT generic oscillators:

- **Kick**: Sine + pitch envelope (200Hz→50Hz, 30ms) + noise click transient
- **Snare**: Triangle (tone layer, BPF) + noise (noise layer, HPF) + separate decay curves
- **Closed HH**: Noise → HPF (8kHz+) → fast VCA (30ms)
- **Open HH**: Noise → HPF → medium VCA (300ms). Choke group with closed
- **Tom (H/M/L)**: Sine + pitch envelope (higher than kick, slower sweep) + optional noise
- **Crash**: Noise → 3× parallel BPF (metallic partials) → long decay (2s+)
- **Ride**: Noise → BPF + triangle undertone → medium decay
- **Clap**: Noise → BPF → burst pattern (3 hits in 30ms, then tail)
- **Rimshot**: Triangle → HPF → very fast decay (20ms)
- **Cowbell**: 2× detuned square oscillators → BPF
- **Shaker/Tamb**: Noise → HPF → short decay, low amplitude
- **Conga/Bongo**: Sine + slight pitch envelope → BPF

Kit = array mapping MIDI note → {drumType, tuning, level, decay}. GM2 standard mapping.
10 kit presets: Standard, Room, Power, TR-808, TR-909, Electronic, Jazz, Brush, Orchestra, SFX.

---

## Phase 2: Rhythm Pattern Player

DrumPatternPlayer engine with clock sync. 30-50 preset patterns covering rock, pop, funk, jazz, Latin, electronic.
Plays alongside synth engine (parallel process, mixed at output). Syncs with existing MIDI clock.

---

## Phase 3: Wavetable Engine

Single-cycle waveforms for acoustic instruments. Multiple tables per instrument by velocity/key range.

| Instrument | Approach |
|-----------|----------|
| Piano | Wavetable (sampled single-cycles) |
| Electric Piano | FM synthesis (engine already supports FM) |
| Organ | Additive (drawbar model — no wavetables needed) |
| Strings | Wavetable (looped sustain + attack transient) |
| Brass | Wavetable or waveguide |
| Acoustic/Electric Guitar | Physical modeling (Karplus-Strong) |
| Bass Guitar | Karplus-Strong + slap model |
| Woodwinds | Waveguide model with breath noise |
| Choir | Wavetable with vowel morphing |
| Mallets | Modal synthesis (struck bar) |

---

## Phase 4-5: Integration + UI
- Lower keyboard zone → DrumKit, upper → SynthEngine
- 4×4 touch pad grid for mobile
- Color-coded by drum type

---

## Key Files to Create

### Setup System (Phase 0)
```
scripts/setup.py              # Setup wizard (Python)
scripts/doctor.py             # Health check
scripts/config.py             # Config management
lib/utils/config.dart         # Dart config loader
lib/utils/paths.dart          # XDG path resolution
```

### Drum Engine (Phase 1)
```
native/include/drum_synth.h          — DrumVoice types + DrumKit class
native/src/drum_synth.cpp            — synthesis algorithms
native/include/drum_kit_mapping.h    — GM2 note → sound mapping
native/src/drum_kit_mapping.cpp
native/include/drum_pattern_player.h — step sequencer for drums
native/src/drum_pattern_player.cpp
native/src/drum_ffi.cpp              — FFI exports
lib/models/drum_kit_config.dart
lib/providers/drum_providers.dart
lib/widgets/drum_pad_grid.dart
lib/widgets/drum_pattern_editor.dart
```

### Wavetable Engine (Phase 3)
```
native/include/wavetable_oscillator.h
native/src/wavetable_oscillator.cpp
native/include/wavetable_bank.h
native/src/wavetable_bank.cpp
native/include/physical_models.h
native/src/physical_models.cpp
native/wavetables/
native/tools/
lib/models/wavetable_config.dart
lib/providers/wavetable_providers.dart
```
