---
name: sonic-pi
description: "Sonic Pi on Arch/CachyOS: install, JACK/scsynth, composing."
version: 1.0.0
tags: [music, sonic-pi, supercollider, live-coding, cachyos, arch, jack]
---

# Sonic Pi on CachyOS/Arch

Setup and composition workflows for Sonic Pi (live-coding music environment,
Ruby-based DSL over SuperCollider).

## Install (CachyOS/Arch)

sonic-pi is AUR-only (no repo or chaotic-aur binary; CachyOS repos don't carry
it). Follow the `aur-package-installs` workflow (paru clone → direct-sudo repo
deps → makepkg → pacman -U). Facts for v4.6.0:

- One AUR dep: `ruby-wavefile`. Everything else is in official repos
  (supercollider, qscintilla-qt6, qt6-svg/wayland, aubio, boost, erlang-*,
  elixir, cmake, gendesk, chrpath, ruby-* gems).
- `sc3-plugins` (extra UGens) is a worthwhile optdepend — install it.
- The build is LONG (Qt6 GUI + Erlang/Elixir runtime + Ruby; expect 20-40 min).
  Run makepkg in background with notify_on_complete.
- Don't verify by launching the GUI from a headless terminal — use
  `pacman -Qi sonic-pi` + the .desktop file, then test audio on the actual
  desktop session.

## Audio: scsynth REQUIRES a JACK server

Sonic Pi boots SuperCollider's `scsynth`, which on Arch's supercollider build
only speaks JACK. PipeWire alone is not enough — without a JACK server Sonic Pi
shows "Critical error! Could not boot Synth Server." Options:

1. **pipewire-jack swap (clean, preferred):** `sudo pacman -S pipewire-jack`
   replaces jack2 but provides the same libjack ABI, so reverse-deps (ffmpeg,
   mpv, audacity, guitarix, blender, obs...) keep working, now routed through
   PipeWire. scsynth then auto-connects to the always-running PipeWire JACK
   server. Fully reversible (`sudo pacman -S jack2`).
   NOTE: synth has NOT consented to this swap yet (denied 2026-07-26) — propose,
   don't run, and respect the answer.
2. **Manual jackd on raw ALSA:** `jackd -d alsa -d hw:X &` before launching
   Sonic Pi. Grabs the device EXCLUSIVELY — all other desktop audio (PipeWire)
   dies while it runs. Find the device with `aplay -l`.

## Composition quick reference

(Expand as patterns are proven in sessions — see references/ when present.)

- Timing: `use_bpm`, `live_loop`, `sync`/`cue` for multi-section song structure,
  `sleep`, `in_thread`.
- Synthwave-friendly synths: `:prophet`, `:tb303`, `:supersaw`, `:dpulse`,
  `:blade`, `:pluck`, `:pretty_bell`.
- 80s drums: `:bd_808`, `:bd_haus`, `:drum_snare_hard`, `:sn_dolf`,
  `:drum_cymbal_closed`, `:elec_*` family.
- Sidechain pump: `with_fx :compressor` keyed off the kick, or a
  `with_fx :slicer`-style amp LFO on pads.
- Pitfalls: live_loop sync deadlocks (every loop needs a `sync` partner or a
  `sleep`), clipping across layered threads (`use_amp`), stop-all before re-run.
