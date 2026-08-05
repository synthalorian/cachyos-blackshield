# VRAM Sizing for Local GGUF Models

When selecting GGUF quants for local inference on a fixed-VRAM GPU, the real-world constraint is:

**GGUF file size + ~2-3GB overhead (KV cache + intermediate buffers) must fit in available VRAM.**

The 2-3GB overhead is conservative and covers 128k context. Larger contexts (256k/512k) add proportionally more overhead. The KV cache alone for a 35B model at Q8_0 cache precision at 128k context is roughly `layers * hidden_dim * 2 * precision_bytes * seq_len` — typically 1-2GB. At 512k it's 4-8GB depending on architecture.

## 16GB RX 9070 XT — Real-World Fit Table

These numbers are empirically verified on a 16GB RDNA 4 GPU (RX 9070 XT) running llama.cpp with Vulkan `--flash-attn on --cache-type-k q8_0 --cache-type-v q8_0`:

| Model | GGUF Size | Quant | GPU Layers | 128k | 256k | 512k |
|:------|:---------:|:-----:|:----------:|:----:|:----:|:----:|
| synthclaw-35b-128k | **13GB** | IQ3_S | 35/28/20 | ✅ | ✅ | ✅ |
| synthclaw-14b-128k | **8.4GB** | Q4_K_M | 99/80/60 | ✅ | ✅ | ✅ |
| synthclaw-14b-128k | **9.7GB** | Q4_K_M | 27/21/15 | ✅ | ✅ | ✅ |
| synthclaw-9b-128k | **5.3GB** | Q4_K_M | 99/80/64 | ✅ | ✅ | ✅ |
| synthclaw-35b-128k | **17GB** | IQ4_XS | 30/24/18 | ❌ | ❌ | ❌ |
| synthclaw-35b-128k | **15GB** | IQ4_XS | 99/80/64 | ❌ | ❌ | ❌ |
| synthclaw-35b-128k | **12GB** | Q3_K_S | 50/40/28 | ✅ | ✅ | ✅ |
| synthclaw-35b-128k | **16GB** | Q4_K_M | 75/55/35 | ❌ | ❌ | ❌ |

**Rule of thumb:** If the GGUF file alone is >80% of VRAM, it won't fit with any usable context. At 90%+ it's dead on arrival at 128k.

## MoE Models and VRAM

MoE (Mixture of Experts) models like Qwen3.6-35B-A3B and synthclaw-35b-128k load ALL parameters into VRAM, not just the active ones. The GGUF file size is the honest size — MoE doesn't give you a VRAM discount. The speed benefit is in inference (fewer FLOPs per token), not memory.

## Multimodal Overhead

Multimodal models need `--mmproj <file.gguf>` which loads an additional 1-1.5GB for the vision encoder. The total VRAM footprint = model GGUF + mmproj GGUF + KV cache. For a 13GB model + 1GB mmproj on a 16GB card, that leaves ~2GB for KV cache — tight but workable at 128k with flash-attn.

## Diagnosis

When a model connection fails (timeout, `APIConnectionError` from llama-swap), suspect VRAM exhaustion first:

1. Check if the process actually started: `ps aux | grep llama-server | grep <model-port>`
2. If running, check dmesg for GPU OOM: `sudo dmesg | grep -i "gpu" | grep -i "oom\|hung\|reset"`  
3. If not running, the model either segfaulted (GGUF corruption or architecture mismatch) or was killed by OOM
4. Verify the GGUF file size against available VRAM using the table above
