# llama-swap Config Auto-Population Pattern

## Problem

OpenShark's local provider config needs to match the models running under llama-swap. Manually keeping the two configs in sync is error-prone — new models get added to llama-swap but forgotten in OpenShark.

## Solution

Parse llama-swap's YAML config and auto-generate OpenShark's TOML model entries.

## llama-swap Config Structure

```yaml
# ~/.config/llama-swap/config.yaml
models:
  - id: synthclaw-35b-128k
    path: /home/synth/models/synthclaw-35b-128k.gguf
    port: 8081
    ...
  - id: synthclaw-35b-256k
    path: /home/synth/models/synthclaw-35b-256k.gguf
    port: 8082
    ...
```

## Auto-Population Script

```bash
#!/bin/bash
# Parse llama-swap config and append models to OpenShark config

LLAMA_CONFIG="$HOME/.config/llama-swap/config.yaml"
OPENSHARK_CONFIG="$HOME/.config/openshark/config.toml"

# Extract model IDs and ports, generate TOML entries
python3 -c "
import yaml, sys
with open('$LLAMA_CONFIG') as f:
    config = yaml.safe_load(f)

models = config.get('models', [])
for m in models:
    name = m['id']
    # Derive context length from model name (e.g., 128k → 131072)
    ctx = 32768  # default
    if '128k' in name: ctx = 131072
    elif '256k' in name: ctx = 262144
    elif '512k' in name: ctx = 524288
    print(f'''[[providers.local.models]]
name = \"{name}\"
context_length = {ctx}
''')
" >> "$OPENSHARK_CONFIG"
```

## Key Insight: Single Provider, Multiple Models

All llama-swap models run behind a single proxy (port 8080). They share the same `[providers.local]` section in OpenShark:

```toml
[providers.local]
base_url = "http://127.0.0.1:8080/v1"
api_key = "llama-swap-local"
kind = "open_ai_compatible"

[[providers.local.models]]
name = "synthclaw-35b-128k"
context_length = 131072

[[providers.local.models]]
name = "synthclaw-35b-256k"
context_length = 262144
# ... etc
```

The model name is what gets sent in the API request. llama-swap routes to the correct backend based on the model ID.

## Context Length Derivation

Model names often encode context length. Parse from the name:

| Suffix | Tokens |
|--------|--------|
| `128k` | 131072 |
| `256k` | 262144 |
| `512k` | 524288 |
| `1m` | 1048576 |
| `32k` | 32768 |
| `64k` | 65536 |

## Verification

After auto-populating, verify the config loads correctly:
```bash
openshark --version  # Should not panic on config load
openshark models     # Should list all local models
```

## Related

- `references/provider-config.md` — Full provider configuration format
