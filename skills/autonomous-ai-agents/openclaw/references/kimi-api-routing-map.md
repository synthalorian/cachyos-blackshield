# Kimi API Routing Map — All Tools

Reference for which tools hit Kimi direct vs through proxy.

## Routing Table

| Tool | Route | Base URL | Model Slug | Notes |
|------|-------|----------|------------|-------|
| **Hermes** | Direct | `https://api.kimi.com/coding` | `kimi-k2.6` | Uses Hermes native provider config |
| **claw-code** | Proxy | `http://127.0.0.1:8699/v1` → `api.kimi.com/v1` | `kimi-k2.6` | Wrapper script sets `KIMI_BASE_URL` |
| **openclaw** | Direct | `https://api.kimi.com/coding/` | `kimi-k2.6` | Config in `models.providers.kimi` |
| **opencode** | Direct | `https://api.kimi.com/coding/v1` | `kimi-k2.6` | Config in `~/.config/opencode/opencode.json` |

Only **claw-code** uses the local proxy at `127.0.0.1:8699`. All other tools hit Kimi directly.

**Important Endpoint Differences:**

The Kimi API has multiple endpoints that behave differently:

| Endpoint | Used By | Behavior |
|----------|---------|----------|
| `api.kimi.com/coding` | Hermes, openclaw | Anthropic-messages API (openclaw), native provider (Hermes) |
| `api.kimi.com/coding/v1` | opencode | OpenAI-compatible chat completions |
| `api.kimi.com/v1` | claw-code (via proxy) | OpenAI-compatible, proxied through local service |

A key working on one endpoint may fail on another. Auth errors on `coding/` vs `coding/v1` vs `v1` are independent. Always test the exact endpoint your tool uses.

## Proxy Details

The proxy (`kimi-proxy.service`) runs on `127.0.0.1:8699` and:
- Spoofs `claude-code/1.0` User-Agent
- Forwards Authorization header as-is
- Translates between OpenAI-compatible and Kimi API formats
- Is ONLY used by claw-code's wrapper script

## Config Locations

| Tool | Config File | Key Field |
|------|-------------|-----------|
| Hermes | `~/.hermes/config.yaml` | `providers.kimi.base_url` |
| claw-code | `~/.config/claw/kimi.env` | `KIMI_API_KEY` |
| openclaw | `~/.openclaw/openclaw.json` | `models.providers.kimi.apiKey` |
| opencode | `~/.config/opencode/opencode.json` | `provider.kimi.options.apiKey` |

## Upgrading Rate Limits (Vivace)

Upgrading from Allegretto → Vivace on the Kimi platform bumps rate limits for the API key. This affects:
- **Hermes** (direct) — immediate benefit
- **openclaw** (direct) — immediate benefit
- **opencode** (direct) — immediate benefit
- **claw-code** (via proxy) — proxy key may need separate upgrade if using different key

## Troubleshooting 401 / Invalid Key

1. **Verify key is valid on the RIGHT endpoint:**
   ```bash
   # Test the exact endpoint your tool uses:
   curl -H "Authorization: Bearer *** \
        https://api.kimi.com/coding/v1/chat/completions \
        -d '{"model":"kimi-k2.6","messages":[{"role":"user","content":"hi"}]}'
   ```
2. **Check which tool is failing:** Each tool has its own config — a working key in Hermes doesn't mean it's configured in openclaw
3. **Check for literal `***` in configs:** Tool output masking can corrupt files if copy-pasted from masked output. The claw-code wrapper had this bug at line 140 — it passed literal `***` instead of the actual key variable.
4. **Verify proxy is running:** `systemctl --user status kimi-proxy.service`
5. **Test proxy directly:** `curl http://127.0.0.1:8699/v1/models -H "Authorization: Bearer $KIMI_API_KEY"`
6. **Check openclaw TUI status line:** The detailed line below the status bar shows the actual model. "local ready" does NOT mean local model — see `references/tui-status-indicators.md`
