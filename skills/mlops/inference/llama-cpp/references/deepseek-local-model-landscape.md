# DeepSeek Open Source Models — Local Inference Landscape

Reference: condensed research from June 2026 session on whether any DeepSeek model can outperform Qwen 3.6 35B Kimi K2.6 distilled on 16 GB VRAM (RX 9070 XT).

## The Short Answer

**No DeepSeek open source model clearly beats Qwen 3.6 35B Kimi K2.6 distilled on 16 GB VRAM.**

DeepSeek's open releases are datacenter-scale MoE architectures. The only local-viable options are distills into older base models (Qwen2.5, Llama3), which lag behind current-generation Qwen3.x.

## DeepSeek Model Catalog (Open Source)

### Full MoE Models (unrunnable locally)

| Model | Total Params | Active Params | Architecture | GGUF Q4 Size | 16GB Fit? |
|---|---|---|---|---|---|
| **DeepSeek-V4-Pro** | ~1.6T | ~49B | MoE | ~400 GB | ❌ |
| **DeepSeek-V4-Flash** | ~235B | ~37B | MoE | ~140 GB | ❌ |
| **DeepSeek-V3.2** | ~236B | ~37B | MoE | ~140 GB | ❌ |
| **DeepSeek-R1** | ~671B | ~37B | MoE | ~400 GB | ❌ |
| **DeepSeek-R1-0528** | ~671B | ~37B | MoE | ~400 GB | ❌ |

These need multi-GPU datacenter deployment. The GGUF repos exist (`antirez/deepseek-v4-gguf`) but the files are 100GB+.

### Distilled Dense Models (local-viable)

| Model | Base | Params | Q4 Size | Q3 Size | 16GB Fit? | Notes |
|---|---|---|---|---|---|---|
| **R1-Distill-Qwen-32B** | Qwen2.5 | 32B | ~20 GB | ~15 GB | ⚠️ Q3 only | Older base; Q3 quality tradeoff |
| **R1-Distill-Qwen-14B** | Qwen2.5 | 14B | ~9 GB | ~7 GB | ✅ Easy | Fast, decent reasoning |
| **R1-Distill-Qwen-7B** | Qwen2.5 | 7B | ~5 GB | ~4 GB | ✅ Easy | Speed over quality |
| **R1-Distill-Qwen-1.5B** | Qwen2.5 | 1.5B | ~1 GB | ~0.8 GB | ✅ Trivial | Embedded/edge only |
| **R1-Distill-Llama-70B** | Llama3 | 70B | ~40 GB | ~30 GB | ❌ No | Q2 at ~20GB still won't fit |
| **R1-Distill-Llama-8B** | Llama3 | 8B | ~5 GB | ~4 GB | ✅ Easy | Fast, Llama ecosystem |

### R1-0528 Distills (newer)

| Model | Base | Params | Size | Notes |
|---|---|---|---|---|
| **R1-0528-Qwen3-8B** | Qwen3 | 8B | ~5 GB | Newer base but small |

The R1-0528 distills use Qwen3 as base (newer), but only the 8B size is available. Too small to compete with 27B-35B models.

## Key Findings

### 1. DeepSeek distills use older base models
R1-Distill-Qwen-32B is distilled into **Qwen2.5**, not Qwen3.x. Your current Qwen 3.6 35B is a full generation newer in base model quality.

### 2. The 32B distill is marginal at best
At Q3_K_M (~15 GB), it fits — but:
- Q3 quality is noticeably worse than Q4
- The base model (Qwen2.5) is older than Qwen3.6
- It won't outperform a dense 27B at IQ4_XS

### 3. No DeepSeek model fits at competitive quality
To beat Qwen 3.6 35B Kimi K2.6 distilled, you'd need:
- A DeepSeek model with Qwen3.x or newer base
- At 24B+ params
- At Q4_K_M or better quant
- That fits in ~15 GB VRAM

None exist as of June 2026.

## When DeepSeek Distills Make Sense

1. **You want R1 reasoning style** — long chain-of-thought, self-correction patterns
2. **You need a smaller/faster model** — 14B or 8B for real-time applications
3. **You're comparing against older local models** — if your baseline is Qwen2.5 14B, R1-Distill-14B is competitive
4. **You have 24GB+ VRAM** — then R1-Distill-32B at Q4 becomes viable

## HF API Search Patterns for DeepSeek

```bash
# All DeepSeek GGUF repos by downloads
curl -s "https://huggingface.co/api/models?search=deepseek+gguf&sort=downloads&direction=-1&limit=20" | jq -r '.[] | "\(.id) | \(.downloads // 0) downloads"'

# R1 distills specifically
curl -s "https://huggingface.co/api/models?search=deepseek-r1-distill+gguf&sort=downloads&direction=-1&limit=20" | jq -r '.[] | "\(.id) | \(.downloads // 0) downloads"'

# R1-0528 (newer) distills
curl -s "https://huggingface.co/api/models?search=deepseek-r1-0528+gguf&sort=downloads&direction=-1&limit=10" | jq -r '.[] | "\(.id) | \(.downloads // 0) downloads"'

# DeepSeek V4 GGUFs
curl -s "https://huggingface.co/api/models?search=deepseek-v4-gguf&sort=downloads&direction=-1&limit=10" | jq -r '.[] | "\(.id) | \(.downloads // 0) downloads"'
```

## Related

- `model-evaluation.md` in this skill — full "can I run this locally?" workflow
- `vram-sizing.md` — VRAM fit tables for 16 GB GPUs
- `llm-provider-strategy` skill — cloud provider comparison including DeepSeek V4 Pro on OpenRouter
