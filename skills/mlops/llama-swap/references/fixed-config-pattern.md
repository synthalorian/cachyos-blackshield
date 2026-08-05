# Fixed llama-swap config pattern

All models require BOTH `cmd` (with explicit `--port N`) AND `proxy` (matching URL).

## Working config structure

```yaml
healthCheckTimeout: 240
logLevel: info

models:
  synthclaw-35b-128k:
    cmd: |
      /home/synth/llama.cpp/build/bin/llama-server
      --model /home/synth/models/qwen3.6-35b/Qwen3.6-35B-A3B-UD-IQ3_S.gguf
      --ctx-size 131072
      --n-gpu-layers 99
      --port 8081
      --host 127.0.0.1
      --alias synthclaw-35b-128k
      --jinja
      --reasoning-budget 0
      --flash-attn on
      --cache-type-k q8_0
      --cache-type-v q8_0
      --threads 8
      --threads-batch 16
      --mlock
      --metrics
      --parallel 2
      --cont-batching
    proxy: http://127.0.0.1:8081

  # ...repeat for each model with unique ports 8082–8086
```

## Port assignments used

| Model | Port |
|-------|------|
| synthclaw-35b-128k | 8081 |
| synthclaw-35b-256k | 8082 |
| synthclaw-35b-512k | 8083 |
| synthclaw-27b-128k | 8084 |
| synthclaw-27b-256k | 8085 |
| synthclaw-27b-512k | 8086 |

## Important notes

- **NO** `${PORT}` placeholders — they are NOT expanded by llama-swap
- **NO** missing `proxy` fields — spawn will silently fail
- Model IDs in client requests must match exactly these names
- Ports must not conflict with other services
- `--alias` should match the model key name for clarity
