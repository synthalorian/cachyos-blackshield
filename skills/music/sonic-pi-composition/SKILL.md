---
name: sonic-pi-composition
description: Use when composing full songs in Sonic Pi (4.x).
version: 1.0.0
tags: [sonic-pi, music, composition, synthwave, supercollider, live-coding, ruby]
---

# Sonic Pi Composition (full songs, deterministic)

How to compose multi-section songs in Sonic Pi 4.x that run start-to-finish
identically every Run. Battle-tested on an EP project (5 tracks, ~16 min).

## Setup on CachyOS/Arch

- Package is AUR-only: `sonic-pi` (source build, ~30 min; deps: supercollider,
  qscintilla-qt6, qt6-*, boost, erlang/elixir, ruby-* gems, AUR `ruby-wavefile`).
- scsynth (SuperCollider) speaks JACK only. On PipeWire systems either swap
  `jack2` → `pipewire-jack` (provides same libjack ABI; audacity/ffmpeg/mpv
  deps stay satisfied) or run a manual `jackd -d alsa` (exclusive device grab).
  Without a JACK server Sonic Pi shows "Critical error! Could not boot Synth Server."
- Verify GUI installs with `pacman -Qi sonic-pi`, NOT by launching it headless.
- **Silent-audio trap**: pipewire-jack auto-connects SuperCollider's outs to
  the HDMI monitor sink, NOT the default device (headset) — sound "plays" but
  nothing is heard, and it recurs on every reboot/scsynth respawn. Fix:
  `~/bin/sonicpi-audio-fix` (one-shot relink to @DEFAULT_AUDIO_SINK@) or the
  `--watch` daemon (KDE autostart at ~/.config/autostart/sonicpi-audio-fix.desktop).
  Diagnose with `pw-link -l | grep -A2 "^SuperCollider:out_"`.
- **Silent output despite "SuperCollider 3 server ready"**: PipeWire auto-links
  `SuperCollider:out_1/2` to the wrong sink (e.g. HDMI monitor instead of the
  default headset). Diagnose: `pw-link -l | grep -A2 "SuperCollider:out_[12]$"`;
  sink names from `wpctl status`. Fix: `pw-link -d SuperCollider:out_1
  <wrong-sink>:playback_FL` then `pw-link SuperCollider:out_1
  <right-sink>:playback_FL` (repeat out_2 → FR). Links die when scsynth
  respawns — re-run after restarting Sonic Pi.

## The Conductor Pattern (use for every composed song)

One live_loop owns the timeline, cues every bar, and sets section state via
`set`. All parts `sync :bar` and gate content by `get(:section)`. Nothing can
drift or deadlock because only the conductor cues. Full template:
`templates/song_skeleton.rb`.

```ruby
SONG = { intro: 8, verse: 16, build: 8, drop: 16, outro: 8 }  # bars per section
live_loop :conductor do
  bar = 0
  SONG.each do |section, bars|
    set :section, section
    bars.times do |i|
      set :bar_global, bar; set :bar_in_sec, i
      cue :bar
      sleep 4
      bar += 1
    end
  end
  set :section, :done; cue :bar; stop
end
```

Parts: `sync :bar; stop if get(:section) == :done; ...; sleep <exactly 4>`.
Always `use_random_seed N` at the top → identical playback every Run.

## Verified API facts (checked against sonic-pi dev-branch source)

- **`:dsaw`, `:dtri`, `:dpulse` have NO `res:` opt** — only note/amp/pan/
  envelope/cutoff/detune. Passing `res:` kills the thread with unknown-opt.
  Resonant filters: use `:prophet`, `:supersaw`, `:tb303`, `:blade`, `:zawa`.
- Chord names confirmed: `:minor, :major, :m7, :m9, :maj7, :add9, :sus2, :sus4`.
- `:blade` vibrato opts: `vibrato_rate, vibrato_depth, vibrato_delay,
  vibrato_onset` — THE Vangelis/sax lead voice.
- `:fm` bells: `divisor:` 2–4, `depth:` 0.5–2. `:pretty_bell` for simpler FM.
- 80s drum-machine sample picks: kick `:bd_808` (sub boom) / `:bd_haus`
  (tight 4otf); snare `:sn_dolf` + `:drum_snare_hard`; hats
  `:drum_cymbal_closed/_open/_pedal`; toms `:drum_tom_*` at `rate: 0.85`
  (Simmons); `:perc_snap` = clap; `:vinyl_hiss` = tape crackle bed.
- Samples accept `cutoff:` (LPF), `hpf:/lpf:`, `rate:`, `attack:/release:`,
  `onset:`, `beat_stretch:`.
- FX verified: `:reverb (room,damp,mix), :gverb, :echo (phase in beats;
  0.375 = dotted 8th), :ping_pong, :slicer, :flanger, :distortion,
  :ixi_techno, :wobble, :lpf/:hpf, :compressor` (NO external sidechain input).
- Full tables: `references/sonic-pi-verified-api.md`.

## Pitfalls (each one bit us in production)

1. **Sleep budget = exactly the bar length.** Every live_loop must consume
   precisely 4 beats per bar. A fill/roll that adds sleeps on top of the
   normal path (e.g. 16th-roll `4.times { sleep 0.25 }` INSIDE a branch that
   also keeps the trailing `sleep 1`) makes the loop 6 beats → misses the next
   `:bar` cue → part silently drops a bar. Fix: the roll consumes the beat
   slot; remove the trailing sleep in that branch.
2. **Melody bars must sum to 4 beats.** When encoding melodies as
   `[[note, beats], ...]` per bar, sum each bar — a 5-beat bar drifts the
   whole lead off the grid. Sum-check before shipping.
3. **Symbol + Integer note arithmetic crashes.** `:a1 + 12` is a NoMethodError.
   Convert first: `root = note(:a1)` then `root + 12`. Chord rings are already
   MIDI numbers; bare note symbols are not.
4. **Sidechain pump**: no true keyed compressor. Use
   `with_fx :slicer, phase: 1, wave: 0, invert_wave: 1, amp_min: 0.2–0.35,
   smooth_up: 0.1` on the pad/bass bus (gate `amp_min:` per section —
   `amp_min: 1.0` = bypass).
5. **Gated-reverb snare**: no gate FX. Layer dry `:sn_dolf` + a short-decay
   `synth :noise, release: 0.22–0.35, cutoff: 75–105` inside
   `with_fx :reverb, room: 0.9, damp: 0.3, mix: 0.9`. Darksynth: longer burst,
   lower cutoff.
6. **Amp discipline vs loudness**: the master limiter glues the mix only when
   driven — v1 "polite" levels (kick 1.15, pads 0.55) were rejected by synth
   as "small, no glue, no loudness". See the mix baseline section below and
   start hot; walk amps DOWN only if the limiter audibly pumps.
7. **Portamento lead**: one synth node per bar — `s = synth :prophet, note: n0,
   note_slide: 0.08–0.25, sustain: total; sleep d; control s, note: n1`.
   Slide time is in BEATS (0.12 beats @ 108 BPM ≈ 66 ms glide).
8. **Up-down arp idiom**: `(ch + ch.map { |n| n + 12 }).sort.ring.mirror
   .drop(1).butlast` — ascending+descending without doubled endpoints.
9. **Structure per subgenre**: consult `references/synthwave-production.md` —
   tempo table, six 16-step drum grids, bass patterns, canonical progressions
   with color chords (m9/maj7/sus2 are the genre's signature), arrangement
   template, and a 5-track EP blueprint.

## Mix baseline: "small, no glue, no loudness" (synth's verdict — bake in from the start)

A structurally correct but politely-mixed track gets rejected. Start every
track at this v2 production level:

1. **One drum bus.** All kit pieces in a single 16-step live_loop wrapped in
   `with_fx :compressor, threshold: 0.35, slope_above: 0.4, clamp_time: 0.005,
   relax_time: 0.05` + `with_fx :distortion, distort: 0.12, mix: 0.25`.
   A shared bus is what glues a kit.
2. **Layer every hit.** Kick = `:bd_808` (sub, amp 1.5) + `:bd_haus` (knock,
   amp 0.55, rate 0.9, hpf 80). Snare = `:sn_dolf` (1.0) +
   `:drum_snare_hard` (0.55, rate 0.9) + `:perc_snap` clap (0.5) + gated
   noise burst — on every hit, not just drops. Crash amp 0.7 on section entries.
3. **Hot levels into the built-in limiter.** v2 reference points: kick 1.5,
   snare 1.0, hats 0.55, pads 0.7, bass 0.65, lead 0.65–0.7.
4. **HPF cleanup.** `with_fx :hpf, cutoff: 55–60` on pads/arp so kick+bass
   own the low end — clarity reads as loudness.
5. **Layered voices everywhere.** Pads: supersaw pan -0.4 + prophet pan +0.4
   (notes +0.04 detune) + hollow +12 shimmer. Bass: dsaw body + tb303 bite
   (cutoff +12, amp 0.28) + sine sub. Lead: prophet + blade 8va double on
   EVERY drop, not just the finale.
6. Reference implementation: track 1 v2 at
   ~/Projects/active/this-is-the-wave/tracks/01_testarossa_nights.rb
   (see the merged `:drum_bus` loop).

## Static verification workflow (no Sonic Pi needed)

1. `ruby -c track.rb` on every file (Sonic Pi is Ruby; parse-checks catch 90%).
2. Validate synth/sample/chord names + opts against upstream source:
   `curl -sL https://raw.githubusercontent.com/sonic-pi-net/sonic-pi/dev/app/server/ruby/lib/sonicpi/synths/synthinfo.rb`
   (grep the class, read `arg_defaults`), `.../sonicpi/chord.rb` for chords.
3. Sum-check every sleep budget and melody bar by hand (see pitfalls 1–2).
4. Runtime test last: load in GUI, Run, listen for missing parts (usually a
   pitfall-1 drift) or unknown-opt thread deaths (check the log pane).

## Files

- `templates/song_skeleton.rb` — conductor + section-gated parts, copy & fill.
- `references/synthwave-production.md` — genre production bible (condensed).
- `references/sonic-pi-verified-api.md` — synth/sample/FX opt tables.
