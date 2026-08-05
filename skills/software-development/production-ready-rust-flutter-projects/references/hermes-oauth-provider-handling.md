# Hermes OAuth Provider Handling

## Problem

Hermes OAuth providers (Nous Free Tier, xAI) use short-lived tokens that the `hermes` CLI manages transparently via refresh flows. The tokens live in `~/.hermes/auth.json` with ~15-minute expiry. A Rust backend that makes **direct HTTP calls** with a static API key (or an env var) will get `401 Unauthorized` from these providers because:

1. The OAuth token is stored in `auth.json`, not in `config.yaml`
2. The token expires every ~15 minutes and needs CLI-mediated refresh
3. The provider's OAuth inference endpoint is different from the standard API endpoint (`inference-api.nousresearch.com/v1` vs `api.nousresearch.com/v1`)

## Detection: Reading auth.json

```rust
fn oauth_providers() -> HashSet<String> {
    let auth_path = hermes_home_dir().join("auth.json");
    match read_file(&auth_path) {
        Ok(content) => {
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
                let mut providers = HashSet::new();
                if let Some(provs) = json["providers"].as_object() {
                    for (name, _cfg) in provs {
                        providers.insert(name.clone());
                    }
                }
                providers
            } else {
                HashSet::new()
            }
        }
        Err(_) => HashSet::new(),
    }
}
```

The function returns a set of provider names (e.g., `{"nous", "xai-oauth"}`). Any provider in this set MUST NOT be called via direct HTTP from the backend — only through the Hermes CLI.

## auth.json Structure

```json
{
  "version": 1,
  "providers": {
    "nous": {
      "access_token": "eyJ...",
      "refresh_token": "rt_...",
      "agent_key": "eyJ...",
      "inference_base_url": "https://inference-api.nousresearch.com/v1",
      "portal_base_url": "https://portal.nousresearch.com",
      "expires_at": "2026-05-19T06:31:22+00:00",
      "agent_key_expires_at": "2026-05-19T06:31:22+00:00",
      "token_type": "Bearer",
      "scope": "inference:mint_agent_key"
    },
    "xai-oauth": {
      "tokens": {
        "access_token": "eyJ...",
        "refresh_token": "8n...",
        "id_token": "eyJ...",
        "expires_in": 21600,
        "token_type": "Bearer"
      },
      "auth_mode": "oauth_pkce",
      "discovery": {
        "authorization_endpoint": "https://auth.x.ai/oauth2/authorize",
        "token_endpoint": "https://auth.x.ai/oauth2/token"
      }
    }
  }
}
```

Key fields for each provider:
- `nous`: has `agent_key` (used as Bearer token for API calls), `inference_base_url` (the API endpoint), and `refresh_token`
- `xai-oauth`: has OAuth PKCE tokens with `access_token`, `refresh_token`, and OAuth discovery endpoints
- Any provider present in `providers` dict is OAuth-based and should be CLI-routed

## Routing Decision

In ALL handlers that proxy LLM API calls, add this check BEFORE deciding to make a direct HTTP call:

```rust
// Existing: check if provider has config
let base_url = config["providers"][provider_name]["base_url"]
    .as_str().unwrap_or("").to_string();

// NEW: also check if provider is OAuth-based
if base_url.is_empty() || oauth_providers().contains(provider_name) {
    // Route through Hermes CLI instead of direct HTTP
    let args = vec!["-z", &message];
    match std::process::Command::new("hermes").args(&args).output() {
        Ok(output) if output.status.success() => {
            // Forward output to client
        }
        _ => {
            // Handle CLI failure
        }
    }
    return;
}
```

This applies to:
- **Streaming chat handler** (SSE endpoint) — check before `reqwest::Client` call
- **Non-streaming chat handler** — check before `curl` subprocess
- **Model probe handler** (`probe_via_provider`) — check before probe curl call
- **Setup wizard probe handler** (`probe_provider_handler`) — check before probe curl call

## Auto-Configure: Skip OAuth Providers

When the setup wizard or auto-configure endpoint scans environment variables for API keys (e.g., `DEEPSEEK_API_KEY` for the `nous` provider), it must skip providers that already have OAuth in `auth.json`. Otherwise it creates a duplicate provider config entry with the wrong base URL and stale auth:

```rust
let oauth = oauth_providers();

for (env_var, provider_name, base_url) in &env_key_map {
    if let Ok(key) = std::env::var(env_var) {
        // CRITICAL: skip OAuth providers — their auth lives in auth.json, not env vars
        if !key.is_empty() && !providers.contains_key(*provider_name) && !oauth.contains(*provider_name) {
            providers.insert(...);
        }
    }
}
```

## CLI Fallback for Probes

When probing an OAuth provider that has no config entry (only auth.json), use the CLI with a known model:

```rust
if base_url.is_empty() {
    if oauth_providers().contains(provider_name) {
        // Probe via CLI — don't fail with "no base_url for provider"
        let full_name = format!("deepseek/{}", test_model);
        match run_hermes(&["--model", &full_name, "--oneshot", "hi"]) {
            Ok((stdout, _, code)) if code == 0 && !stdout.trim().is_empty() => {
                return Json(json!({"success": true, ...}));
            }
            Ok((_, stderr, _)) => {
                return Json(json!({"success": false, "error": stderr.trim(), ...}));
            }
            Err(e) => {
                return Json(json!({"success": false, "error": e, ...}));
            }
        }
    }
    return Json(json!({"success": false, "error": "no base_url for provider"}));
}
```

## Why Not Just Fix the API Key?

The env var `DEEPSEEK_API_KEY` may be set to the old-style API key (pre-OAuth). The real auth is in `auth.json` and is time-limited. Even if you read `auth.json`'s `agent_key` and use it directly, you'd need to implement:

- Token expiry tracking (15 minutes for Nous, 6 hours for xAI)
- Refresh token rotation
- Agent key minting via the portal API

All of this is already handled by the `hermes` CLI. **Delegating to the CLI is simpler and more robust** — one line of code instead of a full OAuth client implementation.

## Token Expiry Window & Mid-Prompt 401s

OAuth tokens expire every ~15 minutes. The Hermes CLI refreshes them between calls, but **during a long-running streaming response** the token can expire mid-stream. This causes 401 mid-prompt for:

- **Discord conversations** — the agent keeps one connection open for the whole exchange
- **Long CLI prompts** — `hermes --oneshot "big prompt with many output tokens"` that exceeds the window
- **Gateway sessions** — persistent channels that stay connected >15 min

### Wingman fix (per-message refresh)

Each Wingman chat message spawns a **fresh `hermes -z` CLI process**. This means each message gets a freshly-refreshed token. The 401 cannot happen mid-prompt because the token is only used for the duration of one request (seconds, not minutes).

### OAuth Token Keepalive Cron

For the Hermes-agent (Discord, gateway, long-running CLI sessions), the token must be kept alive proactively. Set up a cron job that refreshes the token every 10 minutes:

```bash
#!/bin/bash
# ~/.hermes/scripts/oauth-keepalive.sh
AUTH_FILE="$HOME/.hermes/auth.json"

if [ ! -f "$AUTH_FILE" ]; then exit 0; fi

TOKEN_EXPIRY=$(python3 -c "
import json, datetime
with open('$AUTH_FILE') as f:
    auth = json.load(f)
nous = auth.get('providers', {}).get('nous', {})
exp = nous.get('agent_key_expires_at') or nous.get('expires_at', '')
if exp:
    dt = datetime.datetime.fromisoformat(exp.replace('Z','+00:00'))
    now = datetime.datetime.now(datetime.timezone.utc)
    print(int((dt - now).total_seconds()))
" 2>/dev/null)

# Only refresh if less than 6 minutes remaining
if [ "$TOKEN_EXPIRY" -lt 360 ] 2>/dev/null; then
    hermes auth status nous > /dev/null 2>&1
    echo "[$(date)] OAuth refreshed — ${TOKEN_EXPIRY}s left"
fi
```

Register via Hermes scheduler:
```python
cronjob(action='create', name='hermes-oauth-keepalive',
        schedule='every 10 min', script='oauth-keepalive.sh',
        no_agent=True)
```

This runs `hermes auth status nous` every 10 minutes, which triggers an OAuth token refresh if it's close to expiry. The refresh keeps the tokens alive indefinitely without user intervention.

## Re-authentication

When the CLI fallback also returns 401 (because the refresh token itself expired), the user needs to re-authenticate:

```bash
hermes auth logout nous
hermes login nous
```

Token expiry can be verified from `auth.json`:
```bash
python3 -c "
import json, datetime
with open('$HOME/.hermes/auth.json') as f:
    auth = json.load(f)
nous = auth.get('providers', {}).get('nous', {})
now = datetime.datetime.now(datetime.timezone.utc)
for k in ['expires_at', 'agent_key_expires_at']:
    if k in nous:
        expires = datetime.datetime.fromisoformat(nous[k].replace('Z','+00:00'))
        remaining = (expires - now).total_seconds()
        print(f'{k}: {nous[k]} ({remaining:.0f}s remaining)' if remaining > 0 else f'{k}: EXPIRED {-remaining:.0f}s ago!')
"
```
