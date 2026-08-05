# Phi-4 / Phi-4 Reasoning Plus Deployment Guide

Microsoft's Phi-4 series (14B dense) has several incompatibilities with common llama.cpp flags that work fine on Qwen, Llama, and Mistral models. This guide captures the working config and all the pitfalls.

## Working Config (llama-swap)

```yaml
  synthclaw-phi4-128k:
    cmd: /home/synth/.local/bin/evict-and-launch.sh /home/synth/llama.cpp/build/bin/llama-server
      --model /home/synth/models/phi-4/Phi-4-reasoning-plus-Q4_K_M.gguf
      --jinja --ctx-size 131072 --n-gpu-layers 40
      --port 8108 --host 127.0.0.1 --alias synthclaw-phi4-128k
      --cache-type-k q8_0 --cache-type-v q8_0 --threads 8 --threads-batch 16
      --mlock --metrics --parallel 1
    proxy: http://127.0.0.1:8108
    ttl: 900
    aliases:
      - phi4
      - phi-4
```

**Key differences from Qwen/Mistral configs:**
- ❌ NO `--flash-attn on` — causes immediate SIGABRT
- ❌ NO `--reasoning on --reasoning-format deepseek` — causes SIGABRT (model has built-in reasoning template)
- ❌ NO `--cont-batching` — use `--parallel 1` instead
- ❌ NO `--rope-scaling yarn` — not supported
- ✅ `--jinja` alone — uses model's native ChatML template with embedded `<think>` blocks

## Performance (RX 9070 XT, 16GB VRAM, Vulkan)

| Config | Prompt tok/s | Gen tok/s | Notes |
|--------|-------------|-----------|-------|
| 128K, 40 layers, q8_0 KV | ~500 | ~58 | Stable, fast |
| 128K, 40 layers, q4_0 KV | ~880 | ~48 | Faster prompt, slightly slower gen |
| 64K, 40 layers, q8_0 KV | ~750 | ~38 | If you need to free VRAM |

## Incompatibility Matrix

| Flag | Status | Error |
|------|--------|-------|
| `--flash-attn on` | ❌ CRASH | `signal: aborted (core dumped)` |
| `--reasoning on` | ❌ CRASH | `signal: aborted (core dumped)` |
| `--reasoning-format deepseek` | ❌ CRASH | `signal: aborted (core dumped)` |
| `--cont-batching` | ❌ CRASH | `signal: aborted (core dumped)` |
| `--rope-scaling yarn` | ❌ CRASH | `signal: aborted (core dumped)` |
| `--ctx-size 262144` | ❌ CRASH | `signal: aborted (core dumped)` (KV alloc failure) |
| `--jinja` | ✅ WORKS | Native ChatML template |
| `--parallel 1` | ✅ WORKS | Required (no cont-batching) |

## Context Size Hard Limit

Phi-4 **cannot run above ~128K context** with this GGUF and llama.cpp build. Attempts at 256K or 512K fail during KV cache allocation with a core dump — this is not a VRAM exhaustion issue (the same model loads fine at 128K with identical GPU layers). The limitation appears to be in the model's rope/position encoding or the llama.cpp implementation for this architecture.

**Practical implication:** Only deploy Phi-4 as a single 128K entry. Do not create `phi4max` (256K) or `phi4ultra` (512K) variants — they will not work. If the user needs longer context, use Mistral Small 3.2 or Qwen models instead.

## Reasoning Output

Phi-4 Reasoning Plus produces `<think>` / `</think>` reasoning blocks natively via its Jinja template. No special flags are needed. The model's system prompt (embedded in the GGUF) instructs it to use this format:

```
<think>
{reasoning process}
</think>
{final answer}
```

If you need to strip reasoning blocks from output, do it at the client level — llama-server returns the full response including `<think>` sections.

## GPU Layer Tuning (16GB VRAM)

At 128K context with q8_0 KV cache:
- 40 layers (full offload): ~8.5 GB model + ~2.5 GB KV = ~11 GB used
- Headroom for other models: ~5 GB

If running alongside a 35B MoE model, reduce Phi-4 to 28 layers to free VRAM.
