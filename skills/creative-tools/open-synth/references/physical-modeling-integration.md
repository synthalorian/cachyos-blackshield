# Physical Modeling Integration Pattern

How Karplus-Strong and modal synthesis were integrated into the existing subtractive synth architecture.

## Problem

Physical modeling (delay lines, resonator banks) needs per-voice state. The existing `Oscillator` class is global (one per engine, not per voice) and stateless — it just generates samples from a phase accumulator. PM can't work this way.

## Solution

Add `PhysicalModelVoice` to the `Voice` struct. The PM voice owns its own delay lines and resonator state. The synth engine checks oscillator waveform type and routes to PM instead of the normal oscillator when appropriate.

## Files Modified

1. `native/include/physical_model.h` — new header with `KarplusStrongVoice`, `ModalVoice`, `PhysicalModelVoice`
2. `native/src/physical_model.cpp` — implementations
3. `native/include/voice.h` — added `PhysicalModelVoice physicalModel` member
4. `native/src/voice_allocator.cpp` — init PM voices in constructor
5. `native/src/synth_engine.cpp` — route to PM in process loop, setup in noteOn
6. `native/include/oscillator.h` — added PM waveform enum values (18-23)
7. `native/CMakeLists.txt` — added `physical_model.cpp` to sources
8. `lib/models/waveform.dart` — added PM waveform enum entries
9. `lib/services/preset_loader.dart` — added mapping cases

## Integration Steps

### 1. Add PM member to Voice struct

```cpp
struct Voice {
    // ... existing fields ...
    PhysicalModelVoice physicalModel;
};
```

### 2. Initialize in VoiceAllocator

```cpp
VoiceAllocator::VoiceAllocator() {
    for (auto& v : voices_) {
        v.reset();
        v.physicalModel.init(48000.0, 4096);  // sampleRate, maxDelaySamples
    }
}
```

### 3. Check waveform and trigger in noteOn

```cpp
void SynthEngine::noteOn(int midiNote, float velocity) {
    Voice* voice = allocator_.noteOn(midiNote, velocity);
    if (voice) {
        int wf1 = osc1_.waveform();
        if (wf1 >= 18 && wf1 <= 23) {
            voice->physicalModel.setType(static_cast<PhysicalModelType>(wf1 - 17));
            voice->physicalModel.noteOn(voice->baseFreq, voice->velocity);
        }
        // Same for osc2...
    }
}
```

### 4. Handle noteOff

```cpp
void SynthEngine::noteOff(int midiNote) {
    allocator_.noteOff(midiNote);
    for (int v = 0; v < VoiceAllocator::MAX_VOICES; ++v) {
        Voice* voice = allocator_.voice(v);
        if (voice->active && voice->midiNote == midiNote) {
            voice->physicalModel.noteOff();
        }
    }
}
```

### 5. Render in process loop

In the per-frame voice loop, when iterating unison voices:

```cpp
bool isPm1 = (osc1_.waveform() >= 18 && osc1_.waveform() <= 23);
bool isPm2 = (osc2_.waveform() >= 18 && osc2_.waveform() <= 23);

if (osc1Active) {
    if (isPm1 && uv == 0) {
        sample += voice->physicalModel.process() * osc1_.volume();
    } else if (!isPm1) {
        // normal oscillator path
    }
}
```

**Key**: PM voices don't support unison — only render on `uv == 0`.

## Karplus-Strong Algorithm

Delay line with lowpass filter in feedback loop. Key parameters:
- `delayLen = sampleRate / freq` — determines pitch
- `decayCoef` — brightness-controlled (0.85-0.9995)
- Pre-fill delay line with noise for immediate sound
- One-pole lowpass: `filterState += (sample - filterState) * 0.5f`

## Modal Synthesis Algorithm

Multiple parallel state-variable bandpass filters. Key parameters:
- Mode frequencies: harmonic-ish for wood, inharmonic for metal
- Per-mode decay: higher modes decay faster
- Excitation: short noise burst (2ms)
- State variable BPF: `bp += f * (input - lp - q * bp); lp += f * bp;`

## Waveform Enum Values

| Dart Name | Dart Index | C++ Enum | C++ Value | Description |
|-----------|-----------|----------|-----------|-------------|
| pmKarplus | 18 | PM_KARPLUS | 18 | Standard plucked string |
| pmKarplusBright | 19 | PM_KARPLUS_BRIGHT | 19 | Bright pluck (clavinet) |
| pmKarplusBass | 20 | PM_KARPLUS_BASS | 20 | Bass pluck |
| pmModalMallet | 21 | PM_MODAL_MALLET | 21 | Marimba/xylophone |
| pmModalVibraphone | 22 | PM_MODAL_VIBRAPHONE | 22 | Vibraphone |
| pmModalSteel | 23 | PM_MODAL_STEEL | 23 | Steel drum/pan |

## Adding New PM Types

1. Add to `PhysicalModelType` enum in `physical_model.h`
2. Add case in `PhysicalModelVoice::noteOn()` to configure the voice
3. Add case in `PhysicalModelVoice::process()` to render
4. Add to `OscWaveform` enum in `oscillator.h`
5. Add to Dart `Waveform` enum
6. Add to `_waveformToInt()` in `preset_loader.dart`
7. Add to `dartToInternal[]` in `oscillator.cpp`
