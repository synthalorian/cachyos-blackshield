# Model VRAM Budgeting — Does It Fit Your GPU?

How to determine if a GGUF model will fit in your VRAM before downloading. Based on real-world measurements from a 16 GB RX 9070 XT (Vulkan GGML).

## The Formula

```
Total VRAM needed = GGUF file size + KV cache + scratch buffers (~200-500 MB)
```

That's it. If `GGUF file size + KV cache + 500 MB < your VRAM`, the model fits with full GPU offload. Nothing else matters — not the param count, not the name, not the hype. Only file size and KV cache.

### Where to get each number

| Component | How to get it |
|-----------|---------------|
| **GGUF size** | From HuggingFace repo page or `curl -sI <file-url> \| grep content-length` |
| **KV cache** | Calculate from model architecture (see below) |
| **VRAM total** | `rocm-smi` (AMD), `nvidia-smi` (NVIDIA), or `vulkaninfo` |
| **Headroom** | Always reserve 500 MB — llama.cpp needs scratch memory |

## KV Cache Calculation

The KV cache is what eats most of your VRAM at large context sizes. It depends on the NUMBER OF ATTENTION LAYERS, not total parameters.

### Formula

```
KV cache per token = 2 × n_attention_layers × n_kv_heads × head_dim × bytes_per_value

Total KV cache (GB) = KV_per_token × seq_len / 1073741824
```

Where `bytes_per_value` depends on your KV cache type:

| Flag | Bytes/value | Quality |
|------|:----------:|:-------:|
| `-ctk q8_0 -ctv q8_0` | 1.0 | Full |
| `-ctk q4_0 -ctv q4_0` | 0.5 | Slight loss |
| `-ctk f16 -ctv f16` | 2.0 | Max (rarely needed) |

### How to get architecture params from HuggingFace

```bash
# Fetch config.json from any model repo
curl -s "https://huggingface.co/unsloth/Qwen3-14B-GGUF/raw/main/config.json" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
tc = d.get('text_config', d)

# Attention layers (this is what KV cache scales with)
layers = len(tc.get('layer_types', []))  # explicit layer types
if not layers:
    layers = tc.get('num_hidden_layers', tc.get('num_layers', 0))

# KV heads (GQA)
kv = tc.get('num_key_value_heads', tc.get('num_attention_heads', 32))
hd = tc.get('head_dim', tc.get('hidden_size', 4096) // tc.get('num_attention_heads', 32))

# MoE check
moe = bool(tc.get('num_experts', 0) or tc.get('num_local_experts', 0))

print(f'Attention layers: {layers}')
print(f'KV heads: {kv}')
print(f'Head dim: {hd}')
print(f'MoE: {moe}')

# KV cache per token for Q8_0
kv_per_token = 2 * layers * kv * hd  # bytes @ q8_0
print(f'\\nKV cache per token (q8_0): {kv_per_token} bytes ({kv_per_token/1024:.1f} KB)')
print(f'KV cache per token (q4_0): {kv_per_token/2} bytes ({kv_per_token/2048:.1f} KB)')

for ctx in [32768, 65536, 131072, 262144, 524288]:
    gb = kv_per_token * ctx / (1024**3)
    print(f'  {ctx//1024:>4}k context (q8_0): {gb:.1f} GB')
"
```

### MoE vs Dense — Why MoE Wins for VRAM

**Myth:** "Dense models are better because all parameters are active."
**Reality:** MoE models have ~HALF the attention layers of dense models at the same total param count, which means ~HALF the KV cache.

| Model | Total Params | Active/Token | Attention Layers | KV Cache (128k, q8_0) |
|-------|:-----------:|:-----------:|:----------------:|:---------------------:|
| Qwen3.6-35B-A3B (MoE) | 35B | 3B | ~28 | **~7.0 GB** |
| Qwen2.5-Coder-32B (dense) | 32B | 32B | 64 | **~8.6 GB** |

The MoE model uses **more** total disk space (35B weights) but **less** VRAM at inference because its KV cache is smaller. This is why Qwen3.6-35B fits on 16 GB with 128k context but Qwen2.5-Coder-32B doesn't.

### Example: Does Qwen2.5-Coder-32B fit on 16 GB?

```
File (IQ3_S):      12.7 GB
KV cache (128k q4):  4.3 GB  (64 layers × 8 KV heads × 128 dim × 2 bytes × 131072)
Scratch buffers:      0.5 GB
────────────────────────────────
TOTAL:               17.5 GB  ❌ Doesn't fit
```

Even at the lowest viable quant (IQ3_S), the KV cache alone at 128k pushes it over. At 32k context the KV drops to ~1 GB and total = 14.2 GB — it fits. But you lose the context window.

### Example: Does Qwen3.6-35B fit?

```
File (IQ3_S):      13.0 GB
KV cache (128k q8):  7.0 GB  (28 layers × 8 KV heads × 128 dim × 1 byte × 131072)
Scratch buffers:      0.5 GB
────────────────────────────────
TOTAL:               20.5 GB  ❌ Doesn't fit with full layers
```

But this model works! Why? Because `--n-gpu-layers 35` puts only ~35/64 layers on GPU. The rest offloads to CPU. The model fits because NOT all weights are in VRAM.

**Key insight:** With MoE models on 16 GB, you WILL offload some layers to CPU. Use `--n-gpu-layers` to control how much fits. The 35b model runs 35 GPU layers at 128k, 28 at 256k, 20 at 512k.

## Model Selection Process

### Step 1: Identify the model size you need

```bash
# Look at what models exist for a given family
curl -s "https://huggingface.co/api/models?search=Qwen3+GGUF&sort=downloads&limit=10" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data:
    name = m['modelId']
    dl = m['downloads']
    print(f'{dl:>8}  {name}')
"
```

### Step 2: Check available quants and file sizes

```bash
# List GGUF files in a repo
curl -s "https://huggingface.co/api/models/unsloth/Qwen3-14B-GGUF" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data.get('siblings', []):
    rfn = f.get('rfilename', '')
    if '.gguf' not in rfn: continue
    print(f'  {rfn}')
"
```

### Step 3: Get exact file size via HEAD request

```bash
curl -sI "https://huggingface.co/unsloth/Qwen3-14B-GGUF/resolve/main/Qwen3-14B-Q4_K_M.gguf" \
  2>/dev/null | grep -i "^content-length" | awk '{printf "%.2f GB\n", $2/1073741824}'
```

### Step 4: Get architecture, compute KV cache

Use the Python script from "How to get architecture params" above.

### Step 5: Do the math

```
Total = GGUF_size + KV_cache + 0.5 GB

If Total < VRAM:              ✅ Full GPU offload
If Total >= VRAM but < 2×VRAM: ⚠️ Partial offload (use --n-gpu-layers)
If Total >= 2×VRAM:           ❌ Model too large for this card
```

### Step 6: Estimate GPU layers

```
Layer size ≈ GGUF_size / n_total_layers
GPU budget = VRAM - KV_cache - 0.5 GB
GPU layers = floor(GPU_budget / layer_size)
```

### Step 7: Test before committing to config

```bash
/path/to/llama-server \
  --model /path/to/model.gguf \
  --ctx-size 4096 \
  --n-gpu-layers <calculated> \
  --port 9999 --host 127.0.0.1 &>/tmp/test.log &
sleep 10
curl -s http://127.0.0.1:9999/health && echo "OK" || echo "FAILED"
kill %1 2>/dev/null
```

## Model Family Cheat Sheet (16 GB RX 9070 XT)

### Dense Models — Q4_0 KV Cache (0.5 bytes/value, good quality)

| Model | Quant | GGUF Size | Attn Layers | KV/128k | KV/256k | KV/512k | 128k Fit | 256k Fit | 512k Fit |
|:-----:|:-----:|:---------:|:-----------:|:-------:|:-------:|:-------:|:--------:|:--------:|:--------:|
| Qwen3.5-9B | Q4_K_M | 5.3 GB | 28 | 3.8 GB | 7.5 GB | 15 GB (q2) | ✅ 28L | ✅ 28L | ✅ 28L* |
| Qwen3-14B | Q4_K_M | 8.4 GB | 40 | 5.4 GB | 10.7 GB | 21.5 GB | ✅ 40L | ⚠️ 24L | ⚠️ 14L* |
| 24B dense | Q3_K_M | ~8.6 GB | 40 | 5.4 GB | — | — | ✅ full | — | — |
| 32B dense | IQ3_S | ~12.7 GB | 64 | 8.6 GB | — | — | ❌ | — | — |

*\* 512k on all models uses Q2_0 KV cache (0.25 bytes/value) to halve memory*

### MoE Models — Q8_0 KV Cache (1 byte/value, full quality)

MoE models have ~HALF the attention layers of dense models at the same total param count, so their KV cache is roughly half the size.

| Model | Quant | GGUF Size | Attn Layers | KV/128k | Total | GPU Layers |
|:-----:|:-----:|:---------:|:-----------:|:-------:|:-----:|:----------:|
| Qwen3.6-35B | IQ3_S | 13.0 GB | ~28 | 7.0 GB | 20.5 GB | 35/64 @ 128k |
| Qwen3.6-35B | IQ3_S | 13.0 GB | ~28 | 14.0 GB | 27.5 GB | 28/64 @ 256k |
| Qwen3.6-35B | IQ3_S | 13.0 GB | ~28 | 28.0 GB | 41.5 GB | 20/64 @ 512k |

### Produced Installation Recipes (Verified Working)

From this system's actual config:

**Qwen3-14B** — 3 context variants on 16GB:
| Variant | GPU Layers | KV Cache | VRAM | Speed |
|:--------|:----------:|:--------:|:----:|:-----:|
| 128k | 40 (all) | Q4_0 | ~14 GB | ~34 t/s |
| 256k | 24 | Q4_0 | ~15.5 GB | — |
| 512k | 14 | Q2_0 | ~14 GB | — |

**Qwen3.5-9B** — 3 context variants on 16GB (all layers GPU):
| Variant | GPU Layers | KV Cache | VRAM | Speed |
|:--------|:----------:|:--------:|:----:|:-----:|
| 128k | 28 (all) | Q4_0 | ~9 GB | ~30 t/s |
| 256k | 28 (all) | Q4_0 | ~12.5 GB | — |
| 512k | 28 (all) | Q2_0 | ~12.5 GB | — |

## Qwen Model Naming Quick Reference

Models older than April 2025 are likely outclassed by newer ones at the same size, even when the older model has "dense" advantage.

| Name | Release | Params | Type | Coding Score |
|:-----|:-------:|:------:|:----:|:-----------:|
| Qwen2.5-Coder-32B | Nov 2024 | 32B | Dense | 38.7 LiveBench |
| Qwen3-14B | Mar 2025 | 14B | Dense | ~38 est. |
| Qwen3.6-35B-A3B | Apr 2025 | 35B/3B | **MoE** | **41.2 LiveBench** |

**Key:** Qwen3.6-35B beats Qwen2.5-Coder-32B on coding despite being MoE (3B active). Architecture recency matters more than "dense beats MoE."

## Quick Decision Flowchart

```
Want to add a new local model?
  │
  ├─ Does it beat your current best (35b)?
  │   └─ No → don't bother
  │   └─ Yes → check VRAM fit
  │
  ├─ Calculate: GGUF_size + KV_cache + 0.5 GB
  │
  ├─ < 16 GB → ✅ Full GPU offload
  │   └─ Add with --n-gpu-layers 99
  │
  ├─ < 24 GB → ⚠️ Partial offload needed
  │   └─ GPU layers = (16 - KV_cache - 0.5) / (GGUF_size / total_layers)
  │
  └─ > 24 GB → ❌ Too big
```