# Kimi K2.6 Distilled Model — Deployment Notes

Deployed 2026-05-24. Model: `Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled.IQ4_XS.gguf` (18 GB).

## FINAL CONFIGURATION (as of 2026-05-25)

All three Kimi K2.6 variants should use this minimal config:

```
cmd: /home/synth/llama.cpp/build/bin/llama-server
  --model /home/synth/llm/models/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled.IQ4_XS.gguf
  --mmproj /home/synth/llm/models/Qwen3.6-35B-A3B-mmproj-F16.gguf
  --ctx-size N
  --n-gpu-layers LAYERS
  --port PORT
  --host 127.0.0.1
  --alias synthclaw-35bkimi-SIZE
  --cache-type-k CACHE --cache-type-v CACHE
  --threads 8 --threads-batch 16
  --mlock --metrics
  --parallel 1
  [--rope-scaling yarn --yarn-orig-ctx 32768]  # for 256k and 512k only
```

**Key rules: NO custom template, NO `--jinja`, NO `--reasoning` flags, NO `--flash-attn`, NO `--cont-batching`, NO evict wrapper.**

## Config Entries

Three context variants in `/home/synth/llama.cpp/llama-swap/config.yaml`:

| Variant | Port | GPU Layers | Cache | Context |
|---------|------|------------|-------|---------|
| 128k | 8102 | 26 | q8_0/q8_0 | 131072 |
| 256k | 8103 | 20 | q4_0/q4_0 | 262144 |
| 512k | 8104 | 12 | q2_0/q2_0 | 524288 |

## CRITICAL FINDINGS (2026-05-25)

### 1. ALL Qwen Models Are Reasoning Models

Every Qwen-model variant on this system outputs `` `thinking` `` blocks natively:
- Qwen3.5-9B (labeled "base") → outputs ` thinking` blocks
- Qwen3-14B (labeled "base") → outputs ` thinking` blocks
- Qwen3.6-35B-A3B-UD (labeled "UD") → outputs ` thinking` blocks
- Kimi K2.6 distilled → outputs ` thinking` blocks

The "UD" suffix means "Unified Distillation" — it's a reasoning-trained variant. Even plain Qwen model names on HuggingFace are often reasoning-distilled now. Never assume a model is "base" just from its name. Always check by sending a test prompt.

### 2. GGUF Built-in Template is MANDATORY

The model's GGUF file has a baked-in chat template that correctly:
- Parses `` `thinking` `` blocks from the raw output
- Extracts them into the `reasoning_content` API field
- Puts the final answer (after the ` response` tag) into the `content` field

Using `--chat-template-file` with ANY custom template (even simple ChatML) breaks this separation. All output lands in `content` as raw text, causing clients to fail with `"Failed to parse input at pos N: \`thinking\`"`.

### 3. Identity Injection Must Come From Client

Since custom templates are off-limits, identity injection (`"You are synthclaw..."`) must come from the client's system message:
- **Hermes:** Already sends SOUL.md as a system prompt — identity works automatically
- **claw-code:** Add identity instructions to your prompts or configure a system message prefix

### 4. Hybrid/Recurrent Memory — flash-attn Incompatibility

This model has hybrid/recurrent memory layers. The server log confirms:
```
slot update_slots: ... forcing full prompt re-processing due to lack of cache data
    (likely due to SWA or hybrid/recurrent memory)
```

**Do NOT use:**
- `--flash-attn on` — causes silent hang after 1+ requests (process stays alive but HTTP port disappears)
- `--cont-batching` — also incompatible with hybrid memory

**Do use:**
- `--parallel 1` — prevents slot contention

### 5. No evict-and-launch.sh

~~Run llama-server directly (no eviction wrapper). The evict wrapper creates a race condition: when a client retries a request during cold-start, the second spawn's `pkill -SIGTERM llama-server` kills the first spawn mid-init. Both processes die and the model never binds its port.~~

**UPDATE (2026-05-31):** The Kimi K2.6 models MUST use `evict-and-launch.sh` like all other models. Without it, the model loads on first request and never unloads — TTL-based eviction does not work for direct-launched entries. The process stays resident indefinitely, consuming ~8.7GB RAM and 355% CPU even when no requests are active. The original race concern was a misdiagnosis; `evict-and-launch.sh` works correctly with these models.

**Corrected config pattern:**
```yaml
  synthclaw-35bkimi-128k:
    cmd: /home/synth/.local/bin/evict-and-launch.sh /home/synth/llama.cpp/build/bin/llama-server
      --model /home/synth/llm/models/Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled.IQ4_XS.gguf
      --mmproj /home/synth/llm/models/Qwen3.6-35B-A3B-mmproj-F16.gguf
      --ctx-size 131072 --n-gpu-layers 24
      --port 8102 --host 127.0.0.1 --alias synthclaw-35bkimi-128k
      --reasoning on --reasoning-format deepseek --reasoning-budget 4096
      --cache-type-k q8_0 --cache-type-v q8_0 --threads 8 --threads-batch 16
      --mlock --metrics --parallel 1
    proxy: http://127.0.0.1:8102
    ttl: 480
```

### 6. No reasoning flags needed

Do NOT set `--reasoning` or `--reasoning-format` flags. The defaults (`--reasoning auto`, `--reasoning-format auto`) detect the format from the GGUF metadata. The server handles thinking block separation natively.

## Debug History

### Problem 1 — Template parse failure
- **Error:** `common_chat_templates_init: error: lexer: unexpected end of input during consume_while`
- **Root cause:** `{%- set synthclaw_identity = "..." -%}` with 27-line string value. llama.cpp C++ Jinja lexer can't handle multi-line string literals.
- **Fix:** Inlined identity text directly in output section instead of via variable.
- **Recovery:** `systemctl --user restart llama-swap` to clear the permanent process-slot failed state.
- **Note:** This template was later entirely abandoned in favor of the GGUF built-in template.

### Problem 2 — Raw thinking tags in output
- **Symptom:** Response content started with ` think\n` as visible text. Hermes returned `"Failed to parse input at pos 22: \`thinking\`"`.
- **Root cause:** Custom Jinja template (`synthclaw-kimi.jinja` or `synthclaw-kimi-simple.jinja`) broke the GGUF's built-in reasoning extraction.
- **Fix:** Removed ALL `--chat-template-file` and `--jinja` flags. Used GGUF built-in template. Removed ALL `--reasoning` and `--reasoning-format` flags — defaults handle it.
- **Result:** Content field is clean (`"Hi there."`), reasoning goes to `reasoning_content` field.

### Problem 3 — Missing resolver entries
- **Symptom:** `claw 35bkimi` showed banner saying "Local: synthclaw-35bkimi-128k" but resolved model name was wrong.
- **Root cause:** `resolve_model()` in `synthclaw-resolve.sh` had no case for `35bkimi` — fell through to `*)` default which echoed the shorthand back.
- **Fix:** Added `35bkimi`, `35bkimimax`, `35bkimiultra` cases to `resolve_model()`.

### Problem 4 — Hybrid memory + flash-attn silent hang
- **Symptom:** Llama-server process stayed alive for 40+ minutes consuming 2h CPU time, but its HTTP port (8102) wasn't bound. Curl got `connection refused`. Process state was `S` (sleeping) with 26 threads.
- **Root cause:** `--flash-attn on` + `--cont-batching` invompatible with model's hybrid/recurrent memory layers.
- **Fix:** Removed both flags. Changed `--parallel 2` to `--parallel 1`.
- **Diagnosis signal:** Server log message: `"forcing full prompt re-processing due to lack of cache data (likely due to SWA or hybrid/recurrent memory)"`

### Problem 5 — Cold-start timeout mismatch with Hermes
- **Symptom:** `hermes 35bkimi` would fail with 502 even though curl worked fine after 15-20s.
- **Root cause:** Hermes' retry loop: 3 attempts at ~2.5s intervals (7.5s total), each with 0.1s timeout. A 35B MoE takes 15-20s to cold-start. Hermes gives up before the port binds.
- **Fix:** Pre-warm the model before using Hermes, or use curl with `--max-time 180`.

### Problem 6 — Model path mismatches
- **Symptom:** llama-swap logs showed `"gguf_init_from_file: failed to open GGUF file... No such file or directory"` for 9b and 14b models.
- **Root cause:** Config pointed to `.../9b/Qwen3.5-9B-fp16-UD-IQ4_K_M.gguf` and `.../14b/Qwen3.5-14B-fp16-UD-IQ4_K_M.gguf` but actual files were at `.../Qwen3.5-9B-Q4_K_M.gguf` and `.../Qwen3-14B-Q4_K_M.gguf` (flat directory, different quantization).
- **Fix:** Updated config paths to actual file locations. Verify actual files with `find /home/synth -name "*.gguf"`.

## Model Architecture

- **Base:** Qwen3.6-35B-A3B (3B active / 35B total MoE)
- **Distillation:** Kimi K2.6 reasoning distillation
- **Quantization:** IQ4_XS (18.9 GB)
- **Multimodal:** Yes, uses `Qwen3.6-35B-A3B-mmproj-F16.gguf`
- **Context:** 128k, 256k (YaRN), 512k (YaRN)
- **Performance:** ~40 tok/s on RX 9070 XT @ 26 GPU layers
- **Template:** GGUF built-in — DO NOT override with custom template
- **Reasoning:** Native `` `thinking` `` blocks (backtick format, not XML tags)

## Working Harnesses

| Harness | Status | Command |
|---------|--------|---------|
| **claw-code** | ✅ | `claw 35bkimi <prompt>` |
| **Hermes** | ✅ | `hermes 35bkimi <prompt>` (after warm) |
| **OpenCode** | ✅ | Via llama-swap provider endpoint |
| **curl** | ✅ | `curl http://127.0.0.1:8080/v1/...` |