# Model Provisioning Workflow — Adding a New GGUF Model

This is the COMPLETE workflow for adding a new GGUF model to the local inference grid. Every model touches 5+ configuration files. Missing any one means the model is invisible to at least one tool.

## Phase 0: Research & Fit Check

### Find the model on HuggingFace

```bash
# Search for GGUF versions
curl -s "https://huggingface.co/api/models?search=<MODEL>+GGUF&sort=downloads&limit=5" \
  | python3 -c "import sys, json; [print(m['modelId']) for m in json.load(sys.stdin)]"

# Check available quant files and sizes
curl -s "https://huggingface.co/api/models/unsloth/<MODEL>-GGUF" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data.get('siblings', []):
    rfn = f.get('rfilename', '')
    if '.gguf' not in rfn: continue
    print(f'  {rfn}')
"

# Get exact file size via HEAD
curl -sI "https://huggingface.co/unsloth/<MODEL>-GGUF/resolve/main/<FILE>.gguf" \
  2>/dev/null | grep -i "^content-length" | awk '{printf "%.2f GB\n", $2/1073741824}'
```

### Calculate VRAM fit

See `references/model-vram-budgeting.md` for the full VRAM math. Key formula:

```
Total = GGUF_size + (2 × attn_layers × kv_heads × head_dim × ctx_size × bytes_per_value) + 0.5 GB

If Total < VRAM:            ✅ Full GPU offload
If Total < 1.5× VRAM:       ⚠️ Partial offload (calculate GPU layers)
If Total > 1.5× VRAM:       ❌ Model too large for this card
```

For 16GB RX 9070 XT, common scenarios:

| Model | Quant | Size | Layers | KV/128k (q4_0) | Total | GPU Layers |
|:------|:-----:|:----:|:------:|:--------------:|:-----:|:----------:|
| 7-9B | Q4_K_M | ~5 GB | 28 | 3.8 GB | ~9 GB | All 28 ✅ |
| 14B | Q4_K_M | ~8.4 GB | 40 | 5.4 GB | ~14 GB | All 40 ✅ |
| 35B MoE | IQ3_S | 13 GB | ~28 attn | 3.5 GB (q4_0) | ~17 GB | ~35/64 partial |

MoE models have fewer attention layers than dense models at the same total param count. This means smaller KV cache — key advantage for VRAM-constrained users.

## Phase 1: Download

```bash
# Use `hf` CLI (NOT deprecated huggingface-cli)
# Background download with notification
terminal(background=true, command="hf download ORG/MODEL-GGUF --include \"*Q4_K_M.gguf\" --local-dir /home/synth/llm/models", notify_on_complete=true, timeout=600)
```

**PITFALL:** `huggingface-cli` is **deprecated** and no longer works. Only use `hf download`.

**PITFALL:** `--include` uses glob patterns. Exact filename may not match. Use `*Q4_K_M.gguf` to catch any variant.

**PITFALL:** For multimodal models (vision), also download the mmproj file: `--include "*mmproj*"`.

## Phase 2: Add to llama-swap config

File: `/home/synth/llama.cpp/llama-swap/config.yaml`

**CRITICAL — Verify the active config path first:**
```bash
ps aux | grep llama-swap | grep -- --config
```
On this system, the REAL config is at `~/llama.cpp/llama-swap/config.yaml`. Editing `~/.config/llama-swap/config.yaml` has zero effect — it's a stale file with a different format. Always verify which config the running instance loads before editing.

Add 3 context variants (128k, 256k, 512k), each on a unique port:

```yaml
  # ────────────────────────────────────────────────────────────────
  # MODEL-NAME Q4_K_M (~N.GGB, dense, N layers, N K native)
  # Ports: NNNN
  # ────────────────────────────────────────────────────────────────
  synthclaw-<name>-128k:
    cmd: /home/synth/.local/bin/evict-and-launch.sh /home/synth/llama.cpp/build/bin/llama-server
      --model /home/synth/llm/models/MODEL-FILE.gguf
      --jinja --reasoning off --reasoning-format deepseek
      --ctx-size 131072 --n-gpu-layers <N> --port <PORT> --host 127.0.0.1
      --alias synthclaw-<name>-128k --flash-attn on
      --cache-type-k q4_0 --cache-type-v q4_0
      --threads 8 --threads-batch 16 --mlock --metrics --parallel 2 --cont-batching
    proxy: http://127.0.0.1:<PORT>
    ttl: 900
    aliases:
    - hermes-<name>
    - hermes <name>
    - <name>
    - <name>-128k
```

**KV cache quantization by context:**
- 128k: `q4_0` (good quality, half the memory of q8_0)
- 256k: `q4_0` (same tradeoff)
- 512k: `q2_0` (must halve again — 512k at q4_0 is 15+ GB just for KV)

**Port assignments (system convention):**
- 8081-8083: 35b (always kept)
- 8096-8098: 14b or general-duty model
- 8099-8101: 9b or lightweight model

**n-gpu-layers guidance (16GB RX 9070 XT, q4_0 KV):**
| Model | Layers | 128k | 256k | 512k |
|:------|:------:|:----:|:----:|:----:|
| 7-9B | 28 | 28 (all) | 28 (all) | 28 (q2_0 KV) |
| 14B | 40 | 40 (all) | 24 | 14 (q2_0 KV) |
| 35B MoE | ~64 total | 35 | 28 | 20 (q8_0 KV) |

**PITFALL:** `--flash-attn on` is incompatible with models using DeltaNet/linear-attention layers (hybrid architectures). Such models hang on the second request. Verify the model's config.json `layer_types` before adding flash-attn.

**PITFALL:** `--flash-attn on` causes **immediate SIGABRT (core dump)** on Microsoft Phi-4 and Phi-4 Reasoning Plus. Remove it entirely for Phi-4 models. See `references/phi-4-deployment.md` for full details.

**PITFALL:** `--reasoning on --reasoning-format deepseek` causes **SIGABRT on Phi-4 Reasoning Plus**. The model has its own built-in reasoning template (ChatML with `<think>` blocks). Use `--jinja` alone and strip all reasoning flags.

**PITFALL:** `--reasoning off --reasoning-format deepseek` is safe for Qwen models (no-op). But always check model-specific compatibility before applying reasoning flags universally.

## Phase 3: Update synthclaw-resolve.sh

File: `/home/synth/.local/bin/synthclaw-resolve.sh`

Add 3 new shorthand cases:

```bash
<name>)       echo "synthclaw-<name>-128k" ;;
<name>max)    echo "synthclaw-<name>-256k" ;;
<name>ultra)  echo "synthclaw-<name>-512k" ;;
```

Also update `print_model_help()` to list the new entries.

## Phase 4: Update claw wrapper

File: `/home/synth/synthclaw-ai-setup/configs/wrappers/claw`

Add the new shorthands to the `case` statement:

```bash
<name>|<name>max|<name>ultra)
```

## Phase 5: Update .hermes-shorthands.sh

File: `/home/synth/.hermes-shorthands.sh`

Add the new shorthands to the `case` statement — both in the pattern match and in the resolve call.

## Phase 6: Update openclaw.json

File: `/home/synth/.openclaw/openclaw.json`

Add model entries to the `llama-swap` provider's `models` array. Each entry needs:

```json
{
  "id": "synthclaw-<name>",
  "name": "MODEL-NAME (QUANT, SIZE, CTX) - DESCRIPTION",
  "reasoning": true,
  "compat": {
    "thinkingFormat": "deepseek"
  }
}
```

Also add corresponding entries (with `-256k` and `-512k` suffix IDs) for the larger context variants.

**PITFALL:** The `models` array must stay valid JSON. Edit carefully or use a Python script to manipulate it.

**PITFALL:** The `agents.defaults.models` map also needs entries for the new model IDs if they should appear in the model selector.

## Phase 7: Update Hermes config fallback_providers

File: `/home/synth/.hermes/config.yaml`

Add the new model IDs to the `fallback_providers` list. This is a JSON-encoded Python list string. Order matters — Hermes tries them left to right.

## Phase 8: Restart & Verify

```bash
# Restart llama-swap (systemd — don't use kill!)
systemctl --user restart llama-swap

# Verify model appears in catalog
sleep 2
curl -s http://127.0.0.1:8080/v1/models | python3 -c "
import sys, json
d = json.load(sys.stdin)
for m in d.get('data', []):
    print(f\"  {m['id']}\")
"

# Test with curl
curl -s -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"<name>","messages":[{"role":"user","content":"hi"}],"max_tokens":10,"temperature":0.1}' \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
m = d['choices'][0]['message']
t = d.get('timings', {})
print(f'Content: \"{m.get(\"content\",\"\")}\"')
print(f'Speed: {t.get(\"predicted_per_second\",0):.0f} t/s')
"

# Test shorthand resolver
source /home/synth/.local/bin/synthclaw-resolve.sh
resolve_model <name>  # should return synthclaw-<name>-128k

# Test hermes shortcut
hermes <name> "test" 2>&1 | head -3
```

## Phase 9: Update memory

Save the new overall lineup to `memory`:

```
memory(action='replace', old_text='AI: Pri=...', content='AI: Pri=Kimi Allegro ($99/mo). Free fallbacks + N local (N vars): ...')
```

## Deletion Workflow (removing a model)

Reverse of the above:

1. Remove from llama-swap config.yaml (delete the model entry block)
2. Remove from synthclaw-resolve.sh
3. Remove from claw wrapper
4. Remove from .hermes-shorthands.sh
5. Remove from openclaw.json (models array + agents.defaults.models map)
6. Remove from hermes config fallback_providers
7. Delete the GGUF file from disk
8. Update memory
9. Restart llama-swap

## Verification checklist

Before declaring success, confirm:

- [ ] `curl http://127.0.0.1:8080/v1/models` shows the new model
- [ ] `curl -X POST ... -d '{"model":"<name>",...}'` returns a valid response
- [ ] `resolve_model <name>` returns the correct ID
- [ ] `hermes <name>` starts with "🎹🦞  hermes synthclaw-<name>"
- [ ] `claw <name>` starts with "🎹🦞 Local: synthclaw-<name>"
- [ ] `claw <name>max` and `<name>ultra` also resolve correctly
- [ ] fallback_providers in hermes config includes the model
- [ ] openclaw.json model selector lists the model
