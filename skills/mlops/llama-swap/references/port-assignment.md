# Port assignment strategy for llama-swap

## Guiding principles

- **llama-swap itself** listens on `localhost:8080` (configurable via `--listen`)
- **Each model instance** needs a **unique, fixed port** on `127.0.0.1`
- Ports must not overlap with other services (Docker, desktop apps, etc.)

## Recommended range

```
8081 – 8099   (up to 99 concurrent models)
```

This keeps everything in the same /24 subnet as the router and avoids well-known ports.

## Example assignments (session-derived)

For a 6-model Qwen3.6 deployment:

| Model profile            | Port  | Proxy URL                     |
|--------------------------|-------|-------------------------------|
| `synthclaw-35b-128k`     | 8081  | http://127.0.0.1:8081        |
| `synthclaw-35b-256k`     | 8082  | http://127.0.0.1:8082        |
| `synthclaw-35b-512k`     | 8083  | http://127.0.0.1:8083        |
| `synthclaw-27b-128k`     | 8084  | http://127.0.0.1:8084        |
| `synthclaw-27b-256k`     | 8085  | http://127.0.0.1:8085        |
| `synthclaw-27b-512k`     | 8086  | http://127.0.0.1:8086        |

These are sequential starting from 8081 to leave 8080 clear for the router.

## Conflict detection

Before assigning, scan for existing listeners:

```bash
ss -tulpn | grep -E ':(808[1-9]|80[9][0-9])'
```

Or check within the 8000–8099 band:

```bash
for p in $(seq 8081 8099); do
  if ss -tulpn | grep -q ":$p "; then
    echo "Port $p in use"
  fi
done
```

## Config YAML pattern

```yaml
models:
  "model-name":
    cmd: |
      /path/to/llama-server
      --model /path/to/model.gguf
      --ctx-size 131072
      --port 8081             # ← explicit, matches proxy below
      --host 127.0.0.1
      --alias model-name
      --flash-attn on
      --n-gpu-layers 99
    proxy: http://127.0.0.1:8081   # ← must match cmd --port
    ttl: 900
    aliases:
      - model-name
```

**Never** use `${PORT}` without a separate expansion step; llama-swap does not substitute it.

## Port exhaustion

If you need >99 models:
- Use multiple llama-swap routers on different listen ports (8080, 80800, etc.)
- Or consolidate via llama.cpp's built-in multi-model mode (if using recent llama.cpp with `--model` routing)
