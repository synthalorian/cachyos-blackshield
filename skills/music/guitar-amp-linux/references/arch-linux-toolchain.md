# Arch Linux / Omarchy Guitar Amp Toolchain

Session-specific reference for synth's Omarchy (Arch + Hyprland + PipeWire) system.

## System State (as of 2026-05-31)

- **OS**: Arch Linux (Omarchy) — kernel 7.0.9-arch2-1
- **Compositor**: Hyprland
- **Audio**: PipeWire with pipewire-jack, pipewire-alsa, pipewire-pulse
- **PipeWire services**: active (pipewire, wireplumber)
- **OpenAmp project**: `/home/synth/projects/openamp` — v2.0.0, C++ DSP core + Qt6 Linux + Kotlin Android + SwiftUI iOS

## OpenAmp Project Structure

```
openamp/
├── dsp-core/              # Shared C++ DSP engine (amp sim, effects, IR loader)
│   ├── include/openamp/   # Public headers
│   ├── src/               # Core implementation
│   └── plugins/           # 12 effect plugins
├── linux/                 # Qt 6 desktop app (PipeWire/ALSA/Jack)
├── android/               # Kotlin + Oboe + JNI
│   └── app/src/main/
│       ├── cpp/           # AudioEngine.cpp, JniBridge.cpp
│       ├── java/com/openamp/  # MainActivity.kt, AudioEngine.kt
│       └── res/layout/    # activity_main.xml
├── ios/                   # SwiftUI app
└── presets/factory/       # 100 factory presets
```

## OpenAmp Build Status

- **Linux**: Builds successfully. Binary at `linux/build/openamp`. Qt6 + PipeWire backend.
- **Android**: Builds with Gradle. APKs exist (`OpenAmp-v1.2.0-debug.apk`, etc.). Oboe audio engine.
- **iOS**: Scaffold exists, less complete.

## Resolved Issues (2026-05-31)

1. ✅ **Android audio callback uses non-blocking read** — Fixed with blocking read (2x buffer duration timeout) + lock-free ring buffer for input/output synchronization. See `mobile-amp-pitfalls.md`.
2. ✅ **Effect chain incomplete in Android** — Noise gate, compressor, EQ now wired into `InputProcessor::processInput()` signal chain. Default: noise gate ON, compressor OFF, EQ OFF.

## Remaining Known Issues

3. **Cabinet IR empty by default** — Amp simulator has `cabIR_` vector but no default IR loaded
4. **Tuner is hardcoded** — UI shows "E" always, not reading from tuner plugin
5. **Linux version string stale** — `main.cpp` shows 1.0.0 but project is at 2.0.0

## Installed Audio Packages

```
lv2
pipewire
pipewire-alsa
pipewire-audio
pipewire-jack
pipewire-pulse
portaudio
```

## Available Amp Sim Packages (Arch Extra)

| Package | Version | Description |
|---------|---------|-------------|
| `guitarix` | 0.47.0-4 | Mono guitar amp + FX (Faust-based). LV2 + JACK standalone. Includes cab sim, reverb, delay, phaser, chorus, flanger, distortion, wah, compressor, looper. |
| `guitarix-git` | 0.47.0.r40.gc2f32304-1 (AUR) | Latest git version. +11 contributors. |
| `guitarix.vst` | 0.5-1 (AUR) | VST3 plugin version of guitarix. |
| `aida-x` | 1.1.0-2 | AI-based amp model player. Provides LV2, VST2, VST3, CLAP, and standalone formats. |
| `carla` | 2.5.10-3 | Audio plugin host (LV2/VST2/VST3/LADSPA/DSSI). Qt5 GUI. |
| `helvum` | 0.5.1-1 | GTK4 patchbay for PipeWire. |
| `jconvolver` | 1.1.0-4 | Real-time convolution engine. |
| `aliki` | 0.3.0-4 | Impulse response measurement tool. |
| `ardour` | 9.2-3 | Professional DAW. LV2/VST2/VST3 support. |
| `ngspice` | 46-1 | Circuit simulator. |
| `zita-convolver` | 4.0.3-5 | Fast partitioned convolution engine library. |
| `zita-resampler` | 1.6.1-1 | High-quality sample rate converter. |

## Available Amp Sim Packages (AUR)

| Package | Version | Description |
|---------|---------|-------------|
| `tonelib-grandmagus-bin` | 1.0.0-1 | Full amp suite targeting metal. Standalone VST3. |
| `kpp` | 1.2.1-3 | Kapitonov Plugins Pack. Tube amp + cab model. LV2/LADSPA. |
| `kloncentaur-git` | v1.4.0.r4.gf3bb633-1 | Klon Centaur pedal emulation (LV2). |
| `chowkloncentaurmodel.lv2-git` | r136.f3bb633-1 | Klon Centaur model using RNNs and Wave Digital Filters. |
| `rvxx-amp-vst` | 2.0.0-2 (Orphaned) | RVXX Aggressive Guitar Amplifier. |
| `spiceamp-git` | 1.0.r0.g05cd6b7-3 | ngspice circuit simulation. Non-realtime only. Qt app. |
| `yabridge-bin` | 5.1.1-1 | Windows VST2/VST3 bridge via Wine. |
| `yabridge-git` | 5.0.2.r14.g399db4d2-1 | Same as bin, git version. |
| `yabridgectl-git` | 3.8.1.r73.g9420bade-1 | Management utility for yabridge. |
| `yabridge-tui` | 0.2.1-1 | Terminal UI for yabridge management. |

## Current Audio Devices (PipeWire)

```
Sinks:
  56  HDMI output (Navi 48) — 48kHz, s32le
  59  PCM2900C USB Codec — 48kHz, s16le (analog stereo)
  61  Logitech PRO X headset — 48kHz, s16le (analog stereo)
  64  HDMI output (HD-Audio Generic) — 48kHz, s32le
  66  HDMI output (HD-Audio Generic_1) — 48kHz, s32le

Sources:
  59  PCM2900C USB Codec monitor
  60  PCM2900C USB Codec input
  61  Logitech PRO X headset monitor
  62  Logitech PRO X headset mic (mono fallback)
  63  HyperX SoloCast mic (24bit)
  65  Webcam C920 mic
  67  HD-Audio Generic mic
```

## Hardware Assessment

**PCM2900C (BurrBrown USB Audio Codec):**
- Generic USB audio dongle chip
- 2-channel, 48kHz, s16le
- No dedicated instrument input
- High latency for monitoring (~5-15ms)
- Poor noise floor for guitar (cheap ADC)
- ⚠️ Not suitable for serious guitar work

**Logitech PRO X:**
- Gaming headset with mic
- Suitable for monitoring only
- Mono mic fallback has quality limitations

**Recommendation:** Purchase a dedicated USB audio interface (Focusrite Scarlett 2i2 or similar) for proper instrument input and low-latency monitoring.

## Reference Commands

```bash
# Enable JACK compatibility
systemctl --user enable --now pipewire-jack.service

# Check available audio devices
pactl list short sinks
pactl list short sources

# Launch helvum patchbay
helvum

# Launch Guitarix standalone
guitarix

# Launch Carla plugin host
carla

# Scan LV2 plugins
lv2scan

# Check PipeWire status
systemctl --user status pipewire wireplumber

# Check JACK compatibility
systemctl --user status pipewire-jack

# Get debug info (Omarchy)
omarchy debug --no-sudo --print
```
