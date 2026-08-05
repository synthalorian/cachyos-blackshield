# Using Local Models via llama-swap

**PITFALL: `hermes 35b` DOES NOT WORK.** Hermes interprets the second positional argument as a subcommand, not a model name. You must use explicit flags:

```bash
# CORRECT:
hermes -m synthclaw-35b-128k --provider llama-swap -q "your prompt"

# WRONG (fails with "invalid choice: '35b'"):
hermes 35b "your prompt"
```

Hermes can use locally-running models through any OpenAI-compatible endpoint, including llama-swap. However, Hermes does **not** auto-detect `OPENAI_BASE_URL` and `OPENAI_MODEL` environment variables; you must explicitly select the `llama-swap` provider via `--provider` or config.

## Quick start

1. **Ensure llama-swap is running** on `http://127.0.0.1:8080/v1` with your models configured.

2. **Test the endpoint directly** (bypass Hermes):
   ```bash
   curl -s http://127.0.0.1:8080/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"model":"synthclaw-27b-128k","messages":[{"role":"user","content":"hi"}],"max_tokens":20}' \
     | jq
   ```
   Should return quickly after cold-start (27B ~30s first load).

3. **Invoke Hermes with explicit provider flag:**
   ```bash
   # Single prompt with 27b
   hermes chat -m synthclaw-27b-128k --provider llama-swap -q "your prompt"

   # Interactive session with 35b
   hermes chat -m synthclaw-35b-128k --provider llama-swap
   ```

4. **Use shorthand aliases** through llama-swap config to avoid typing full model IDs:
   In `~/.llama.cpp/llama-swap/config.yaml`:
   ```yaml
   models:
     synthclaw-27b-128k:
       cmd: ... --port 8084 ...
       proxy: http://127.0.0.1:8084
       aliases: ["27b", "27b-128k"]
   ```
   Then request with `--model 27b`.

## The `--provider` flag is mandatory for local models

Hermes model selection logic:
1. Reads `model.default` from `~/.hermes/config.yaml` (usually a cloud model like `stepfun/step-3.5-flash` with provider `nous`).
2. If you pass `-m MODEL` without `--provider`, Hermes still uses the configured *default provider* (nous) and tries to fetch that cloud model — resulting in a 404 for local-only model names.

**Therefore, always pair `-m <local-model>` with `--provider llama-swap`** when using local models through llama-swap.

## Persistent configuration (optional)

To make `llama-swap` your default provider for a profile, edit `~/.hermes/config.yaml`:

```yaml
model:
  default: synthclaw-27b-128k
  provider: llama-swap
  base_url: http://127.0.0.1:8080/v1
```

After that, `hermes chat -q "prompt"` uses local models without extra flags.

**Note:** The `llama-swap` provider must be listed under `providers:` in the same config file:
```yaml
providers:
  llama-swap:
    base_url: http://127.0.0.1:8080/v1
    api_key: llama-swap-local   # sentinel; any non-empty value works
```

## Wrapper scripts (recommended)

For ergonomic shorthand usage, install wrapper scripts that embed the provider flag and model resolution.

**Install location:** `~/.local/bin/hermes` (symlink or wrapper script)

**Wrapper implementation:** see `llama-swap-debugging` skill, `references/wrapper-symlink-resolution.md` for the full, production-ready script that:
- Resolves symlinks correctly to source `synthclaw-resolve.sh`
- Maps shorthands (`35b`, `27bmax`, `35bultra`) → full model IDs
- Sets `OPENAI_API_KEY=llama-swap-local` and `OPENAI_BASE_URL=http://127.0.0.1:8080/v1`
- Calls `hermes chat -m <resolved> --provider llama-swap [-q prompt]`

**Usage after install:**
```bash
hermes 35b "write a function"    # single prompt → resolves to synthclaw-35b-128k
hermes 27b                       # interactive chat with 27b
hermes "cloud prompt"            # no shorthand → uses default cloud model
```

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `hermes: error: argument command: invalid choice: '35b'` | Passed model name as positional argument instead of `-m` flag | `hermes -m <model>` or `hermes chat --model <model>` |
| `Provider: nous` in output | `--provider llama-swap` missing | Add the flag or use wrapper |
| 404 `Model 'synthclaw-27b-128k' not found` | Model not defined in llama-swap config or llama-swap not restarted | Add model + `proxy`, restart llama-swap |
| Request hangs 60–120s | Cold-start loading large model (35B) into GPU | Wait; normal on first use. Pre-warm if needed. |
| Wrapper prints `OPENAI_API_KEY=***` | API key placeholder corrupted in wrapper file | Set to `"llama-swap-local"` |
| `hermes: error: unrecognized arguments: -z` | Wrapper using wrong hermes flag | Use `-q` for query; wrapper must call `hermes chat -q` |

## Debug checklist

```bash
# 1. Verify llama-swap health
curl -s http://127.0.0.1:8080/v1/models | jq

# 2. Check hermes provider config
cat ~/.hermes/config.yaml | grep -A3 'providers:'

# 3. Run hermes verbosely
hermes chat -m synthclaw-27b-128k --provider llama-swap -q "hi" -v

# 4. Check llama-swap logs
journalctl --user -u llama-swap -n 50

# 5. Verify wrapper resolution (if using wrapper)
bash -x ~/.local/bin/hermes 35b test 2>&1 | grep -E 'RESOLVED|exec'
```

## References

- Hermes model configuration: https://hermes-agent.nousresearch.com/docs/user-guide/configuration#model
- llama-swap debugging: `llama-swap-debugging` skill (proxy fields, aliases, TTL, cold-start)
- Wrapper symlink resolution: `llama-swap-debugging` → `references/wrapper-symlink-resolution.md`
