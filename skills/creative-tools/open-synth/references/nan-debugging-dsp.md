# NaN Debugging in DSP Audio Engines

Technique for tracing NaN/infinity origin in real-time audio synthesis engines.

## When to Use

Audio engine produces silence but no crash. PortAudio stream starts successfully.
Peak output measures as NaN or infinity. The NaN guard at output zeroes everything.

## Minimal C++ Test Harness

```cpp
#include <stdio.h>
#include <dlfcn.h>
#include <stdint.h>
#include <cmath>

typedef void* (*create_fn)(double, uint32_t);
typedef void (*note_on_fn)(void*, int, float);
typedef void (*process_fn)(void*, float*, uint32_t);
typedef void (*set_float_fn)(void*, float);
typedef void (*set_int_fn)(void*, int32_t);

int main() {
    void* lib = dlopen("./libopenamp_dart_ffi.so", RTLD_NOW);
    auto create = (create_fn)dlsym(lib, "synth_engine_create");
    auto note_on = (note_on_fn)dlsym(lib, "synth_engine_note_on");
    auto process = (process_fn)dlsym(lib, "synth_engine_process");
    auto set_osc1_wave = (set_int_fn)dlsym(lib, "synth_engine_set_osc1_waveform");
    auto set_osc1_vol = (set_float_fn)dlsym(lib, "synth_engine_set_osc1_volume");
    auto set_cutoff = (set_float_fn)dlsym(lib, "synth_engine_set_filter_cutoff");
    auto set_attack = (set_float_fn)dlsym(lib, "synth_engine_set_amp_attack");
    auto set_decay = (set_float_fn)dlsym(lib, "synth_engine_set_amp_decay");
    auto set_sustain = (set_float_fn)dlsym(lib, "synth_engine_set_amp_sustain");
    auto set_release = (set_float_fn)dlsym(lib, "synth_engine_set_amp_release");
    auto set_master = (set_float_fn)dlsym(lib, "synth_engine_set_master_volume");
    auto reset = (void (*)(void*))dlsym(lib, "synth_engine_reset");
    
    void* engine = create(48000.0, 256);
    reset(engine);
    
    set_osc1_wave(engine, 1);      // saw
    set_osc1_vol(engine, 0.8f);
    set_cutoff(engine, 20000.0f);
    set_attack(engine, 10.0f);
    set_decay(engine, 100.0f);
    set_sustain(engine, 0.8f);
    set_release(engine, 200.0f);
    set_master(engine, 0.8f);
    
    note_on(engine, 60, 1.0f);
    
    float buffer[512];
    for (int i = 0; i < 20; i++) {
        process(engine, buffer, 128);
        float peak = 0.0f;
        for (int j = 0; j < 256; j++) {
            float v = std::abs(buffer[j]);
            if (v > peak) peak = v;
        }
        printf("Block %d: peak=%.6f %s\n", i, peak,
               std::isfinite(peak) ? "" : "[NaN/INF]");
    }
    
    dlclose(lib);
    return 0;
}
```

Compile: `g++ test.cpp -o test -ldl && ./test`

## Per-Section NaN Tracing in process()

Add a static location tracker and check helper:

```cpp
static const char* nanCheckLocation = nullptr;

static bool checkNaN(float val, const char* location) {
    if (!std::isfinite(val)) {
        nanCheckLocation = location;
        return true;
    }
    return false;
}

static void printNaNTrace() {
    if (nanCheckLocation) {
        std::fprintf(stderr, "[OpenSynth NaN] First NaN at: %s\n", nanCheckLocation);
        nanCheckLocation = nullptr;
    }
}
```

Place `checkNaN()` after every DSP stage in the per-frame loop:
- After envelope processing (`ampEnv`, `filterEnv`, `pitchEnv`)
- After pitch modulation (`modFreq`)
- After each oscillator (`osc1`, `osc2`)
- After oscillator mix (`oscMix`)
- After filter (`filter`)
- After part pan (`partPanL`, `partPanR`)
- After LFO amplitude modulation (`ampMod`)
- After FX engine (`fx`)
- After master volume (`master`)

Call `printNaNTrace()` once per block, after the frame loop.

## Common NaN Sources

| Source | Cause | Fix |
|--------|-------|-----|
| `ampEnv` | Zero attack time → division by zero in envelope rate | Clamp attack to >= 1ms |
| `modFreq` | `std::pow(2.0f, pitchMod * 2.0f)` with uninitialized `pitchMod` | Initialize pitchMod = 0.0f |
| `filter` | SVF with zero cutoff or uninitialized state | Set default cutoff to 20000Hz, init filter state |
| `oscMix` | Uninitialized `oscMix` field (default 0.0f) | Set default to 0.5f |
| `masterVolume_` | Uninitialized (default 0.0f) | Set default to 0.8f |
| `phaseIncrement()` | Hardcoded 48000.0f instead of actual sample rate | Use constructor sampleRate_ |

## Verification

Run app from terminal and grep stderr:
```bash
~/.local/share/open_synth/open_synth 2>&1 | grep "\[OpenSynth NaN\]"
```

If no output and peak stays at 0.0, the engine is producing valid zeros — check if preset is loaded or if voices are active.

## Cleanup

Remove `checkNaN()` and `printNaNTrace()` before release builds. They add per-frame branching that costs CPU on the audio thread.
