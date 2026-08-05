# Open Synth Architecture Notes

## Audio Thread Flow

```
UI Thread (Dart)                Audio Thread (C++ PortAudio callback)
─────────────────               ──────────────────────────────────────
ParamQueue.enqueue()    ──→     SynthEngine::drainQueue()
  (lock-free SPSC)                ↓
                           applyParam() → updates osc/filter/env/FX params
                                 ↓
                           VoiceAllocator::processActiveVoices()
                                 ↓
                           SynthEngine::renderBlock()
                             oscillators → filter → envelopes → FX chain
                                 ↓
                           NaN/inf guard → hard limiter → output buffer
```

## Provider Lifecycle

```dart
// synth_providers.dart — load order matters

synthEngineProvider (Riverpod)
  onCreate:  AudioSystem::instance().init()    // Pa_Initialize once
             SynthEngine::create()
  onDispose: AudioSystem::instance().shutdown() // Pa_Terminate once

synthAudioStreamProvider (Riverpod)
  onCreate:  AudioStream::create(engine)
             AudioStream::start()               // Begin audio callback
  onDispose: AudioStream::stop()               // MUST stop first!
             AudioStream::destroy()

// CRITICAL: synthAudioStreamProvider must dispose BEFORE synthEngineProvider
// Riverpod disposes in reverse creation order — create engine first, stream second
```

## ParamQueue Design

```
┌──────────────────────────────────────────────────────┐
│  ParamQueue (1024 entries, power-of-2 wrapping)       │
│  ┌────────┬────────┬────────┬─────────┬─────────┐    │
│  │paramId │value   │isFloat │ ──────── │ ──────── │    │
│  │(uint32)│(float) │(bool)  │         │         │    │
│  └────────┴────────┴────────┴─────────┴─────────┘    │
│  writeIdx (UI thread) ──→  readIdx (audio thread)     │
│  cache-line padded: 64-byte alignment                   │
└──────────────────────────────────────────────────────┘
```

Param ID ranges (from synth_ffi.cpp / ParamId in openamp_synth.dart):
- 1-99: Oscillator params (waveform, level, detune, pulse width, octave, unison count, unison spread, noise level)
- 100-199: Filter params (cutoff, resonance, type, env amount, key tracking, LFO amount)
- 200-299: Envelope params (attack, decay, sustain, release for amp + filter)
- 300-399: LFO params (rate, depth, waveform, sync for LFO1 + LFO2)
- 400-499: FX params (all 7 effect types, param indices per effect)
- 500-599: Compressor params (threshold, ratio, attack, release, makeup gain, enabled)
- 600-699: Master params (volume, pan)
- 1000+: MIDI notes (note on, note off, velocity, channel)

## FFI Bridge

```
Dart (openamp_synth.dart)           C++ (synth_ffi.cpp)
─────────────────────────           ─────────────────────
OpenAmpSynth class                  extern "C" functions
  synth_engine_create()       ──→  synth_engine_create()
  synth_engine_enqueue_float()──→  synth_engine_enqueue_float()
  synth_engine_enqueue_int()  ──→  synth_engine_enqueue_int()
  synth_engine_enqueue_note_on()──→ synth_engine_enqueue_note_on()
  synth_engine_enqueue_note_off()─→ synth_engine_enqueue_note_off()
  synth_engine_reset()        ──→  synth_engine_reset()

  // Backward compat — avoid during playback:
  synth_engine_set_osc1_waveform()  // Direct setter, NOT thread-safe
```

## Effects Chain (Current)

```
Input → Chorus → Delay → Reverb → Phaser → Flanger → Drive → Compressor → Output
```

Each effect has an `enabled` toggle. Effect parameters are per-effect structs stored in SynthEngine.

## Key Files Quick Reference

| File | Purpose |
|------|---------|
| `native/include/param_queue.h` | Lock-free SPSC ring buffer (1024 entries) |
| `native/include/audio_system.h` | PortAudio lifecycle singleton |
| `native/include/audio_stream.h` | Audio output stream (uses AudioSystem) |
| `native/include/synth_engine.h` | Main DSP engine (osc, filter, env, LFO, FX) |
| `native/include/synth_ffi.h` | FFI exports (enqueue + legacy direct setters) |
| `lib/ffi/openamp_synth.dart` | Dart FFI bindings + ParamId constants |
| `lib/ffi/openamp_audio_stream.dart` | Dart audio system/stream bindings |
| `lib/providers/synth_providers.dart` | Riverpod providers with lifecycle management |
| `lib/data/factory_presets.dart` | 36+ factory preset definitions |
| `PLAN.md` | Master feature roadmap (Phases 0-6) |
