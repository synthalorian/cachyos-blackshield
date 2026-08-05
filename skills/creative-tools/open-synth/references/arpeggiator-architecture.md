# Arpeggiator Architecture

## Overview

The arpeggiator is a real-time MIDI note pattern generator that runs inside the C++ audio callback. It intercepts `noteOn`/`noteOff`, tracks held notes, and generates pattern-based note sequences at block boundaries.

## Note Routing Flow

```
User plays C-E-G chord (arp enabled)
    │
    ├─► SynthEngine::noteOn(C, 1.0)
    │       feeds Arpeggiator::noteOn(C, 1.0)  ✓ stored in heldNotes_
    │       skips allocator_.noteOn()           (arp is enabled)
    │
    ├─► SynthEngine::noteOn(E, 1.0)
    │       feeds Arpeggiator::noteOn(E, 1.0)  ✓ stored
    │       skips allocator_
    │
    └─► SynthEngine::noteOn(G, 1.0)
            feeds Arpeggiator::noteOn(G, 1.0)  ✓ stored
            skips allocator_

Next audio callback:
    SynthEngine::process()
        drainQueue()
        arpeggiator_.process(blockSize, sampleRate, allocator_)
            │  samplesSinceStep_ += numSamples
            │  when samplesSinceStep_ >= stepLength:
            │      currentStep_++
            │      playStep(allocator_) → allocator_.noteOn(note, vel)
            │  when samplesSinceStep_ >= gateSamples:
            │      allocator_.noteOff(lastPlayedNote_)
            │
            └─► Voice repeats this per block
```

## Pattern Generation Logic

Each pattern is computed in `noteFromPattern()`:

**UP**: `noteIdx = step % numNotes`, `octave = (step / numNotes) % octaveRange`
- Steps through held notes lowest→highest, then cycles through octaves

**DOWN**: `revStep = numNotes - 1 - (step % numNotes)`, same octave logic
- Steps highest→lowest

**UP_DOWN**: `stepsPerOct = numNotes * 2 - 2` (skip top/bottom repeats)
- Goes up then down without repeating the top/bottom notes

**RANDOM**: `fastRand() % numNotes` + `fastRand() % octaveRange`
- LCG random (`state * 1103515245 + 12345`)

**CHORD**: First step plays held notes, subsequent steps... currently plays one note per step (needs refinement for true chord mode)

## Held Note Tracking

- `noteOn()`: if note already held, updates velocity. Otherwise appends, then re-sorts.
- Sorting: creates `vector<pair<int,float>>`, sorts by `.first` (midi note), distributes back.
- `noteOff()`: erases matching entry from both vectors by index.

## Step Timing

- Step length = `(60.0 / tempo) * sampleRate * resolutionMultiplier`
  - Quarter: 1.0, Eighth: 0.5, Sixteenth: 0.25, Thirty-second: 0.125
- Gate length = `stepLength * gate_` (clamped to [1, stepLength])
- Step counter wraps at `stepsPerCycle`:
  - UP/DOWN/CHORD/RANDOM: `numNotes * octaveRange`
  - UP_DOWN: `numNotes * octaveRange * 2 - 2` (more complex cycle)

## Thread Safety

The arpeggiator is called from the audio callback thread only:
- `process()` runs at block boundaries — this IS the audio thread
- `allocator_.noteOn()`/`noteOff()` calls are on the same thread — safe
- All parameter changes come through the param queue (drained at process start)
- `heldNotes_` vector is modified from `SynthEngine::noteOn()`/`noteOff()` which can be called from:
  - The queue drain (audio thread)
  - MIDI input thread (if enabled)

**Potential race**: `SynthEngine::noteOn()` (non-queue path — direct FFI setter or MIDI callback) could call `arpeggiator_.noteOn()` while `process()` is also reading `heldNotes_`. In practice this only happens during MIDI input, which isn't yet fully wired. For now, `noteOn`/`noteOff` are called from the queue drain (audio thread only) so no race.

## File Layout

- `native/include/arpeggiator.h` — class definition, enums, public API
- `native/src/arpeggiator.cpp` — implementation
- `lib/ffi/openamp_synth.dart` — ParamId constants (150-155) + OpenAmpSynth setters

## ParamId Constants (Dart)

```dart
static const int arpEnabled = 150;      // enqueueInt — 0/1
static const int arpTempo = 151;        // enqueueFloat — 20.0-300.0 BPM
static const int arpPattern = 152;      // enqueueInt — 0=UP, 1=DOWN, 2=UP_DOWN, 3=RANDOM, 4=CHORD
static const int arpOctaveRange = 153;  // enqueueInt — 1-4
static const int arpGate = 154;         // enqueueFloat — 0.0-1.0
static const int arpResolution = 155;   // enqueueInt — 0=1/4, 1=1/8, 2=1/16, 3=1/32
```

## Future Enhancements

- 128+ preset arpeggio patterns (rhythm + note order presets)
- Shuffle/groove feel (swing)
- Velocity patterns (fixed, accent, random per step)
- Pattern editor (draw notes in grid)
- Tempo sync to master clock
- Hold function (latch arpeggiator — already partially supported by `sustained` flag in voice allocator)
- MPE support per-note arpeggiation
