# Roland Juno-Di Feature Research

## Roland Juno-Di (Full Specs)

### Core Synthesis
- **Polyphony**: 128 voices
- **Waveforms**: 1000+ PCM waveforms + analog modeling
- **Sound Engine**: ZEN-Core derived (later models), original used combined PCM/synth
- **Parts**: 16-part multitimbral
- **Oscillators**: Per-part PCM + synth modeling
- **Filters**: Resonant filters (LPF, HPF, BPF, Notch) per part

### Preset System
- **User Presets**: 256 user locations
- **Factory Presets**: 1,082 (total 1,338 with expansions)
- **Favorites**: 100 favorite slots for quick access
- **Categories**: 12 categories (Piano, E.Piano, Organ, Strings, Pad, Bass, Guitar, Brass, Synth Lead, Synth Pad, Rhythm/Percussion, SFX)
- **Preset Structure**: Tone → Patch (layers/splits) → Performance (multitimbral)

### Effects
- **Total FX Types**: 79 algorithms
- **FX Processors**: 3 independent MFX processors + reverb + chorus
- **MFX Categories**: Distortion, Filter, Compressor, Limiter, EQ, Modulation (chorus/phaser/flanger), Delay (8 types), Reverb, Lo-Fi, Voice Transformer, Guitar Amp Simulator, Rotary, Isolator, Speaker Simulator, Mastering FX
- **Reverb**: 5 types (Room, Hall, Plate, Spring, Gate)
- **Chorus**: 3 types (Standard, Space D, SRS)
- **Input FX**: Dedicated input effects for external audio

### Arpeggiator
- **Patterns**: 128 preset patterns
- **Grid**: 16-step programmable
- **Modes**: Up, Down, Up/Down, Random, Chord
- **Tempo Sync**: BPM sync with external clock
- **One-shot + Loop**: Both supported

### Rhythm Patterns
- **Preset Patterns**: 300+ rhythm patterns
- **Drum Kits**: 10 preset + 8 user drum kits
- **Rhythm Groups**: Organized by genre (Rock, Pop, Jazz, Latin, Electronic, Hip-hop, etc.)
- **Pattern Length**: 1-128 measures
- **Tempo**: 20-300 BPM

### Chord Memory
- **Chord Types**: Standard triads, 7ths, 9ths, sus2, sus4, add9, diminished, augmented
- **One-finger chords**: Play full chords with single keys
- **Chord detection**: Auto-detect chords played on keyboard

### Sequencer / Song Player
- **Song Playback**: SMF (Standard MIDI File) playback
- **Song Recorder**: 16-track sequencer
- **Recording**: Realtime + Step
- **Song Length**: Up to 999 measures
- **Resolution**: 480 ticks per quarter note
- **Audio Playback**: WAV/MP3/AIFF playback with pitch/tempo control (via USB)

### Audio Features
- **USB Audio**: Class-compliant USB audio interface
- **Audio Playback**: WAV, MP3, AIFF via USB memory
- **Center Cancel**: Vocal cancel for backing track playback
- **Key Shift**: Audio key shift (-12 to +12 semitones)
- **Time Stretch**: Audio tempo change without pitch shift
- **Mic Input**: 1/4" mic input with dedicated reverb
- **Line Input**: Stereo line input

### Keyboard
- **Keys**: 61 keys (synth-action, velocity sensitive)
- **Velocity Curves**: 6 curves + fixed velocity
- **Aftertouch**: No (Juno-Di), Yes on Juno-Di37 (channel pressure)
- **Transpose**: -12 to +12 semitones
- **Octave Shift**: -3 to +3

### Connectivity
- **USB**: USB Type A (memory), USB Type B (MIDI + Audio)
- **MIDI**: In, Out
- **Audio Out**: L/Mono, R (1/4")
- **Headphones**: 1/4" stereo
- **Damper Pedal**: 1/4" jack (continuous detection)
- **Control Pedal**: 1/4" expression pedal jack
- **DCO Input**: No
- **Bluetooth**: Audio (Juno-Di37 only)

### Display & UI
- **Display**: Backlit LCD
- **Knobs**: 4 realtime control knobs (filter, envelope, effects)
- **Buttons**: Category, Favorites, Song, Rhythm, Arpeggio, D-Beam
- **D-Beam**: Infrared controller for spatial performance control
- **Favorites buttons**: 10 physical buttons (pages of 10 = 100 total)

### Battery & Portability
- **Battery**: 8x AA batteries (approx 4 hours)
- **Weight**: 5.2 kg (11.5 lbs)
- **Dimensions**: 1,009 x 283 x 82 mm

---

## Feature Gap Analysis: Open Synth vs Juno-Di

| Feature | Juno-Di | Open Synth (Current) | Gap |
|---------|---------|---------------------|-----|
| Polyphony | 128 voices | 16 voices | 112 voices |
| Presets | 1,338 | 36 | 1,302 |
| Categories | 12 | 8 | 4 (need Guitar, Brass, SFX, Rhythm/Perc) |
| FX Types | 79 | 7 | 72 |
| FX Processors | 3 MFX + reverb + chorus | 1 chain | +4 processors |
| Multitimbral | 16 parts | 1 part | 15 parts |
| Arpeggio Patterns | 128 | UI exists, patterns limited | ~120 patterns |
| Rhythm Patterns | 300+ | None | 300+ patterns |
| Drum Kits | 18 | None | 18 kits |
| Chord Memory | Full | None | Complete feature |
| Sequencer | 16-track | UI exists, basic | Full sequencer |
| Audio Playback | WAV/MP3/AIFF | None | Full playback engine |
| PCM Waveforms | 1000+ | None (synth only) | Sample engine |
| Song Player | SMF + audio | None | File playback |
| Favorites | 100 slots | None | Favorites system |
| Key Split | Full | Basic | Enhanced split |
| USB Audio | Yes | N/A (software) | N/A |
| D-Beam | Yes | N/A (software) | N/A |
| Battery | AA | N/A (software) | N/A |

## Phased Roadmap (from PLAN.md)

- **Phase 0** (COMPLETE): Audio crash fixes, thread safety, build stability
- **Phase 1**: 128-voice polyphony, 100+ presets, 12 categories, 16-part multitimbral
- **Phase 2**: 79 FX types, FX routing matrix, input FX
- **Phase 3**: PCM sample engine, 1000+ waveforms, drum kits, rhythm patterns
- **Phase 4**: Full sequencer, chord memory, arpeggiator expansion
- **Phase 5**: Audio file playback (WAV/MP3), center cancel, time stretch
- **Phase 6**: Favorites system, performance layers, polish
