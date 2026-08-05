# Synth's Local Model Roster (llama-swap)

All models served through llama-swap at `http://127.0.0.1:8080`.

## Fast LLM (OpenAI-compatible endpoint)

Provider name in opencode.json: `local`
Base URL: `http://127.0.0.1:8080/v1`

| Model ID | Size | Context | Notes |
|----------|------|---------|-------|
| `synthclaw-35bkimi-128k` | 35B | 128K | **Primary** — Kimi K2.6 Reasoning Distilled IQ4_XS |
| `synthclaw-35bkimi-256k` | 35B | 256K | Extended context variant |
| `synthclaw-35bkimi-512k` | 35B | 512K | Max context variant |
| `synthclaw-35b-128k` | 35B | 128K | Qwen3.6-35B non-reasoning |
| `synthclaw-35b-256k` | 35B | 256K | Extended context |
| `synthclaw-35b-512k` | 35B | 512K | Max context |
| `synthclaw-14b-128k` | 14B | 128K | Qwen3-14B Q4_K_M |
| `synthclaw-14b-256k` | 14B | 256K | Extended context |
| `synthclaw-14b-512k` | 14B | 512K | Max context |
| `synthclaw-9b-128k` | 9B | 128K | Qwen3.5-9B Q4_K_M |
| `synthclaw-9b-256k` | 9B | 256K | Extended context |
| `synthclaw-9b-512k` | 9B | 512K | Max context |

## Model Limits for opencode.json

```json
{
  "synthclaw-35bkimi-128k": { "context": 128000, "output": 65536 },
  "synthclaw-35bkimi-256k": { "context": 256000, "output": 65536 },
  "synthclaw-35bkimi-512k": { "context": 512000, "output": 65536 },
  "synthclaw-35b-128k":     { "context": 128000, "output": 65536 },
  "synthclaw-35b-256k":     { "context": 256000, "output": 65536 },
  "synthclaw-35b-512k":     { "context": 512000, "output": 65536 },
  "synthclaw-14b-128k":     { "context": 128000, "output": 65536 },
  "synthclaw-14b-256k":     { "context": 256000, "output": 65536 },
  "synthclaw-14b-512k":     { "context": 512000, "output": 65536 },
  "synthclaw-9b-128k":      { "context": 128000, "output": 65536 },
  "synthclaw-9b-256k":      { "context": 256000, "output": 65536 },
  "synthclaw-9b-512k":      { "context": 512000, "output": 65536 }
}
```

## Recommended OmO Agent Routing

Heavy agents → `local/synthclaw-35bkimi-128k` (primary coding model)
Light agents → `opencode/deepseek-v4-flash-free` or `local/synthclaw-9b-128k`

## Server Notes

- Kimi 35B runs on port 8102 (direct), swapped via port 8080
- AMD Vulkan GPU — no `--flash-attn` or `--cont-batching` on Kimi
- `--parallel 1` only on Kimi to avoid VRAM hangs
- Direct port check: `curl -s http://127.0.0.1:8102/v1/models`
