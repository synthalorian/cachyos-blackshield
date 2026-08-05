# Kimi Coding Plan — Provider Reference

Kimi K2.6 via Moonshot AI's coding plan ($199/mo). This is synth's PRIMARY model across all harnesses as of May 2026.

## Endpoint

```
Base URL:  https://api.kimi.com/coding/v1   (OpenAI-compatible)
Model ID:  kimi-k2.6
Auth:      Bearer token (API key)
```

**Direct vs Proxy:** claw-code, opencode, and openclaw route directly to `https://api.kimi.com/coding/v1`. Hermes uses the local proxy on `http://127.0.0.1:8699/v1` (see Proxy section below).

## API Key

Stored in `~/.config/claw/kimi.env`:
```
KIMI_API_KEY="sk-kimi-..."
```
chmod 600. Sourced at runtime by wrappers — never hardcoded in version-controlled scripts.

**IMPORTANT:** Hermes tools (`read_file`, `terminal`, `write_file`, `execute_code`) actively mask API keys in output. When writing keys to files, the tools may truncate or replace them with `***`. If a key file ends up with `sk-k...` or `***`, it was masked by the tool — the user must manually edit the file. Always verify key files with `wc -c` (real key is ~95 chars) or `python3 -c "print(open(path).read())"`.

## Reasoning Format

Kimi outputs chain-of-thought in a format compatible with DeepSeek's thinking block style. When configuring for tools that need a `thinkingFormat` parameter, use `"deepseek"`.

Allowed values (gateway-validated): `openai`, `openrouter`, `deepseek`, `together`, `qwen`, `qwen-chat-template`, `zai`. Using anything else causes gateway crash loops with `start-limit-hit`.

## Harness Configurations

### claw-code
```bash
KIMI_BASE_URL="https://api.kimi.com/coding/v1"
KIMI_MODEL="kimi-k2.6"
# Key sourced from ~/.config/claw/kimi.env
# Default shortcut: claw (no args) or claw kimi
```

### opencode / OmO
Provider in `~/.config/opencode/opencode.json`:
```json
"kimi": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "Kimi K2.6 Kimi for Coding",
  "options": {
    "baseURL": "https://api.kimi.com/coding/v1",
    "apiKey": "${KIMI_API_KEY}"
  },
  "models": {
    "kimi-k2.6": {
      "name": "Kimi K2.6 Kimi for Coding",
      "limit": { "context": 128000, "output": 65536 }
    }
  }
}
```
Model reference in OmO: `kimi/kimi-k2.6`

### openclaw
Provider in `~/.openclaw/openclaw.json` under `models.providers`:
```json
"kimi": {
  "baseUrl": "https://api.kimi.com/coding/v1",
  "api": "openai-completions",
  "apiKey": "sk-kimi-...",
  "models": [{
    "id": "kimi-k2.6",
    "name": "Kimi K2.6 Kimi for Coding (direct)",
    "reasoning": true,
    "compat": { "thinkingFormat": "deepseek" }
  }]
}
```
Model reference: `kimi/kimi-k2.6`

### Hermes
```yaml
model:
  default: kimi-k2.6
  provider: kimi-coding
  base_url: http://127.0.0.1:8699/v1   # local proxy, NOT direct Kimi API
```
Key from `KIMI_API_KEY` in `~/.hermes/.env`.

**Why the proxy?** The proxy on `127.0.0.1:8699` spoofs `claude-code/1.0` User-Agent. Kimi for Coding requires an approved client identity; without the proxy, Hermes gets 401/403 even with a valid key. The proxy is a transparent forwarder — it does NOT inject the key. Hermes must still send `Authorization: Bearer *** in every request.

**Common failure:** If Hermes `base_url` is set to `https://api.kimi.com/coding` (direct), the proxy is bypassed entirely and Kimi rejects the request. If `base_url` is correct but the key is missing from `~/.hermes/.env`, the proxy returns 401 from Kimi. Verify with: `curl -H "Authorization: Bearer *** http://127.0.0.1:8699/v1/models`.

**Hermes config drift check:** After any Hermes config edit or update, verify `base_url` is still pointing at the proxy:
```bash
grep "base_url" ~/.hermes/config.yaml | head -1
```
Expected: `base_url: http://127.0.0.1:8699/v1`. If it shows `https://api.kimi.com/coding`, the proxy is bypassed. This happens when config is regenerated or restored from backup.

## Proxy Details

The proxy is a Python script at `~/.local/bin/kimi-proxy` (runs as user service). It:
- Listens on `127.0.0.1:8699`
- Forwards all requests to `https://api.kimi.com/coding`
- Replaces `User-Agent` with `claude-code/1.0`
- Streams responses (chunked)
- Does NOT modify or inject the `Authorization` header

To check proxy health: `curl -s http://127.0.0.1:8699/v1/models -H "Authorization: Bearer $KIMI_API_KEY"`

## Fallback Strategy

Only use fallbacks when Kimi is rate-limited:
1. Hermes free tier / OpenCode free tier (deepseek-v4-flash-free, minimax-m2.5-free, etc.)
2. FreeBuff free sessions
3. Local Kimi K2.6 35B distilled (llama-swap, `-m` flag only — NOT in auto-fallback chain)
4. Z.AI GLM-5.1 (coding plan, last resort)
