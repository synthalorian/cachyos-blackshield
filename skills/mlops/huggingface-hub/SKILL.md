---
name: huggingface-hub
description: "HuggingFace hf CLI: search/download/upload models, datasets."
version: 1.0.0
author: Hugging Face
license: MIT
tags: [huggingface, hf, models, datasets, hub, mlops]
platforms: [linux, macos, windows]
---

# Hugging Face CLI (`hf`) Reference Guide

The `hf` command is the modern command-line interface for interacting with the Hugging Face Hub, providing tools to manage repositories, models, datasets, and Spaces.

> **IMPORTANT:** The `hf` command replaces the now deprecated `huggingface-cli` command.

## Quick Start
*   **Installation:** `curl -LsSf https://hf.co/cli/install.sh | bash -s`
*   **Help:** Use `hf --help` to view all available functions and real-world examples.
*   **Authentication:** Recommended via `HF_TOKEN` environment variable or the `--token` flag.

---

## Core Commands

### General Operations
*   `hf download REPO_ID`: Download files from the Hub.
*   `hf upload REPO_ID`: Upload files/folders (recommended for single-commit).
*   `hf upload-large-folder REPO_ID LOCAL_PATH`: Recommended for resumable uploads of large directories.
*   `hf sync`: Sync files between a local directory and a bucket.
*   `hf env` / `hf version`: View environment and version details.

### Authentication (`hf auth`)
*   `login` / `logout`: Manage sessions using tokens from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens).
*   `list` / `switch`: Manage and toggle between multiple stored access tokens.
*   `whoami`: Identify the currently logged-in account.

### Repository Management (`hf repos`)
*   `create` / `delete`: Create or permanently remove repositories.
*   `duplicate`: Clone a model, dataset, or Space to a new ID.
*   `move`: Transfer a repository between namespaces.
*   `branch` / `tag`: Manage Git-like references.
*   `delete-files`: Remove specific files using patterns.

---

## Specialized Hub Interactions

### Datasets & Models
*   **Datasets:** `hf datasets list`, `info`, and `parquet` (list parquet URLs).
*   **SQL Queries:** `hf datasets sql SQL` — Execute raw SQL via DuckDB against dataset parquet URLs.
*   **Models:** `hf models list` and `info`.
*   **Papers:** `hf papers list` — View daily papers.

### Discussions & Pull Requests (`hf discussions`)
*   Manage the lifecycle of Hub contributions: `list`, `create`, `info`, `comment`, `close`, `reopen`, and `rename`.
*   `diff`: View changes in a PR.
*   `merge`: Finalize pull requests.

### Infrastructure & Compute
*   **Endpoints:** Deploy and manage Inference Endpoints (`deploy`, `pause`, `resume`, `scale-to-zero`, `catalog`).
*   **Jobs:** Run compute tasks on HF infrastructure. Includes `hf jobs uv` for running Python scripts with inline dependencies and `stats` for resource monitoring.
*   **Spaces:** Manage interactive apps. Includes `dev-mode` and `hot-reload` for Python files without full restarts.

### Storage & Automation
*   **Buckets:** Full S3-like bucket management (`create`, `cp`, `mv`, `rm`, `sync`).
*   **Cache:** Manage local storage with `list`, `prune` (remove detached revisions), and `verify` (checksum checks).
*   **Webhooks:** Automate workflows by managing Hub webhooks (`create`, `watch`, `enable`/`disable`).
*   **Collections:** Organize Hub items into collections (`add-item`, `update`, `list`).

---

## GGUF Model Downloads

Downloading GGUF model files for local inference requires specific flags:

```bash
# Download a single GGUF file by glob pattern (preferred)
hf download unsloth/Qwen3-14B-GGUF \
  --include "*Q4_K_M.gguf" \
  --local-dir /home/synth/llm/models

# Download only the vision projector for multimodal models
hf download unsloth/Qwen3.6-35B-A3B-GGUF \
  --include "*mmproj*" \
  --local-dir /home/synth/llm/models

# Download with background + notification (when using Hermes)
terminal(background=true,
  command="hf download ORG/MODEL-GGUF --include \"*Q4_K_M.gguf\" --local-dir /home/synth/llm/models",
  notify_on_complete=true,
  timeout=600)
```

**PITFALL:** `huggingface-cli` is **deprecated**. It prints a warning and exits. Only use `hf download`.

**PITFALL:** `--include` uses a **glob pattern**, not an exact filename. Use `*Q4_K_M.gguf` instead of the exact `Qwen3-14B-Q4_K_M.gguf`.

**PITFALL:** `--local-dir` is the output directory. Files are placed directly there (not in a subdirectory). For GGUF files >5GB, this can take 1-5 minutes on typical connections.

**PITFALL:** No HF_TOKEN is set on this system. Downloads work but are slower (unauthenticated rate limiting applies). Set `HF_TOKEN` in `~/.hermes/.env` for faster downloads if needed.

### Finding GGUF files on HuggingFace

The most reliable GGUF publishers (sorted by downloads):
- `unsloth/<ModelName>-GGUF` — Largest collection, best quality control
- `bartowski/<ModelName>-GGUF` — Comprehensive, many quant options
- `lmstudio-community/<ModelName>-GGUF` — Good quality, LM Studio curated
- `Qwen/<ModelName>-GGUF` — Official, limited quant selection

```bash
# Search with HuggingFace API
curl -s "https://huggingface.co/api/models?search=Qwen3+GGUF&sort=downloads&limit=5" \
  | python3 -c "import sys, json; [print(m['modelId']) for m in json.load(sys.stdin)]"

# List available GGUF files in a repo
curl -s "https://huggingface.co/api/models/unsloth/Qwen3-14B-GGUF" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data.get('siblings', []):
    rfn = f.get('rfilename', '')
    if '.gguf' not in rfn: continue
    print(f'  {rfn}')
"

# Check actual file size via HEAD request
curl -sI "https://huggingface.co/unsloth/Qwen3-14B-GGUF/resolve/main/Qwen3-14B-Q4_K_M.gguf" \
  2>/dev/null | grep -i "^content-length" | awk '{printf "%.2f GB\n", $2/1073741824}'
```

### Global Flags
*   `--format json`: Produces machine-readable output for automation.
*   `-q` / `--quiet`: Limits output to IDs only.

### Extensions & Skills
*   **Extensions:** Extend CLI functionality via GitHub repositories using `hf extensions install REPO_ID`.
*   **Skills:** Manage AI assistant skills with `hf skills add`.
