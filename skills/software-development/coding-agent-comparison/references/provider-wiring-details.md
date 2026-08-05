# Provider Wiring Details for claw-code

## claw-code Provider Routing Internals

Source: `claw-code/rust/crates/api/src/providers/mod.rs`

### Model Resolution Chain

```rust
// metadata_for_model() — prefix-based routing
"openai/" || "gpt-"  → OpenAI-compat  (OPENAI_API_KEY + OPENAI_BASE_URL)
"claude"             → Anthropic      (ANTHROPIC_API_KEY)
"grok"               → xAI            (XAI_API_KEY)
"qwen/" || "qwen-"   → DashScope      (DASHSCOPE_API_KEY + DASHSCOPE_BASE_URL)
"kimi/" || "kimi-"   → DashScope      (DASHSCOPE_API_KEY + DASHSCOPE_BASE_URL)
"gemini/" || "gemini-" → Google       (GOOGLE_API_KEY + GOOGLE_BASE_URL)

// detect_provider_kind() — env var fallback when no prefix matches
1. OPENAI_BASE_URL + OPENAI_API_KEY both set  → OpenAI-compat
2. ANTHROPIC_API_KEY set                       → Anthropic
3. OPENAI_API_KEY set                          → OpenAI-compat
4. XAI_API_KEY set                             → xAI
5. OPENAI_BASE_URL set (no key)                → OpenAI-compat
6. GOOGLE_API_KEY set                          → OpenAI-compat
7. Fallback                                    → Anthropic
```

**Key insight:** The env var check (item 1) catches any unprefixed model name. This means you can pass `--model deepseek/deepseek-v4-flash` without any `openai/` prefix, and as long as `OPENAI_BASE_URL` + `OPENAI_API_KEY` are set, it routes correctly. The `openai/` prefix in the GLM-5.1 setup is redundant.

### ProviderClient Construction

Source: `claw-code/rust/crates/api/src/client.rs`

```rust
ProviderClient::from_model_with_anthropic_auth(model, auth) {
    match detect_provider_kind(resolved_model) {
        Anthropic → AnthropicClient::from_env()
        Xai       → OpenAiCompatClient::from_env(OpenAiCompatConfig::xai())
        OpenAi    → {
            // Checks metadata_for_model() for provider-specific config
            match meta.auth_env {
                "DASHSCOPE_API_KEY" → OpenAiCompatConfig::dashscope()
                "GOOGLE_API_KEY"    → OpenAiCompatConfig::google()
                _                   → OpenAiCompatConfig::openai()
            }
        }
    }
}
```

## The OAuth Token Refresh Problem

### How claw-code handles (or doesn't handle) token expiry

Source: `claw-code/rust/crates/api/src/providers/openai_compat.rs`

The `OpenAiCompatClient` has two token-related methods:

```rust
resolve_api_key()     → auto-refreshes gcloud tokens > 50 min old
force_refresh_token() → only activates on 401 for gcloud tokens
```

**Both methods only work for `TokenSource::Gcloud`.** Generic OAuth tokens (`TokenSource::Static`) are read once at construction and NEVER refreshed. A 401 on a static token is treated as a fatal error, not a signal to re-authenticate.

### Available OAuth Providers

From `hermes proxy providers`:
- `nous` — Nous Portal (scope: `inference:mint_agent_key`, 15-min TTL)
- `xai` — xAI Grok OAuth

### Hermes Proxy Architecture

```bash
hermes proxy start --provider nous --host 127.0.0.1 --port 8645
```

The proxy exposes an OpenAI-compatible endpoint at `http://127.0.0.1:8645/v1`:

| Endpoint | Purpose |
|----------|---------|
| `POST /v1/chat/completions` | Chat completions (stream + non-stream) |
| `GET /v1/models` | Available model listing |

The proxy accepts any `Authorization: Bearer <anything>` header and replaces it with the real OAuth token. The token is refreshed automatically before expiry using Hermes's OAuth refresh loop.

### Systemd Service

Service file: `~/.config/systemd/user/hermes-proxy.service`

```ini
[Unit]
Description=Hermes Agent OAuth Proxy - Nous provider
After=network-online.target

[Service]
Type=simple
ExecStart=<venv>/python -m hermes_cli.main proxy start --provider nous --host 127.0.0.1 --port 8645
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

## Wrapper Architecture

Source: `~/synthclaw-ai-setup/configs/wrappers/claw`

### Shorthand Resolution Flow

```
claw ds "task"
  → wrapper parses first arg "ds"
  → case "ds|deepseek" matches
  → exports OPENAI_API_KEY="hermes-proxy-auth" (dummy key)
  → exports OPENAI_BASE_URL="http://127.0.0.1:8645/v1"
  → exec claw --model "deepseek/deepseek-v4-flash" "$@"
  → claw's detect_provider_kind sees OPENAI_BASE_URL + OPENAI_API_KEY → OpenAI-compat
  → sends request to http://127.0.0.1:8645/v1/chat/completions with model="deepseek/deepseek-v4-flash"
  → Hermes proxy forwards to inference-api.nousresearch.com with real OAuth token
```

### Current Shorthand Table

| Shorthand | Model String | Base URL | Key | Type |
|-----------|-------------|----------|-----|------|
| *(none)* | `openai/glm-5.1` | `api.z.ai/api/coding/paas/v4` | Z.AI key | Cloud (Z.AI) |
| `glm` | `openai/glm-5.1` | Same | Same | Cloud (Z.AI) |
| `ds` | `deepseek/deepseek-v4-flash` | `localhost:8645/v1` | Dummy | Cloud (Nous proxy) |
| `mm` | `minimax/minimax-m2.5` | `localhost:8645/v1` | Dummy | Cloud (Nous proxy, paid) |
| `local` | `openai/synthclaw-35b-128k` | `localhost:8080/v1` | Dummy | Local (llama-swap) |
| `35b` | `synthclaw-35b-128k` | `localhost:8080/v1` | Dummy | Local (llama-swap) |
| `27b` | `synthclaw-27b-128k` | `localhost:8080/v1` | Dummy | Local (llama-swap) |

### Resolver script

Source: `~/synthclaw-ai-setup/configs/wrappers/synthclaw-resolve.sh`

Maps shorthands to full model names for local llama-swap models. Supports 3 sizing tiers × 3 context tiers × multiple model families (Qwen3.6, Gemma 4, DeepSeek, etc.). Cloud shorthands (`glm`, `ds`, `mm`) are handled directly in the claw wrapper, not in the resolver.

## Provider Status Matrix

| Provider | Model | Free? | Endpoint | Key Source | Expiry |
|----------|-------|-------|----------|------------|--------|
| Nous | `deepseek/deepseek-v4-flash` | ✅ Free | `inference-api.nousresearch.com/v1` | Hermes OAuth | 15 min |
| Nous | `deepseek/deepseek-v4-pro` | ❌ Paid | Same | Hermes OAuth | 15 min |
| Nous | `minimax/minimax-m2.5` | ❌ Paid | Same | Hermes OAuth | 15 min |
| Nous | `minimax/hailuo-2.3` | ❌ Paid | Same | Hermes OAuth | 15 min |
| Nous | `google/gemini-3.5-flash` | ✅ Free | Same | Hermes OAuth | 15 min |
| Z.AI | `glm-5.1` | ✅ $10/mo | `api.z.ai/api/coding/paas/v4` | Static key | Never |
| Z.AI | `glm-4.7` | ✅ $10/mo | Same | Static key | Never |
| Z.AI | `glm-5-turbo` | ✅ $10/mo | Same | Static key | Never |

Note: Nous free tier has 409 models total listed at `GET /v1/models`, but most are paid-gated. The free models typically include some older DeepSeek variants, some Google Flash models, and a few smaller models.
