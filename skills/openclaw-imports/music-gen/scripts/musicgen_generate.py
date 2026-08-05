#!/usr/bin/env python3
"""
MusicGen generation script for synthwave music.
Requirements: pip install transformers scipy torchaudio

Usage:
    python musicgen_generate.py --prompt "outrun" --output track.wav --duration 30
    python musicgen_generate.py --prompt "dark synthwave horror" --model-size medium
 --temperature 1.2
"""

import argparse
import warnings
warnings.filterwarnings("ignore")

try:
    import torch
    import scipy.io.wavfile as wavfile
    from transformers import AutoProcessor, MusicgenForConditionalGeneration
except ImportError as e:
    print(f"Error: {e}")
    print("\nInstall required packages:")
    print("  pip install transformers scipy torchaudio")
    exit(1)

# Model configurations
MODELS = {
    "small": "facebook/musicgen-small",
    "medium": "facebook/musicgen-medium",
    "large": "facebook/musicgen-large",
    "melody": "facebook/musicgen-melody",
}

# Synthwave prompt templates
SYNTHWAVE_PROMPTS = {
    "outrun": "80s synthwave driving music, gated reverb snare, analog bass guitar, arpeggiated synth lead, night highway atmosphere, sports car, 118 BPM",
    "darksynth": "dark synthwave horror, heavy distorted bass, atmospheric pads, minor key, cinematic tension, aggressive, 100 BPM",
    "dreamwave": "80s dreamwave, soft analog pads, gentle melody, sunset atmosphere, nostalgic vibes, lo-fi warmth, 95 BPM",
    "cyberpunk": "cyberpunk industrial synth, glitch effects, aggressive bass, futuristic atmosphere, neon city nightlife, 128 BPM",
    "spacewave": "spacewave cosmic synth, ethereal pads, floating atmosphere, slow evolving textures, stargazing, ambient elements, 80 BPM",
    "chillwave": "80s chillwave lo-fi, tape saturation, slow tempo, dreamy pads, nostalgic vibes, bedroom production, 85 BPM",
    "action": "action synthwave driving, powerful drums, aggressive bass, heroic lead melody, cinematic tension, high energy, 130 BPM",
}

def list_models():
    """List available models and their requirements."""
    print("Available Models:")
    print("  small   - 300M params, ~4GB VRAM, fastest")
    print("  medium  - 1.5B params, ~16GB VRAM, balanced (recommended)")
    print("  large   - 3.3B params, ~32GB VRAM, highest quality")
    print("  melody  - 1.5B params, ~16GB VRAM, supports melody conditioning")


def list_prompts():
    """List available synthwave prompt templates."""
    print("Available Prompt Templates:")
    for name, prompt in SYNTHWAVE_PROMPTS.items():
        print(f"  {name:12} - {prompt[:60]}...")


def generate_music(
    prompt: str,
    output_path: str,
    duration: int = 30,
    model_size: str = "medium",
    guidance_scale: float = 3.0,
    temperature: float = 1.0,
    top_k: int = 250,
    top_p: float = 0.95
):
    """
    Generate music using MusicGen.
    
    Args:
        prompt: Text description or style keyword (outrun, darksynth, dreamwave, etc.)
        output_path: Path to save the .wav file
        duration: Duration in seconds (1-30)
        model_size: Model size - small, medium, large, melody
        guidance_scale: Prompt adherence (1.0-5.0, higher = more adherence)
        temperature: Sampling temperature (0.5-1.5, higher = more random)
        top_k: Top-k sampling (0-250)
        top_p: Top-p sampling (0.0-1.0)
    """
    # Validate inputs
    if duration < 1 or duration > 30:
        print("Error: Duration must be between 1 and 30 seconds")
        return
    
    if model_size not in MODELS:
        print(f"Error: Invalid model size. Choose from: {', '.join(MODELS.keys())}")
        return
    
    # Map style keyword to full prompt if needed
    if prompt.lower() in SYNTHWAVE_PROMPTS:
        prompt = SYNTHWAVE_PROMPTS[prompt.lower()]
        print(f"Using prompt template: {prompt[:60]}...")
    
    # Select model
    model_name = MODELS[model_size]
    print(f"\n{'='*60}")
    print(f"MusicGen Synthwave Generator")
    print(f"{'='*60}")
    print(f"Model: {model_name}")
    print(f"Duration: {duration}s")
    print(f"Prompt: {prompt}")
    print(f"{'='*60}\n")
    
    # Load processor and model
    print("Loading model (this may take a moment)...")
    processor = AutoProcessor.from_pretrained(model_name)
    model = MusicgenForConditionalGeneration.from_pretrained(model_name)
    
    # Prepare inputs
    inputs = processor(
        text=[prompt],
        padding=True,
        return_tensors="pt",
    )
    
    # Set generation parameters
    model.generation_config.max_new_tokens = int(duration * 50)  # ~50 tokens per second
    model.generation_config.guidance_scale = guidance_scale
    model.generation_config.temperature = temperature
    if top_k > 0:
        model.generation_config.top_k = top_k
    if top_p > 0:
        model.generation_config.top_p = top_p
    
    # Generate audio
    print(f"Generating {duration} seconds of music...")
    audio_values = model.generate(**inputs, do_sample=True)
    
    # Process audio
    sampling_rate = model.config.audio_encoder.sampling_rate
    audio_data = audio_values[0, 0].numpy()
    
    # Normalize audio to prevent clipping
    max_val = abs(audio_data).max()
    if max_val > 0:
        audio_data = audio_data / max_val * 0.9
    
    # Save as WAV
    wavfile.write(output_path, sampling_rate, (audio_data * 32767).astype('int16'))
    
    print(f"\n{'='*60}")
    print(f"✓ Generation complete!")
    print(f"{'='*60}")
    print(f"Output: {output_path}")
    print(f"Sample rate: {sampling_rate} Hz")
    print(f"Duration: {duration} seconds")
    print(f"Model: {model_size}")
    print(f"{'='*60}\n")
    
    return output_path


def main():
    parser = argparse.ArgumentParser(
        description="Generate synthwave music using MusicGen",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--prompt", "-p",
        type=str,
        default="outrun",
        help="Text prompt or style keyword (outrun, darksynth, dreamwave, cyberpunk, spacewave, chillwave, action)"
    )
    parser.add_argument(
        "--output", "-o",
        type=str,
        default="output.wav",
        help="Output filename"
    )
    parser.add_argument(
        "--duration", "-d",
        type=int,
        default=30,
        help="Duration in seconds (1-30)"
    )
    parser.add_argument(
        "--model-size", "-m",
        type=str,
        default="medium",
        choices=["small", "medium", "large", "melody"],
        help="Model size"
    )
    parser.add_argument(
        "--guidance-scale", "-g",
        type=float,
        default=3.0,
        help="Prompt adherence (1.0-5.0)"
    )
    parser.add_argument(
        "--temperature", "-t",
        type=float,
        default=1.0,
        help="Sampling temperature (0.5-1.5)"
    )
    parser.add_argument(
        "--top-k",
        type=int,
        default=250,
        help="Top-k sampling (0-250)"
    )
    parser.add_argument(
        "--top-p",
        type=float,
        default=0.95,
        help="Top-p sampling (0.0-1.0)"
    )
    parser.add_argument(
        "--list-models",
        action="store_true",
        help="List available models"
    )
    parser.add_argument(
        "--list-prompts",
        action="store_true",
        help="List available prompt templates"
    )
    
    args = parser.parse_args()
    
    if args.list_models:
        list_models()
        return
    
    if args.list_prompts:
        list_prompts()
        return
    
    generate_music(
        prompt=args.prompt,
        output_path=args.output,
        duration=args.duration,
        model_size=args.model_size,
        guidance_scale=args.guidance_scale,
        temperature=args.temperature,
        top_k=args.top_k,
        top_p=args.top_p
    )


if __name__ == "__main__":
    main()
