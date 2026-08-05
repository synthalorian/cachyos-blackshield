---
name: audio-dsp-debugging
description: Use when audio sounds wrong (static, drone, clipping).
---

# Audio DSP Debugging

For bugs where the symptom is audible ("there's static", "notes never stop", "chords distort") but invisible in logs. Audio bugs are data bugs — measure, don't listen.

## Core moves (in order)

1. **Build a headless render harness EARLY.** Instantiate the full engine, apply the failing preset, fire notes, render N seconds to WAV, print per-100ms RMS/peak buckets. This turns "there's static" into numbers you can bisect. Keep the harness as a permanent regression test.
2. **Layer isolation.** Add harness modes muting all-but-one layer (osc / samples / FX / drums). One run converts "noise everywhere" into "layer X is the culprit".
3. **Read the signatures** (see references/audio-dsp-debugging.md):
   - RMS ≈ peak → square wave / hard clip upstream
   - Flat RMS over time → stuck envelope or self-sustaining feedback
   - Peaks pinned at a limiter's magic number (`tanh(1.0)=0.7616`) → upstream rails at exactly ±1.0
   - Inspect the WAV directly (python `wave`+`struct`): count near-max samples per window for flat-top detection
4. **gdb, not printf archaeology.** Conditional-break at the mix point on an absurd threshold (`break file.cpp:NN if leftOut > 100.0f`), `run`, `info locals` — find which stage railed. Use a **Debug (-O0) build**: RelWithDebInfo optimizes out locals.
5. **Fix the math, not the level.** Don't reach for gain-staging when a component is in exponential blow-up.

## Classic instabilities (details in references/audio-dsp-debugging.md)

- **Chamberlin SVF is unstable above fs/6** (8kHz @ 48k) regardless of "clamp f < 2.0" comments. Cutoff > fs/6 → filter state explodes into square-wave noise. Fix: TPT/Zavalishin SVF (stable to Nyquist) — drop-in replacement, recipe in the reference.
- **Envelope params that never reach voices** (latched at the wrong point / not at all) → every note drones at defaults. Sync from the voice's part per-block when voices spawn via multiple paths (direct/arp/queue).
- **Zero poly mix headroom**: 8 voices × ±1 into a soft clipper = distorted chords. Scale 1/√N(active voices).
- **Acoustic instruments with pad envelopes**: sustain 0.6+ under one-shot samples = drone. Acoustic = sustain 0–0.15, instrument-matched decay.

## Framework traps

- **JUCE**: `AudioFormat::createWriterFor(stream, ...)` takes ownership of the stream — passing a `unique_ptr`'s raw pointer without `.release()` double-frees at cleanup, AFTER the test "passed".

## Hunt discipline (learned the hard way)

- **Real bug, wrong bug.** Code-reading found "envelope params never reach voices" mid-hunt and it was declared the root cause — a genuine bug, but NOT the static (the filter blow-up was). A plausible code-read finding is a hypothesis: fix it, then RE-MEASURE the original symptom. If the symptom survives, you fixed bug #1 of N — keep going. Phrase findings as "a real bug, verifying it's the cause" until the measurement dies.
- **Progress beats.** During long empirical hunts, post one-line progress signals between slow steps (builds, gdb runs): what you just learned, what's next. Long silent stretches read as "stuck" to the user.

## References

- `references/audio-dsp-debugging.md` — full technique write-up: render-harness pattern, signature table, gdb recipes, TPT SVF code, voice lifecycle traps. Distilled from the OpenSynth "static behind the piano" hunt (2026-07-25).
