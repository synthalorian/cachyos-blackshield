# llama-swap config fix — missing `proxy` field

## Root cause

**Symptom:** `llama-swap` starts and returns a model list from `/v1/models`, but when a request is made to `/v1/chat/completions` it responds:

```
unable to start process: no upstream available to check /health
```

No `llama-server` child processes appear in `ps aux`.

**Cause:** Each model definition in `config.yaml` is missing the required `proxy` field. llama-swap uses `proxy` to know:
- Where to health-check (`<proxy>/health`)
- Where to forward requests once the child is ready

Without `proxy`, llama-swap cannot complete the health check phase, so it aborts the spawn.

## The fix

Add `proxy: http://127.0.0.1:<port>` to every model entry, where `<port>` matches the `--port` argument in that model's `cmd`.

### Before (broken)

```yaml
models:
  "my-model":
    cmd: |
      /path/to/llama-server
      --model /path/to/model.gguf
      --port ${PORT}    # ← placeholder NOT expanded
      --host 127.0.0.1
    ttl: 900
    # proxy field MISSING → spawn fails
```

### After (working)

```yaml
models:
  "my-model":
    cmd: |
      /path/to/llama-server
      --model /path/to/model.gguf
      --port 8081        # ← explicit port
      --host 127.0.0.1
    proxy: http://127.0.0.1:8081   # ← added
    ttl: 900
```

If you prefer the folded style (recommended for readability):

```yaml
    cmd: >
      /path/to/llama-server
      --model /path/to/model.gguf
      --port 8081 --host 127.0.0.1
```

## Additional fixes encountered

1. **`${PORT}` placeholder not expanded**  
   llama-swap does not substitute `${PORT}` automatically. Replace with an explicit number.

2. **`cmd` newline handling (`|` vs `>`)**  
   Using `|` (literal block) preserves newlines correctly; YAML parses them as actual newlines, not `\n` strings. The original config was valid YAML; the real blocker was the missing `proxy`.  
   However, if your editor accidentally double-escapes (producing literal `\n` in the parsed string), switch to `>` (folded) or ensure the YAML is saved with real newlines.

3. **Verification**  
   After fixing `proxy` and setting explicit ports:
   ```bash
   # Restart llama-swap
   pkill -f llama-swap
   llama-swap --config /path/to/config.yaml --listen localhost:8080 &

   # Trigger a spawn
   curl -X POST http://127.0.0.1:8080/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"model":"my-model","messages":[{"role":"user","content":"hi"}],"max_tokens":5}'

   # Confirm child
   ps aux | grep llama-server
   ```

## Related errors

- `unable to start process: no upstream available to check /health` → missing or unreachable `proxy`
- `timeout waiting for health check` → port mismatch, firewall blocking, or llama-server crashed on launch
- `command not found` (silent) → bad `cmd` string or missing execute permission on binary
