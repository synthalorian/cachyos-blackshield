---
name: linux-audio-troubleshooting
description: "Use when desktop audio is silent or wrong device."
version: 1.0.0
author: synthclaw
metadata:
  hermes:
    tags: [linux, audio, pipewire, alsa, cachyos, troubleshooting]
---

# Linux Desktop Audio Troubleshooting (PipeWire/ALSA)

For system-level audio failures on Arch/CachyOS + KDE: no output, wrong device, audio died after logout/update. NOT for synth/DAW DSP bugs — that's `audio-dsp-debugging`.

## Layer Isolation — The Core Move

Desktop audio has TWO independent volume layers, and they desync:

1. **PipeWire/Pulse volume** (`pactl get-default-sink`, `pactl list sinks`) — what KDE's applet shows
2. **ALSA hardware mixer** (`amixer -c <card> sget PCM`) — the actual hardware gain

PipeWire can show 99% while the ALSA mixer sits at **0%** → complete silence with everything "looking right". Always check BOTH before deeper debugging.

```bash
# Layer 1: PipeWire
pactl list sinks short
pactl get-default-sink
wpctl status

# Layer 2: ALSA hardware mixer (find card number first)
aplay -l
amixer -c <N> sget PCM          # if this shows 0% [0.00dB], that's the bug
amixer -c <N> sset PCM 100%     # fix
```

## Verification Ladder (bottom-up)

Test each layer independently to isolate where the chain breaks:

```bash
# 1. Direct ALSA (bypasses PipeWire entirely — proves hardware works)
speaker-test -D plughw:<N>,0 -c2 -t sine -f 440 -l 1

# 2. PipeWire playback
paplay /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga

# 3. If ALSA works but PipeWire doesn't → PipeWire routing/session issue
#    If neither works → hardware/driver/USB issue
```

## Stale PipeWire After Logout/Login

PipeWire user services can survive a logout with stale session state. If audio dies right after re-login:

```bash
# Check if PipeWire predates your login
ps -p $(pgrep -f "pipewire$" | head -1) -o lstart

# Restart the full user stack
systemctl --user restart pipewire pipewire-pulse wireplumber
pactl get-default-sink   # confirm default sink survived
```

## Standard Health Check Sequence

```bash
# Services running?
systemctl --user status pipewire pipewire-pulse wireplumber | grep Active

# Device detected at USB/ALSA level?
lsusb | grep -i <device-name>
aplay -l

# Right default sink? Not muted? Sane volume?
pactl get-default-sink
pactl list sinks | grep -E "Name:|Mute:|Volume:"

# ALSA hardware volume (THE commonly missed one)
amixer -c <N> sget PCM
```

## Pitfalls

- **All sinks show SUSPENDED in `pactl list sinks` is NORMAL** — sinks suspend when idle. Not a bug indicator.
- **USB wireless headsets re-enumerate on re-login** — card number can change between sessions. Never hardcode card numbers in scripts; resolve via `aplay -l` grep at runtime.
- **KDE volume applet only controls the PipeWire layer.** Dragging it to 100% does nothing if the ALSA hardware mixer is at 0. This desync was observed after a session restart on a USB wireless headset (H510-PRO) — PipeWire showed 99%, ALSA showed 0%, total silence. Fix was one `amixer` command.
- **`speaker-test` succeeding proves hardware + driver + ALSA are fine.** If it produces sound but apps don't, the problem is 100% in PipeWire routing/session — don't touch drivers.
