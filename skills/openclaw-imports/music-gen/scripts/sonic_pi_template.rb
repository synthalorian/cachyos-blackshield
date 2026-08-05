# Sonic Pi Synthwave Template
# 80s-style electronic music with Ruby live coding
# Copy this file to Sonic Pi and run it

# ============================================
# CONFIGURATION
# ============================================

use_bpm 118
use_random_seed Time.now.to_i / 1000

# ============================================
# DRUMS - Gated Reverb Pattern
# ============================================

live_loop :kick do
  sample :drum_heavy_kick, amp: 0.8
  sleep 1
end

live_loop :snare do
  # Main snare with heavy gated reverb
  with_fx :reverb, mix: 0.7, room: 0.95 do
    sample :drum_snare_hard, amp: 0.6
  end
  sleep 0.5
  with_fx :reverb, mix: 0.7, room: 0.95 do
    sample :drum_snare_hard, amp: 0.4
  end
  sleep 0.5
end

live_loop :hihats do
  # 16th note hi-hats
  with_fx :distortion, distort: 0.2 do
    sample :drum_cymbal_closed, rate: 8, amp: 0.3
  sleep 0.25
  sample :drum_cymbal_closed, rate: 8, amp: 0.25
  sleep 0.25
  sample :drum_cymbal_closed, rate: 8, amp: 0.2
  sleep 0.25
  sample :drum_cymbal_closed, rate: 8, amp: 0.15
  sleep 0.25
end

# ============================================
# BASS - Analog 303 Style
# ============================================

live_loop :bass do
  use_synth :tb303
  use_synth_defaults release: 0.3, cutoff: rrand_i(60, 100), wave: 1, amp: 0.7
  
  with_fx :distortion, distort: 0.3 do
    with_fx :lpf, cutoff: 60, res: 0.3 do
      # E minor bass pattern
      play :e2, release: 0.3, cutoff: rrand_i(60, 90)
 wave: 1
 sleep: 0.25
      play :e2, release: 0.3, cutoff: rrand_i(60, 90) wave: 1
 sleep: 0.25
      play :g2, release: 0.3, cutoff: rrand_i(60, 100) wave: 1
 sleep: 0.25
      play :a2, release: 0.3, cutoff: rrand_i(60, 100) wave: 1
 sleep: 0.25
    end
  end
end

# ============================================
# PADS - Warm Analog Strings
# ============================================

live_loop :pads do
  use_synth :prophet
  use_synth_defaults release: 4, cutoff: rrand_i(60, 90), amp: 0.4
  
  with_fx :reverb, mix: 0.6, room: 0.9 do
    with_fx :lpf, cutoff: 80 do
      with_fx :chorus, mix: 0.4 do
        # Chord progression: Em - C - D - Bm
        play chord(:e2, :m7), release: 4, cutoff: rrand_i(60, 80) amp: 0.35
 sleep 4
        play chord(:c3, :major), release: 4, cutoff: rrand_i(60, 80) amp: 0.35
 sleep 4
        play chord(:d3, :major), release: 4, cutoff: rrand_i(60, 80) amp: 0.35
 sleep 4
        play chord(:b2, :minor), release: 4, cutoff: rrand_i(60, 80) amp: 0.35
 sleep 4
      end
    end
  end
end

# ============================================
# ARP - Arpeggiated Lead
# ============================================

live_loop :arp do
  use_synth :prophet
  use_synth_defaults release: 0.15, cutoff: rrand_i(70, 110), amp: 0.5
  
  with_fx :echo, phase: 0.375, decay: 2 do
    with_fx :reverb, mix: 0.4, room: 0.8 do
      with_fx :lpf, cutoff: 100 do
        # E minor arpeggio pattern
        play_pattern_timed chord(:e3, :minor7), [0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25] amp: 0.45
      end
    end
  end
  sleep 2
end

# ============================================
# ATMOSPHERE - Background Texture
# ============================================

live_loop :atmosphere do
  sample :ambi_lunar_land, amp: 0.2, rate: 0.8
  sleep 8
end

# ============================================
# MELODY - Optional Lead Line
# ============================================
# Uncomment to add melody

# live_loop :melody do
#   use_synth :prophet
#   use_synth_defaults release: 0.6, cutoff: rrand_i(50, 130), amp: 0.6
#   
#   with_fx :reverb, mix: 0.5, room: 0.9 do
#     with_fx :echo, phase: 0.5, decay: 1.5 do
#       play :e4, release: 0.6, cutoff: rrand_i(50, 130)
#       sleep 0.5
#       play :g4, release: 0.4, cutoff: rrand_i(50, 130)
#       sleep 0.25
#       play :a4, release: 0.6, cutoff: rrand_i(50, 130)
#       sleep 0.5
#       play :b3, release: 0.8, cutoff: rrand_i(50, 130)
#       sleep 1
#     end
#   end
# end

# ============================================
# VARIATIONS - Modify These
# ============================================
# 
# Change BPM:
#   use_bpm 100-130
# 
# Change key (modify chord patterns):
#   :pads - change chord(:e2, :m7) to chord(:a2, :m7)
#   :bass - change bass notes to match new key
#   :arp - change chord(:e3, :minor7) to match new key
# 
# Add more variation:
#   :bass - add randomization to cutoff values
#   :pads - change release times for different textures
#   :arp - change arpeggio speed with sleep times
# 
# Add effects:
#   Add :distortion to bass for darker sound
#   Add :flanger to arp for movement
#   Add :gverb to pads for bigger space
