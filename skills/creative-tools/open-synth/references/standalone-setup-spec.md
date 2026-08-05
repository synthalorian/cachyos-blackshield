# OpenSynth Standalone Setup System

## Overview

OpenSynth has its own setup and configuration pipeline — completely independent from Hermes Agent, OpenShark, and any other AI harness. The setup wizard runs during first install and can be re-run anytime.

## CLI Commands

```bash
opensynth setup              # Interactive setup wizard
opensynth doctor             # Check dependencies and config health
opensynth config             # View current config
opensynth config edit        # Open config in $EDITOR
opensynth config set KEY VAL # Set a config value
opensynth config path        # Print config file path
```

## Setup Flow

```
1. DETECT  → 2. INSTALL DEPS (if needed)  → 3. AUTO-CONFIGURE  → 4. TEST  → 5. DONE
```

### Step 1 — Detect
- Check Flutter SDK installation and version
- Check native build toolchain (CMake, C++ compiler)
- Check PortAudio (desktop) or Android NDK (mobile)
- Check for existing OpenSynth config at `~/.config/opensynth/`
- **Do NOT** detect or interact with Hermes, OpenClaw, or OpenShark

### Step 2 — Install Dependencies
- Flutter SDK (if missing, prompt for install path)
- PortAudio development headers (`portaudio` on Arch, `libportaudio2-dev` on Debian)
- CMake 3.22+
- Android SDK + NDK (if mobile build selected)

### Step 3 — Auto-Configure
- Write `~/.config/opensynth/config.yaml` with defaults:
  - Audio backend preference (PortAudio/Oboe/auto)
  - Default sample rate (48000)
  - Default buffer size (256 samples)
  - UI theme (synthwave/default)
  - MIDI input device (auto-detect)
- Create `~/.local/share/opensynth/` for presets, wavetables, recordings
- Create `.desktop` entry for app launchers

### Step 4 — Test
- Verify native library builds successfully
- Run audio probe (detect available audio devices)
- Test MIDI device enumeration (if available)

### Step 5 — Done
- Print summary of configured settings
- Show quick-start commands
- Offer to launch the app

## Config File (`~/.config/opensynth/config.yaml`)

```yaml
audio:
  backend: auto              # portaudio | oboe | auto
  sample_rate: 48000
  buffer_size: 256
  device_index: null         # null = default device
  input_device_index: null   # for MIDI/audio input

ui:
  theme: synthwave           # synthwave | dark | light
  show_spectrum: true
  show_oscilloscope: true
  keyboard_size: medium      # small | medium | large
  default_octave: 4

midi:
  enabled: true
  input_device: null         # null = first available
  channel: 0                 # 0-15

presets:
  factory_path: ~/.local/share/opensynth/presets
  user_path: ~/.local/share/opensynth/user_presets
  favorites_path: ~/.local/share/opensynth/favorites.json

paths:
  recordings: ~/.local/share/opensynth/recordings
  wavetables: ~/.local/share/opensynth/wavetables
  drum_kits: ~/.local/share/opensynth/drum_kits
```

## Implementation Files

```
scripts/setup.py              # Setup wizard (Python)
scripts/doctor.py             # Health check
scripts/config.py             # Config management
lib/utils/config.dart         # Dart config loader
lib/utils/paths.dart          # XDG path resolution
```

## No External AI Harness Integration

OpenSynth setup is **purely for the synthesizer**. It does NOT:
- Import config from Hermes
- Import config from OpenClaw
- Import config from OpenShark
- Transfer settings to any AI harness

If the user wants to migrate AI harness config, they should use the appropriate harness's setup command:
- Hermes → OpenShark: `openshark setup --migrate-from hermes`
- OpenClaw → OpenShark: `openshark setup --migrate-from openclaw`
- OpenClaw → Hermes: `hermes claw migrate`

## Pitfalls

1. **Do not conflate OpenSynth setup with AI harness setup.** OpenSynth is a synthesizer app, not an AI agent. Its setup configures audio backends, MIDI devices, and UI themes — not model providers or agent personalities.
2. **XDG paths only.** Use `~/.config/opensynth/` for config and `~/.local/share/opensynth/` for data. Do NOT use `~/.hermes/`, `~/.openclaw/`, or `~/.openshark/` paths.
3. **Flutter SDK required.** The setup wizard must verify Flutter is installed before proceeding. Native builds won't work without it.
4. **Java 21 for Android.** Java 25 breaks Gradle. Always verify `JAVA_HOME` points to Java 21 before Android builds.
