# Procedural WAV Generation for Bevy Audio

Full working implementation from retro-spec's `src/audio.rs`. Generates a synthwave ambient drone as a 16-bit PCM WAV file in memory, then plays it via Bevy's AudioPlugin.

## WAV Structure

A WAV file has three sections:
1. **RIFF header** (12 bytes): "RIFF" + file size + "WAVE"
2. **fmt chunk** (24 bytes): "fmt " + chunk size + format tag + channels + sample rate + byte rate + block align + bits per sample
3. **data chunk** (8 + N bytes): "data" + data size + raw PCM samples

## Full Rust Implementation

```rust
use bevy::prelude::*;
use bevy::audio::{AudioPlayer, AudioSource, PlaybackMode, PlaybackSettings};
use std::sync::Arc;

fn generate_synthwave_wav(sample_rate: u32, duration_secs: f32) -> Vec<u8> {
    let num_samples = (sample_rate as f32 * duration_secs) as usize;
    let mut samples = Vec::with_capacity(num_samples);

    // Synthwave drone: sub-bass + fifth + pad + shimmer
    let base_freq = 55.0;   // A1
    let pad_freq = 220.0;   // A3
    let shim_freq = 440.0;  // A4

    for i in 0..num_samples {
        let t = i as f32 / sample_rate as f32;

        let bass = (t * base_freq * std::f32::consts::TAU).sin() * 0.3;
        let fifth = (t * base_freq * 1.5 * std::f32::consts::TAU).sin() * 0.12;

        // Pad with slow LFO wobble
        let pad_mod = (t * 0.08).sin() * 0.3 + 0.7;
        let pad = (t * pad_freq * std::f32::consts::TAU).sin() * 0.15 * pad_mod;

        // Shimmer with faster modulation
        let shim_mod = (t * 0.25).sin() * 0.5 + 0.5;
        let shim = (t * shim_freq * std::f32::consts::TAU).sin() * 0.06 * shim_mod;

        let sample = (bass + fifth + pad + shim).tanh(); // soft clip
        samples.push(sample);
    }

    // ── Pack as 16-bit PCM WAV ──
    let bits_per_sample = 16u16;
    let channels = 1u16;
    let byte_rate = sample_rate * channels as u32 * (bits_per_sample / 8) as u32;
    let block_align = channels * (bits_per_sample / 8);
    let data_size = num_samples as u32 * block_align as u32;

    let mut wav = Vec::with_capacity(44 + data_size as usize);

    // RIFF header
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + data_size).to_le_bytes());
    wav.extend_from_slice(b"WAVE");

    // fmt chunk
    wav.extend_from_slice(b"fmt ");
    wav.extend_from_slice(&16u32.to_le_bytes());  // chunk size
    wav.extend_from_slice(&1u16.to_le_bytes());   // PCM = 1
    wav.extend_from_slice(&channels.to_le_bytes());
    wav.extend_from_slice(&sample_rate.to_le_bytes());
    wav.extend_from_slice(&byte_rate.to_le_bytes());
    wav.extend_from_slice(&block_align.to_le_bytes());
    wav.extend_from_slice(&bits_per_sample.to_le_bytes());

    // data chunk
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&data_size.to_le_bytes());

    // Write 16-bit PCM samples
    for &s in &samples {
        let clamped = s.clamp(-1.0, 1.0);
        let val = (clamped * i16::MAX as f32) as i16;
        wav.extend_from_slice(&val.to_le_bytes());
    }

    wav
}
```

## Playing the Audio

```rust
pub fn setup_audio(mut commands: Commands, mut audio_assets: ResMut<Assets<AudioSource>>) {
    let wav_bytes = generate_synthwave_wav(44100, 300.0); // 5 minutes
    let source = AudioSource { bytes: wav_bytes.into() };
    let handle = audio_assets.add(source);

    commands.spawn((
        AudioPlayer::new(handle),
        PlaybackSettings {
            mode: PlaybackMode::Loop,
            ..Default::default()
        },
    ));
}
```

## Cargo.toml Requirement

```toml
bevy = { version = "0.15", features = ["wav"] }
```

The `wav` feature is NOT enabled by default (only `vorbis` for OGG is). Without it, `rodio::Decoder` will panic with `UnrecognizedFormat`.

## Synthwave Palette Used

- Sub-bass: 55Hz (A1), 30% volume
- Fifth: 82.5Hz (E2), 12% volume
- Pad: 220Hz (A3), 15% with 0.08Hz LFO wobble
- Shimmer: 440Hz (A4), 6% with 0.25Hz LFO
- Soft clipped with `.tanh()` to prevent harshness
