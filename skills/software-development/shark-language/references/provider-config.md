# OpenShark Provider Configuration Reference

## ProviderKind TOML Values

| Rust Enum Variant | TOML Value | Notes |
|---|---|---|
| `OpenAiCompatible` | `open_ai_compatible` | NOT `openai_compatible` — serde snake_case adds underscore |
| `Anthropic` | `anthropic` | Native Claude messages API |
| `Gemini` | `gemini` | Google Gemini contents API |

## Full Config Example

```toml
default_model = "kimi-for-coding"

[providers.kimi]
base_url = "http://127.0.0.1:8699/v1"
api_key = "${KIMI_API_KEY}"
kind = "open_ai_compatible"
env_file = "kimi.env"

[[providers.kimi.models]]
name = "kimi-for-coding"
display_name = "Kimi-k2.6"
context_length = 256000
max_tokens = 256000

[providers.kimi.headers]
x-kimi-agent-name = "OpenShark"
x-kimi-agent-version = "1.0.0"

[providers.local]
base_url = "http://127.0.0.1:8080/v1"
api_key = "llama-swap-local"
kind = "open_ai_compatible"

[[providers.local.models]]
name = "synthclaw-35b"
context_length = 32768

[[providers.local.models]]
name = "synthclaw-14b"
context_length = 32768

[[providers.local.models]]
name = "synthclaw-9b"
context_length = 32768

[providers.nous]
base_url = "http://127.0.0.1:8645/v1"
api_key = "hermes-proxy-auth"
kind = "open_ai_compatible"

[[providers.nous.models]]
name = "deepseek-flash"
context_length = 64000

[[providers.nous.models]]
name = "minimax"
context_length = 64000

[providers.openrouter]
base_url = "https://openrouter.ai/api/v1"
api_key = "${OPENROUTER_API_KEY}"
kind = "open_ai_compatible"
env_file = "openrouter.env"

[[providers.openrouter.models]]
name = "deepseek-v4-pro"
context_length = 64000

[providers.openrouter.headers]
HTTP-Referer = "https://openshark.dev"
X-Title = "OpenShark"

[providers.zai]
base_url = "https://api.z.ai/api/coding/paas/v4"
api_key = "${ZAI_API_KEY}"
kind = "open_ai_compatible"
env_file = "zai.env"

[[providers.zai.models]]
name = "glm-5.1"
context_length = 32000

[providers.anthropic]
base_url = "https://api.anthropic.com/v1"
api_key = "${ANTHROPIC_API_KEY}"
kind = "anthropic"

[[providers.anthropic.models]]
name = "claude-sonnet-4"
context_length = 200000

[providers.gemini]
base_url = "https://generativelanguage.googleapis.com/v1beta"
api_key = "${GEMINI_API_KEY}"
kind = "gemini"

[[providers.gemini.models]]
name = "gemini-2.5-pro"
context_length = 1000000
```

## Model Config Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Model ID used in API calls (the slug) |
| `display_name` | string | No | Human-readable name shown in UI |
| `context_length` | integer | Yes | Native context window in tokens |
| `max_tokens` | integer | No | Max tokens to request per response |

## Env-File Key Management

API keys are **never** hardcoded in config. The pattern:
1. Store keys in `~/.config/openshark/<provider>.env` with `chmod 600`
2. Reference in config: `api_key = "${KIMI_API_KEY}"` or `env_file = "kimi.env"`
3. `Config::resolve_env_keys()` loads at startup

**Important:** Tool output masking replaces API keys with `***` in ALL tool outputs. You cannot write `.env` files through tools. Have the user create them manually, then verify by file size.

## Kimi via Local Proxy (Recommended)

Pattern matching claw-code's `kimi` shortcut:

```toml
[providers.kimi]
base_url = "http://127.0.0.1:8699/v1"
api_key = "${KIMI_API_KEY}"
kind = "open_ai_compatible"
env_file = "kimi.env"

[[providers.kimi.models]]
name = "kimi-for-coding"
display_name = "Kimi-k2.6"
context_length = 256000
max_tokens = 256000

[providers.kimi.headers]
x-kimi-agent-name = "OpenShark"
x-kimi-agent-version = "1.0.0"
```

Env file at `~/.config/openshark/kimi.env`:
```bash
KIMI_API_KEY="sk-kimi-..."
```

## Model Resolution

`Config::find_provider_for_model(model_name)` returns the first provider that has a model matching the given name. The TUI uses this to:
1. Find the right provider for the selected model
2. Set `model_context_length` from the model config
3. Pass `max_tokens` in the chat request

## Adding a New Provider

1. Add `ProviderConfig` to `Config::default()` in `src/config/mod.rs`
2. If non-OpenAI backend, extend `ProviderKind` and handle in:
   - `build_request_builder()` — auth headers
   - `build_chat_body()` — request format
   - `parse_chat_response()` — response format
   - `chat_stream()` — delta extraction
3. Update setup wizard in `src/config/setup.rs`
