---
name: music-gen
description: AI-powered music generation specializing in synthwave and electronic genres. Use when creating music tracks, generating audio from text prompts, writing Sonic Pi code for live coding, creating MIDI compositions, or producing synthwave/retrowave/darksynth/cyberpunk/spacewave music. Triggers include requests to "make music", "generate a track", "write synthwave", "create audio", "compose music", "AI music generation", or any music production task.
---

# Music Generation Skill

Generate music using AI tools and code-based composition, with specialization in synthwave aesthetics.

## Generation Paradigms

| Paradigm | Description | Best For |
|----------|-------------|----------|
| **Text-to-Audio** | Full waveform from prompt | Quick drafts, inspiration, full tracks |
| **Text-to-MIDI** | Symbolic music generation | DAW integration, precise control |
| **Audio Continuation** | Extend existing audio | Completing ideas, variations |
| **Code-based** | Programmatic composition | Live coding, generative, infinite variation |

## Quick Start

### Option 1: Text-to-Audio (Suno/Udio/MusicGen)

```
"80s synthwave driving music, gated reverb drums, warm analog bass, 
arpeggiated synth lead, night highway atmosphere, 118 BPM, outrun style"
```

**MusicGen Parameters:**
| Parameter | Range | Effect |
|-----------|-------|--------|
| `guidance_scale` | 1-5 | Higher = more prompt adherence, lower quality (default: 3) |
| `temperature` | 0.5-1.5 | Higher = more random/creative (default: 1.0) |
| `top_k` | 0-250 | Limits token choices (default: 250) |
| `top_p` | 0-1 | Nucleus sampling (default: 0.95) |
| `max_new_tokens` | 1-1503 | ~50 tokens/sec (1503 = 30 sec max) |

### Option 2: Sonic Pi (Live Coding)

```ruby
use_bpm 118

live_loop :drums do
  sample :drum_heavy_kick
  sleep 0.5
  sample :drum_snare_hard, amp: 0.8
  sleep 0.5
end

live_loop :bass do
  use_synth :tb303
  play :e2, release: 0.4, cutoff: 80, wave: 1
  sleep 0.25
end
```

### Option 3: MusicGen Python Script

```bash
python scripts/musicgen_generate.py --prompt "synthwave track" --duration 30
```

## Platform Comparison

### Commercial Services

| Platform | Strengths | Limitations | Best For |
|----------|-----------|-------------|----------|
| **Suno** | Best vocal handling, full songs | 2-min max, watermark on free | Vocal tracks, quick drafts |
| **Udio** | High quality, genre flexibility | Subscription required | High-quality instrumentals |
| **Stable Audio** | Stability AI, good for SFX | Shorter generations | Sound design, short clips |
| **AIVA** | Classical/film scoring | Limited electronic styles | Orchestral, film scoring |

### Open-Source / Local

| Model | VRAM Required | Quality | Best For |
|-------|--------------|---------|----------|
| `musicgen-small` | ~4GB | Good | Fast iteration, testing |
| `musicgen-medium` | ~16GB | Great | Production quality |
| `musicgen-large` | ~32GB | Excellent | Maximum quality |
| `musicgen-melody` | ~16GB | Great + conditioning | Melody-guided generation |

## Synthwave Subgenres

| Style | BPM | Key Elements | Mood |
|-------|-----|--------------|------|
| **Outrun** | 110-120 | Driving beat, neon, highway, analog bass | Energetic, driving |
| **Darksynth** | 90-110 | Horror, distorted, aggressive, minor key | Tense, cinematic |
| **Dreamwave** | 80-100 | Chill, lo-fi, nostalgic, soft pads | Relaxed, wistful |
| **Cyberpunk** | 120-140 | Glitch, industrial, futuristic | Aggressive, tech |
| **Spacewave** | 70-90 | Cosmic, ethereal, ambient, evolving | Floating, meditative |
| **Retrowave** | 100-120 | Vintage, cassette, VHS warmth | Nostalgic, retro |

## Prompt Engineering

### Essential Synthwave Elements

**Drums:**
- Gated reverb snare (signature 80s sound)
- 808 kick drums
- Electronic toms
- Hi-hat patterns (16th notes)
- Rim shots

**Bass:**
- Analog bass (Juno-106, Minimoog style)
- Arpeggiated bass lines
- Sub-bass frequencies (40-80 Hz)
- Sidechain compression to kick

**Synths:**
- Warm pads (strings, brass)
- Bright leads (DX7 bells, FM sounds)
- Arpeggios (16th note patterns)
- Portamento/glide between notes
- Filter sweeps (cutoff automation)

**FX:**
- Large reverb (plate, hall)
- Tape delay
- Chorus/ensemble
- Vinyl crackle (lo-fi aesthetic)
- VHS static (retro texture)

**Atmosphere:**
- Night driving feel
- Neon cityscapes
- Retro-futuristic
- Nostalgic longing
- Cinematic tension

### Prompt Construction Formula

```
[Era] [Genre] [Drums] [Bass] [Synths] [Atmosphere] [Tempo] [Reference]
```

Example:
```
"80s synthwave driving music, gated reverb snare, analog bass guitar, 
arpeggiated synth lead, night highway atmosphere, 118 BPM, Kavinsky style"
```

### Prompt Templates

See [references/prompts.md](references/prompts.md) for complete prompt library covering all subgenres.

## Code-Based Generation

### Sonic Pi

**Recommended Synths:**
- `:tb303` - Analog bass
- `:prophet` - Warm pads
- `:hollow` - Ethereal pads
- `:fm` - FM bells

**Recommended FX:**
- `:reverb, mix: 0.6-0.8, room: 0.9` - Large space
- `:echo, phase: 0.375, decay: 2` - Tape delay feel
- `:lpf, cutoff: 60-100` - Warm filtering
- `:distortion, distort: 0.2-0.4` - Grit

### Python + MusicGen

**Installation:**
```bash
pip install transformers scipy torchaudio
```

**Basic Usage:**
```python
from transformers import AutoProcessor, MusicgenForConditionalGeneration
import scipy.io.wavfile as wavfile

processor = AutoProcessor.from_pretrained("facebook/musicgen-medium")
model = MusicgenForConditionalGeneration.from_pretrained("facebook/musicgen-medium")

inputs = processor(text=["synthwave track"], padding=True, return_tensors="pt")
audio_values = model.generate(**inputs, do_sample=True, guidance_scale=3, max_new_tokens=512)

sampling_rate = model.config.audio_encoder.sampling_rate
wavfile.write("output.wav", rate=sampling_rate, data=audio_values[0, 0].numpy())
```

**Use `scripts/musicgen_generate.py` for command-line generation.**

## Workflows

| Workflow | Tools | Best For | Control |
|----------|-------|----------|---------|
| **Quick Draft** | Suno/Udio | Full vocal tracks, fast | Low |
| **Local AI** | MusicGen | Instrumentals, prompt control | Medium |
| **Hybrid** | MusicGen + DAW | Extended tracks, mixing | High |
| **Generative** | Sonic Pi | Live coding, infinite variation | Full |
| **MIDI + VST** | AIVA + Serum | Pro production, Maximum |

See [references/workflows.md](references/workflows.md) for detailed workflow guides.

## Synthwave Production Checklist

### Drums
- [ ] Gated reverb on snare (mix: 0.6-0.8, room: 0.9)
- [ ] 808-style kick (punchy, sidechain)
- [ ] 16th note hi-hats (electronic feel)
- [ ] Electronic toms (pitch descending)

### Bass
- [ ] Analog-style sound (warm, rounded)
- [ ] Arpeggiated patterns (16th notes)
- [ ] Sidechain to kick (ducking)
- [ ] Sub frequencies present (40-80 Hz)

### Synths
- [ ] Warm pads (strings/brass)
- [ ] Arpeggiated lead (16th note patterns)
- [ ] Filter sweeps (cutoff automation)
- [ ] Portamento on leads (glide)

### FX
- [ ] Large reverb (plate/hall, mix: 0.5-0.7)
- [ ] Tape delay on leads (phase: 0.375)
- [ ] Chorus on pads (mix: 0.3-0.5)
- [ ] Optional: Vinyl/VHS texture (lo-fi)

### Mix
- [ ] High-pass filter non-bass elements (80-120 Hz)
- [ ] Stereo width on pads (wide)
- [ ] Reference against genre tracks (Kavinsky, The Midnight)
- [ ] Loudness: -14 LUFS for streaming

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/musicgen_generate.py` | Generate audio from text prompts | `python musicgen_generate.py --prompt "outrun" --duration 30` |
| `scripts/sonic_pi_template.rb` | Synthwave template for live coding | Load in Sonic Pi, modify parameters |

## References

| File | Contents |
|------|----------|
| `references/prompts.md` | Complete prompt library for all synthwave subgenres |
| `references/workflows.md` | Detailed workflow guides for each production method |

## Reference Tracks

| Artist | Track | Style |
|--------|-------|-------|
| Kavinsky | Nightcall | Outrun, cinematic |
| The Midnight | Days of Thunder | Dreamwave, nostalgic |
| Perturbator | She Is Young... | Darksynth, aggressive |
| Carpenter Brut | Roller Mobster | Darksynth, driving |
| Gunship | Tech Noir | Retrowave, vocal |
| Home | Resonance | Spacewave, ethereal |
