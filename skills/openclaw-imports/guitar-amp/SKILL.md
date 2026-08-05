# Guitar Amp Development

Developing a cross-platform guitar amplifier and effects processor app.

## Project Location

`/home/synth/projects/guitar-amp-app`

## Platforms

| Platform | Audio Backend | UI Framework | Status |
|----------|--------------|--------------|--------|
| Linux | PipeWire / ALSA | Qt 6 | ✅ Building |
| Android | AAudio / Oboe | Kotlin + JNI | 🔄 Needs testing |
| iOS | AVAudioEngine | SwiftUI | 🔄 Needs testing |

## Building

### Linux
```bash
cd /home/synth/projects/guitar-amp-app/linux
./build.sh
# Executable: build/guitar-amp-linux
```

### DSP Core Only
```bash
cd /home/synth/projects/guitar-amp-app/dsp-core
mkdir build && cd build
cmake ..
make
```

## USB Audio Interface Setup

### Linux (PipeWire)
- PipeWire auto-detects USB interfaces
- Check devices: `pw-cli list-objects`
- Guitar Amp app creates "GuitarAmp Input" and "GuitarAmp Output" streams
- Use `pw-link` to connect interface to app if needed

### Linux (ALSA Fallback)
- Check devices: `arecord -l` (inputs), `aplay -l` (outputs)
- Configure in app settings
- Common device: `hw:1,0` for first USB interface

### Android
- USB Audio Class 2.0 devices supported on Android 12+
- Oboe handles device enumeration automatically
- May need OTG adapter for USB-C

### iOS
- Lightning/USB-C Camera Connection Kit required
- iOS handles USB audio automatically via AVAudioEngine
- Check `AVAudioSession.sharedInstance().availableInputs`

## DSP Architecture

```
Input (mono)
    ↓
[Noise Gate] → [Wah] → [Compressor] → [Distortion]
    ↓
[Amp Simulator: Gain → Drive → EQ → Presence → Master]
    ↓
[EQ] → [Modulation] → [Delay] → [Reverb]
    ↓
[Looper] → [Tuner (parallel)]
    ↓
Output (stereo)
```

## Effect Plugin Development

### Creating a New Plugin

1. Create directory: `dsp-core/plugins/myeffect/`
2. Implement `AudioProcessor` interface:

```cpp
#pragma once
#include "guitar_amp/plugin_interface.h"

class MyEffect : public guitar_amp::AudioProcessor {
public:
    void prepare(double sampleRate, uint32_t maxBlockSize) override;
    void process(guitar_amp::AudioBuffer& buffer) override;
    void reset() override;
    std::string getName() const override { return "MyEffect"; }
    std::string getVersion() const override { return "1.0.0"; }
};
```

3. Create CMakeLists.txt:
```cmake
add_library(myeffect_plugin SHARED myeffect.cpp myeffect_plugin.cpp)
target_include_directories(myeffect_plugin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../../include)
target_link_libraries(myeffect_plugin PRIVATE guitar-amp-dsp)
```

4. Add to `dsp-core/plugins/CMakeLists.txt`

## Preset Format

```
name=Preset Name
inputGainDb=0.0
outputGainDb=0.0
ampEnabled=1
effectsEnabled=1
delayEnabled=1
reverbEnabled=1
distortionEnabled=0
delayFirst=1
delayTimeMs=350.0
delayFeedback=0.35
delayMix=0.25
reverbRoom=0.5
reverbDamp=0.3
reverbMix=0.25
distortionDrive=0.5
distortionTone=0.5
distortionLevel=0.7
distortionType=0
ampGainDb=0.0
ampDrive=0.5
ampBassDb=0.0
ampMidDb=0.0
ampTrebleDb=0.0
ampPresenceDb=0.0
ampMasterDb=0.0
cabIrPath=
```

## Common Tasks

### Adding a Knob in UI
```cpp
auto* knob = new KnobWidget;
knob->setLabel("Drive");
knob->setValueSuffix("%");
knob->setMinValue(0);
knob->setMaxValue(100);
knob->setTheme(theme_);
connect(knob, &KnobWidget::valueChanged, [](float value) {
    engine->setDrive(value / 100.0f);
});
```

### Testing Audio Latency
```bash
# Linux PipeWire
pw-top  # Show real-time latency

# Check buffer size in app settings
# 256 samples @ 48kHz = ~5.3ms
```

### Debugging DSP
- Add debug output: `std::cout << "Sample: " << sample << std::endl;`
- Use meters to visualize levels
- Test with simple sine wave input

## Reference: Guitarix

Guitarix is a Linux guitar amplifier application using:
- JACK/PipeWire for audio
- LV2 plugin format
- Faust DSP language
- GTK UI

Key differences in our app:
- Cross-platform (not just Linux)
- Simpler plugin system (shared libraries)
- Qt/SwiftUI/Kotlin UIs
- Mobile-first design

## Key Files

| File | Purpose |
|------|---------|
| `dsp-core/include/guitar_amp/dsp_engine.h` | Main DSP engine class |
| `dsp-core/include/guitar_amp/plugin_interface.h` | Plugin base class |
| `linux/src/audio/pipewire_backend.cpp` | Linux audio |
| `linux/src/ui/main_window.cpp` | Main UI |
| `presets/factory/*.preset` | Factory presets (100 total) |

## Troubleshooting

### No Audio on Linux
1. Check PipeWire is running: `systemctl --user status pipewire`
2. Check device permissions: `groups` (should include 'audio')
3. Try ALSA backend in app settings

### High Latency
1. Reduce buffer size in settings (try 128 or 64)
2. Close other audio apps
3. Use PipeWire instead of ALSA
4. Check for CPU throttling

### Distortion Sounds Bad
- Check gain staging (input should be around -12dB)
- Try different distortion types
- Adjust tone control
- Add some compression before distortion

### Build Errors
```bash
# Clean rebuild
rm -rf build && mkdir build && cd build
cmake .. && make -j$(nproc)
```
