# Multitimbral Engine Architecture

How the 16-part multitimbral engine was retrofitted onto the existing monotimbral SynthEngine.

## Problem

The original `SynthEngine` was monotimbral: one `Oscillator osc1_`, one `Oscillator osc2_`, one `Filter filter_`, one `LFO lfo1_`, one `LFO lfo2_`, and envelope parameters as direct members (`ampAttack_`, `filterAttack_`, etc.). Adding 16-part multitimbral support required splitting these into per-part configurations while keeping ALL existing behavior intact.

## Solution: SynthPart + Backward-Compatible Routing

### SynthPart Struct

```cpp
struct SynthPart {
    Oscillator osc1;
    Oscillator osc2;
    Filter filter;
    LFO lfo1;
    LFO lfo2;
    float ampAttack = 0.01f, ampDecay = 0.3f, ampSustain = 0.7f, ampRelease = 0.3f;
    float filterAttack = 0.01f, filterDecay = 0.3f, filterSustain = 0.0f, filterRelease = 0.3f;
    float oscMix = 0.5f;
    // ... other per-part params
    
    int midiChannel = -1;  // -1 = off, 0-15 = MIDI channel
    bool omni = false;
    float volume = 0.8f;
    float pan = 0.0f;
    bool mute = false;
    bool solo = false;
};
```

### Engine Changes

```cpp
class SynthEngine {
    static constexpr int MAX_PARTS = 16;
    std::array<SynthPart, MAX_PARTS> parts_;
    bool anySolo_ = false;
    // ...
};
```

### Backward Compatibility

All legacy parameter setters now route to `parts_[0]`:

```cpp
void SynthEngine::setOsc1Waveform(int v) { parts_[0].osc1.setWaveform(v); }
void SynthEngine::setFilterCutoff(float v) { parts_[0].filter.setCutoff(v); }
void SynthEngine::setAmpAttack(float v) { parts_[0].ampAttack = v; }
// etc.
```

Preset save/load also uses `parts_[0]` for the single-timbre format.

### Voice Allocation with Part Tags

```cpp
struct Voice {
    // ... existing fields ...
    int partIndex = 0;  // NEW: which part this voice belongs to
};
```

VoiceAllocator::noteOn now takes a `partIndex`:

```cpp
Voice* VoiceAllocator::noteOn(int midiNote, float velocity, int partIndex) {
    // Find free voice or steal oldest
    voice->partIndex = partIndex;
    // ...
}
```

### MIDI Channel Routing

```cpp
int SynthEngine::channelToPart(int channel) const {
    if (channel < 0 || channel > 15) return 0;
    for (int i = 0; i < MAX_PARTS; ++i) {
        if (parts_[i].midiChannel == channel || parts_[i].omni) {
            return i;
        }
    }
    return 0;  // Fallback to part 0
}
```

### Process Loop — Per-Voice Part Lookup

In the per-frame voice loop, look up the part for each active voice:

```cpp
for (int v = 0; v < VoiceAllocator::MAX_VOICES; ++v) {
    Voice* voice = allocator_.voice(v);
    if (!voice->active) continue;
    
    SynthPart& part = parts_[voice->partIndex];
    
    // Use part.osc1, part.osc2, part.filter, etc. instead of engine-level members
    float osc1Sample = part.osc1.generate(/* ... */);
    float filtered = part.filter.process(osc1Sample, voice->filterState);
    // ...
    
    // Apply part volume/pan/mute/solo
    if (part.mute) continue;
    if (anySolo_ && !part.solo) continue;
    
    float leftGain = part.volume * (1.0f - part.pan) * 0.5f;
    float rightGain = part.volume * (1.0f + part.pan) * 0.5f;
    leftOut += sample * leftGain;
    rightOut += sample * rightGain;
}
```

### Solo/Mute Logic

```cpp
void SynthEngine::updateSoloState() {
    anySolo_ = false;
    for (int i = 0; i < MAX_PARTS; ++i) {
        if (parts_[i].solo) { anySolo_ = true; break; }
    }
}
```

When `anySolo_` is true, only solo'd parts produce sound. Mute always silences regardless of solo state.

## Files Modified

1. `native/include/synth_part.h` — NEW: `SynthPart` struct
2. `native/src/synth_part.cpp` — NEW: implementation
3. `native/include/synth_engine.h` — Added `parts_` array, part management methods
4. `native/include/voice.h` — Added `partIndex` to `Voice`
5. `native/include/voice_allocator.h` — `noteOn`/`noteOff`/`allNotesOff` take `partIndex`
6. `native/src/voice_allocator.cpp` — Part-tagged allocation logic
7. `native/src/voice.cpp` — Reset `partIndex` in `reset()`
8. `native/src/synth_engine.cpp` — Refactored process loop, param handlers, preset functions
9. `native/CMakeLists.txt` — Added `synth_part.cpp`

## Refactoring Cascade

Moving `osc1_`, `osc2_`, `filter_`, `lfo1_`, `lfo2_`, and envelope params into `parts_[0]` required changes in ~15 locations:

| Location | Old | New |
|----------|-----|-----|
| Constructor | `lfo1_.prepare(sr)` | `parts_[i].lfo1.prepare(sr)` loop |
| reset() | `osc1_.reset()` | `parts_[i].osc1.reset()` loop |
| applyParam (OSC1) | `osc1_.setWaveform(v)` | `parts_[0].osc1.setWaveform(v)` |
| applyParam (Filter) | `filter_.setCutoff(v)` | `parts_[0].filter.setCutoff(v)` |
| applyParam (LFO) | `lfo1_.setRate(v)` | `parts_[0].lfo1.setRate(v)` |
| applyParam (Amp env) | `ampAttack_ = v` | `parts_[0].ampAttack = v` |
| applyParam (Filter env) | `filterAttack_ = v` | `parts_[0].filterAttack = v` |
| savePreset | `osc1_.waveform()` | `parts_[0].osc1.waveform()` |
| loadPreset | `setOsc1Waveform(v)` | (unchanged — routes to parts_[0]) |
| process() LFO | `lfo1_.process()` | `parts_[0].lfo1.process()` |
| process() piano check | `osc1_.waveform()` | `parts_[0].osc1.waveform()` |
| process() voice loop | `osc1_.generate()` | `part.osc1.generate()` |
| process() amp mod | `lfo1_.target()` | `parts_[0].lfo1.target()` |
| noteOn PM setup | `osc1_.waveform()` | `voicePart.osc1.waveform()` |
| noteOn PM setup | `osc2_.waveform()` | `voicePart.osc2.waveform()` |

## Key Insight

The voice loop is the critical path. Instead of using `parts_[0]` for all voices, use `parts_[voice->partIndex]` so each voice gets its correct part's synthesis parameters. This is what makes multitimbral actually work — without it, all 16 parts would sound identical.
