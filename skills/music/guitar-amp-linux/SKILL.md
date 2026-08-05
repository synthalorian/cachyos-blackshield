---
name: guitar-amp-linux
description: >
  Linux guitar amplifier toolchain: audio interfaces, amp sim plugins, JACK/PipeWire routing,
  LV2/CLAP/VST hosts, impulse response cab simulation, low-latency monitoring, and audio
  backend design for cross-platform guitar-amp-app projects. Triggers: guitar, amp, amplifier,
  audio interface, JACK, PipeWire, LV2, VST host, plugin host, cab sim, IR loader,
  guitarix, pedal, DI box, monitoring, latency, guitar-amp-app, pro-audio on Linux.
tags: [music, linux, audio, guitar, plugins]
---

# Guitar Amp on Linux — Toolchain & Workflow

Research, configure, and maintain guitar amplifier toolchains on Linux (Arch/Omarchy/Hyprland),
covering audio interfaces, amp sim plugins, plugin hosts, JACK/PipeWire routing, cab simulation,
and cross-platform app backend design.

## When This Skill Applies

- User asks about guitar amp software on Linux
- User wants to route guitar → amp sim → speakers with low latency
- User is building a cross-platform guitar amp app and needs Linux audio backend advice
- User asks about audio interfaces, JACK, PipeWire, LV2 plugins, VST hosts
- User needs help with guitar signal flow, cab simulation, or impulse responses

## Linux Audio Backend Stack

### Core Components

| Layer | Package | Purpose |
|-------|---------|---------|
| **PipeWire** | `pipewire` (extra) | Low-latency audio server (default on Arch/Omarchy) |
| **JACK Compat** | `pipewire-jack` (extra) | JACK API compatibility — no legacy JACK needed |
| **Patchbay** | `helvum` (extra) | GTK patchbay for PipeWire routing (visual cables) |
| **Plugin Host** | `carla` (extra) | Full VST/LV2/CLAP/LADSPA host |
| **Amp Sim** | `guitarix` (extra) | Standalone amp chain + LV2 plugins |
| **AI Amp** | `aida-x` (extra) | Deep learning amp model player |
| **Plugin Bridge** | `yabridge-bin` (AUR) | Bridge Windows VST2/VST3 via Wine |

### Installation

```bash
# Essential stack
sudo pacman -S pipewire-jack helvum carla guitarix gxplugins.lv2

# Optional: Windows VST bridge, AI amp, DAW
sudo pacman -S yabridge-bin aida-x ardour

# Enable JACK compatibility (PipeWire provides this)
systemctl --user enable --now pipewire-jack.service
```

### Routing Workflow

```
Guitar → DI Box → Audio Interface → PipeWire → Amp Sim → Speakers/Headphones
```

Use `helvum` to visually route: audio interface input node → amp sim input → speaker output.

## Amp Sim Plugins (Ranked)

### Tier 1: Full Amp Chains

| Tool | Type | Real-time | Notes | Install |
|------|------|-----------|-------|---------|
| **Guitarix** | Standalone + LV2 | ✅ | Preamp, cab sim, wah, phaser, chorus, reverb, delay, compressor, looper. Most complete. | `guitarix` (extra) |
| **AIDA-X** | Standalone + LV2/VST/CLAP | ✅ | AI/deep learning amp models. Clean/edge/crunch/metal voices. State-of-the-art quality. | `aida-x` (extra) |
| **ToneLib GrandMagus** | Standalone VST3 | ✅ | Metal-focused amp suite. Granular distortion, multi-band cab sim. | `tonelib-grandmagus-bin` (AUR) |

### Tier 2: Focused Plugins

| Tool | Type | Real-time | Notes | Install |
|------|------|-----------|-------|---------|
| **KPP** | LV2/LADSPA | ✅ | Tube amp + cab model (Faust + Zita convolver). Kapitonov's pack. | `kpp` (AUR) |
| **KlonCentaur** | LV2 | ✅ | Klon Centaur pedal emulation | `kloncentaur-git` (AUR) |
| **RVXX Amp** | VST | ✅ | Aggressive guitar amplifier | `rvxx-amp-vst` (AUR) |

### Tier 3: Offline/Circuit Simulation

| Tool | Type | Real-time | Notes | Install |
|------|------|-----------|-------|---------|
| **SpiceAmp** | Qt standalone | ❌ | ngspice circuit simulation. Ultra-realistic but NOT real-time. Batch processing only. | `spiceamp-git` (AUR) |

## Audio Interface Recommendations

### Budget ($50-100)
- **Behringer U-Phoria UM2** — USB-C, 2 in/2 out, 24-bit/192kHz. Class Compliant.
- **Focusrite Scarlett 2i2** (3rd gen) — USB-C, gold standard for a reason.

### Mid-range ($100-200)
- **Motu M2** — 2 in/4 out, exceptional clocking, lowest latency.
- **UA Volt 2** — Built-in 500-series preamp, great for guitar.

### Pro ($200+)
- **RME Babyface** — Legendary on Linux. Best-in-class drivers and latency.
- **Focusrite Clarett+** — Thunderbolt/USB, ultra-low latency.

### ⚠️ Pitfall: Generic USB Audio Codecs

The **PCM2900C** (BurrBrown) and similar generic USB audio dongles are **not suitable for guitar monitoring**:
- High latency (~5-15ms round-trip vs ~1-3ms on dedicated interfaces)
- Poor noise floor (hiss/buzz from cheap ADCs)
- No instrument-level input (no hi-Z input, requires DI box anyway)
- No direct monitoring option (always goes through CPU)

If the user has only a PCM2900C or similar dongle, recommend upgrading to a proper audio interface.

## Cross-Platform App Backend Design

For `guitar-amp-app` (C++ Qt desktop, SwiftUI iOS, Kotlin Android):

### Architecture

```
┌─────────────────────────────────────┐
│         Core Engine (C++)           │
│  Amp modeling · EQ · Distortion     │
│  Cab sim (convolution IR) · Reverb  │
│  Delay · Chorus · Compressor        │
└──────────┬────────────────┬─────────┘
           │                │
   ┌───────┴──────┐  ┌─────┴────────┐
   │ LV2 Plugin   │  │ iOS AUnit    │
   │ Android APK  │  │ Android NDK  │
   └──────────────┘  └──────────────┘
```

### Signal Chain

```
Instrument Input → DI Buffer (hi-Z) → Gain Stage → EQ → Distortion
  → Cab Convolution (IR) → Reverb → Delay → Output
```

### Audio Backend Abstraction

Use `PortAudio` as the cross-platform audio layer. Wraps:
- ALSA/PipeWire on Linux
- CoreAudio on macOS/iOS  
- AudioTrack/AudioRecord on Android

### Key Libraries

| Library | Purpose | Cross-platform? |
|---------|---------|----------------|
| **libsndfile** | Read/write WAV/IR files | ✅ Yes |
| **FFTW** | FFT for convolution | ✅ Yes |
| **zita-resampler** | High-quality sample rate conversion | ❌ Linux only |
| **custom C++ convolution** | Cab sim engine | ✅ Write yourself |

### Plugin Formats

| Platform | Format | Notes |
|----------|--------|-------|
| Linux | LV2 (primary) | Native Linux, mature C API |
| Linux | CLAP (secondary) | Emerging standard, libclap available |
| Linux | VST2/VST3 | Via yabridge wrapper |
| macOS/iOS | AudioUnit (CoreAudio) | Native Apple format |
| Android | Native C++ (NDK) or AudioPlugin | NDK preferred for performance |

## Impulse Response (Cab Sim)

### Loading IRs

- **Guitarix**: Built-in IR loader in cab module. Accepts mono/stereo WAV files.
- **Carla**: Can load IRs as simple LV2 plugins.
- **Custom C++**: Use `libsndfile` to read WAV + FFTW for real-time FFT convolution.

### IR Sources

Free IR packs: Celestion, Eminence, OwnHammer, ML Sound Lab (some free).
Format: mono or stereo WAV, sample rate matching audio stream (48kHz recommended).

### Reference Files

| File | Contents |
|------|----------|
| `references/arch-linux-toolchain.md` | Session-specific reference for synth's Omarchy system: installed packages, audio devices, hardware assessment, commands |

## Development Workflow

### Testing Amp Engine on Linux

```bash
# 1. Install stack
sudo pacman -S pipewire-jack helvum carla guitarix

# 2. Enable JACK compat
systemctl --user enable --now pipewire-jack.service

# 3. Connect audio interface (if any)
# Check available devices
pactl list short sinks
pactl list short sources

# 4. Launch helvum for routing
helvum

# 5. Launch amp sim
guitarix

# 6. Or use Carla as plugin host
carla
```

### For Your App Development

1. Build core amp engine as a **static C++ library** (no dependencies)
2. Create an **LV2 plugin wrapper** for Linux testing
3. Test in Guitarix standalone and Carla host
4. Port to iOS as AudioUnit
5. Port to Android as native library or AudioPlugin APK
6. Qt desktop app hosts the core engine directly (not via plugins)

## Troubleshooting

### No audio through amp sim
- Check `pactl list short sinks` to verify output device
- Launch `helvum` and confirm routing: interface → amp → output
- Ensure `pipewire-jack.service` is active: `systemctl --user status pipewire-jack`

### High latency (>20ms)
- Use a dedicated audio interface (PCM2900C is not suitable)
- Lower PipeWire buffer: `pw-cli` or edit `~/.config/pipewire/pipewire.conf.d/`
- Set `default-fragments = 2` and `default-fragment-size-msec = 1` in pipewire config

### Plugin not loading
- Check plugin format: `lv2scan` for LV2, `carla` auto-scans
- For VST plugins: need `yabridge-bin` + Wine
- Verify LV2 path: `pkg-config --variable=lv2dir lv2` (usually `/usr/lib/lv2`)

## Cross-Platform Mobile Amp App Architecture

When building a guitar amp app that targets Android (primary) + iOS + Linux desktop, use a shared C++ DSP core with platform-specific audio backends.

### Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Shared C++ DSP Core                       │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │NoiseGate│ │Compressor│ │   EQ    │ │Distortion│          │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘          │
│       └─────────────┴─────────────┴─────────┘               │
│                         │                                    │
│                    ┌────┴────┐                               │
│                    │ Amp Sim │                               │
│                    │Preamp+PA│                               │
│                    └────┬────┘                               │
│       ┌─────────────────┼─────────────────┐                 │
│  ┌────┴────┐      ┌────┴────┐      ┌────┴────┐             │
│  │ IR Cab  │      │ Delay   │      │ Reverb  │             │
│  │Loader   │      │         │      │         │             │
│  └─────────┘      └─────────┘      └─────────┘             │
└─────────────────────────┬───────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────┴────┐      ┌────┴────┐      ┌────┴────┐
   │ Android │      │  iOS    │      │  Linux  │
   │  Oboe   │      │AVAudioEngine│   │PipeWire/│
   │         │      │         │      │  ALSA   │
   └─────────┘      └─────────┘      └─────────┘
```

### Android Audio Backend (Oboe)

**Critical pattern for duplex audio:**

Use a **single output stream callback** with a **blocking read** from the input stream. Do NOT use `read()` with timeout=0 in the callback — this causes `ErrorTimeout` and dropouts.

```cpp
// CORRECT: blocking read in output callback
oboe::DataCallbackResult onAudioReady(
    oboe::AudioStream* stream, void* audioData, int32_t numFrames) {
    
    float* output = static_cast<float*>(audioData);
    int32_t framesRead = 0;
    
    if (inputStream_) {
        // Use a reasonable timeout (e.g., 2x expected buffer duration)
        auto result = inputStream_->read(
            inputBuffer_.data(), numFrames, 
            numFrames * 2 * 1'000'000'000 / sampleRate_);
        if (result) framesRead = result.value();
    }
    
    // Process framesRead frames through DSP chain
    // Fill remaining with silence if underrun
    for (int32_t i = framesRead; i < numFrames; ++i) {
        inputBuffer_[i] = 0.0f;
    }
    
    dspEngine_->process(inputBuffer_.data(), output, numFrames);
    return oboe::DataCallbackResult::Continue;
}
```

**Better: lock-free ring buffer** (smoother, handles jitter):
- Write input frames to ring buffer after blocking read
- Read exactly `numFrames` from ring buffer for processing
- Zero-fill on underrun instead of glitching

```cpp
// In onAudioReady():
writeToRing(inputBuffer_.data(), numFrames);
size_t ringFramesRead = readFromRing(inputBuffer_.data(), numFrames);
if (ringFramesRead < numFrames) {
    for (size_t i = ringFramesRead; i < numFrames; ++i) {
        inputBuffer_[i] = 0.0f;  // graceful underrun
    }
}
```

See `references/mobile-amp-pitfalls.md` for full ring buffer implementation.

**Oboe Dependency Setup:**

If `third_party/oboe/` is empty, the build fails with `oboe/CMakeLists.txt not found`.

```bash
cd third_party
rm -rf oboe
git clone --depth 1 --branch 1.9.0 https://github.com/google/oboe.git
```

Then rebuild: `./gradlew assembleDebug`

### Common Mobile Amp App Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| **Non-blocking input read** | Stuttering, silence, `ErrorTimeout` spam | Use blocking read with timeout, or ring buffer |
| **Effect chain not wired** | Only clean guitar sound, no amp/effects | Ensure all DSP modules are instantiated AND added to processing chain |
| **Missing cabinet sim** | Thin, fizzy tone | Load default IR or enable built-in cab filter. Empty IR = no cab |
| **Hardcoded tuner** | Tuner always shows "E" | Wire tuner plugin to analyze input buffer, return frequency to UI |
| **Modulation stubs** | Chorus/flanger knobs do nothing | Actually instantiate Modulation object in engine constructor |
| **Wrong effect order** | Muddy tone, noise gate ineffective | Gate → Compressor → EQ → Distortion → Amp → Cab → Delay → Reverb |
| **No input gain staging** | Clipping or too quiet | Add input gain knob (0-48dB) before DSP chain for instrument-level signals |
| **Preset save without DSP state** | Preset loads but sounds different | Serialize ALL parameters including hidden defaults |
| **Effects declared but not wired** | Cabinet/modulation/harmonizer do nothing | Add `unique_ptr` owners, instantiate in constructor, call `process()` in `onAudioReady()` |
| **Oboe `read()` timeout=0** | Stuttering, silence, `ErrorTimeout` spam in logs | Use blocking read with calculated timeout (2x buffer duration), or ring buffer |
| **No ring buffer** | Dropouts when input/output callbacks drift | Add lock-free ring buffer between input read and DSP processing |
| **Preset save without DSP state** | Preset loads but sounds different | Serialize ALL parameters including hidden defaults |

### Signal Chain Order (Critical for Tone)

```
Input Gain → Noise Gate → Compressor → EQ → Distortion → Amp Simulator
  → Cabinet IR → Modulation → Delay → Reverb → Acoustic Sim → Harmonizer
  → Output Limiter → Master Volume
```

### Reference Files

| File | Contents |
|------|----------|
| `references/arch-linux-toolchain.md` | Session-specific reference for synth's Omarchy system: installed packages, audio devices, hardware assessment, commands |
| `references/mobile-amp-pitfalls.md` | Detailed reproduction recipes and fixes for common mobile amp app bugs discovered in OpenAmp development |