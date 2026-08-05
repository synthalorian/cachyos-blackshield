# Drum Synthesis Algorithms — Quality Pass Reference

Reference for the drum synthesis quality algorithms implemented in `native/src/drum_synth.cpp`.

## Architecture

Each drum type has a dedicated synthesis algorithm in the `process()` switch statement. The `DrumVoice` struct carries per-voice state including:
- `pinkB0..pinkB6` — Paul Kellet pink noise filter states
- `modePhases[8]` — multi-partial oscillator phases for cymbals/hats
- Standard: `phase`, `phase2`, `subPhase`, `filterState1/2`, `noiseState`

## Pink Noise

Paul Kellet's refined method (6 white noise generators at different octaves):

```cpp
static float pinkNoise(float& whiteState, float& b0, float& b1, float& b2,
                       float& b3, float& b4, float& b5, float& b6) {
    float white = fastRand(whiteState);
    b0 = 0.99886f * b0 + white * 0.0555179f;
    b1 = 0.99332f * b1 + white * 0.0750759f;
    b2 = 0.96900f * b2 + white * 0.1538520f;
    b3 = 0.86650f * b3 + white * 0.3104856f;
    b4 = 0.55000f * b4 + white * 0.5329522f;
    b5 = -0.7616f * b5 - white * 0.0168980f;
    float out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362f;
    b6 = white * 0.115926f;
    return out * 0.11f;
}
```

## Kick Drum

Layers: sub-boom (sine at 0.5x freq) + body (pitched sine with exponential curve) + shell resonance (detuned sine at 0.72x endFreq) + beater click (filtered noise burst) + knock transient (very short low-mid thump).

Pitch envelope: exponential, not linear. `pow(0.7, sweepPhase * 10.0)` gives fast initial drop then settles.

```cpp
float freq = pitchEnvelope(v.envelopePhase, v.pitchStart, v.pitchEnd,
                           v.pitchSweepTime, v.baseDecay);
// Main body
v.phase += freq * invSr;
float body = sin(twoPi * v.phase);
// Sub-boom
v.subPhase += freq * 0.5f * invSr;
float sub = sin(twoPi * v.subPhase);
// Shell
v.phase2 += v.pitchEnd * 0.72f * invSr;
float shell = sin(twoPi * v.phase2);
// Click (filtered noise, very fast decay)
float click = (noise - filterState2) * exp(-phase * 60) * 0.5f;
// Knock (80Hz sine, very fast)
float knock = sin(twoPi * phase * 20) * exp(-phase * 60) * 0.3f;
```

## Snare Drum

Layers: shell tone (fundamental + first overtone at 1.6x) + wire rattle (4 parallel BPFs on pink noise) + strike transient (bright noise burst) + rimshot edge (for high velocity).

Wire resonator frequencies: 1200Hz, 2500Hz, 3800Hz, 5200Hz. Decreasing amplitude per resonator.

```cpp
// 4 parallel resonant BPFs
float wireFreqs[4] = {1200.0f, 2500.0f, 3800.0f, 5200.0f};
float wireQs[4] = {0.85f, 0.75f, 0.65f, 0.55f};
for (int w = 0; w < 4; ++w) {
    float f = 2.0f * sin(pi * wireFreqs[w] * invSr);
    float qf = 1.0f - clamp(1.0f / wireQs[w], 0.01f, 0.99f);
    float bp = modePhases[w] + f * (wireNoise - filterState1 - qf * modePhases[w]);
    float lp = filterState1 + f * bp;
    modePhases[w] = bp;
    filterState1 = lp;
    wireOut += bp * (0.25f - w * 0.03f);
}
```

## Hi-Hats

6 inharmonic sine partials + pink noise through HPF. Metallic shimmer from inharmonic ratios.

```cpp
float baseFreq = 400.0f * v.tuning;
float ratios[6] = {1.0f, 1.43f, 1.89f, 2.37f, 2.89f, 3.47f};
float amps[6] = {0.35f, 0.25f, 0.20f, 0.12f, 0.05f, 0.03f};
for (int m = 0; m < 6; ++m) {
    modePhases[m] += baseFreq * ratios[m] * invSr;
    float partialDecay = exp(-phase * (2.0f + m * 1.5f));
    metallic += sin(twoPi * modePhases[m]) * amps[m] * partialDecay;
}
```

## Crash Cymbal

8 metallic partials with frequency-dependent decay. Higher partials die faster.

```cpp
float crashRatios[8] = {1.0f, 1.38f, 1.72f, 2.15f, 2.58f, 3.12f, 3.67f, 4.25f};
float crashAmps[8] = {0.30f, 0.22f, 0.18f, 0.14f, 0.08f, 0.04f, 0.02f, 0.02f};
for (int m = 0; m < 8; ++m) {
    modePhases[m] += baseFreq * crashRatios[m] * invSr;
    float partialDecay = exp(-phase * (1.0f + m * 0.8f));
    metallic += sin(twoPi * modePhases[m]) * crashAmps[m] * partialDecay;
}
```

## Cowbell

Classic LP cowbell: 853Hz + 1130Hz. Triangle waves for metallic edge.

```cpp
float freq1 = 853.0f * tuning;        // Primary
float freq2 = 1130.0f * tuning;       // Secondary (853 + 277)
v.phase += freq1 * invSr;
v.phase2 += freq2 * invSr;
float tri1 = 2.0f * fabs(2.0f * (phase - floor(phase + 0.5f))) - 0.5f;
float tri2 = 2.0f * fabs(2.0f * (phase2 - floor(phase2 + 0.5f))) - 0.5f;
float mixed = tri1 * 0.55f + tri2 * 0.45f;
```

## Velocity-Dependent Brightness

Harder hits = brighter sound. Implemented by:
- More noise in the mix at high velocity
- Rimshot edge only activates when velocity > 0.7
- Strike transient amplitude scales with velocity

## Stereo Panning

Cymbals get slight stereo width:
- Crash: pan -0.3 (left)
- Ride: pan +0.3 (right)
- Open HH: pan -0.2

All other drums are center-panned.

## Envelope Types

Different envelope curves per drum type:
- **Kick**: Multi-stage — ampEnv (exp -3.5x), toneEnv (exp -2.8x), noiseEnv (exp -25x), clickEnv (exp -60x)
- **Snare**: ampEnv (exp -4x), toneEnv (exp -3x), noiseEnv (exp -5.5x), clickEnv (exp -40x)
- **Cymbals**: Frequency-dependent decay — highs die faster via `partialDecay = exp(-phase * (1 + m * 0.8))`
- **Clap**: 4-pulse Gaussian burst + exponential tail
