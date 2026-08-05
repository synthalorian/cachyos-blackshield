# Sonic Pi Song Skeleton — conductor + section-gated parts (v2 mix baseline)
# Copy this, edit SONG + PROG, fill in parts. Deterministic: same seed, same song.
# Mix baseline: merged drum bus (glue), layered kit, hot levels, HPF cleanup.

use_bpm 108
use_random_seed 1984
set_sched_ahead_time! 1

SONG = { intro: 8, verse: 16, build: 8, drop: 16,
         breakdown: 8, build2: 8, drop2: 16, outro: 8 }

PROG  = (ring (chord :a2, :minor), (chord :f2, :major),
              (chord :c3, :major), (chord :g2, :major))
ROOTS = (ring :a1, :f1, :c2, :g1)

define :sec? do |*s|
  s.include? get(:section)
end

define :chord_now do
  PROG[get(:bar_global) % 4]
end

define :root_now do
  note ROOTS[get(:bar_global) % 4]   # MIDI number so +12 works
end

# ============================================================
live_loop :conductor do
  bar = 0
  SONG.each do |section, bars|
    set :section, section
    bars.times do |i|
      set :bar_global, bar
      set :bar_in_sec, i
      cue :bar
      sleep 4
      bar += 1
    end
  end
  set :section, :done
  cue :bar
  stop
end

# Every part below: sync :bar, stop on :done, sleep EXACTLY 4 beats.
# ============================================================

# DRUM BUS — whole kit in ONE 16-step loop through shared compressor+drive.
KICK_PAT  = (ring 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0)
SNARE_PAT = (ring 0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0)
HAT_ACC   = (ring 0.55, 0.25, 0.4, 0.25)

live_loop :drum_bus do
  sync :bar
  stop if sec? :done
  roll = sec?(:build, :build2) && get(:bar_in_sec) >= 6
  crash = get(:bar_in_sec) == 0 && sec?(:verse, :drop, :drop2)
  with_fx :compressor, threshold: 0.35, slope_above: 0.4,
                       clamp_time: 0.005, relax_time: 0.05 do
    with_fx :distortion, distort: 0.12, mix: 0.25 do
      16.times do |i|
        if KICK_PAT[i] == 1 && sec?(:verse, :build, :build2, :drop, :drop2)
          sample :bd_808, amp: 1.5, cutoff: 100        # sub
          sample :bd_haus, amp: 0.55, rate: 0.9, hpf: 80  # knock
        end
        if roll
          # 16th roll CONSUMES steps — crescendo into the drop
          sample :sn_dolf, amp: 0.25 + i * 0.045
          sample :drum_snare_hard, amp: 0.12 + i * 0.02, rate: 0.95
        elsif SNARE_PAT[i] == 1 && sec?(:verse, :build, :build2, :drop, :drop2)
          sample :sn_dolf, amp: 1.0
          sample :drum_snare_hard, amp: 0.55, rate: 0.9
          sample :perc_snap, amp: 0.5 if sec? :drop, :drop2
          with_fx :reverb, room: 0.9, damp: 0.3, mix: 0.9 do
            synth :noise, release: 0.22, cutoff: 105, amp: 0.6  # gated burst
          end
        end
        sample :drum_cymbal_closed, amp: HAT_ACC.tick(:hat) if i % 2 == 0 &&
          sec?(:verse, :build, :build2, :drop, :drop2)
        sample :drum_cymbal_open, amp: 0.4 if i == 14 && sec?(:drop, :drop2)
        sample :drum_cymbal_hard, amp: 0.7, hpf: 90 if crash && i == 0
        sleep 0.25
      end
    end
  end
end

live_loop :bass do
  sync :bar
  stop if sec? :done
  root = root_now
  cut = sec?(:drop, :drop2) ? 98 : 68
  patt = (ring root, root + 12, root, root + 12,
               root, root + 12, root + 7, root + 12)
  with_fx :slicer, phase: 1, wave: 0, invert_wave: 1,
                   amp_min: (sec?(:drop, :drop2) ? 0.35 : 1.0),
                   smooth_up: 0.1 do
    8.times do
      if sec? :verse, :build, :build2, :drop, :drop2
        n = patt.tick(:bp)
        synth :dsaw, note: n, release: 0.18, attack: 0.01,
              cutoff: cut, detune: 0.08, amp: 0.65
        synth :tb303, note: n, release: 0.15, attack: 0.005,
              cutoff: cut + 12, res: 0.55, wave: 0, amp: 0.28
        synth :sine, note: n, release: 0.15, amp: 0.5   # sub, same octave
      end
      sleep 0.5
    end
  end
end

live_loop :pads do
  sync :bar
  stop if sec? :done
  ch = chord_now
  with_fx :hpf, cutoff: 55 do
    with_fx :reverb, room: 0.85, mix: 0.45 do
      with_fx :slicer, phase: 1, wave: 0, invert_wave: 1,
                       amp_min: (sec?(:drop, :drop2) ? 0.2 : 1.0),
                       smooth_up: 0.1 do
        synth :supersaw, notes: ch, attack: 1, sustain: 2.5, release: 1.5,
              cutoff: (sec?(:drop, :drop2) ? 95 : 80), res: 0.4,
              amp: 0.7, pan: -0.4
        synth :prophet, notes: ch.map { |n| n + 0.04 }, attack: 1.2,
              sustain: 2.5, release: 1.5, cutoff: 75, res: 0.5,
              amp: 0.5, pan: 0.4
        synth :hollow, notes: ch.map { |n| n + 12 }, attack: 2,
              sustain: 2, release: 2, cutoff: 70, amp: 0.2
      end
    end
  end
  sleep 4
end

live_loop :arp do
  sync :bar
  stop if sec? :done
  ch = chord_now
  arp_notes = (ch + ch.map { |n| n + 12 }).sort.ring.mirror.drop(1).butlast
  with_fx :hpf, cutoff: 60 do
    with_fx :ping_pong, phase: 0.375, decay: 2, mix: 0.3 do
      16.times do
        if sec? :verse, :build, :build2, :drop, :drop2
          synth :prophet, note: arp_notes.tick(:arp), release: 0.18,
                cutoff: 105, res: 0.5, amp: 0.45
        end
        sleep 0.25
      end
    end
  end
end

# Portamento lead helper: one gliding synth node per bar.
# pairs = [[note, beats], ...] and MUST sum to 4.
define :lead_bar do |pairs, amp: 0.65, cut: 102, syn: :prophet|
  total = pairs.sum { |_, d| d }
  s = synth syn, note: pairs[0][0], sustain: total, release: 0.25,
            attack: 0.01, note_slide: 0.12, cutoff: cut, res: 0.55, amp: amp
  pairs.each_cons(2) do |(_, d), (n2, _)|
    sleep d
    control s, note: n2
  end
  sleep pairs[-1][1]
end

# live_loop :lead do
#   sync :bar
#   stop if sec? :done
#   if sec? :drop, :drop2
#     in_thread do   # blade 8va double on every drop
#       lead_bar [[:a5, 1.5], [:g5, 0.5], [:e5, 1], [:g5, 1]],
#                amp: 0.28, cut: 108, syn: :blade
#     end
#     lead_bar [[:a4, 1.5], [:g4, 0.5], [:e4, 1], [:g4, 1]]
#   else
#     sleep 4
#   end
# end
