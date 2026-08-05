# Local Model Stack — MODELS.md

Hardware target: GTX 1080 Ti 11GB (Vulkan) / i7-8700K / 16GB RAM.
llama-swap swaps one resident model at a time (group `gpu`, swap+exclusive).

## Layout

| Piece | Path | Source |
|---|---|---|
| llama.cpp binaries | `~/llama.cpp/llama-b10092/` | github.com/ggml-org/llama.cpp releases (b10092, Vulkan build) |
| llama-swap binary | `~/.local/bin/llama-swap` | github.com/mostlygeek/llama-swap releases (linux_amd64) |
| llama-swap config | `~/.config/llama-swap/config.yaml` | restored by install.sh |
| Chat templates | `~/.config/llama-swap/template-*.jinja` | restored by install.sh |
| GGUF weights | `~/models/` | download manually (below) |
| systemd unit | `~/.config/systemd/user/llama-swap.service` | restored, serves 127.0.0.1:8080 |

## Models (download with `hf download`)

Install the CLI first: `pip install -U "huggingface_hub[cli]"` (use a venv or `--break-system-packages`), then:

```bash
cd ~/models

# Flagship — Gemma 4 12B IT QAT Q4_0 + vision projector (~6.7GB)
hf download <REPO_CONTAINING>/gemma-4-12b-it-qat-q4_0.gguf --local-dir ~/models
hf download <REPO_CONTAINING>/mmproj-gemma-4-12b-it-qat-q4_0.gguf --local-dir ~/models

# Fast lane — Qwen3.5 9B MTP Q6_K (~7.7GB)
hf download <REPO_CONTAINING>/Qwen3.5-9B-MTP-Q6_K.gguf --local-dir ~/models

# Experimental — ADI GLM-5.2 distill (Qwen3.5-9B base) q4_k_m (~5.6GB)
hf download <REPO_CONTAINING>/adi-qwen3.5-9b-glm5.2-general-q4_k_m.gguf --local-dir ~/models
```

> NOTE: `<REPO_CONTAINING>` = the HF repo each GGUF lives in. Search
> `hf search <filename-without-ext>` if unsure — filenames in
> `~/.config/llama-swap/config.yaml` must match exactly.

## Endpoints in llama-swap config

| ID | Weights | Ctx | Notes |
|---|---|---|---|
| `synthclaw` | gemma-4-12b-it-qat-q4_0 | 128K | flagship, vision |
| `synthclaw-262k` | same | 256K | native ctx ceiling |
| `synthclaw-fast` | Qwen3.5-9B-MTP-Q6_K | 128K | `:think` alias enables reasoning |
| `synthclaw-fast-262k` | same | 262K | |
| `synthclaw-glm` | adi-qwen3.5-9b-glm5.2 q4_k_m | 128K | experimental |
| `synthclaw-glm-262k` | same | 262K | |

## After models are in place

```bash
systemctl --user start llama-swap
curl http://127.0.0.1:8080/v1/models   # should list the six endpoints
```
