# Music Generation Workflows

## Workflow Comparison

| Method | Speed | Control | Quality | Best For |
|--------|------|---------|---------|----------|
| **Suno/Udio** | ⚡⚡⚡ | Low | Great | Full vocal tracks, quick drafts |
| **MusicGen (local)** | ⚡⚡ | Medium | Great | Prompt engineering, no cloud dependency |
| **MusicGen + DAW** | ⚡ | High | Excellent | Extended tracks, professional mixing |
| **Sonic Pi** | ⚡⚡ | Full | Good | Live coding, generative, infinite variation |
| **MIDI + VSTs** | ⚡ | Maximum | Excellent | Professional production, exact sound |

---

## Workflow 1: Quick Draft (Suno/Udio)

### When to Use
- Need full track with vocals quickly
- Don't have GPU or local setup
- Want to test ideas before committing to local generation

### Process
1. Open Suno (suno.com) or Udio (udio.com)
2. Craft prompt using synthwave prompt engineering techniques
3. Generate 2-4 variations
4. Download best version
5. Iterate on prompt if needed

### Tips
- **Suno**: Best for vocal tracks with lyrics
- **Udio**: Higher audio quality, better for instrumentals
- Add specific production terms: "gated reverb", "analog warmth", "tape saturation"
- Specify tempo: "118 BPM", "driving beat"
- Use subgenre keywords: "outrun", "darksynth", "dreamwave"

### Example Prompt
```
80s synthwave driving music, gated reverb snare, analog bass guitar, 
arpeggiated synth lead, night highway atmosphere, sports car, neon lights
 118 BPM, Kavinsky Nightcall style
```

---

## Workflow 2: Local Generation (MusicGen)

### When to Use
- Want full control over generation
- Have GPU with 16GB+ VRAM (for medium model)
- Want to iterate quickly on prompts
- Don't want cloud dependency

### Setup

```bash
# Install dependencies
pip install transformers scipy torchaudio

# Download model (first run only)
python -c "from transformers import AutoProcessor, MusicgenForConditionalGeneration; \
processor = AutoProcessor.from_pretrained('facebook/musicgen-medium'); \
model = MusicgenForConditionalGeneration.from_pretrained('facebook/musicgen-medium')"
```

### Process
1. Use `scripts/musicgen_generate.py` or direct Python
2. Craft prompt with essential synthwave elements
3. Run generation (30 seconds typical)
4. Listen to output, iterate
5. Refine prompt based on results

### Tips
- **Model selection**: 
  - `musicgen-small` (300M, ~4GB VRAM) - Fast, good quality
  - `musicgen-medium` (1.5B, ~16GB VRAM) - Best balance
  - `musicgen-large` (3.3B, ~32GB VRAM) - Highest quality
  - `musicgen-melody` (1.5B, ~16GB VRAM) - Melody conditioning
- **Parameters**:
  - `guidance_scale`: 3.0 (default) - balance of prompt adherence vs quality
  - `temperature`: 1.0 (default) - higher = more creative/random
  - `top_k`: 250 (default) - limits token choices
  - `duration`: 30 seconds max (1503 tokens)

### Example Command
```bash
python scripts/musicgen_generate.py \
  --prompt "80s synthwave outrun driving music, gated reverb drums, analog bass" \
  --duration 30 \
  --output outrun_track.wav \
  --model-size medium
```

---

## Workflow 3: Hybrid (MusicGen + DAW)

### When to Use
- Want extended tracks (> 30 seconds)
- Need professional mixing and production
- Want to combine AI generation with human creativity

### Process
1. Generate stems with MusicGen:
   - Drums only
   - Bass only
   - Synth pads only
   - Lead melody only
2. Import stems into DAW (Ableton, Reaper, Logic, etc.)
3. Arrange and extend structure
4. Mix and add production:
   - EQ, compression, reverb
   - Additional layers
5. Master final track

### Tips
- Generate longer stems than needed (can always shorten)
- Use consistent tempo across all stems
- Sidechain bass to kick for pumping
- Reference against commercial synthwave tracks
- Export at -14 LUFS for streaming

### DAW Recommendations
- **Ableton Live**: Best for electronic music, clip launching, flexible
- **Reaper**: Free, lightweight, great for audio editing
- **Logic Pro**: Professional, built-in synths
- **FL Studio**: Pattern-based workflow

---

## Workflow 4: Generative (Sonic Pi)

### When to Use
- Want infinite variation
- Live performance or improvisation
- Want to learn code-based music
- Don't need final polished tracks

### Setup

```bash
# Linux
sudo apt install sonic-pi

# macOS
brew install --cask sonic-pi

# Windows
Download from sonic-pi.net
```

### Process
1. Open Sonic Pi application
2. Load template from `scripts/sonic_pi_template.rb`
3. Modify parameters:
   - BPM
   - Key/scale
   - Synth choices
   - Effects
4. Run and listen
5. Tweak live
6. Record output

### Tips
- **Live loops**: Each instrument in its loop for independent variation
- **Randomization**: Use `rrand()` and `.choose` for variation
- **Effects chain**: Build complex effects for 80s sound
- **Recording**: Use Sonic Pi's built-in recorder or external tool

### Key Concepts
- `use_bpm`: Set tempo
- `live_loop`: Create repeating patterns
- `use_synth`: Select synthesizer
- `with_fx`: Add effects
- `play` / `sample`: Trigger sounds
- `sleep`: Control timing

---

## Workflow 5: Professional (MIDI + VSTs)

### When to Use
- Need highest quality output
- Have extensive VST library
- Want complete control over every element
- Producing for commercial release

### Tools Needed
- **DAW**: Ableton, Logic, Reaper
- **VSTs**:
  - Serum (Xfer Synth) - Modern synthwave
  - Vital (Free) - Wavetable synth
  - Diva (Analog modeling) - Juno-106, Jupiter-8
  - Pigments (Hybrid) - Versatile
  - Spire (Free) - Linux compatible

### Process
1. Generate MIDI:
   - Use AIVA (aiva.com) for classical/film
   - Or write Python script with music21
2. Import MIDI into DAW
3. Assign VSTs to tracks:
4. Program synth patches
5. Mix and produce
6. Master at -14 LUFS

### Tips
- **MIDI generation**: Focus on chord progressions and melodies
- **Sound design**: Layer multiple synths for rich textures
- **Mixing**: Reference professional synthwave tracks
- **Mastering**: Use proper loudness standards

---

## Production Checklist

### Pre-Production
- [ ] Choose subgenre and tempo range
- [ ] Plan structure (intro, verse, chorus, bridge, outro)
- [ ] Select reference tracks for study

### Sound Design
- [ ] Design synth patches (Serum, Vital, etc.)
- [ ] Create drum patterns (808, gated reverb)
- [ ] Craft bass lines (analog, sidechained)
- [ ] Layer pads and textures

### Mixing
- [ ] High-pass filter non-bass (80-100 Hz)
- [ ] Sidechain bass to kick
- [ ] Stereo width on pads
- [ ] Reverb depth on snare
- [ ] EQ cuts/boosts as needed

### Mastering
- [ ] Reference at -14 LUFS (streaming)
- [ ] Check on multiple systems
- [ ] Ensure no clipping
- [ ] Final A/B comparison

---

## Troubleshooting

### MusicGen Issues

**Problem**: Out of memory error
- **Solution**: Use smaller model or reduce duration, close other apps

**Problem**: Poor quality output
- **Solution**: Increase guidance_scale (up to 5), try different prompt, use melody conditioning

**Problem**: Too repetitive
- **Solution**: Increase temperature (1.2-1.5), add more creative descriptors

### Sonic Pi Issues

**Problem**: Audio clipping
- **Solution**: Reduce amp levels, use limiter

**Problem**: Timing drift
- **Solution**: Use `sync` for precise timing, reduce CPU load

**Problem**: Harsh sounds
- **Solution**: Add effects (reverb, lpf), adjust filter cutoff

---

## Best Practices

1. **Always reference professional tracks** in your target style
2. **Generate multiple versions** of each prompt (3-5 variations)
3. **A/B test prompts** - small changes can big differences
4. **Save intermediate files** - stems, alternate takes, unused generations
5. **Document what works** - build personal prompt library
6. **Trust your ears** - if it sounds good, it is good
 regardless of theory

---

*"The future is synthesized."* 🎹🦞
