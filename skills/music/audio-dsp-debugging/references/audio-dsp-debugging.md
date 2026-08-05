# Audio DSP Debugging — Full Technique Write-up

Distilled from the OpenSynth "static behind the piano" hunt (2026-07-25). Applies to any synth/effects/audio-engine codebase where the bug is audible but invisible in logs.

## Principle: measure, don't listen

Audio bugs are data bugs. Build a headless render harness EARLY — instantiate the full engine, apply the failing preset, fire notes, render N seconds to WAV + print per-100ms RMS/peak buckets. This turns "there's static" into a number you can bisect against. Keep the harness as a permanent regression test (OpenSynth: `tests/engine_render_test`).

## Diagnostic signatures

- **RMS ≈ peak (ratio ~1.0)** — the signal is a square wave or DC. Something is hard-clipping or oscillating rail-to-rail. A healthy musical waveform reads 0.3–0.7.
- **Flat RMS across time** (never decays) — an envelope is stuck open, a voice never terminates, or a feedback loop is self-sustaining.
- **Exact magic numbers** — recognize your limiters: `tanh(1.0) = 0.7616`. If peaks pin at 0.7616 exactly, the pre-limiter signal is pinned at exactly ±1.0 (something upstream clamps or rails).
- **RMS rises while peak falls** — signal is being squashed into a sustained drone (e.g. clipper eating a decaying note's transient first).
- **Inspect the WAV directly** (python `wave` + `struct`): count samples near the window max; thousands of near-max samples per window = flat-topped/clipped.

```python
import wave, struct
w = wave.open('/tmp/render.wav','rb')
n = w.getnframes(); sr = w.getframerate()
L = struct.unpack(f'<{n*2}h', w.readframes(n))[0::2]  # left channel
full = 32767
for t in [0.6, 1.0, 2.0, 3.0]:
    c = L[int(t*sr):int(t*sr)+4800]
    mx = max(max(c), -min(c))/full
    rms = (sum(s*s for s in c)/len(c))**0.5/full
    flat = sum(1 for s in c if abs(s) >= 0.98*mx*full)
    print(f"t={t}s peak={mx:.4f} rms={rms:.4f} ratio={rms/mx:.2f} near-max={flat}")
```

## Layer isolation

When the engine mixes layers (osc synth + sample player + FX + drum kit), add harness modes that mute all-but-one layer (`synth`/`sample`/`synthdry`/`both`). This is the fastest cut: it turned "static everywhere" into "sample layer clean, synth layer constant drone" in one run.

## gdb for audio (the winning move)

When the blow-up is numeric, don't printf-archaeology:

```
break synth_engine.cpp:NNN if leftOut > 100.0f || leftOut < -100.0f
run
info locals
```

- Conditional-break at the mix point on an absurd threshold, then inspect locals to find which stage railed.
- **RelWithDebInfo (-O2) optimizes out locals.** For gdb inspection use a Debug (-O0) build, even if it means a separate build dir.
- Batch gdb: `gdb -batch -x cmds.txt ./binary` with `run`, `bt`, `p var` lines; grep the output.

Session example: mix probe read -142 while filter input (monoMix) was 0.22 and filter state was lp=-2479/bp=-2958 — the SVF was in exponential blow-up. Found in two gdb runs after ~10 failed static-analysis guesses.

## Two verification traps that cost time

- **Identical measurements after a code change** = the change either isn't in the binary or isn't in the signal path. Check the cheap one first: `touch file.cpp && rebuild && ls -la binary` — then question whether the edited code is even reached (probe it).
- **Probe globals and C++ namespaces**: an `extern float g_probe;` declared inside `namespace foo { }` refers to `foo::g_probe`. If the definition sits at file scope (global namespace), the link fails with "undefined reference to foo::g_probe". Define the probes inside the same namespace (or qualify the definition `float foo::g_probe = 0;`).

## Classic DSP instability: Chamberlin SVF

The Chamberlin state-variable filter (`f = 2·sin(π·fc/fs)`, `bp += f·hp; lp += f·bp`) is **unstable above fs/6** (8kHz @ 48k). A comment saying "clamp f to <2.0 for stability" is WRONG — it goes unstable well below 1.95. Symptom: any preset with cutoff > fs/6 explodes the filter state into square-wave noise.

**Fix: TPT/Zavalishin SVF** (stable to Nyquist, same drop-in shape):

```cpp
float g = tanf(M_PI * cutoff / sampleRate);  // pre-warped; clamp to ~10 near Nyquist
float k = 2.0f - 2.0f * resonance;           // k = 2 - 2R
float a1 = 1/(1 + g*(g+k)), a2 = g*a1, a3 = g*a2;
float v3 = sample - ic2;
float v1 = a1*ic1 + a2*v3;                     // band-pass
float v2 = ic2 + a2*ic1 + a3*v3;               // low-pass
ic1 = 2*v1 - ic1;  ic2 = 2*v2 - ic2;
hp = sample - k*v1 - v2;
```

Keep NaN/inf state-reset guards on both sides of the update.

## Voice/envelope lifecycle traps

- **Envelope params latched nowhere**: preset envelope lived on the "part", voices kept Envelope defaults (sustain 0.8) → every note droned under decaying samples. When voices are created via multiple paths (direct noteOn, arpeggiator, param queue), syncing params per-block from the voice's part beats latching at noteOn — covers all paths AND live edits.
- **Mix headroom**: raw poly accumulation (8 voices × ±1) into a tanh limiter = clipped chords. Scale by 1/√N(active voices) — single notes stay full-scale, chords get gentle averaging.
- **Acoustic instruments need decay envelopes**: sustain 0.6–0.7 (pad values) on piano/guitar/bass presets makes the synth layer drone under one-shot samples. Acoustic = sustain 0–0.15, decay matched to the instrument (piano ~2.4s).

## JUCE trap

`AudioFormat::createWriterFor(stream, ...)` **takes ownership** of the stream. Passing a `unique_ptr<FileOutputStream>`'s raw pointer without `.release()` → double-free → segfault at cleanup, AFTER your test "passed".

## Harness ordering pitfall

If the engine applies queued params at block boundaries, a noteOn sent in the same block as preset application latches pre-preset state. Render a few silent blocks first (let the queue drain), THEN send notes.
