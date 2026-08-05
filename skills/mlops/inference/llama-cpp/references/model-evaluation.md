# Model Evaluation Workflow — "Can I run this locally?"

When the user asks whether a specific model can run locally, follow this evaluation pipeline. It covers the full path from research → feasibility → download → config.

## 1. Find the original model

Search HF for the model family:

```
https://huggingface.co/models?search=<model-name>&sort=trending
```

Look at the model card to determine:
- **Parameter count** — this tells you if local inference is feasible at all
- **Architecture** — must be supported by llama.cpp (Qwen, Llama, Mistral, Gemma, DeepSeek, etc.)
- **License** — some models have restrictions on local use
- **Model type** — MoE models need special handling

### Size thresholds (16 GB RX 9070 XT reference)

| Parameter count | Feasibility |
|---|---|
| < 10B | ✅ Easy — fits even at Q8_0 |
| 10B-27B | ✅ Good — Q4_K_M through Q6_K fits |
| 27B-35B | ⚠️ Tight — IQ3/IQ4 only, limited context |
| 35B-70B | ❌ MoE only (e.g. 35B-A3B = 3B active), or forget it |
| 70B+ | ❌ Not possible locally on consumer GPU |

## 2. If too big, find alternatives

When the original model is too large, search for:

- **Distilled versions** — search `<model-name> distill` or `<model-name> distil`
- **Smaller releases** — many orgs release 8B/9B variants alongside 70B+
- **GGUF quantized repos** — search `apps=llama.cpp` filtered by size:

```
https://huggingface.co/models?search=<term>+gguf&num_parameters=min:0,max:12B&apps=llama.cpp&sort=downloads
```

### Distillation recognition

A distilled model has the SAME architecture as its base model but different weights trained on the teacher model's outputs. Check:
- `base_model` field in config.json (points to the actual architecture)
- `model_type` — must match something llama.cpp already supports
- The training description mentions "distillation from <teacher>"

## 3. Verify architecture compatibility

Check that the model's architecture is supported by the **local llama.cpp build**:

```bash
# Check what backends are compiled in
strings /home/synth/llama.cpp/build/bin/llama-server | grep -E "ggml_vulkan|ggml_hip"
```

The fastest way: check `config.json` from the Hugging Face repo:

```
curl -s https://huggingface.co/<repo>/raw/main/config.json | head -20
```

Look for:
- `model_type` — e.g. `qwen3_5` = supported
- `architectures` — e.g. `Qwen3_5ForConditionalGeneration`
- `text_config.model_type` — for multimodal models, check the text sub-component

**Compare with existing known-good models** — if the architecture matches something already running in llama-swap (same `model_type`), it will almost certainly work.

### Pitfall: new/unreleased architectures

If `model_type` isn't in the known-good list (Qwen, Llama, Mistral, DeepSeek, Gemma, Phi, Cohere, Starcoder2, DBRX, Grok, etc.), the model likely won't work with the current llama.cpp build. Report this rather than attempting a download.

## 4. Get GGUF file sizes

Once you've found a candidate GGUF repo, get the real file sizes.

### Method A: Tree API (preferred)

```
curl -s "https://huggingface.co/api/models/<repo>/tree/main?recursive=true"
```

Look for LFS entries (type="file", path ending in .gguf). The `size` field in the tree API response gives the actual stored file size. Filter out:
- `mmproj-*.gguf` — projector files (multimodal only)
- `BF16/` — full-precision shards (too large)
- `README.md`, config blobs

### Method B: LFS pointer fallback

When the model API or tree API returns 0-byte entries (LFS pointer file metadata), curl the raw LFS pointer file directly:

```bash
curl -sL "https://huggingface.co/<repo>/raw/main/<filename>.gguf" | head -5
```

LFS pointer files contain a `size <bytes>` field as plain text on the second line. Parse it:

```bash
curl -sL "https://huggingface.co/<repo>/raw/main/<filename>.gguf" | grep "^size " | awk '{print $2}'
```

Convert to GB: `size / 1073741824`.

Pitfall: the `curl -sL` follows redirects. LFS pointers are small (~1400 bytes), so it's fast. This works because LFS pointer files are NOT binary — they're plain text metadata.

## 5. Quantization selection for VRAM

With the real file sizes and the user's VRAM budget (16 GB RX 9070 XT):

| Free VRAM after model | Safe? |
|---|---|
| Model uses < 70% of VRAM | ✅ Comfortable — room for context |
| Model uses 70-85% | ⚠️ Tight — limit context size |
| Model uses > 85% | ❌ Will OOM |

**Recommended quants for 16 GB VRAM:**

| Model size | Best quant | Size est. | Headroom |
|---|---|---|---|
| 7-9B | Q5_K_M | ~6 GB | ✅ Lots |
| 9B | Q4_K_M | ~5.2 GB | ✅ Lots |
| 14B | Q4_K_M | ~8.5 GB | ✅ Good |
| 27B | IQ4_XS | ~16 GB | ❌ No headroom |
| 35B-A3B (MoE) | IQ3_S | ~16 GB | ❌ No headroom |

## 6. Check for multimodal requirements

If the model card says `image-text-to-text` or `Image-Text-to-Text`:
- The repo should include an `mmproj-*.gguf` file (multimodal projector)
- llama-server needs `--mmproj <path>` flag
- The projector is typically small (500 MB - 1 GB) and separate from the main model

## 7. Add to llama-swap

Once downloaded, add a config entry to `/home/synth/llama.cpp/llama-swap/config.yaml`:

```yaml
  "<model-alias>":
    cmd: >
      /home/synth/llama.cpp/build/bin/llama-server
      --model /home/synth/llm/models/<filename>.gguf
      --jinja --reasoning off
      --ctx-size 131072
      --n-gpu-layers 99
      --port <unique-port>
      --host 127.0.0.1
      --alias <model-alias>
      --flash-attn on
      --cache-type-k q8_0 --cache-type-v q8_0
      --threads 8 --threads-batch 16 --mlock --metrics
      --parallel 2 --cont-batching
    proxy: http://127.0.0.1:<unique-port>
    ttl: 900
    aliases:
      - <model-alias>
```

Restart llama-swap: `systemctl --user restart llama-swap`.

## 7.6 Context-first configuration (synth's preference)

When the user says "as much context as you can give me", optimize for max context, not max speed:

1. **Native context is preferred** — use the model's `max_position_embeddings` as the primary target (e.g., 262144 for Qwen3.x). YaRN scaling beyond native should be the backup, not the default.
2. **For Qwen DeltaNet models at Q4_K_M (5.2 GB on 16 GB VRAM):**
   - 128k: all layers in GPU, parallel=2
   - 256k (native max): all layers in GPU, parallel=1
   - 512k (YaRN scaled): all layers in GPU, parallel=1, q8_0 KV cache needs ~8 GB
3. **Add all three context variants** to llama-swap so the user can choose per-session — fast (128k), balanced (256k native max), or max reach (512k scaled).
4. **Always set `--flash-attn on`** — reduces memory bandwidth for attention computation.
5. **Use q8_0 KV cache** — it's the standard choice. q4_0 saves space but loses quality. Only downgrade to q4_0 when 512k+ context is needed and VRAM is tight.

### n-gpu-layers estimation for mixed-attention models

For DeltaNet models, KV cache is only 16 KB/token. Use this formula:
```
kv_gb = (full_attn_layers * 2 * n_kv_heads * head_dim / 1024 / 1024 / 1024) * ctx_size
model_gb = (total_params_in_billions * 4.5) / 1024 * quant_bpw  # rough estimator
```

For a 9B Q4_K_M (~4.5 bpw) model with 8 full-attn layers:
- 131k context: ~2 GB KV → 99 layers in GPU
- 262k context: ~4 GB KV → 99 layers in GPU  
- 524k context: ~8 GB KV → 99 layers in GPU

The difference vs a dense 32-layer model: ~6x less KV cache for the same context. You can fit far more context at full GPU offload.

## 7.5 KV cache sizing from architecture (DeltaNet / linear attention)

Some modern architectures (Qwen3.5/3.6, Qwen3-Coder-Next) use **mixed attention** — a mix of full-attention layers (need KV cache) and linear-attention layers (DeltaNet — no KV cache needed). This drastically changes how much context fits in VRAM.

### How to check

```bash
curl -s "https://huggingface.co/<repo>/raw/main/config.json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
tc = d.get('text_config', d)
lt = tc.get('layer_types', [])
full_attn = sum(1 for l in lt if l == 'full_attention')
linear_attn = sum(1 for l in lt if l == 'linear_attention')
nkv = tc.get('num_key_value_heads', 4)
hd = tc.get('head_dim', 128)
kv_per_token = full_attn * 2 * nkv * hd  # bytes at q8_0
kb = kv_per_token / 1024
print(f'Full attention layers: {full_attn}')
print(f'Linear attention layers: {linear_attn}')
print(f'KV cache with q8_0: {kb:.1f} KB per token')
print(f'128k: {128*kb/1024:.1f} GB')
print(f'256k: {256*kb/1024:.1f} GB')
print(f'512k: {512*kb/1024:.1f} GB')
"
```

### Impact on context sizing

For example, the Qwen3.5-9B / GLM-5.1 distilled 9B has:
- 32 layers total: 8 full-attention + 24 DeltaNet
- KV cache: only 16 KB/token with q8_0 (vs ~80 KB for a fully-dense 9B)
- 512k context: ~8 GB for KV (vs ~40 GB for fully-dense)
- This means 512k is **easily feasible** on 16 GB VRAM for mixed-attention models

**PITFALL:** Not all "Qwen" models use DeltaNet. Check the actual `layer_types` array. Earlier Qwen 2.5 models were fully dense. Only Qwen3.x introduces hybrid attention.

**New-model heuristic:** If the model card says "DeltaNet" or "linear attention" in the architecture description, it likely has reduced KV cache.

### Quantization selection with efficiency in mind

For a mixed-attention model at Q4_K_M (5.2 GB weights), with 16 GB VRAM:

| Context | KV cache (q8_0) | Total VRAM | Feasibility |
|---------|-----------------|------------|-------------|
| 128k    | ~2 GB           | ~7.3 GB    | ✅ Easy |
| 256k    | ~4 GB           | ~9.3 GB    | ✅ Comfortable |
| 512k    | ~8 GB           | ~13.3 GB   | ✅ Fits |
| 1M      | ~16 GB          | ~21 GB     | ❌ Too much |

For fully-dense models of the same size, 512k context alone would consume 40+ GB of KV cache — impossible for consumer GPUs.

## 8. Benchmark comparison — picking between viable candidates

Once you've identified multiple models that fit in VRAM, compare their actual quality using model card benchmarks. Qwen model cards are the gold standard here — they publish detailed comparison tables against competitors.

### Benchmark extraction from model cards

```bash
# Fetch the model card README
curl -s "https://huggingface.co/<org>/<model>/raw/main/README.md"
```

Qwen model cards embed HTML tables with benchmark comparisons. Extract key coding benchmarks:

```bash
curl -s "https://huggingface.co/<repo>/raw/main/README.md" | python3 -c "
import sys, re
text = sys.stdin.read()
# Find coding agent benchmarks
start = text.find('Coding Agent')
if start == -1: start = 0
end = text.find('General Agent') if 'General Agent' in text else len(text)
section = text[start:end]
rows = re.findall(r'<tr>(.*?)</tr>', section, re.DOTALL)
for row in rows:
    cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
    if cells:
        clean = [re.sub(r'<[^>]+>', '', c).strip() for c in cells]
        print(' | '.join(clean))
"
```

## 8. Benchmark comparison — picking between viable candidates

Once you've identified multiple models that fit in VRAM, compare their actual quality using model card benchmarks. Qwen model cards are the gold standard here — they publish detailed comparison tables against competitors.

### Benchmark extraction from model cards

```bash
# Fetch the model card README
curl -s "https://huggingface.co/<org>/<model>/raw/main/README.md"
```

Qwen model cards embed HTML tables with benchmark comparisons. Extract key coding benchmarks:

```bash
curl -s "https://huggingface.co/<repo>/raw/main/README.md" | python3 -c "
import sys, re
text = sys.stdin.read()
# Find coding agent benchmarks
start = text.find('Coding Agent')
if start == -1: start = 0
end = text.find('General Agent') if 'General Agent' in text else len(text)
section = text[start:end]
rows = re.findall(r'<tr>(.*?)</tr>', section, re.DOTALL)
for row in rows:
    cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
    if cells:
        clean = [re.sub(r'<[^>]+>', '', c).strip() for c in cells]
        print(' | '.join(clean))
"
```

### Dense vs MoE tradeoff

This is the most important comparison for 16 GB VRAM users. Two strategies compete:

| Strategy | Example | Active params | Quant quality | Coherence |
|---|---|---|---|---|
| **Dense at high quant** | synthclaw-35b-128k IQ4_XS (~15 GB) | 27B (all active) | IQ4_XS — good | ✅ All weights always available |
| **MoE at low quant** | Qwen3.6-35B-A3B IQ3_S (~13 GB) | 3B (active subset) | IQ3_S — fair | ⚠️ MoE mode-switching can feel incoherent |

**Key finding from this session:** synthclaw-35b-128k (dense, IQ4_XS) beats Qwen3.6-35B-A3B (MoE, IQ3_S) on coding benchmarks. The dense model at higher quant quality outperforms the MoE with more total parameters at lower quant — despite having fewer total params on paper.

**Decision rule:** When you can fit a dense model at Q4_K_M / IQ4_XS or better, prefer it over a MoE model with more total params at IQ3_S or worse. MoE only wins when the dense alternative can't fit at all.

### Ollama-specific MoE size trap (16 GB VRAM ceiling)

Ollama community builds of Qwen3.6-35B-A3B publish distinct sizes per quant — not all will fit a 16 GB card:

| Quant | Approx size | 16 GB fit? |
|---|---|---|
| Q4_K_M | ~22 GB | ❌ OOM |
| Q4_K_M (UD variant) | ~22 GB | ❌ OOM |
| IQ4_XS | ~20–21 GB | ❌ No |
| IQ3_S | ~18–19 GB | ❌ Borderline OOM |
| IQ2 / Q2 | ~16 GB | ⚠️ Marginal |

**Bottom line for 16 GB VRAM:** No Ollama GGUF of Qwen3.6-35B-A3B at usable quality (Q4_K_M or IQ4_XS) fits locally. The previous workflow assumption that a 35B MoE will fit if the 27B does is wrong — the 35B is 2–6 GB larger than the 27B across all quants, and that 2–6 GB is the difference between fitting and OOM.

**Ollama OOM Diagnostics:** Check `ollama ps` — if a model shows `processor: 22%/78% CPU/GPU`, it overflows VRAM and layer-skips between RAM and VRAM on every token. Cold-start failure (`llama runner process has terminated: signal arrived during cgo execution`) is the unmissable sign: swap-backed only, unusable. Purge the model and switch to a smaller quant or a smaller model variant.

### Cross-repo comparison via HF search rank

Use download count and likes as a rough quality signal:

```bash
curl -s "https://huggingface.co/api/models?search=<term>+GGUF&sort=downloads&direction=-1&limit=10" | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    print(f'{m[\"modelId\"]:55s} {m.get(\"downloads\",0):>8} downloads  {m.get(\"pipeline_tag\",\"\")}')
"
```

High download counts (millions) indicate community trust. Cross-reference with benchmark data from model cards.

### Competitive landscape for 16 GB VRAM — updated June 2026 (RX 9070 XT, RADV)

Sorted by estimated quality for coding on 16 GB VRAM:

1. **synthclaw-35b-128k** (dense 27B, IQ4_XS ~15 GB) — Best overall. Dense architecture, high quant quality. Beats the A3B MoE on benchmarks. Already configured via llama-swap.
2. **Mistral-Small-3.2-24B-Instruct** (dense 24B, Q4_K_M ~15 GB) — Strong contender. Dense architecture, excellent coding/reasoning. Often trades blows with 30B+ MoE models. GGUF: `MaziyarPanahi/Mistral-Small-24B-Instruct-2501-GGUF`. Worth A/B testing against synthclaw-35b.
3. **Phi-4-reasoning-plus** (dense 15B, Q4_K_M ~10 GB) — Dark horse. Microsoft's 15B model punches way above its weight on reasoning benchmarks. Often beats 30B+ models on logic/math. Fits with massive headroom. GGUF: `MaziyarPanahi/phi-4-GGUF`. Best for reasoning-heavy standalone tasks.
4. **Qwen3.6-35B-A3B** (MoE 35B/3B active) — ❌ No usable quality quant fits 16 GB VRAM. Ollama GGUF variants are 18–22 GB at Q4_K_M/IQ4_XS. IQ3_S at ~16 GB is marginal and quality-degraded. Do not attempt without verifying exact file size.
5. **DeepSeek-R1-Distill-Qwen-32B** (dense 32B, Q3_K_M ~15 GB) — Fits at Q3, but it's a distill of older R1 into Qwen2.5 base. Your Qwen 3.6 35B Kimi K2.6 distilled is likely newer and better. Only worth trying if you specifically need R1 reasoning style.
6. **DeepSeek-R1-Distill-Llama-70B** (dense 70B) — ❌ Q2_K at ~20 GB still won't fit. Not viable on 16 GB.
7. **Gemma 3 12B** (dense 12B, Q4_K_M ~8 GB) — Solid tier-2 offline fallback. Fits with room to spare; lower ceiling than Qwen but viable as a secondary resident model.
8. **Gemma 3 27B** (dense 27B, Q4_K_M ~17 GB) — Too large — does not fit 16 GB VRAM alone before KV cache.
9. **Qwen3.5-27B-A3B** (MoE 27B/3B active, IQ4_XS ~15 GB) — Older MoE gen. Still viable, but being displaced by dense 27B.
10. **Qwen3.6-70B-A3B** (MoE 70B / 6B active, Q4_K_M ~42 GB) — Impossible for 16 GB VRAM. Cloud only.

### DeepSeek open source models — the 16 GB VRAM reality

DeepSeek releases are **datacenter-scale MoE architectures**, not consumer-GPU friendly:

| Model | Total params | Active params | GGUF size (Q4) | Fits 16 GB? |
|---|---|---|---|---|
| **DeepSeek-V4-Pro** | ~1.6T | ~49B | ~400 GB | ❌ Impossible |
| **DeepSeek-V4-Flash** | ~235B | ~37B | ~140 GB | ❌ Impossible |
| **DeepSeek-R1** | ~671B | ~37B | ~400 GB | ❌ Impossible |
| **DeepSeek-R1-0528** | ~671B | ~37B | ~400 GB | ❌ Impossible |
| **DeepSeek-R1-Distill-Qwen-32B** | 32B (dense) | 32B | Q4=~20 GB, Q3=~15 GB | ⚠️ Q3 only |
| **DeepSeek-R1-Distill-Qwen-14B** | 14B (dense) | 14B | Q4=~9 GB | ✅ Easy |
| **DeepSeek-R1-Distill-Llama-70B** | 70B (dense) | 70B | Q4=~40 GB, Q2=~20 GB | ❌ No |
| **DeepSeek-R1-Distill-Llama-8B** | 8B (dense) | 8B | Q4=~5 GB | ✅ Easy |

**Key insight:** DeepSeek's full models (V4, R1) are designed for multi-GPU datacenter deployment. The **distilled versions** are the only local-viable options, and even the 32B distill is marginal at Q3 on 16 GB. There is no DeepSeek model that clearly beats Qwen 3.6 35B Kimi K2.6 distilled on 16 GB VRAM.

**DeepSeek distills are older:** R1-Distill-Qwen-32B uses Qwen2.5 as base, not Qwen3.x. Your current Qwen 3.6 35B is a generation newer.

**When to consider DeepSeek distills:**
- You specifically want R1's reasoning style (long CoT, self-correction patterns)
- You need a smaller model (14B/8B) for speed over quality
- You're willing to run at Q3 quality for the 32B variant

### AMD RX 9070 XT (RDNA 4 / gfx1201) compatibility notes

The RX 9070 XT is very new (gfx1201 architecture). Specific considerations:

- **llama.cpp version:** Needs `b4000+` for gfx1201 support in the Vulkan backend
- **Backend:** Vulkan (`-DGGML_VULKAN=ON`) is the most portable across RDNA 4; ROCm/HIP support may lag for new architectures
- **Formats to use:** GGUF only. Avoid AWQ, EXL2, GPTQ — these are CUDA-optimized and don't work on AMD
- **FP8 on AMD:** Hit-or-miss. Stick to GGUF Q4/Q3 for reliability
- **Verification:** `strings ./build/bin/llama-server | grep ggml_vulkan` should show symbols

### Research methodology: finding models that fit your hardware

When the user asks "what local models can beat X on my setup", use this pattern:

1. **Identify the hardware ceiling** — VRAM, GPU backend (CUDA/Vulkan/ROCm), RAM
2. **Search HF for candidate families** — use the API, not just browsing:
   ```bash
   # Search by model family + GGUF
   curl -s "https://huggingface.co/api/models?search=<family>+gguf&sort=downloads&direction=-1&limit=20" | jq -r '.[] | "\(.id) | \(.downloads // 0) downloads"'
   
   # Search for distills of a specific teacher
   curl -s "https://huggingface.co/api/models?search=<teacher>+distill+gguf&sort=downloads&direction=-1&limit=20" | jq -r '.[] | "\(.id) | \(.downloads // 0) downloads"'
   ```
3. **Get real GGUF sizes** — tree API or LFS pointer fallback (see Section 4)
4. **Filter by VRAM fit** — model size + ~2-3GB overhead for KV cache
5. **Check architecture compatibility** — `config.json` model_type must be in known-good list
6. **Compare benchmarks** — extract from model card README (see Section 8)
7. **Recommend A/B test candidates** — don't declare a winner without testing

### Models to A/B test against synthclaw-35b-128k

If the user wants to find something better, these are the most likely candidates:

| Model | Size | Quant | VRAM | Why test? |
|---|---|---|---|
| **Mistral-Small-3.2-24B** | 24B dense | Q4_K_M | ~15 GB | Dense architecture, strong coding, fits comfortably |
| **Phi-4-reasoning-plus** | 15B dense | Q4_K_M | ~10 GB | Shockingly good reasoning for the size; massive VRAM headroom |
| **EXAONE-4.5-33B** | 33B dense | Q3_K_M | ~16 GB | LG's model, strong multilingual + coding; tight fit |
| **Nemotron-3-Nano-30B** | 30B MoE | — | ~30 GB (FP8) | ❌ NVFP4 only — NVIDIA-locked, useless on AMD |

**Verdict:** On 16 GB VRAM with an AMD GPU, there is no clearly superior alternative to a well-quantized dense 27B model. Mistral-Small-24B and Phi-4-reasoning are the only ones worth testing.

## Quick reference: curl commands for model evaluation

```bash
# Check original model architecture
curl -s "https://huggingface.co/<org>/<model>/raw/main/config.json" | python3 -c "import json,sys; d=json.load(sys.stdin); print('model_type:', d.get('model_type', d.get('text_config',{}).get('model_type','?')))"

# Get GGUF file sizes from tree API
curl -s "https://huggingface.co/api/models/<org>/<gguf-repo>/tree/main?recursive=true" | python3 -c "
import json, sys
for f in json.load(sys.stdin):
    if f['type']=='file' and f['path'].endswith('.gguf'):
        gb = f['size']/1073741824
        print(f\\\"{f['path']:60s} {gb:6.2f} GB\\\")\"

# Fallback: LFS pointer file size extraction
curl -sL "https://huggingface.co/<org>/<gguf-repo>/raw/main/<file>.gguf" | grep "^size " | awk '{print $2}' | numfmt --to=iec

# Benchmark comparison from model card
curl -s "https://huggingface.co/<org>/<model>/raw/main/README.md" | python3 -c "
import sys, re
text = sys.stdin.read()
start = text.find('Coding Agent')
if start == -1: start = 0
end = text.find('General Agent') if 'General Agent' in text else len(text)
rows = re.findall(r'<tr>(.*?)</tr>', text[start:end], re.DOTALL)
for row in rows:
    cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
    if cells:
        print(' | '.join(re.sub(r'<[^>]+>','',c).strip() for c in cells))
"

# Popular GGUF repos by download count
curl -s "https://huggingface.co/api/models?search=GGUF&sort=downloads&direction=-1&limit=30" | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    print(f'{m[\"modelId\"]:55s} {m.get(\"downloads\",0):>8} dwl  {m.get(\"pipeline_tag\",\"\")}')
"
```
