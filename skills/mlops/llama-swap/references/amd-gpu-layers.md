# AMD GPU Layer Tuning for llama-swap

When configuring models for AMD GPUs with Vulkan backend, the `--n-gpu-layers` values need careful tuning per model size and context length, especially on consumer GPUs with limited VRAM (e.g. RX 9070 XT with 16 GB).

## Golden Rule

More context = less layers in VRAM. KV cache grows linearly with context size, consuming VRAM that would otherwise hold model layers.

## Patterns by GPU (16 GB VRAM)

These assume Q4_K_M or similar quantization (~4.5 bpw). Adjust down for larger quants, up for smaller (IQ/IQ4).

### 14B models (48 layers)
| Context | GPU Layers | VRAM Notes |
|---------|-----------|------------|
| 128k    | 48 (full) | Fits entirely. ~8.4 GB model + ~1.5 GB KV cache |
| 256k    | 36        | KV cache ~3 GB for 256k. Reduces layers to fit |
| 512k    | 28        | KV cache ~6 GB for 512k. Leaves ~10 GB for model |

### 15B MoE models (27 layers, e.g., synthclaw-14b-128k)
| Context | GPU Layers | VRAM Notes |
|---------|-----------|------------|
| 128k    | 27 (full) | MoE models have smaller KV cache vs params ratio. Fits entirely |
| 256k    | 22        | Some layers spill to CPU |
| 512k    | 16        | More aggressive spill; CPU-computed expert layers will be slower |

### 32B models (64 layers)
| Context | GPU Layers | VRAM Notes |
|---------|-----------|------------|
| 128k    | 30        | ~16.5 GB model. Only ~30 layers fit with 16 GB VRAM at Q4 |
| 256k    | 22        | KV cache takes more room |
| 512k    | 14        | Mostly CPU compute; expect 5–10 tok/s generation |

### 9B models (dense, e.g., synthclaw-9b-128k)
| Context | GPU Layers | VRAM Notes |
|---------|-----------|------------|
| 128k    | 99 (all)  | Tiny model, fits entirely |
| 256k    | 80        | Can spare some to keep KV cache |
| 512k    | 64        | Still mostly in VRAM |

### 9B models (DeltaNet hybrid — 8 full-attn + 24 linear-attn, e.g., synthclaw-9b-128k)

These models have drastically smaller KV cache because only ~25% of layers need it. The model weights are the same size (~5.2 GB at Q4_K_M), but context consumes far less VRAM.

| Context | GPU Layers | VRAM Notes |
|---------|-----------|------------|
| 128k    | 99 (all)  | All layers + 2 GB KV, plenty of headroom |
| 256k    | 99 (all)  | All layers + 4 GB KV, still 7+ GB free |
| 512k    | 99 (all)  | All layers + 8 GB KV, ~3 GB headroom remains |

**Key insight:** DeltaNet models can run **full GPU offload at 512k context** on 16 GB VRAM. The existing 9B Q8_0 KV cache estimate (~80 KB/token for dense) drops to ~16 KB/token here. Always check `layer_types` in config.json before assuming a model is fully dense.

### 9B models (MoE, e.g., synthclaw-14b-128k*)
| Context | GPU Layers | VRAM Notes |
1. Check VRAM total: `rocm-smi --showmeminfo vram` or `vulkaninfo | grep -i "VkPhysicalDeviceMemoryProperties"`
2. Check model size from GGUF metadata: `ls -lh model.gguf`
3. Estimate KV cache per layer: `2 * n_ctx * n_embd_v * 2 bytes` (for Q8_0)
4. Available for layers = VRAM - KV cache budget (leave ~500 MB headroom)
5. Layer size ≈ model_file_size / n_layers
6. `n_gpu_layers = available / layer_size`

## Verification

After setting new values, verify the model actually uses GPU:
```bash
# Start a request through llama-swap
curl -s -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"your-model","messages":[{"role":"user","content":"test"}],"max_tokens":5}'
```
Check the `timings` field in the response:
- `prompt_per_second` > 200 tok/s → GPU working well
- `prompt_per_second` < 50 tok/s → most compute on CPU, need more layers

## Note

The `--n-gpu-layers` flag and VRAM behavior is identical across NVIDIA, AMD, and Intel GPUs — only the build flag (`-DGGML_VULKAN=ON` vs `-DGGML_CUDA=ON`) differs. Layer tuning tables above are specific to 16 GB VRAM; scale proportionally for other capacities.
