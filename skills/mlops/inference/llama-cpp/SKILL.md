---
name: llama-cpp
description: llama.cpp local GGUF inference + HF Hub model discovery.
version: 2.1.2
author: Orchestra Research
license: MIT
dependencies: [llama-cpp-python>=0.2.0]
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [llama.cpp, GGUF, Quantization, Hugging Face Hub, CPU Inference, Apple Silicon, Edge Deployment, AMD GPUs, Intel GPUs, NVIDIA, URL-first]
---

# llama.cpp + GGUF

Use this skill for local GGUF inference, quant selection, or Hugging Face repo discovery for llama.cpp.

## When to use

- Run local models on CPU, Apple Silicon, CUDA, ROCm, or Intel GPUs
- Find the right GGUF for a specific Hugging Face repo
- Build a `llama-server` or `llama-cli` command from the Hub
- Search the Hub for models that already support llama.cpp
- Enumerate available `.gguf` files and sizes for a repo
- Decide between Q4/Q5/Q6/IQ variants for the user's RAM or VRAM

## Model Discovery workflow

Prefer URL workflows before asking for `hf`, Python, or custom scripts.

1. Search for candidate repos on the Hub:
   - Base: `https://huggingface.co/models?apps=llama.cpp&sort=trending`
   - Add `search=<term>` for a model family
   - Add `num_parameters=min:0,max:24B` or similar when the user has size constraints
2. Open the repo with the llama.cpp local-app view:
   - `https://huggingface.co/<repo>?local-app=llama.cpp`
3. Treat the local-app snippet as the source of truth when it is visible:
   - copy the exact `llama-server` or `llama-cli` command
   - report the recommended quant exactly as HF shows it
4. Read the same `?local-app=llama.cpp` URL as page text or HTML and extract the section under `Hardware compatibility`:
   - prefer its exact quant labels and sizes over generic tables
   - keep repo-specific labels such as `UD-Q4_K_M` or `IQ4_NL_XL`
   - if that section is not visible in the fetched page source, say so and fall back to the tree API plus generic quant guidance
5. Query the tree API to confirm what actually exists:
   - `https://huggingface.co/api/models/<repo>/tree/main?recursive=true`
   - keep entries where `type` is `file` and `path` ends with `.gguf`
   - use `path` and `size` as the source of truth for filenames and byte sizes
   - separate quantized checkpoints from `mmproj-*.gguf` projector files and `BF16/` shard files
   - use `https://huggingface.co/<repo>/tree/main` only as a human fallback
6. If the local-app snippet is not text-visible, reconstruct the command from the repo plus the chosen quant:
   - shorthand quant selection: `llama-server -hf <repo>:<QUANT>`
   - exact-file fallback: `llama-server --hf-repo <repo> --hf-file <filename.gguf>`
7. Only suggest conversion from Transformers weights if the repo does not already expose GGUF files.

## Quick start

### Install llama.cpp

```bash
# macOS / Linux (simplest)
brew install llama.cpp
```

> **Pitfall:** The binary from `brew` or a package manager is often CPU-only — verify with `strings $(which llama-server) | grep -E "ggml_vulkan|ggml_cuda"` before assuming GPU acceleration works.

```bash
winget install llama.cpp
```

```bash
# Generic CPU build
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build
cmake --build build --config Release
```

### GPU builds

**NVIDIA (CUDA):**
```bash
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release
```

**AMD (Vulkan) — most portable across RDNA 2/3/4:**
```bash
# Requires: mesa vulkan-radeon, vulkan-tools (for debugging)
# Verify GPU visible first: vulkaninfo --summary | grep deviceName
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release
```

**AMD (ROCm/HIP) — requires rocm-hip-sdk packages:**
```bash
cmake -B build -DGGML_HIP=ON
cmake --build build --config Release
```

**Verification:**
```bash
strings ./build/bin/llama-server | grep -E "ggml_vulkan|ggml_hip|ggml_cuda" | head -5
```
If the only output is `ggml_backend_cpu` symbols, the binary was built without GPU support. Rebuild with the appropriate `-DGGML_*=ON` flag. The `llama-server --help` output will also show a `warning: no usable GPU found` message at startup if GPU support is missing.

### Run directly from the Hugging Face Hub

```bash
llama-cli -hf bartowski/Llama-3.2-3B-Instruct-GGUF:Q8_0
```

```bash
llama-server -hf bartowski/Llama-3.2-3B-Instruct-GGUF:Q8_0
```

### Run an exact GGUF file from the Hub

Use this when the tree API shows custom file naming or the exact HF snippet is missing.

```bash
llama-server \
    --hf-repo microsoft/Phi-3-mini-4k-instruct-gguf \
    --hf-file Phi-3-mini-4k-instruct-q4.gguf \
    -c 4096
```

### OpenAI-compatible server check

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Write a limerick about Python exceptions"}
    ]
  }'
```

## Chat Template Mismatch Debugging

When a model outputs raw template tokens instead of natural text (e.g. `<|im_start|>`, `<|turn|>`, `[INST]` tokens appearing verbatim in the output), the Jinja chat template format does NOT match the model's training format.

**Root cause:** llama-server uses `--jinja` + `--chat-template-file` or the model's built-in `tokenizer.chat_template` to format the prompt. If the template uses different delimiter tokens than what the model was trained on, the model treats the delimiters as regular text to continue, not as structural markers.

**Common mismatches by model family:**

| Model Family | Expected Format | Example Tokens |
|---|---|---|
| Qwen 2.5 / 3.x | ChatML | `<|im_start|>system\n...<|im_end|>\n<|im_start|>user\n...<|im_end|>\n<|im_start|>assistant\n` |
| Llama 3.x | Llama 3 | `<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n...<|eot_id|>` |
| Mistral / Mixtral | Mistral | `[INST] ... [/INST]` |
| DeepSeek V2 | DeepSeek | `<｜begin▁of▁sentence｜>...<｜end▁of▁sentence｜>` |
| Command R | Cohere | `<BOS_TOKEN><|START_OF_TURN_TOKEN|><|USER_TOKEN|>...<|END_OF_TURN_TOKEN|>` |

**Diagnostic steps:**
1. Send a simple request to the running llama-server:
   ```bash
   curl -s http://127.0.0.1:PORT/v1/chat/completions \
     -H 'Content-Type: application/json' \
     -d '{"model": "model-name", "messages": [{"role": "user", "content": "say hi"}], "max_tokens": 10}'
   ```
2. If the response `content` field contains template tokens like `<|turn|>` or `<|im_start|>`, the template format is wrong.
3. Check which template is active: `llama-server --help | grep -A5 chat-template` or look at the `--jinja` + `--chat-template-file` args in the server command.
4. The fix is to use the chat template format that matches the model's training data. For Qwen models, this means standard ChatML (`<|im_start|>` / `<|im_end|>`). For custom templates, the format tokens MUST match what the base model was trained to recognize as structural delimiters.

**PITFALL:** Custom Jinja templates that use non-standard delimiter tokens (e.g. `<|turn|>` instead of `<|im_start|>`) will cause the model to echo back the delimiters. The model was trained to recognize the standard delimiters as processing instructions. Any substitution must use the same token IDs that the model learned during training.

**PITFALL:** The `--jinja` flag does NOT validate that the chat template tokens match the model's tokenizer vocabulary. A template that uses tokens the tokenizer maps to different IDs than expected will silently produce garbage output.

**PITFALL: Multi-line string literals in `{% set %}` blocks crash the C++ Jinja lexer.** llama.cpp's embedded Jinja parser (C++ implementation, not full Jinja2) cannot parse multi-line string literals assigned via `{% set var = "...\n..." %}`. This triggers `lexer: unexpected end of input during consume_while`. The template fails to initialize and the model slot enters a permanent failed state.

**Example of broken pattern:**
```jinja
{%- set synthclaw_identity = "You are synthclaw.
Born from the neon grid of 1984." -%}
```

**Fix:** Inline the content directly instead of assigning to a variable:
```jinja
{{- 'You are synthclaw.\n' -}}
{{- 'Born from the neon grid of 1984.\n' -}}
```

Or use single-line concatenation with explicit `\n` escapes:
```jinja
{%- set identity = "You are synthclaw.\nBorn from the neon grid of 1984." -%}
```

The single-line form with `\n` escapes works because the string is parsed as one line — the `\n` is just content. Multi-line literal strings where the actual line break falls inside the quote break the lexer because it sees the closing quote on the wrong line.

**Deep reference:** For detailed Jinja template format specifications by model architecture (Qwen ChatML, DeepSeek plain text, Gemma Llama-3 style), identity injection patterns, tool calling formats, and working template examples, see the `production-ready-rust-flutter-projects` skill reference `references/llm-jinja-template-formats.md`.

## Python bindings (llama-cpp-python)

`pip install llama-cpp-python` (CUDA: `CMAKE_ARGS="-DGGML_CUDA=on" pip install llama-cpp-python --force-reinstall --no-cache-dir`; Metal: `CMAKE_ARGS="-DGGML_METAL=on" ...`).

### Basic generation

```python
from llama_cpp import Llama

llm = Llama(
    model_path="./model-q4_k_m.gguf",
    n_ctx=4096,
    n_gpu_layers=35,     # 0 for CPU, 99 to offload everything
    n_threads=8,
)

out = llm("What is machine learning?", max_tokens=256, temperature=0.7)
print(out["choices"][0]["text"])
```

### Chat + streaming

```python
llm = Llama(
    model_path="./model-q4_k_m.gguf",
    n_ctx=4096,
    n_gpu_layers=35,
    chat_format="llama-3",   # or "chatml", "mistral", etc.
)

resp = llm.create_chat_completion(
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is Python?"},
    ],
    max_tokens=256,
)
print(resp["choices"][0]["message"]["content"])

# Streaming
for chunk in llm("Explain quantum computing:", max_tokens=256, stream=True):
    print(chunk["choices"][0]["text"], end="", flush=True)
```

### Embeddings

```python
llm = Llama(model_path="./model-q4_k_m.gguf", embedding=True, n_gpu_layers=35)
vec = llm.embed("This is a test sentence.")
print(f"Embedding dimension: {len(vec)}")
```

You can also load a GGUF straight from the Hub:

```python
llm = Llama.from_pretrained(
    repo_id="bartowski/Llama-3.2-3B-Instruct-GGUF",
    filename="*Q4_K_M.gguf",
    n_gpu_layers=35,
)
```

## Multimodal models (vision)

Many GGUF repos on HF are tagged `Image-Text-to-Text` even when their filenames look like plain text models (e.g. `Qwen3.6-35B-A3B-UD-IQ3_S.gguf`). The `-UD` suffix means understanding-and-generation, which includes vision capability — but only if `--mmproj` is loaded.

**To enable vision on a multimodal GGUF:**

1. Check the HF repo has `mmproj-*.gguf` files (F16 is the best size/quality balance)
2. Download: `curl -L -o /path/to/mmproj-F16.gguf "https://huggingface.co/<repo>/resolve/main/mmproj-F16.gguf"`
3. Add `--mmproj /path/to/mmproj-F16.gguf` to your `llama-server` command, right after `--model`
4. Restart the server

**PITFALL:** Without `--mmproj`, a multimodal GGUF loads and runs fine — but silently refuses image inputs. It looks like a text model, generates text fine, but errors on any vision request. The missing mmproj is the first thing to check when a model that claims vision support can't process images.

**PITFALL:** The mmproj adds ~1-1.5GB of VRAM overhead. On a 16GB card, a 13GB model GGUF + 1GB mmproj + KV cache = borderline but workable at 128k.

**Also on quant selection**

Use the Hub page first, generic heuristics second.

- Prefer the exact quant that HF marks as compatible for the user's hardware profile.
- For general chat, start with `Q4_K_M`.
- For code or technical work, prefer `Q5_K_M` or `Q6_K` if memory allows.
- For very tight RAM budgets, consider `Q3_K_M`, `IQ` variants, or `Q2` variants only if the user explicitly prioritizes fit over quality.
- For multimodal repos, mention `mmproj-*.gguf` separately. The projector is not the main model file.
- Do not normalize repo-native labels. If the page says `UD-Q4_K_M`, report `UD-Q4_K_M`.

## Extracting available GGUFs from a repo

When the user asks what GGUFs exist, return:

- filename
- file size
- quant label
- whether it is a main model or an auxiliary projector

Ignore unless requested:

- README
- BF16 shard files
- imatrix blobs or calibration artifacts

Use the tree API for this step:

- `https://huggingface.co/api/models/<repo>/tree/main?recursive=true`

For a repo like `unsloth/Qwen3.6-35B-A3B-GGUF`, the local-app page can show quant chips such as `UD-Q4_K_M`, `UD-Q5_K_M`, `UD-Q6_K`, and `Q8_0`, while the tree API exposes exact file paths such as `Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` and `Qwen3.6-35B-A3B-Q8_0.gguf` with byte sizes. Use the tree API to turn a quant label into an exact filename.

## Search patterns

Use these URL shapes directly:

```text
https://huggingface.co/models?apps=llama.cpp&sort=trending
https://huggingface.co/models?search=<term>&apps=llama.cpp&sort=trending
https://huggingface.co/models?search=<term>&apps=llama.cpp&num_parameters=min:0,max:24B&sort=trending
https://huggingface.co/<repo>?local-app=llama.cpp
https://huggingface.co/api/models/<repo>/tree/main?recursive=true
https://huggingface.co/<repo>/tree/main
```

## Output format

When answering discovery requests, prefer a compact structured result like:

```text
Repo: <repo>
Recommended quant from HF: <label> (<size>)
llama-server: <command>
Other GGUFs:
- <filename> - <size>
- <filename> - <size>
Source URLs:
- <local-app URL>
- <tree API URL>
```

## References

- **[deepseek-local-model-landscape.md](references/deepseek-local-model-landscape.md)** — condensed research on DeepSeek open source models for local inference: which fit 16 GB VRAM, which don't, and why no DeepSeek model currently beats Qwen 3.6 35B on consumer hardware
- **[hub-discovery.md](references/hub-discovery.md)** — URL-only Hugging Face workflows, search patterns, GGUF extraction, and command reconstruction
- **[model-evaluation.md](references/model-evaluation.md)** — end-to-end workflow for evaluating "can I run this model locally?" — size thresholds, distillation search, architecture checks, LFS file size fallback, quantization selection, llama-swap integration
- **[vram-sizing.md](references/vram-sizing.md)** — VRAM fit tables for 16GB GPUs, MoE overhead, multimodal overhead, OOM diagnosis
- **[advanced-usage.md](references/advanced-usage.md)** — speculative decoding, batched inference, grammar-constrained generation, LoRA, multi-GPU, custom builds, benchmark scripts
- **[quantization.md](references/quantization.md)** — quant quality tradeoffs, when to use Q4/Q5/Q6/IQ, model size scaling, imatrix
- **[server.md](references/server.md)** — direct-from-Hub server launch, OpenAI API endpoints, Docker deployment, NGINX load balancing, monitoring
- **[optimization.md](references/optimization.md)** — CPU threading, BLAS, GPU offload heuristics, batch tuning, benchmarks
- **[troubleshooting.md](references/troubleshooting.md)** — install/convert/quantize/inference/server issues, Apple Silicon, debugging

## Resources

- **GitHub**: https://github.com/ggml-org/llama.cpp
- **Hugging Face GGUF + llama.cpp docs**: https://huggingface.co/docs/hub/gguf-llamacpp
- **Hugging Face Local Apps docs**: https://huggingface.co/docs/hub/main/local-apps
- **Hugging Face Local Agents docs**: https://huggingface.co/docs/hub/agents-local
- **Example local-app page**: https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF?local-app=llama.cpp
- **Example tree API**: https://huggingface.co/api/models/unsloth/Qwen3.6-35B-A3B-GGUF/tree/main?recursive=true
- **Example llama.cpp search**: https://huggingface.co/models?num_parameters=min:0,max:24B&apps=llama.cpp&sort=trending
- **License**: MIT
