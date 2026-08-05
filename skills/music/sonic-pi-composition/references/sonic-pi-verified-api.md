# Sonic Pi 4.x — Verified API Reference (Synthwave-focused)

Verified against official Sonic Pi dev-branch cheatsheets (`samples.md`, `synths.md`, `fx.md`) and `synthinfo.rb` — stable across all 4.x (incl. 4.6). Sonic Pi language is Ruby; `sleep`/`attack`/`release` times are in **beats**, not seconds.

---

## 1. Core Timing & Multi-Section Song Structure

### Tempo & sleeps
```ruby
use_bpm 100              # beats/min; sleep 1 = one beat
use_bpm_mul 2            # global multiplier
with_bpm 140 do          # scoped tempo
  sleep 4
end
sleep 0.25               # sixteenth at any bpm
```

### Threads & loops
- `in_thread do ... end` — parallel block, runs once. Name it (`in_thread(name: :x)`) or a re-run spawns duplicates.
- `live_loop :name do ... end` — named thread that restarts on each Run (no duplicates).
- v4+ live_loop opts: `live_loop :foo, sync: :bar, auto_cue: true, seed: 42, init: 0`
  - `sync:` — wait for cue once **before first iteration only**.
  - `auto_cue:` — every iteration automatically `cue :foo` at its start (default **true** in v4). Set `auto_cue: false` if unwanted.
  - `seed:` — per-loop random seed (determinism per part).
- `sync :a` — block until next `cue :a`. `sync :a, :b` — resume on **either**. Syncs are level-triggered on *future* cues only: a cue fired before `sync` is reached is missed.
- `cue :bar, 0.5` — cue with value; receive via `sync :bar` then `get[:bar]`. Values: `set :k, v` / `get :k`.
- `at [0, 0.5, 1.5], [:c4, :e4, :g4] do |n| play n end` — schedule notes at beat offsets (block must `sleep` long enough to contain them).
- `time_warp 2 do ... end` — run code as if 2 beats in the future.
- `tick` is per-thread. `use_random_seed N` at top makes `.choose`, `rrand`, `dice` fully reproducible.

---

## 2. Synths for Synthwave (verified opts)

Common to most: `note:, amp:, pan:, attack:, decay:, sustain:, release:, attack_level:, sustain_level:, env_curve:` (envelope times in **beats**; total length = attack+decay+sustain+release).

| Synth | Character | Key opts (defaults) |
|---|---|---|
| `:prophet` | THE synthwave pad/lead — dark, swirly PWM | `cutoff: 110, res: 0.7` |
| `:supersaw` | thick trance/rave saws | `cutoff: 130, res: 0.7` |
| `:tb303` | acid bassline | `cutoff: 120, cutoff_min: 30, res: 0.9, wave: 0 (0=saw,1=pulse,2=tri), pulse_width: 0.5` + full cutoff envelope |
| `:dpulse` | detuned pulse — fat bass | `cutoff: 100, detune: 0.1, pulse_width: 0.5` (NO res) |
| `:dsaw` | detuned saw | `cutoff: 100, detune: 0.1` (NO res) |
| `:dtri` | detuned triangle | `cutoff`, `detune` (NO res) |
| `:blade` | Blade Runner strings (Vangelis!) | `cutoff: 100, vibrato_rate: 6, vibrato_depth: 0.15, vibrato_delay: 0.5, vibrato_onset: 0.1` |
| `:saw` | plain saw, no filter | envelope only |
| `:beep` / `:sine` | pure sine (subs, 80s bass) | envelope only |
| `:pluck` | Karplus-Strong pluck (80s mallets) | `noise_amp: 0.8, max_delay_time: 0.125, pluck_decay: 30, coef: 0.3` |
| `:pretty_bell` / `:dull_bell` | FM bells | envelope only |
| `:hoover` | early-90s rave lead | `cutoff: 130, res: 0.1` |
| `:zawa` | phase-animated wobble lead | `wave: 3, phase: 1, range: 24, cutoff: 100, res: 0.9, pulse_width: 0.5` |
| `:tech_saws`, `:growl`, `:hollow`, `:dark_ambience`, `:fm`, `:mod_*` | texture/ambience | — |

Notes:
- Filter cutoff is a **MIDI note** value (0–130), not Hz. 60 ≈ muffled, 100 ≈ open, 120+ ≈ bright.
- Slideable opts can be automated: capture the synth node and `control` it:
```ruby
s = play :a2, synth: :prophet, note_slide: 0.5, sustain: 4
control s, note: :e3      # glides (portamento) over 0.5 beats
```

---

## 3. Drum Samples (verified from `synthinfo.rb`)

**Kicks:** `:bd_808, :bd_ada, :bd_boom, :bd_fat, :bd_gas, :bd_haus, :bd_klub, :bd_mehackit, :bd_pure, :bd_sone, :bd_tek, :bd_zome, :bd_zum`, `:drum_bass_hard, :drum_bass_soft, :drum_heavy_kick`

**Snares:** `:sn_dolf, :sn_dub, :sn_zome, :sn_generic`, `:drum_snare_hard, :drum_snare_soft`, `:elec_snare, :elec_lo_snare, :elec_mid_snare, :elec_hi_snare, :elec_filt_snare, :elec_flip`

**Hi-hats / cymbals:** `:drum_cymbal_closed, :drum_cymbal_pedal, :drum_cymbal_open, :drum_cymbal_hard, :drum_cymbal_soft, :drum_splash_hard, :drum_splash_soft, :elec_cymbal`, `:hat_bdu, :hat_cab, :hat_cats, :hat_gem, :hat_gnu, :hat_gump, :hat_hier, :hat_len, :hat_mess, :hat_metal, :hat_noiz, :hat_psych, :hat_raw, :hat_sci, :hat_snap, :hat_star, :hat_tap, :hat_yosh, :hat_zan, :hat_zap, :hat_zild`

**Toms:** `:drum_tom_hi_hard, :drum_tom_hi_soft, :drum_tom_mid_hard, :drum_tom_mid_soft, :drum_tom_lo_hard, :drum_tom_lo_soft`, `:elec_fuzz_tom`

**Other percussion / extras:** `:drum_cowbell, :drum_roll` (use `onset:`), `:perc_bell, :perc_bell2, :perc_snap, :perc_snap2, :perc_swash, :perc_till, :perc_door, :perc_impact1, :perc_impact2, :perc_swoosh`, `:elec_triangle, :elec_chime, :elec_bong, :elec_twang, :elec_wood, :elec_pop, :elec_beep, :elec_blip, :elec_blip2, :elec_ping, :elec_bell, :elec_tick, :elec_hollow_kick, :elec_twip, :elec_plip, :elec_blup, :elec_soft_kick`, loops: `:loop_amen, :loop_amen_full, :loop_breakbeat, :loop_compus, :loop_garzul, :loop_industrial, :loop_mika`, vinyl: `:vinyl_hiss, :vinyl_backspin, :vinyl_rewind`

**80s drum-machine picks:**
- Kick: `:bd_808` (deep 808 boom — *the* synthwave kick), `:bd_haus` (tight 909-ish four-on-floor), `:drum_heavy_kick`, `:elec_hollow_kick` (Simmons-ish)
- Snare: `:sn_dolf` (classic clap-snare hybrid), `:elec_filt_snare`, `:drum_snare_hard` + reverb = gated 80s snare; layer with `:perc_snap` for claps
- Hats: `:drum_cymbal_closed`/`_open`/`_pedal`, `:elec_cymbal`
- Toms/fills: `:drum_tom_*` pitched down (`rate: 0.85`) for Simmons toms

**Sample opts worth using:** `rate:` (negative = reverse), `amp:, pan:`, `attack:/release:`, `start:/finish:`, `onset:`, `beat_stretch: n`, `lpf:/hpf:/cutoff:`, `slice:`.

---

## 4. FX (verified opts) & Sidechain Pump

`with_fx :name, opt: v do ... end`. `mix: 0..1` = dry/wet. `pre_amp:` boosts into the FX. FX opts are control-able: `with_fx :reverb do |r| ... control r, mix: 0.8 end`.

| FX | Key opts (defaults) | Use |
|---|---|---|
| `:reverb` | `room: 0.6, damp: 0.5, mix: 0.4` | space; huge `room: 0.9` on snare = 80s gate-verb vibe |
| `:gverb` | `room: 10, release: 3, spread: 0.5, dry: 1, tail_level: 0.5` | lush cavernous verb |
| `:echo` | `phase: 0.25, decay: 2, max_phase: 2, mix: 1` | tempo-synced delay; `phase: 0.375` = dotted 8th |
| `:ping_pong` | `phase:, decay:, mix:` | stereo bouncing delay |
| `:slicer` | `phase: 0.25, pulse_width: 0.5, wave: 1, amp_min: 0, amp_max: 1, smooth: 0, smooth_up: 0, smooth_down: 0, invert_wave: 0` | rhythmic gating / tremolo / **sidechain pump** |
| `:panslicer` | `phase: 0.25, pan_min: -1, pan_max: 1` | auto-pan |
| `:compressor` | `threshold: 0.2, slope_above: 0.5, slope_below: 1, clamp_time: 0.01, relax_time: 0.01` | glue/louden. **No external sidechain input** |
| `:distortion` | `distort: 0.5` | grit on bass/leads |
| `:bitcrusher` | `sample_rate: 10000, bits: 8` | lofi 8-bit |
| `:krush` | `gain:, cutoff:, res:` | bitcrush + filter combo |
| `:ixi_techno` | `phase: 4, cutoff_min: 60, cutoff_max: 120, res: 0.8` | slow rhythmic filter sweep |
| `:wobble` | `phase: 0.5, cutoff_min: 60, cutoff_max: 120, res: 0.8` | dubstep-style LFO filter |
| `:flanger` | `phase: 4, wave: 4, depth: 5, delay: 5, feedback: 0, decay: 2` | 80s jet swoosh / Juno chorus approx at depth 2–3, feedback 0.05 |
| `:lpf / :rlpf` | `cutoff: 100` (+`res:` on r) | filter whole buses |
| `:hpf / :rhpf` | `cutoff: 100` | clear mud; sweep up in intros |
| `:bpf/:rbpf` | `centre:, res:` | band-pass |
| `:pitch_shift, :octaver, :whammy, :tremolo, :ring_mod, :vowel, :tanh, :normaliser, :level, :pan, :mono` | — | misc |

**Sidechain pump — three idiomatic ways:**

1. **Slicer on the pad/bass bus** (easiest, tempo-locked):
```ruby
with_fx :slicer, phase: 0.25, wave: 0, invert_wave: 1,
                smooth_up: 0.05, smooth_down: 0.05, amp_min: 0.1 do
  # pads + bass here — volume ducks on every beat
end
```
(`phase: 0.25` = 16th rate; use `0.5`/8ths or `1`/quarters. `amp_min` sets duck depth; `amp_min: 1.0` = bypass.)

2. **`:level` FX + amp automation** (true "kick hits, volume ducks, recovers" shape):
```ruby
with_fx :level, amp: 1 do |lvl|
  # play chord inside the fx block, then in a thread:
  control lvl, amp: 0.15, amp_slide: 0.05   # fast duck
  sleep 0.05
  control lvl, amp: 1, amp_slide: 0.7       # slow recovery
end
```

3. **Per-note envelope shaping**: pad chords with `attack: 0.3` retriggered every beat swell after each kick — cheap pump without FX.

---

## 5. Music Theory Helpers

```ruby
scale(:e3, :minor_pentatonic)            # => ring of MIDI notes
scale(:c4, :minor, num_octaves: 2)
scale_names / chord_names                # discover available types
chord(:a3, :minor7)                      # ring [57, 60, 64, 67]
chord_degree(:i, :a3, :minor, 3)         # triad of degree i in A minor
chord_invert(chord(:a3, :minor), 1)      # inversions (neg. = down)
note(:c4), note_info(:c4), hz_to_midi(440), midi_to_hz(69)
```

Chord names confirmed: `:minor, :major, :m7, :m9, :maj7, :add9, :sus2, :sus4`.

**Rings** (immutable, circular):
```ruby
(ring :a2, :c3, :e3)
(1..8).ring
r.tick      # next element each call (per-thread counter)
r.look      # current element without advancing
r.choose    # random element (seeded by use_random_seed)
r.tick(:b)  # separate named counter for a second sequence
```
Useful: `.reverse, .rotate(n), .shuffle, .sort, .mirror, .stretch, .take(n), .drop(n), .butlast, .pick(n), .choose, .size, .include?, +` (concat).

**Euclidean rhythms:**
```ruby
spread(3, 8)          # ring of booleans — 3 hits over 8 steps
bools(1, 0, 1, 0)
knit(:c4, 2, :e4, 1)
line(0, 1, steps: 8)  # numeric ramp (cutoff automation)
```
Pattern: `sample :bd_haus if spread(4, 16).tick` inside a 16-step loop.

**Randomness:** `rrand(60, 100)`, `rrand_i(0, 7)`, `dice(6)`, `one_in(4)`, `rdist(0.5, 0.2)`. Always `use_random_seed N` for composed songs.

**Sequencing shortcuts:**
```ruby
play_pattern_timed (scale :a3, :minor), [0.25, 0.5], release: 0.2
use_synth :prophet
use_synth_defaults cutoff: 90
use_transpose 12 / with_transpose -12 do ... end
```

---

## 6. Common Pitfalls

1. **Sync deadlock / missed cues.** `sync` only hears *future* cues. Conductor cues **every bar** (`cue :bar` + `sleep 4`) and parts read `get(:section)` — parts can never wait forever.
2. **Circular waits.** Loop A `sync :b` while loop B `sync :a` → both block forever. One root timekeeper only.
3. **`in_thread` with no name + re-running** → duplicate threads stack. Use `live_loop` for anything repeating.
4. **Stopping everything:** Run ▸ Stop (Alt+S). `stop` inside a live_loop kills just that loop.
5. **Clipping.** Summed amps > 1 degrade everything. Per-voice `amp:` ≤ ~0.8; master: `set_volume! 0.8`, `use_amp 0.7`, or a `:compressor` bus.
6. **Envelope clicks.** `release: 0` on loud material clicks — use `attack: 0.01, release: 0.1` minimum. Total synth length = attack+decay+sustain+release.
7. **BPM confusion.** Envelope times and `echo phase:`/`slicer phase:` are in **beats** and scale with `use_bpm`.
8. **`tick` shared counter.** One implicit counter per thread — use named: `tick(:melody)`.
9. **Non-determinism.** Always seed for composed songs (`use_random_seed N` + per-loop `seed:`).
10. **Timing drift under load.** Reduce polyphony, `set_sched_ahead_time! 1`. Errors in one live_loop kill only that thread — check the log.

---

## 7. Verified Snippets

### 4-on-the-floor drums (808-flavored)
```ruby
use_bpm 118

live_loop :kick do
  sample :bd_808, amp: 1.2, cutoff: 90
  sleep 1
end

live_loop :snare do
  sleep 1
  sample :sn_dolf, amp: 0.9
  with_fx :reverb, room: 0.6, mix: 0.3 do
    sample :drum_snare_hard, amp: 0.5, rate: 0.9
  end
  sleep 1
end

live_loop :hats do
  sample :drum_cymbal_closed, amp: (ring 0.5, 0.25, 0.4, 0.25).tick
  sleep 0.5
end
```

### Driving 16th-note bassline (TB-303)
```ruby
live_loop :bass do
  use_synth :tb303
  use_synth_defaults release: 0.22, res: 0.85, wave: 0
  notes = (ring :a1, :a1, :a1, :c2, :a1, :a1, :g1, :e1,
                :a1, :a1, :a1, :c2, :d2, :c2, :g1, :g1)
  n = notes.tick
  play n, cutoff: (line 55, 95, steps: 16).mirror.look + rdist(0, 5)
  sleep 0.25
end
```

### Supersaw pad progression (Am–F–C–G)
```ruby
live_loop :pads do
  use_synth :supersaw
  prog = (ring (chord :a2, :minor), (chord :f2, :major),
               (chord :c3, :major), (chord :g2, :major))
  with_fx :reverb, room: 0.85, mix: 0.5 do
    with_fx :lpf, cutoff: 85 do
      play prog.tick, attack: 2, sustain: 4, release: 2,
           cutoff: 75, res: 0.5, amp: 0.6
    end
  end
  sleep 8
end
```

### Sidechain pump (slicer method)
```ruby
live_loop :pumped do
  use_synth :prophet
  with_fx :slicer, phase: 1, wave: 0, invert_wave: 1,
                  amp_min: 0.15, smooth_up: 0.1, smooth_down: 0.05 do
    with_fx :reverb, room: 0.8 do
      play (chord :a2, :minor7), attack: 0.5, sustain: 3, release: 1,
           cutoff: 90, amp: 0.7
    end
  end
  sleep 4
end
```

### Arpeggiated lead (Prophet + dotted echo)
```ruby
live_loop :arp do
  use_synth :prophet
  use_synth_defaults release: 0.2, cutoff: 100, res: 0.6, amp: 0.5
  arp_notes = (ring :a3, :c4, :e4, :a4, :e4, :c4)
  with_fx :echo, phase: 0.375, decay: 3, mix: 0.35 do
    with_fx :reverb, room: 0.6, mix: 0.3 do
      play arp_notes.tick
    end
  end
  sleep 0.25
end
```

---

## 8. Minimal Full-Song Skeleton

See `templates/song_skeleton.rb` in this skill — the conductor + section-gated
parts used across all five EP tracks. Run once → identical playback every time.
