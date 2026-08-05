# SYNTHWAVE PRODUCTION CHEAT-SHEET (for Sonic Pi composition)

Notation: 16-step grid = one bar of 4/4 sixteenth notes. `X` = hit, `x` = soft/ghost hit, `.` = rest.
Step indices below each grid: beat 1 = steps 1-4, beat 2 = 5-8, beat 3 = 9-12, beat 4 = 13-16.
Sonic Pi mapping: `steps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0].ring`, then `sample :bd_haus if steps.tick == 1`, `sleep 0.25`.

---

## 1. TEMPO BY SUBGENRE

| Subgenre   | BPM range | Sweet spot | Feel / reference |
|------------|-----------|------------|------------------|
| Outrun     | 100–118   | 104–112    | Driving, 4-on-floor. Kavinsky "Nightcall" ~104, Perturbator mid-tempo ~110 |
| Darksynth  | 100–130   | 115–125    | Aggressive; half-time drums at higher BPM feel heavier. Carpenter Brut ~120+ |
| Dreamwave  | 80–100    | 88–96      | Lush, romantic. FM-84 "Running in the Night" ~92, Timecop1983 ~90 |
| Chillsynth | 70–90     | 75–85      | Ambient-adjacent, sparse. HOME "Resonance" ~85 |
| Spacewave/scifi | 90–110 | 100       | Tangerine Dream sequencing territory |

Rule of thumb: pick BPM first, it dictates grid density. Below 95 BPM use 8th-note hats; above 100 use 16th hats or they feel sluggish. At 100 BPM one bar = 2.4 s; a 3.5-min track ≈ 88 bars.

---

## 2. DRUMS

### Core patterns (16-step)

**A. Classic outrun / pop pattern (the genre default)**
```
Kick : X . . . | X . . . | X . . . | X . . .    (four-on-floor)
Snare: . . . . | X . . . | . . . . | X . . .    (backbeat 2 & 4)
Clap : . . . . | X . . . | . . . . | X . . .    (layer ON snare, slightly quieter)
CHat : X . X . | X . X . | X . X . | X . X .    (8ths; accent the offbeats)
OHat : . . X . | . . X . | . . X . | . . X .    (open hat on "and", optional)
```

**B. 16th-hat drive (faster outrun / darksynth, 110+ BPM)**
```
Kick : X . . . | X . . . | X . . . | X . . .
Snare: . . . . | X . . . | . . . . | X . . .
CHat : X x X x | X x X x | X x X x | X x X x   (accent downbeats, ghost offbeats)
```

**C. Syncopated kick (slower BPM < 100, adds groove)**
```
Kick : X . . . | . . X . | . . X . | X . . .
Snare: . . . . | X . . . | . . . . | X . x .   (ghost snare step 15)
CHat : X . X . | X . X . | X . X . | X . X .
```

**D. Half-time darksynth stomp**
```
Kick : X . . . | . . . . | . . X . | . . . .
Snare: . . . . | . . . . | X . . . | . . . .   (huge snare on beat 3 only)
CHat : X x X x | X x X x | X x X x | X x X x
```

**E. Darksynth double-kick gallop (metal influence)**
```
Kick : X . X . | . . X . | X . X . | . . X .
Snare: . . . . | X . . . | . . . . | X . . .
```

**F. Chill/dreamwave sparse (75–90 BPM)**
```
Kick : X . . . | . . . . | X . . . | . . . .
Snare: . . . . | X . . . | . . . . | X . . .
CHat : . . X . | . . X . | . . X . | . . X .   (offbeat-only hats = laid back)
```

Fills: every 8 or 16 bars — snare 16th roll on last bar (`x x x x | x x x x | x x x x | x x x x` crescendo), or tom fill descending steps 13–16. Crash cymbal on step 1 of each new section.

### Gated reverb snare (THE signature sound)
Origin: Phil Collins "In the Air Tonight" (1981), AMS RMX16 "NonLin" program.
Technique: send snare into a HUGE reverb (plate/hall, 2–4 s decay, 100% wet on the send), then chop the reverb tail with a noise gate ~0.2–0.4 s after the hit. Result: massive explosive "BOOM" that vanishes instantly — punch + size without mud.
Sonic Pi approximation (no true gate FX): keep dry snare centered; layer a short-decay white-noise hit (release 0.2–0.3 s) through heavy reverb, triggered with the snare:
```ruby
sample :sn_dolf, amp: 0.85          # dry hit
with_fx :reverb, room: 0.9, damp: 0.3, mix: 0.9 do
  synth :noise, release: 0.22, cutoff: 105, amp: 0.55
end
```
Darksynth: exaggerate — longer burst (0.3–0.35), lower cutoff (~70–80).

### Classic drum machines & sonic character
| Machine | Year | Type | Character | Signature users/use |
|---|---|---|---|---|
| LinnDrum (LM-2) | 1982 | 12-bit samples | Crisp, punchy, tight snare; THE 80s pop machine | Prince, Madonna; gated-snare archetype |
| Roland TR-808 | 1980 | Analog synth | Boomy sub kick w/ long pitch-decay, thin snappy snare, cowbell, clap | Hip-hop/electro; modern synthwave sub-kick |
| Oberheim DMX | 1981 | 8-bit samples | Aggressive, gritty punch | New Order "Blue Monday", early hip-hop |
| Linn LM-1 | 1980 | 12-bit samples | Raw, looser timing, Prince's sound | Prince |
| Simmons SDS-V | 1981 | Analog synth pads | Hexagonal pads, "doo-doo" tom swoops | Tom fills, instantly 1983 |
| Roland TR-707/727 | 1985 | 12-bit samples | Clean, house-adjacent | Sleeker synthwave/dreamwave |
| E-mu Drumulator | 1983 | 8-bit samples | Dry, hard, punchy | Depeche Mode, Cocteau Twins |

Practical layer recipe: 808-style sub kick (long decay) + LinnDrum-style mid "knock" layered on same grid; Linn/DMX snare + clap stack; Simmons tom for fills.

---

## 3. BASS

### Patterns (all on chord root unless noted; R=root, 5=fifth, O=octave-up root)

**Driving 8ths (outrun default):** root every 8th note
```
R . R . | R . R . | R . R . | R . R .
```
**16th-note engine (darksynth / high energy):**
```
R R R R | R R R R | R R R R | R R R R    (mono, short release 0.08–0.12 s)
```
**Octave bounce (classic disco/outrun):**
```
R . O . | R . O . | R . O . | R . O .
R . O R | O . R . | R . O . | R O . .    (variation)
```
**Root-5-octave arp bass:**
```
R . 5 . | O . 5 . | R . 5 . | O . . .
```
**Chord-tone 16th arp (per chord, cycle degrees 1-5-8-5):**
```
R 5 O 5 | R 5 O 5 | R 5 O 5 | R 5 O 5
```
**Sparse chill bass:** whole/half notes on roots, or `R . . . | . . . . | 5 . . . | . . . .`

### Bass patch design
- Oscillators: 2 saws detuned ±5–10 cents (Sonic Pi: two `:saw` plays a few cents apart, or `:dsaw` with `detune: 0.1`). Add sine/triangle sub one octave below at −6 dB for weight.
- Filter: 24 dB/oct low-pass. Static driving bass: cutoff 60–85 (Sonic Pi scale), res 0.3–0.5.
- Pluck bass: filter envelope — attack 0, decay 0.15–0.3, sustain ~0.2; this "wow" transient is the 80s bass bite. In Sonic Pi: `cutoff:` base 55–65 with `cutoff_slide:` — or `:dsaw` with short `release:` and higher-cutoff accent steps.
- Amp envelope: attack 0.001–0.005, release just under note length (16ths → release 0.1; 8ths → 0.2) so notes don't blur. Mono voice, slight legato glide for movement.
- Octave doubling: keep sub strictly mono + centered.
- Cutoff automation arc: closed (55–70) in verses, open (90–115) on the drop; slow 4–8 bar `cutoff_slide` ramps during builds.

---

## 4. HARMONY

All Roman numerals relative to natural minor (aeolian). Canon progressions, with A minor spellings:

| Progression | In A minor | Character / use |
|---|---|---|
| i–VI–III–VII | Am–F–C–G | THE outrun progression. Nostalgic-heroic. Kavinsky, Gunship |
| i–VII–VI–VII | Am–G–F–G | Andalusian-flavored loop; darksynth workhorse, driving |
| i–VI–VII | Am–F–G | Simple 3-chord pump; Stranger Things-adjacent |
| iv–i (or i–iv) | Dm–Am | Dark, unresolved; horror/darksynth tension. Alternate iv–i–VII–VI |
| i–III–VII–VI | Am–C–G–F | Brooding cinematic |
| VI–VII–i | F–G–Am | Build/tension loop into drop |
| i–iv–VI–V | Am–Dm–F–E(major) | The V major (harmonic minor) adds drama — use sparingly, very "epic darksynth" |
| vi–IV–I–V (rel. major) | Am–F–C–G | Dreamwave's pop lift; i–VI–III–VII re-voiced with major-key emphasis |
| i–bII (Phrygian) | Am–Bb | Menace flavor; sprinkle into darksynth intros |

### Color chords (this is what separates synthwave from generic EDM)
- On III and VI: **maj7** and **maj9** — Cmaj7, Fmaj7, Fmaj9. Instant melancholy-glow.
- On VII: **sus2/sus4** or add9 — Gsus2, Gadd9.
- On i and iv: **m7, m9** — Am9, Dm7. m9 (root–b3–5–b7–9) is THE dreamwave chord.
- **sus2 arpeggiated** = instant 80s intro.
- Voice-leading trick: hold a common tone on top across the loop (e.g., keep E ringing through Am–F–C–G) — pads become cohesive instantly.
- Slash-bass walk: Am → F/A... or run bass R–5–7–8 under static chord for motion.

### Common keys
Minor keys dominate (~90% of the genre). Most common: **A minor** (white keys, bass A1 in sub sweet spot), **C minor** (Stranger Things), **D minor**, **E minor**, **F minor**. Darksynth leans Eb/C# minor; dreamwave often F minor or Bb minor for warmth. Practical: choose key so the bass root sits :a1–:d2 — below that = mud, above = thin.

---

## 5. LEAD / MELODY

- **Portamento saw lead** (the anthem voice): mono `:saw`/`:prophet`-style, glide 50–150 ms between notes (`note_slide: 0.08–0.25` beats), vibrato LFO ~5–6 Hz depth 10–30 cents delayed ~300 ms into held notes, low-pass cutoff 90–110. Doubled an octave up, quiet, for shine. Delay: dotted-8th.
- **Pluck**: saw/square, amp env A 0 / D 0.1–0.25 / S 0 / R 0.1, filter env mirroring with cutoff base 70–95. Rhythmically interlock with bass (play offbeats the bass skips).
- **Bell (DX7-style FM)**: Sonic Pi `:fm` or `:pretty_bell`; try divisor 2–4, depth 0.5–2, release 1.5–3 s, big reverb, low velocity. Sparse — one or two notes per bar max.
- **Arpeggiator**: 16ths cycling chord tones up-down (`R 3 5 O 5 3`) or up over 2 octaves; gate time 40–60% of step; automate cutoff opening over 4 bars. Layer arp one octave above the pad, not in lead register.
- Melodic grammar: pentatonic minor (1-b3-4-5-b7) for 90% of leads; land on chord tones at bar lines; long held note + vibrato at phrase ends; call-and-response between lead and arp. Darksynth: add b2 and tritone passing tones. Dreamwave: major pentatonic of the relative major over i–VI–III–VII.

---

## 6. FX / MIX

- **Sidechain pump**: duck bass + pads (NOT drums, NOT lead) on every kick. Depth 30–60% gain reduction, attack <5 ms, release ~1/8–1/4 note. Sonic Pi has no true sidechain — use `with_fx :slicer, phase: 1, wave: 0, invert_wave: 1, amp_min: 0.2–0.35, smooth_up: 0.1`.
- **Chorus**: Juno-60 style on pads/keys — rate 0.5–1.5 Hz, depth 20–40%, mix 30–50%. Sonic Pi `with_fx :flanger` approximates vintage chorus at low feedback (depth 2–3, feedback 0.05–0.1). Keep bass chorus-free.
- **Delay**: dotted-8th ping-pong on leads (feedback 25–35%, mix 15–25%); slapback 80–120 ms on plucks; tempo-sync everything (`phase: 0.375` = dotted 8th).
- **Reverb**: big hall/plate on snare (gated, see §2); medium hall 1.5–2.5 s on pads; small room or none on bass/kick — low-end reverb = mud. High-pass reverb returns ~250 Hz.
- **Tape saturation / vintage**: gentle drive (`with_fx :distortion, distort: 0.2–0.4`), high-shelf rolloff above ~10–12 kHz (`cutoff ~110–115` on the master bus), subtle wow/flutter = slow random pitch drift ±6 cents on pads (`control p, notes: ch.map { |n| n + rdist(0, 0.06) }`). Vinyl crackle (`:vinyl_hiss`, amp ~0.12) for chill tracks.
- **Stereo width**: everything below ~120 Hz MONO (kick, sub, bass). Pads/leads wide via chorus, detune (two plays panned ±0.4), or Haas. Snare center. Arps slightly off-center (pan 0.2–0.4). Mid/side check: the mix should still punch when summed to mono.

---

## 7. SONG STRUCTURE (3–4 min template, ~100 BPM, ≈ 84–92 bars)

| Section | Bars | Time @104 BPM | Contents |
|---|---|---|---|
| Intro | 8 | ~18 s | Pad + arp fades in (cutoff rising), filtered drums (lowpassed kick/hat only), maybe bell motif. No snare or gated verb only |
| Verse A | 16 | ~37 s | Full drum pattern A, driving bass enters, pad holds chords. No lead yet |
| Build | 4–8 | ~14 s | Snare builds to 16ths, cutoff opening on bass+arp, riser noise, drop kick out last bar, crash into… |
| Drop / Main theme | 16 | ~37 s | Everything: lead melody, pattern B drums, widest mix, cutoff fully open |
| Breakdown | 8 | ~18 s | Strip to pad + bell + half drums; introduce variation chords (maj7 colors) |
| Build 2 | 4–8 | ~14 s | Faster ramp than Build 1; tom fill (Simmons) into… |
| Drop 2 / Final | 16 | ~37 s | Lead + counter-arp octave up; biggest section |
| Outro | 4–8 | ~12 s | Elements exit in reverse order of entry; last sound = pad or reverb tail |

Variation tricks: half-time drums in breakdown (pattern D); remove bass for 2 bars mid-drop ("fake-out"); modulate loop up a whole step in final 8 bars (classic 80s move).

---

## 8. FIVE-TRACK EP BLUEPRINT (one recipe per subgenre)

1. **Outrun anthem** — 108 BPM, A minor, i–VI–III–VII, pattern A drums, octave-bounce bass, portamento saw lead, big gated snare.
2. **Darksynth** — 120 BPM, C# minor, i–VII–VI–VII with iv–i bridge, pattern E drums, 16th-engine bass cutoff 65, distorted lead, Phrygian b2 in intro.
3. **Dreamwave ballad** — 92 BPM, F minor, i(m9)–VImaj7–IIImaj7–VIIsus2, pattern F drums, sparse 8th bass, DX7 bells + slow arp, sax-like lead (:blade).
4. **Chillsynth** — 78 BPM, D minor, i–VI loop with m9 colors, pattern F sparser, half-note sub bass, pad-forward, vinyl crackle, dotted-8th delay bells, minimal percussion.
5. **Spacewave sequencer piece** — 100 BPM, E minor, VI–VII–i, 16th chord-tone arp bass as the lead voice, no snare until bar 33, Tangerine Dream-style evolving cutoff ramps.
