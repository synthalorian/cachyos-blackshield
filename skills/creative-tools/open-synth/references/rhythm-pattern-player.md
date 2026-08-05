# Rhythm Pattern Player Architecture

Reference for the RhythmPatternPlayer engine added to Open Synth.

## Overview

A preset drum pattern sequencer that runs on the audio thread, driving the embedded `DrumKit` via step-triggered note events. 24+ patterns across 9 categories with song-mode auto-advance.

## Files

```
native/include/rhythm_pattern_player.h    # DrumPattern, DrumHit, RhythmPatternPlayer class
native/src/rhythm_pattern_player.cpp      # Pattern definitions + process() implementation
lib/models/rhythm_pattern.dart            # Dart pattern metadata + built-in library
lib/providers/rhythm_provider.dart        # State notifier + engine bridge
lib/widgets/rhythm_panel.dart             # Transport, pattern browser, step indicator
```

## C++ Data Structures

```cpp
struct DrumHit {
    uint8_t note;        // GM2 drum note (36=kick, 38=snare, etc.)
    uint8_t velocity;    // 0-127
    uint8_t step;        // 0-based position in pattern
    float   probability; // 0.0-1.0 chance this hit fires
    float   timingShift; // -0.5 to +0.5 step offset
    float   accent;      // 1.0=normal, >1.0=accent, <1.0=ghost
};

struct DrumPattern {
    std::array<DrumHit, 64> hits;
    int hitCount;
    int steps;           // 16, 32, or 64
    int beatsPerBar;     // 3, 4, 5, 6, 7
    int subdivisions;    // 4=16th, 3=triplet, 8=32nd
    const char* name;
    const char* style;
    const char* category;
    float defaultTempo;
    float swing;
};
```

## Integration Points

1. **SynthEngine owns the player**: `RhythmPatternPlayer rhythmPlayer_` as member
2. **Process called in audio callback**: `rhythmPlayer_.process(drumKit_, numFrames, sampleRate)` in `SynthEngine::process()`, after arpeggiator, before voice processing
3. **Param queue control**: ParamIds 270-276 (RHYTHM_PATTERN, RHYTHM_PLAY, RHYTHM_STOP, RHYTHM_TEMPO, RHYTHM_VOLUME, RHYTHM_VARIATION, RHYTHM_SONG_MODE)
4. **FFI exports**: `synth_engine_rhythm_play/stop/set_pattern/set_tempo/set_volume/set_variation/set_song_mode`, `synth_engine_get_rhythm_current_step/total_steps`

## Pattern Library (24 patterns)

| # | Name | Category | Steps | Tempo | Style |
|---|------|----------|-------|-------|-------|
| 0 | Basic Rock | Rock | 16 | 120 | 4/4 straight |
| 1 | Rock Ballad | Rock | 16 | 72 | 4/4 sparse |
| 2 | Driving Rock | Rock | 16 | 140 | Heavy kick |
| 3 | Shuffle Rock | Rock | 12 | 110 | Triplet feel |
| 4 | Half Time | Rock | 16 | 85 | Snare on 3 only |
| 5 | Pop Basic | Pop | 16 | 118 | Standard |
| 6 | Dance Pop | Pop | 16 | 128 | Four-on-floor |
| 7 | Synth Pop | Pop | 16 | 125 | Clap on 2/4 |
| 8 | Funk 16th | Funk | 16 | 108 | Ghost notes |
| 9 | James Brown | Funk | 16 | 115 | Syncopated |
| 10 | Jazz Swing | Jazz | 12 | 140 | Ride on triplets |
| 11 | Jazz Waltz | Jazz | 12 | 160 | 3/4 |
| 12 | Brush Sweep | Jazz | 16 | 120 | Shaker sim |
| 13 | Bossa Nova | Latin | 16 | 120 | Classic |
| 14 | Samba | Latin | 16 | 130 | Surdo pattern |
| 15 | Reggaeton | Latin | 16 | 95 | Dembow |
| 16 | Four on Floor | Electronic | 16 | 128 | Techno kick |
| 17 | House | Electronic | 16 | 124 | Off-beat snare |
| 18 | Techno | Electronic | 16 | 135 | Minimal |
| 19 | Drum & Bass | Electronic | 16 | 174 | Breakbeat |
| 20 | Trap | Electronic | 16 | 140 | 808 hats |
| 21 | UK Garage | Electronic | 16 | 130 | Skippy |
| 22 | Afrobeat | World | 16 | 110 | Tony Allen |
| 23 | Reggae | World | 16 | 80 | One drop |

## Adding a New Pattern

1. Add `makePatternName(DrumPattern& p)` function in `rhythm_pattern_player.cpp`
2. Register in `buildPatternLibrary()` static initializer
3. Bump `kPatternCount`
4. Add corresponding entry to `kRhythmPatterns` in `lib/models/rhythm_pattern.dart`
5. Rebuild native library

## Song Mode

When `songMode_` is true, the player auto-advances variations every 4 bars:
```
Intro → MainA → FillA → MainB → FillB → MainA (loop)
```

Call `nextVariation()` to manually advance.

## Timing

```cpp
float stepsPerBeat = subdivisions;  // 4 for 16th notes
float beatsPerSecond = bpm / 60.0f;
float stepsPerSecond = stepsPerBeat * beatsPerSecond;
samplesPerStep_ = sampleRate / stepsPerSecond;
```

The `process()` method accumulates `numFrames` into `sampleAccumulator_` and triggers steps when it exceeds `samplesPerStep_`.

## Future Enhancements

- Micro-timing (swing/feel applied per-hit)
- Probability-based humanization
- Custom pattern editor
- Pattern import from MIDI files
- More fill variations per pattern
