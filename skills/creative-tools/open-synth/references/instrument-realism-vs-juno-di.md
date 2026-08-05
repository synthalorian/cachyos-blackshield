# OpenSynth Instrument Realism vs Roland Juno-Di

## The Fundamental Gap

**Roland Juno-Di**: PCM sample engine (1000+ recorded waveforms) + analog modeling
**OpenSynth**: Pure synthesis (wavetables, physical modeling, subtractive)

A 2048-sample single-cycle wavetable cannot capture hammer strikes, tine behavior, bow noise, breath noise, or body resonance. Without a PCM sample engine, we will never sound exactly like a Juno-Di for acoustic instruments.

## Current Realism Assessment

| Category | Presets | Waveform | Realism (1-10) | Main Issue |
|----------|---------|----------|----------------|------------|
| Piano | 16 | wtPiano | 3 | No hammer transient, no string resonance, sounds organ-like |
| Electric Piano | 8 | wtPiano/triangle | 3 | No tine strike, no pickup noise |
| Organ | 16 | wtOrgan/subtractive | 4 | No drawbar mixing, no rotary on presets |
| Guitar | 12 | wtGuitar/pmKarplus | 5 | KS decent but no body resonance |
| Strings | 12 | wtStrings/saw | 4 | No bow noise, no ensemble spread |
| Brass | 10 | wtBrass/saw | 4 | Too clean, no breath noise |
| Choir | 8 | wtChoir | 3 | No formant filtering, sounds like cheap organ |
| Drums | 10 kits | Drum synthesis | 6 | Good for electronic, not acoustic |
| Synth Pads | 50+ | saw/square/triangle | 7 | Our strength |
| Synth Leads | 50+ | saw/square | 7 | Our strength |
| Bass | 40+ | saw/sine/square | 7 | Our strength |

## What Real Instruments Actually Sound Like

### Piano
- Bright, compressed attack; short sustain; modest reverb
- Velocity: soft = mellow, hard = bright with hammer noise
- **Synthesis approach**: FM transient + noise burst + wavetable sustain + string resonance delay

### Electric Piano (Rhodes)
- Bell-like attack, "bark" on hard strikes, tine chorus
- Mechanical key noise, stereo tremolo
- **Synthesis approach**: Triangle + sine mix, filter envelope for bark, chorus for shimmer

### Organ
- 9 drawbars controlling harmonic content
- Rotary: doppler + tremolo
- Percussion: short bright attack on sustained tone
- **Synthesis approach**: Multiple sine oscillators at drawbar frequencies, rotary FX

### Guitar
- Pluck transient, body resonance (formants at ~100Hz, ~300Hz, ~800Hz)
- **Synthesis approach**: Karplus-Strong + body resonance filters + pluck noise

### Strings
- Bow noise (aperiodic), ensemble detune, delayed vibrato
- **Synthesis approach**: Filtered noise + multiple detuned voices + vibrato LFO

### Brass
- Lip buzz (rich harmonics), breath noise, valve clicks
- **Synthesis approach**: Saw + filter envelope + breath noise generator

### Choir
- Formant peaks ("ah": ~800Hz, ~1200Hz; "oo": lower)
- Multiple voices, natural beat frequencies
- **Synthesis approach**: Formant filter + rich source + ensemble detune

### Drums
- Kick: deep punch, short decay
- Snare: crack + wire rattle
- Hats: tight closed, shimmering open
- **Synthesis approach**: Current algorithms are good for electronic; need room reverb for acoustic feel

## Improvement Roadmap

### Phase 1: Quick Wins (No C++ Work)
1. Rewrite piano presets with FM transient + noise burst
2. Rewrite organ presets with multiple sine oscillators (drawbar emulation)
3. Add rotary effect to organ presets
4. Improve wavetable harmonic content (16+ harmonics, inharmonicity)
5. Add velocity-sensitive parameters (filter, attack, noise)

### Phase 2: New Synthesis Modes (C++ Engine)
1. **FM synthesis** — For EPiano, bells, mallets
2. **Drawbar organ oscillator** — 9 sine waves with individual levels
3. **Formant filter** — For choir/voice (vowel morphing)
4. **Body resonance** — Extend Karplus-Strong for guitar
5. **Bow/breath noise generators** — For strings and brass

### Phase 3: Hybrid Sample+Synthesis (Major Architecture)
- Short attack samples crossfaded to synthesis sustain
- Much smaller than full PCM library (~50MB vs ~500MB)
- Best of both worlds: real transients + synthetic flexibility

### Phase 4: Full PCM Sample Engine
- SFZ/SoundFont support
- Multi-sample mapping with velocity layers
- Turns OpenSynth from ~10MB synth into ~500MB sample player
- Fundamentally changes project character

## Recommendation

Pursue Phase 1 immediately (preset rewrites). Phase 2 next (new synthesis modes). Evaluate Phase 3 after Phase 2. Phase 4 only if the project direction shifts toward sample playback.
