# Unified Audio Stream Architecture

Fixing multiple PortAudio streams conflicting on the same device by mixing all sources (synth A, synth B, samples) into a single `Pa_OpenStream` callback.

## Problem

PortAudio does NOT support multiple concurrent output streams on the same device. Creating separate `AudioStream` instances for synth, pair, and sample engines causes:
- Whichever stream opens last wins
- Earlier streams are silently stopped
- Complete silence or audio corruption

## Solution

`SynthEnginePair` optionally owns a `SampleEngine*` and mixes all sources in its `process()` callback. There is exactly ONE `Pa_OpenStream` call.

## C++ Changes

### synth_mixer.h

```cpp
class SynthEnginePair {
public:
    SynthEnginePair(double sampleRate, uint32_t blockSize);
    ~SynthEnginePair();
    
    void process(AudioBuffer& output);
    
    // Sample engine attachment
    void setSampleEngine(SampleEngine* engine);
    void setSampleVolumeDb(float db);
    
    SynthEngine& engineA() { return engineA_; }
    SynthEngine& engineB() { return engineB_; }
    
private:
    SynthEngine engineA_;
    SynthEngine engineB_;
    SampleEngine* sampleEngine_ = nullptr;
    float sampleVolumeDb_ = 0.0f;
    float sampleVolumeLinear_ = 1.0f;
    
    bool tempBufferAllocated_ = false;
    std::vector<float> tempBuffer_;
};
```

### synth_mixer.cpp

```cpp
void SynthEnginePair::process(AudioBuffer& output) {
    const uint32_t frames = output.numFrames;
    const bool stereo = output.numChannels >= 2;
    
    // Render engine A into output
    engineA_.process(output);
    
    // Render engine B into temp buffer, mix into output
    if (tempBufferAllocated_) {
        AudioBuffer temp(tempBuffer_.data(), frames, stereo ? 2 : 1);
        engineB_.process(temp);
        
        for (uint32_t i = 0; i < (stereo ? frames * 2 : frames); i++) {
            output.data[i] += temp.data[i];
        }
    }
    
    // Render sample engine into temp buffer, mix into output
    if (sampleEngine_ && sampleEngine_->isLoaded()) {
        const uint32_t sampleChannels = sampleEngine_->numChannels();
        const uint32_t sampleFrames = sampleEngine_->blockSize();
        
        if (sampleFrames >= frames) {
            std::vector<float> sampleBuf(frames * sampleChannels);
            sampleEngine_->renderBlock(sampleBuf.data(), frames);
            
            if (sampleChannels == 2 && stereo) {
                for (uint32_t i = 0; i < frames; i++) {
                    output.data[i * 2] += sampleBuf[i * 2] * sampleVolumeLinear_;
                    output.data[i * 2 + 1] += sampleBuf[i * 2 + 1] * sampleVolumeLinear_;
                }
            } else if (sampleChannels == 1) {
                for (uint32_t i = 0; i < frames; i++) {
                    float sample = sampleBuf[i] * sampleVolumeLinear_;
                    if (stereo) {
                        output.data[i * 2] += sample;
                        output.data[i * 2 + 1] += sample;
                    } else {
                        output.data[i] += sample;
                    }
                }
            }
        }
    }
    
    // NaN/inf guard
    const uint32_t totalSamples = stereo ? frames * 2 : frames;
    for (uint32_t i = 0; i < totalSamples; i++) {
        if (!std::isfinite(output.data[i])) {
            output.data[i] = 0.0f;
        }
    }
}

void SynthEnginePair::setSampleEngine(SampleEngine* engine) {
    sampleEngine_ = engine;
}

void SynthEnginePair::setSampleVolumeDb(float db) {
    sampleVolumeDb_ = db;
    sampleVolumeLinear_ = std::pow(10.0f, db / 20.0f);
}
```

### synth_ffi.cpp

```cpp
extern "C" {

void synth_pair_set_sample_engine(void* pair, void* sampleEngine) {
    if (!pair) return;
    static_cast<SynthEnginePair*>(pair)->setSampleEngine(
        static_cast<SampleEngine*>(sampleEngine));
}

void synth_pair_set_sample_volume(void* pair, float db) {
    if (!pair) return;
    static_cast<SynthEnginePair*>(pair)->setSampleVolumeDb(db);
}

} // extern "C"
```

### synth_ffi.h

```cpp
#ifdef __cplusplus
extern "C" {
#endif

void synth_pair_set_sample_engine(void* pair, void* sampleEngine);
void synth_pair_set_sample_volume(void* pair, float db);

#ifdef __cplusplus
}
#endif
```

## Dart Changes

### openamp_synth.dart

```dart
typedef _PairSetSampleEngineNative = Void Function(Pointer<Void> pair, Pointer<Void> engine);
typedef _PairSetSampleEngineDart = void Function(Pointer<Void> pair, Pointer<Void> engine);
typedef _PairSetSampleVolumeNative = Void Function(Pointer<Void> pair, Float db);
typedef _PairSetSampleVolumeDart = void Function(Pointer<Void> pair, double db);

class PairBindings {
  // ... existing fields ...
  
  final _PairSetSampleEngineDart setSampleEngine;
  final _PairSetSampleVolumeDart setSampleVolume;
  
  PairBindings._(DynamicLibrary lib)
      : // ... existing init ...
        setSampleEngine = lib.lookupFunction<_PairSetSampleEngineNative, _PairSetSampleEngineDart>('synth_pair_set_sample_engine'),
        setSampleVolume = lib.lookupFunction<_PairSetSampleVolumeNative, _PairSetSampleVolumeDart>('synth_pair_set_sample_volume');
}

class OpenAmpSynthPair {
  // ... existing methods ...
  
  void setSampleEngine(OpenAmpSynth? sampleEngine) {
    _bindings.setSampleEngine(_handle, sampleEngine?._handle ?? nullptr);
  }
  
  void setSampleVolumeDb(double db) {
    _bindings.setSampleVolume(_handle, db);
  }
}
```

## Provider Changes

### keyboard_split_provider.dart

```dart
// OLD — separate streams, causes conflict:
// final synthAudioStreamProvider = Provider<OpenAmpSynthAudioStream?>((ref) { ... });
// final synthPairAudioStreamProvider = Provider<OpenAmpSynthAudioStream?>((ref) { ... });
// final sampleAudioStreamProvider = Provider<OpenAmpSynthAudioStream?>((ref) { ... });

// NEW — unified single stream:
final unifiedAudioStreamProvider = Provider<OpenAmpSynthAudioStream?>((ref) {
  final split = ref.watch(keyboardSplitProvider);
  
  if (split.enabled) {
    final pair = ref.watch(synthPairProvider);
    if (pair == null) return null;
    return OpenAmpSynthAudioStream.forSynthPair(pair);
  } else {
    final synth = ref.watch(synthEngineProvider);
    if (synth == null) return null;
    return OpenAmpSynthAudioStream.forSynth(synth);
  }
});

final synthPairProvider = Provider<OpenAmpSynthPair?>((ref) {
  final pair = OpenAmpSynthPair.create(sampleRate: 48000, blockSize: 256);
  if (pair == null) return null;
  
  // Attach sample engine if active
  final sampleEngine = ref.watch(sampleEngineProvider);
  if (sampleEngine != null) {
    pair.setSampleEngine(OpenAmpSynth.fromHandle(sampleEngine.handle));
  }
  
  return pair;
});
```

### synth_providers.dart

```dart
class PlaybackStateNotifier extends StateNotifier<PlaybackState> {
  // ...
  
  OpenAmpSynth? get _engine {
    final split = _ref.read(keyboardSplitProvider);
    if (split.enabled) {
      final pair = _ref.read(synthPairProvider);
      return pair != null ? OpenAmpSynth.fromHandle(pair.engineA) : null;
    }
    return _ref.read(synthEngineProvider);
  }
  
  void _ensureAudioRunning() {
    _ref.read(unifiedAudioStreamProvider); // triggers creation
  }
  
  void _routeSampleNoteOn(int note, double velocity) {
    final sampleEngine = _ref.read(sampleEngineProvider);
    if (sampleEngine != null) {
      sampleEngine.noteOn(note, velocity);
    }
  }
  
  void _routeSampleNoteOff(int note) {
    final sampleEngine = _ref.read(sampleEngineProvider);
    if (sampleEngine != null) {
      sampleEngine.noteOff(note);
    }
  }
  
  void noteOn(int note, double velocity) {
    _ensureAudioRunning();
    _engine?.noteOn(note, velocity);
    _routeSampleNoteOn(note, velocity);
    // ...
  }
  
  void noteOff(int note) {
    _engine?.noteOff(note);
    _routeSampleNoteOff(note);
    // ...
  }
}
```

### sample_engine_provider.dart

```dart
// OLD — always creates sample engine:
// final sampleEngineProvider = Provider<SampleEngine?>((ref) {
//   return SampleEngine.create();
// });

// NEW — lazy creation only when preset selected:
final sampleEngineProvider = Provider<SampleEngine?>((ref) {
  final preset = ref.watch(samplePresetProvider);
  if (preset == null) return null;
  
  final engine = SampleEngine.create();
  if (engine == null) return null;
  
  final resolvedPath = resolveSamplePath(preset.sfzPath);
  if (resolvedPath != null) {
    engine.loadSfzFile(resolvedPath);
  }
  
  return engine;
});
```

## Screen Changes

All screens replace:
```dart
// OLD
ref.watch(synthAudioStreamProvider);
ref.watch(synthPairAudioStreamProvider);

// NEW
ref.watch(unifiedAudioStreamProvider);
```

## Verification

After implementing, verify with:
```bash
# Check only one stream exists
nm -D libopenamp_dart_ffi.so | grep audio_stream_create
# Should show: audio_stream_create_for_synth, audio_stream_create_for_pair
# Should NOT show: audio_stream_create_for_sample_engine

# Check sample engine attachment symbols
nm -D libopenamp_dart_ffi.so | grep synth_pair_set_sample
# Should show: synth_pair_set_sample_engine, synth_pair_set_sample_volume
```

## Pitfalls

1. **Don't forget to delete old providers** — `synthAudioStreamProvider`, `synthPairAudioStreamProvider`, and `sampleAudioStreamProvider` must all be removed from the codebase or they'll still be instantiated.
2. **Sample engine must be non-owning wrapper** — `OpenAmpSynth.fromHandle()` sets `_ownsHandle = false` so the pair doesn't double-free the sample engine.
3. **Volume conversion** — dB to linear uses `pow(10, db/20)`, NOT `pow(2, db/6)`.
4. **Temp buffer sizing** — `SynthEnginePair` needs a temp buffer large enough for engine B output. Allocate in constructor based on `blockSize`.
5. **Stereo vs mono mixing** — Sample engine may output mono (1 channel) while pair outputs stereo (2). Mix mono into both channels.
