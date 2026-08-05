# Mobile Guitar Amp App — Common Pitfalls & Fixes

Reference for cross-platform guitar amplifier apps (Android/iOS/Linux) with shared C++ DSP core.

## Oboe Duplex Audio Patterns

### Problem: Non-blocking read causes dropouts

**Symptom:** Audio stutters, `ErrorTimeout` in logs, callback count increases but no sound.

**Root cause:** Calling `inputStream_->read(buffer, frames, 0)` with timeout=0 is non-blocking. When the input buffer isn't ready, it returns immediately with an error.

**Fix — Blocking read in output callback:**

```cpp
oboe::DataCallbackResult onAudioReady(
    oboe::AudioStream* stream, void* audioData, int32_t numFrames) {
    
    float* output = static_cast<float*>(audioData);
    int32_t framesRead = 0;
    
    if (inputStream_) {
        // Timeout in nanoseconds: 2x expected buffer duration
        int64_t timeoutNanos = numFrames * 2 * 1'000'000'000 / sampleRate_;
        auto result = inputStream_->read(inputBuffer_.data(), numFrames, timeoutNanos);
        if (result) framesRead = result.value();
    }
    
    // Zero-fill if underrun
    for (int32_t i = framesRead; i < numFrames; ++i) {
        inputBuffer_[i] = 0.0f;
    }
    
    // Convert interleaved input to mono if needed
    float monoBuffer[numFrames];
    for (int i = 0; i < numFrames; ++i) {
        monoBuffer[i] = inputBuffer_[i * inputChannels]; // take left channel
    }
    
    // Process through DSP
    dspEngine->process(monoBuffer, output, numFrames);
    return oboe::DataCallbackResult::Continue;
}
```

**Fix — Lock-free ring buffer (smoother, handles jitter):**

Add to header:
```cpp
std::vector<float> ringBuffer_;
std::atomic<size_t> ringWritePos_{0};
std::atomic<size_t> ringReadPos_{0};
size_t ringSize_ = 0;
static constexpr size_t kRingBufferFrames = 2048; // ~42ms at 48kHz

void writeToRing(const float* data, size_t frames);
size_t readFromRing(float* data, size_t frames);
```

Initialize in constructor:
```cpp
ringSize_ = kRingBufferFrames;
ringBuffer_.resize(ringSize_, 0.0f);
ringWritePos_.store(0);
ringReadPos_.store(0);
```

In `onAudioReady()`, after converting input to mono:
```cpp
// Decouple input timing from output timing
writeToRing(inputBuffer_.data(), numFrames);
size_t ringFramesRead = readFromRing(inputBuffer_.data(), numFrames);
if (ringFramesRead < static_cast<size_t>(numFrames)) {
    for (size_t i = ringFramesRead; i < static_cast<size_t>(numFrames); ++i) {
        inputBuffer_[i] = 0.0f;  // graceful underrun
    }
}
```

Implementation:
```cpp
void writeToRing(const float* data, size_t frames) {
    size_t writePos = ringWritePos_.load(std::memory_order_relaxed);
    for (size_t i = 0; i < frames; ++i) {
        ringBuffer_[writePos % ringSize_] = data[i];
        ++writePos;
    }
    ringWritePos_.store(writePos, std::memory_order_release);
}

size_t readFromRing(float* data, size_t frames) {
    size_t readPos = ringReadPos_.load(std::memory_order_relaxed);
    size_t writePos = ringWritePos_.load(std::memory_order_acquire);
    size_t available = writePos - readPos;
    size_t toRead = std::min(frames, available);
    for (size_t i = 0; i < toRead; ++i) {
        data[i] = ringBuffer_[readPos % ringSize_];
        ++readPos;
    }
    ringReadPos_.store(readPos, std::memory_order_relaxed);
    return toRead;
}
```

**Key insight:** The ring buffer absorbs timing jitter between input and output callbacks. If input runs slightly ahead, frames accumulate in the buffer. If input runs behind, we zero-fill a few frames instead of glitching. This is the most robust pattern for Oboe duplex on Android.

## Wiring Input Dynamics into InputProcessor (Phase 2 Pattern)

### Problem: Noise gate, compressor, EQ exist as plugins but aren't in the audio path

**Symptom:** Only clean guitar -> amp -> output. No noise suppression, no compression, no tone shaping.

**Root cause:** `InputProcessor::processInput()` only applies input gain -> effect chain -> amp simulator. The `NoiseGate`, `Compressor`, and `EQ` plugins exist in `dsp-core/plugins/` and are instantiated in `DSPEngine` (Linux desktop), but `InputProcessor` (shared core used by Android) doesn't own or process them.

**Fix — Add plugin ownership to InputProcessor:**

```cpp
// input_processor.h
#include "noise_gate.h"
#include "compressor.h"
#include "eq.h"

class InputProcessor {
public:
    // Enable toggles
    void setNoiseGateEnabled(bool enabled) { noiseGateEnabled_ = enabled; }
    void setCompressorEnabled(bool enabled) { compressorEnabled_ = enabled; }
    void setEQEnabled(bool enabled) { eqEnabled_ = enabled; }
    bool isNoiseGateEnabled() const { return noiseGateEnabled_; }
    bool isCompressorEnabled() const { return compressorEnabled_; }
    bool isEQEnabled() const { return eqEnabled_; }
    
    // Parameter access for AudioEngine to tune
    NoiseGate* getNoiseGate() { return noiseGate_.get(); }
    Compressor* getCompressor() { return compressor_.get(); }
    EQ* getEQ() { return eq_.get(); }
    
private:
    std::unique_ptr<NoiseGate> noiseGate_;
    std::unique_ptr<Compressor> compressor_;
    std::unique_ptr<EQ> eq_;
    
    bool noiseGateEnabled_ = true;    // default ON for guitar
    bool compressorEnabled_ = false;  // default OFF (user opt-in)
    bool eqEnabled_ = false;          // default OFF (user opt-in)
};
```

**Fix — Instantiate in InputProcessor::initialize():**

```cpp
bool InputProcessor::initialize(const ProcessingConfig& config) {
    config_ = config;
    
    if (ampSimulator_) ampSimulator_->prepare(config.sampleRate, config.bufferSize);
    if (effectChain_) effectChain_->prepare(config.sampleRate, config.bufferSize);
    
    // Create dynamics and tone plugins with sensible defaults
    if (!noiseGate_) {
        noiseGate_ = std::make_unique<NoiseGate>();
        noiseGate_->prepare(config.sampleRate, config.bufferSize);
        noiseGate_->setThreshold(-45.0f);  // typical for guitar
        noiseGate_->setAttack(1.0f);
        noiseGate_->setRelease(100.0f);
    }
    if (!compressor_) {
        compressor_ = std::make_unique<Compressor>();
        compressor_->prepare(config.sampleRate, config.bufferSize);
        compressor_->setThreshold(-20.0f);
        compressor_->setRatio(4.0f);
        compressor_->setAttack(10.0f);
        compressor_->setRelease(100.0f);
    }
    if (!eq_) {
        eq_ = std::make_unique<EQ>();
        eq_->prepare(config.sampleRate, config.bufferSize);
        // All 10 bands flat at 0dB by default
    }
    
    return true;
}
```

**Fix — Process in correct signal chain order:**

```cpp
void InputProcessor::processInput(const float* input, float* output, uint32_t numFrames) {
    // 1. Input gain staging
    std::vector<float> processed(numFrames);
    for (uint32_t i = 0; i < numFrames; ++i) {
        processed[i] = input[i] * inputGain_;
    }
    
    // 2. Build mono AudioBuffer for plugin processing
    AudioBuffer monoBuffer;
    monoBuffer.data = processed.data();
    monoBuffer.numChannels = 1;
    monoBuffer.numFrames = numFrames;
    monoBuffer.sampleRate = static_cast<uint32_t>(config_.sampleRate);
    
    // 3. Signal chain: Gate -> Compressor -> EQ -> Effects -> Amp
    if (noiseGate_ && noiseGateEnabled_) {
        noiseGate_->process(monoBuffer);
    }
    
    if (compressor_ && compressorEnabled_) {
        compressor_->process(monoBuffer);
    }
    
    if (eq_ && eqEnabled_) {
        eq_->process(monoBuffer);
    }
    
    if (effectChain_ && effectsEnabled_) {
        effectChain_->process(monoBuffer);
    }
    
    if (ampSimulator_ && ampEnabled_) {
        ampSimulator_->process(monoBuffer);
    }
    
    // 4. Output gain + stereo expansion + limiter
    for (uint32_t i = 0; i < numFrames; ++i) {
        float sample = processed[i] * outputGain_;
        sample = std::clamp(sample, -1.0f, 1.0f);
        for (uint32_t ch = 0; ch < config_.numOutputChannels; ++ch) {
            output[i * config_.numOutputChannels + ch] = sample;
        }
    }
}
```

**Fix — Wire AudioEngine state to InputProcessor:**

```cpp
// AudioEngine.h — add state variables
bool compressorEnabled_ = false;
bool eqEnabled_ = false;
float noiseGateThreshold_ = -45.0f;
float noiseGateAttack_ = 1.0f;
float noiseGateRelease_ = 100.0f;
float compressorThreshold_ = -20.0f;
float compressorRatio_ = 4.0f;
float compressorAttack_ = 10.0f;
float compressorRelease_ = 100.0f;
```

```cpp
// AudioEngine constructor — sync state to InputProcessor
if (processor_) {
    processor_->setNoiseGateEnabled(noiseGateEnabled_);
    processor_->setCompressorEnabled(compressorEnabled_);
    processor_->setEQEnabled(eqEnabled_);
    
    if (auto* ng = processor_->getNoiseGate()) {
        ng->setThreshold(noiseGateThreshold_);
        ng->setAttack(noiseGateAttack_);
        ng->setRelease(noiseGateRelease_);
    }
    if (auto* comp = processor_->getCompressor()) {
        comp->setThreshold(compressorThreshold_);
        comp->setRatio(compressorRatio_);
        comp->setAttack(compressorAttack_);
        comp->setRelease(compressorRelease_);
    }
}
```

**Fix — Add eq.cpp to Android CMake:**

```cmake
add_library(openamp-native SHARED
    AudioEngine.cpp
    JniBridge.cpp
    ${DSP_CORE_DIR}/plugins/eq/eq.cpp   // <-- ADD THIS
    // ... other sources ...
)

target_include_directories(openamp-native
    PRIVATE
        ${DSP_CORE_DIR}/plugins/eq      // <-- ADD THIS
        // ... other includes ...
)
```

**Key insight:** The `InputProcessor` is the shared core used by both Linux and Android. Adding plugins here (rather than only in `DSPEngine`) ensures cross-platform consistency. Default states: noise gate ON (essential for guitar), compressor OFF (user opt-in), EQ OFF (user opt-in).

## Wiring a Real Tuner (Phase 3 Pattern)

### Problem: Tuner UI shows hardcoded note

**Symptom:** `NeonTunerDisplay` always shows "E" with 0 cents, regardless of actual guitar pitch.

**Root cause:** The meter loop calls `neonTunerDisplay.setNote("E", 0f, true)` instead of querying the actual `Tuner` plugin. The `Tuner` plugin exists in `dsp-core/plugins/tuner/` with full autocorrelation-based pitch detection, but is never instantiated in `AudioEngine` or exposed via JNI.

**Fix — Add Tuner to AudioEngine:**

```cpp
// AudioEngine.h
#include "tuner.h"

class AudioEngine {
public:
    void setTunerEnabled(bool enabled);
    bool getTunerEnabled() const;
    std::string getTunerNote() const;
    float getTunerCents() const;
    bool getTunerValid() const;

private:
    std::unique_ptr<openamp::Tuner> tuner_;
    bool tunerEnabled_ = false;
};
```

```cpp
// Constructor — create and prepare tuner
tuner_ = std::make_unique<openamp::Tuner>();
if (tuner_) {
    tuner_->prepare(config_.sampleRate, config_.bufferSize);
    tuner_->setMute(false); // Don't mute audio when tuning
}
```

```cpp
// onAudioReady — run tuner on input BEFORE DSP processing
if (tunerEnabled_ && tuner_) {
    openamp::AudioBuffer tunerBuffer;
    tunerBuffer.data = inputBuffer_.data();  // raw input, not processed
    tunerBuffer.numChannels = 1;
    tunerBuffer.numFrames = numFrames;
    tunerBuffer.sampleRate = static_cast<uint32_t>(config_.sampleRate);
    tuner_->process(tunerBuffer);
}
```

```cpp
// Getters — return latest detection result
std::string AudioEngine::getTunerNote() const {
    if (!tuner_) return "--";
    auto result = tuner_->getLastDetection();
    return result.valid ? result.noteName : "--";
}
float AudioEngine::getTunerCents() const {
    if (!tuner_) return 0.0f;
    auto result = tuner_->getLastDetection();
    return result.valid ? result.cents : 0.0f;
}
bool AudioEngine::getTunerValid() const {
    return tuner_ && tuner_->getLastDetection().valid;
}
```

**Fix — Add JNI bridge:**

```cpp
// JniBridge.cpp
extern "C" JNIEXPORT void JNICALL
Java_com_openamp_AudioEngine_nativeSetTunerEnabled(JNIEnv*, jobject, jboolean enabled) {
    if (g_engine) g_engine->setTunerEnabled(enabled == JNI_TRUE);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_openamp_AudioEngine_nativeGetTunerNote(JNIEnv* env, jobject) {
    std::string note = g_engine ? g_engine->getTunerNote() : "--";
    return env->NewStringUTF(note.c_str());
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_openamp_AudioEngine_nativeGetTunerCents(JNIEnv*, jobject) {
    return g_engine ? g_engine->getTunerCents() : 0.0f;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_openamp_AudioEngine_nativeGetTunerValid(JNIEnv*, jobject) {
    return g_engine && g_engine->getTunerValid() ? JNI_TRUE : JNI_FALSE;
}
```

**Fix — Kotlin bindings:**

```kotlin
// AudioEngine.kt
external fun nativeSetTunerEnabled(enabled: Boolean)
external fun nativeGetTunerEnabled(): Boolean
external fun nativeGetTunerNote(): String
external fun nativeGetTunerCents(): Float
external fun nativeGetTunerValid(): Boolean
```

**Fix — UI integration in meter loop:**

```kotlin
// MainActivity.kt — replace hardcoded call with real data
if (audioEngine.nativeGetTunerEnabled()) {
    val note = audioEngine.nativeGetTunerNote()     // e.g. "E2", "A2"
    val cents = audioEngine.nativeGetTunerCents()   // -50 to +50
    val valid = audioEngine.nativeGetTunerValid()   // confidence check
    neonTunerDisplay.setNote(note, cents, valid)
}
```

**Fix — Add to CMakeLists.txt:**

```cmake
add_library(openamp-native SHARED
    // ... existing sources ...
    ${DSP_CORE_DIR}/plugins/tuner/tuner.cpp
)

target_include_directories(openamp-native
    PRIVATE
        ${DSP_CORE_DIR}/plugins/tuner
)
```

**Key insight:** The `Tuner::process()` method uses autocorrelation on a 2048-sample circular buffer. It needs the RAW input (before gain staging or effects) for accurate pitch detection. Run it in `onAudioReady()` after reading input but before the DSP chain. The `Tuner` plugin's `setMute(false)` ensures it analyzes without silencing the audio path.

## Oboe API Compatibility (1.9.0)

### Problem: `setDataCallback(this)` / `setErrorCallback(this)` fails to compile

**Symptom:** Build errors: `no matching member function for call to 'setDataCallback'` / `'setErrorCallback'`.

**Root cause:** Oboe 1.9.0 changed the callback API. `AudioStreamCallback` still exists but `setDataCallback()` and `setErrorCallback()` now require `AudioStreamDataCallback*` and `AudioStreamErrorCallback*` respectively. The old unified `setCallback(AudioStreamCallback*)` still works.

**Fix — Use `setCallback(this)` for both streams:**

```cpp
// CORRECT for Oboe 1.9.0
outputBuilder_.setDirection(oboe::Direction::Output)
    ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
    ->setCallback(this)   // <-- use setCallback, not setDataCallback+setErrorCallback
    ->setBufferCapacityInFrames(128);

inputBuilder_.setDirection(oboe::Direction::Input)
    ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
    ->setCallback(this)   // <-- same for input
    ->setBufferCapacityInFrames(128);
```

The `AudioEngine` class should inherit from `oboe::AudioStreamCallback` (which itself inherits from both `AudioStreamDataCallback` and `AudioStreamErrorCallback`):

```cpp
class AudioEngine : public oboe::AudioStreamCallback {
    // onAudioReady() and onErrorBeforeClose()/onErrorAfterClose() 
};
```

**Pitfall:** Do NOT inherit from `AudioStreamDataCallback` and `AudioStreamErrorCallback` separately — `AudioStreamCallback` already does this. Using the separate classes causes type mismatch errors because `setCallback()` expects `AudioStreamCallback*`.

## Wiring Missing Effects (Phase 4 Pattern)

### Problem: Cabinet, Acoustic Sim, Harmonizer declared but not instantiated or processed

**Symptom:** Effects are declared in header, JNI bindings exist, but audio never changes when enabled.

**Root cause:** Raw pointers exist (`CabinetSimulator* cabinet_`) but no `unique_ptr` owner creates the object. Even if created, the `onAudioReady()` callback doesn't call `process()` on them.

**Fix — Add unique_ptr owners + wire into audio callback:**

```cpp
// AudioEngine.h — add unique_ptr owners alongside raw pointers
class AudioEngine {
private:
    // Raw pointers for quick access
    openamp::Modulation* modulation_ = nullptr;
    openamp::CabinetSimulator* cabinet_ = nullptr;
    openamp::AcousticSimulator* acousticSim_ = nullptr;
    openamp::Harmonizer* harmonizer_ = nullptr;
    
    // Owners (keep objects alive)
    std::unique_ptr<openamp::Modulation> modulationOwner_;
    std::unique_ptr<openamp::CabinetSimulator> cabinetOwner_;
    std::unique_ptr<openamp::AcousticSimulator> acousticSimOwner_;
    std::unique_ptr<openamp::Harmonizer> harmonizerOwner_;
};
```

```cpp
// Constructor — create and prepare each effect
AudioEngine::AudioEngine() {
    // ... existing modules ...
    
    modulationOwner_ = std::make_unique<openamp::Modulation>();
    if (modulationOwner_) {
        modulationOwner_->prepare(config_.sampleRate, config_.bufferSize);
        modulationOwner_->setBypass(!modulationEnabled_);
        modulation_ = modulationOwner_.get();
    }
    
    cabinetOwner_ = std::make_unique<openamp::CabinetSimulator>();
    if (cabinetOwner_) {
        cabinetOwner_->prepare(config_.sampleRate, config_.bufferSize);
        cabinetOwner_->setMix(cabinetMix_);
        cabinet_ = cabinetOwner_.get();
    }
    
    acousticSimOwner_ = std::make_unique<openamp::AcousticSimulator>();
    if (acousticSimOwner_) {
        acousticSimOwner_->prepare(config_.sampleRate, config_.bufferSize);
        acousticSimOwner_->setAmount(acousticAmount_);
        acousticSim_ = acousticSimOwner_.get();
    }
    
    harmonizerOwner_ = std::make_unique<openamp::Harmonizer>();
    if (harmonizerOwner_) {
        harmonizerOwner_->prepare(config_.sampleRate, config_.bufferSize);
        harmonizerOwner_->setMix(harmonizerMix_);
        harmonizer_ = harmonizerOwner_.get();
    }
}
```

```cpp
// onAudioReady — process effects in correct signal chain order
oboe::DataCallbackResult AudioEngine::onAudioReady(
    oboe::AudioStream* stream, void* audioData, int32_t numFrames) {
    
    // ... read input, process through InputProcessor ...
    
    // Post-amp effects (in order)
    if (irEnabled_ && irLoader_ && irLoader_->isIRLoaded()) {
        irLoader_->process(buffer);
    }
    
    if (cabinetEnabled_ && cabinet_) {
        cabinet_->process(buffer);
    }
    
    if (modulationEnabled_ && modulation_ && !modulation_->isBypassed()) {
        modulation_->process(buffer);
    }
    
    if (acousticSimEnabled_ && acousticSim_) {
        acousticSim_->process(buffer);
    }
    
    if (harmonizerEnabled_ && harmonizer_) {
        harmonizer_->process(buffer);
    }
    
    // ... looper, metronome, output ...
}
```

**Fix — Re-prepare on sample rate change:**

When `openStreams()` discovers the actual sample rate (often different from the 48kHz default), re-prepare ALL effects:

```cpp
bool AudioEngine::openStreams() {
    // ... open output stream, get actual sampleRate ...
    
    if (processor_) {
        processor_->initialize(config_);
        
        if (irLoader_) irLoader_->prepare(config_.sampleRate, config_.bufferSize);
        if (modulationOwner_) modulationOwner_->prepare(config_.sampleRate, config_.bufferSize);
        if (cabinetOwner_) cabinetOwner_->prepare(config_.sampleRate, config_.bufferSize);
        if (acousticSimOwner_) acousticSimOwner_->prepare(config_.sampleRate, config_.bufferSize);
        if (harmonizerOwner_) harmonizerOwner_->prepare(config_.sampleRate, config_.bufferSize);
    }
}
```

**Fix — Implement all stubbed getter/setter methods:**

```cpp
void AudioEngine::setCabinetEnabled(bool enabled) { cabinetEnabled_ = enabled; }
void AudioEngine::setCabinetType(int type) {
    cabinetType_ = type;
    if (cabinet_) cabinet_->setCabinetType(static_cast<CabinetSimulator::CabinetType>(type));
}
void AudioEngine::setCabinetMix(float amount) {
    cabinetMix_ = amount;
    if (cabinet_) cabinet_->setMix(amount);
}
bool AudioEngine::getCabinetEnabled() const { return cabinetEnabled_; }
int AudioEngine::getCabinetType() const { return cabinetType_; }
float AudioEngine::getCabinetMix() const { return cabinetMix_; }
```

**Fix — Add missing member variables to header:**

```cpp
// AudioEngine.h — parameter storage
int modulationType_ = 0;
float modulationRate_ = 1.5f;
float modulationDepth_ = 0.5f;
float modulationMix_ = 0.5f;
int cabinetType_ = 0;
float cabinetMix_ = 1.0f;
float acousticAmount_ = 0.5f;
float acousticBodySize_ = 0.5f;
float acousticBrightness_ = 0.5f;
int harmonizerMode_ = 0;
float harmonizerMix_ = 0.5f;
```

### Preset Serialization for New Effects

When adding new effects, extend the Preset struct AND the save/load logic AND the applyPreset method:

```cpp
// preset_store.h
struct Preset {
    // ... existing fields ...
    
    // Modulation
    bool modulationEnabled = false;
    int modulationType = 0;
    float modulationRate = 1.5f;
    float modulationDepth = 0.5f;
    float modulationMix = 0.5f;
    
    // Cabinet
    bool cabinetEnabled = true;
    int cabinetType = 0;
    float cabinetMix = 1.0f;
    
    // Acoustic Sim
    bool acousticSimEnabled = false;
    float acousticAmount = 0.5f;
    float acousticBodySize = 0.5f;
    float acousticBrightness = 0.5f;
    
    // Harmonizer
    bool harmonizerEnabled = false;
    int harmonizerMode = 0;
    float harmonizerMix = 0.5f;
};
```

```cpp
// preset_store.cpp — save
file << "modulationEnabled=" << (preset.modulationEnabled ? "1" : "0") << "\n";
file << "modulationType=" << preset.modulationType << "\n";
// ... etc for all new fields ...

// preset_store.cpp — load
else if (key == "modulationEnabled") preset.modulationEnabled = parseBool(value);
else if (key == "modulationType") preset.modulationType = std::stoi(value);
// ... etc ...
```

```cpp
// AudioEngine.cpp — applyPreset
setModulationEnabled(preset.modulationEnabled);
setModulationType(preset.modulationType);
setModulationRate(preset.modulationRate);
setModulationDepth(preset.modulationDepth);
setModulationMix(preset.modulationMix);
setCabinetEnabled(preset.cabinetEnabled);
setCabinetType(preset.cabinetType);
setCabinetMix(preset.cabinetMix);
// ... etc for all new effects ...
```

## Oboe Dependency Setup

### Problem: Build fails with "oboe/CMakeLists.txt not found"

**Symptom:** `./gradlew assembleDebug` fails with `expected buildFiles file '/path/to/third_party/oboe/CMakeLists.txt' to exist`.

**Root cause:** The `third_party/oboe/` directory is empty (created as placeholder but never populated).

**Fix — Clone Oboe into third_party:**

```bash
cd /path/to/project/third_party
rm -rf oboe  # remove empty placeholder
git clone --depth 1 --branch 1.9.0 https://github.com/google/oboe.git
```

The Android `CMakeLists.txt` references Oboe via:
```cmake
if(DEFINED OBOE_DIR)
    add_subdirectory(${OBOE_DIR} "${CMAKE_BINARY_DIR}/oboe")
    target_link_libraries(openamp-native PRIVATE oboe)
else()
    message(FATAL_ERROR "OBOE_DIR not set. Provide the path to Oboe.")
endif()
```

And `build.gradle` passes it:
```gradle
externalNativeBuild {
    cmake {
        arguments '-DANDROID_STL=c++_shared'
        def oboeDir = project.findProperty('OBOE_DIR') as String
        if (oboeDir) {
            arguments "-DOBOE_DIR=${oboeDir}"
        }
    }
}
```

If `OBOE_DIR` is not set as a Gradle property, the build falls back to looking in `third_party/oboe/`. Ensure this directory is populated before building.

## Cabinet Simulation

### Problem: Thin, fizzy tone even with amp cranked

**Symptom:** Sounds like a preamp direct out, not a real amp.

**Root cause:** Cabinet IR is empty or not loaded. The amp simulator's `cabIR_` vector is size 0, so the convolution loop is skipped.

**Fix — Load a default IR or enable fallback filter:**

```cpp
// In amp simulator, if no IR loaded, use a simple lowpass as fallback
void AmpSimulator::process(AudioBuffer& buffer) {
    // ... preamp, tone stack, power amp ...
    
    for (uint32_t i = 0; i < buffer.numFrames; ++i) {
        float sample = channelData[i];
        
        if (!cabIR_.empty()) {
            // Full convolution
            cabHistory_[cabIndex_] = sample;
            float acc = 0.0f;
            size_t idx = cabIndex_;
            for (size_t k = 0; k < cabIR_.size(); ++k) {
                acc += cabIR_[k] * cabHistory_[idx];
                idx = (idx == 0) ? (cabIR_.size() - 1) : (idx - 1);
            }
            cabIndex_ = (cabIndex_ + 1) % cabIR_.size();
            channelData[i] = acc;
        } else {
            // Fallback: simple cab-like filtering
            float hp = sample - cabHighPass_.process(sample);
            channelData[i] = cabLowPass_.process(hp);
        }
    }
}
```

## Modulation Effects (Chorus/Flanger/Phaser)

### Problem: Modulation knobs do nothing

**Symptom:** Rate/depth/mix knobs turn but no chorus/flanger effect.

**Root cause:** `AudioEngine.h` declares `Modulation* modulation_` but constructor never creates it. JNI methods call `modulation_->setRate()` on null pointer (silent failure because of `if (modulation_)` guard).

**Fix — Instantiate in constructor:**

```cpp
AudioEngine::AudioEngine() {
    // ... other modules ...
    
    auto modulation = std::make_unique<Modulation>();
    if (modulation) {
        modulation->prepare(sampleRate, bufferSize);
        modulation->setType(Modulation::Type::Chorus);
        modulation->setRate(1.5f);
        modulation->setDepth(0.5f);
        modulation->setMix(0.5f);
        modulation_ = modulation.get();
        effectChain_->addEffect(std::move(modulation));
    }
}
```

## Preset Serialization

### Problem: Preset loads but sounds different from when saved

**Symptom:** Save preset, reload, tone is off — some parameters reset to defaults.

**Root cause:** Preset struct is missing fields that were added after initial design, OR `applyPreset()` doesn't set all parameters.

**Fix — Audit preset struct and apply method:**

```cpp
struct Preset {
    std::string name;
    
    // Input/output
    float inputGainDb = 0.0f;
    float outputGainDb = 0.0f;
    
    // Amp
    bool ampEnabled = true;
    float ampGainDb = 0.0f;
    float ampDrive = 0.5f;
    float ampBassDb = 0.0f;
    float ampMidDb = 0.0f;
    float ampTrebleDb = 0.0f;
    float ampPresenceDb = 0.0f;
    float ampMasterDb = 0.0f;
    
    // Effects
    bool noiseGateEnabled = true;
    float noiseGateThreshold = -45.0f;
    float noiseGateAttack = 1.0f;
    float noiseGateRelease = 100.0f;
    
    bool compressorEnabled = false;
    float compressorThreshold = -20.0f;
    float compressorRatio = 4.0f;
    
    bool eqEnabled = false;
    std::array<float, 10> eqBands{};
    
    bool distortionEnabled = false;
    int distortionType = 0;
    float distortionDrive = 0.5f;
    float distortionTone = 0.5f;
    float distortionLevel = 0.7f;
    
    bool delayEnabled = true;
    float delayTimeMs = 350.0f;
    float delayFeedback = 0.35f;
    float delayMix = 0.25f;
    bool delayFirst = true;
    
    bool reverbEnabled = true;
    float reverbRoom = 0.5f;
    float reverbDamp = 0.3f;
    float reverbMix = 0.25f;
    
    // IR
    std::string irPath;
    bool irEnabled = false;
    float irMix = 1.0f;
    
    // Modulation
    bool modulationEnabled = false;
    int modulationType = 0;
    float modulationRate = 1.5f;
    float modulationDepth = 0.5f;
    float modulationMix = 0.5f;
};
```

## Input Gain Staging

### Problem: Signal too quiet or clipping

**Symptom:** Have to crank master to hear anything, OR constant clipping light.

**Root cause:** Guitar pickups output instrument-level signal (~-20dBu to -40dBu). Mobile ADCs expect line-level (~0dBu). Without input gain, the signal is too low. With too much, it clips.

**Fix — Add input gain control (0 to +48dB):**

```cpp
// Default: +36dB for passive guitar pickups
processor_->setInputGain(36.0f);

// For active pickups or line-level sources, reduce:
processor_->setInputGain(12.0f);

// UI knob range: -24dB to +24dB (relative to default)
// Or absolute: 0dB to +48dB
```

## Version Consistency

### Problem: App shows wrong version number

**Symptom:** About dialog says v1.0.0 but APK is v2.0.0.

**Root cause:** Version string hardcoded in multiple places (build.gradle, CMakeLists.txt, main.cpp, about dialog).

**Fix — Single source of truth:**

```cpp
// In a header file
#define OPENAMP_VERSION_MAJOR 2
#define OPENAMP_VERSION_MINOR 0
#define OPENAMP_VERSION_PATCH 0
#define OPENAMP_VERSION_STRING "2.0.0"
```

Or generate from git tag at build time:

```cmake
// CMakeLists.txt
execute_process(
    COMMAND git describe --tags --always
    OUTPUT_VARIABLE GIT_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
add_compile_definitions(OPENAMP_VERSION="${GIT_VERSION}")
```
