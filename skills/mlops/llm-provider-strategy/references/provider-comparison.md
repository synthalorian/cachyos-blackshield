# Provider Comparison — Quick Reference (May 2026, updated for synth's stack)

## synth's Active Stack

| Role | Model | Provider | Cost |
|------|-------|----------|:----:|
| **Primary** | Kimi K2.6 | Kimi Allegro | $99/mo |
| **Backup** | DeepSeek V4 Pro | OpenRouter (~$2-5/mo) | $50 seed deposit |
| **Free** | DeepSeek V4 Flash | Nous | $0 |
| **Local** | 35b Kimi distilled / 35b / 14b / 9b | llama-swap | $0 |

## Artificial Analysis Intelligence Scores (May 2026)

| Model | AA Score | Speed | Context | Notes |
|-------|:--------:|:-----:|:-------:|-------|
| Kimi K2.6 (full) | **54** | 73 tok/s | 256k | Top of synth's reachable models |
| Qwen3.6 35B A3B | **43** | 179 tok/s | 262k | Base Qwen, synth's 35b (UD) variant |
| Gemma 4 31B | **39** | 35 tok/s | 256k | Dense — more VRAM per token |
| Gemma 4 26B A4B | **31** | -- | 256k | MoE — lower capability |

Kimi K2.6 significantly outranks everything else synth can run locally or afford.

## Removed Models (do not re-recommend)

| Model | Reason |
|-------|--------|
| GPT Codex | Dropped — Kimi + DeepSeek cover everything through claw-code/Hermes/OpenCode |
| GLM 5.1 Pro | Evicted — $72 plan exhausted in 3 days at synth's burn rate |
| DeepSeek V4 Pro as primary | Demoted — Kimi is now primary, DeepSeek is backup/overflow |

## Local Model Architecture

ALL Qwen3.x models synth runs (9b, 14b, 35b, 35bkimi) are **reasoning-distilled** — they output ` thinking` blocks baked into training. Custom templates break reasoning extraction. Must use GGUF built-in template.

Kimi K2.6 distilled (35b): hybrid/recurrent memory. NO `--flash-attn on` or `--cont-batching`. Use `--parallel 1`, no evict wrapper.