# Kimi K2.6 Vivace Setup for claw-code

## Quick Setup

1. Create the env file:
```bash
echo 'KIMI_API_KEY="sk-k...d"' > ~/....env
chmod 600 ~/....env
```

2. Verify the wrapper can read it:
```bash
claw
# Should print: 🎹🦞 Cloud: kimi-k2.6 via Kimi direct
```

3. Test a simple prompt:
```bash
claw prompt "hello"
```

## How It Works

The `claw` wrapper at `~/synthclaw-ai-setup/configs/wrappers/claw`:

1. Sets `KIMI_API_KEY_SOURCE="$HOM..."`
2. Sources that file to get `KIMI_API_KEY`
3. Exports it as `OPENAI_API_KEY` (claw-code reads this)
4. Sets `OPENAI_BASE_URL="https://api.kimi.com/coding/v1"`
5. Sets `OPENAI_API_HEADERS="x-kimi-agent-name:Kimi-CLI,x-kimi-agent-version:1.0.0"`
6. Launches `claw --model kimi-k2.6`

## Common Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `🎹🦞 Cloud: kimi-k2.6 via Nous proxy` | `~/....env` missing, wrapper fell back | Create `~/....env` with real key |
| `404 Not Found: model requires available credits` | Nous proxy doesn't route Kimi | Fix the env file so wrapper uses Kimi direct |
| `401 Unauthorized` | Key is wrong or expired | Regenerate key at Kimi portal |
| `***` in env file | Placeholder not replaced | Replace with real `sk-kimi-...` key |

## Model String Variants

- `kimi-k2.6` — Full model (default)
- `kimi-k2.6-allegro` — Faster variant
- `kimi-k2.6-vivace` — Explicit variant name

All use the same endpoint and auth. The wrapper default is `kimi-k2.6`.

## Upstream Model Syntax Changes

claw-code upstream (`ultraworkers/claw-code` main) now requires `provider/model` syntax (e.g., `kimi/kimi-k2.6`, `openai/gpt-4o`). Bare model names like `kimi-k2.6` fail with:
```
error: invalid model syntax: 'kimi-k2.6'. Expected provider/model (e.g., anthropic/claude-opus-4-7)
```

**Fix the wrapper:** Update `KIMI_MODEL` in `~/synthclaw-ai-setup/configs/wrappers/claw`:
```bash
# Before:
KIMI_MODEL="kimi-k2.6"

# After:
KIMI_MODEL="kimi/kimi-k2.6"
```

The `kimi/` prefix routes to the OpenAI-compatible provider, which then uses `OPENAI_BASE_URL` (your local proxy or direct API) to reach the actual backend.

## Local Kimi Coding Plan Proxy

If the direct API fails or you need the Coding Plan (requires `claude-code/1.0` User-Agent), use the local proxy:

- **Service:** `~/.config/systemd/user/kimi-proxy.service` (auto-starts at login)
- **Binary:** `~/.local/bin/kimi-proxy` (Python3, spoofs UA as `claude-code/1.0`)
- **Listen:** `127.0.0.1:8699`
- **Upstream:** `https://api.kimi.com/coding`

**Enable in wrapper:**
```bash
KIMI_BASE_URL="http://127.0.0.1:8699/v1"
```

**Check proxy status:**
```bash
systemctl --user status kimi-proxy
ss -tlnp | grep 8699
```

**Proxy error:** If the proxy returns 400 with `reasoning_content is missing`, see `references/kimi-reasoning-content-error.md` for the claw-code patch.
