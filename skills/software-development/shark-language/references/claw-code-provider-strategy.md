# Claw-Code Provider Strategy for OpenShark

**Date:** 2026-05-30
**Context:** Making OpenShark compatible with most API keys by studying claw-code's approach

## Claw-Code's Pattern

Claw-code uses a **prefix-based routing system** with env-file key management:

```bash
# ~/.local/bin/claw
# Provider routing based on model name prefix:
# - "kimi" or "kimi-k2" -> Kimi proxy at 127.0.0.1:8699
# - "deepseek" or "ds" -> Kimi proxy (DeepSeek models)
# - "glm" or "zai" -> Z.AI proxy
# - "claude" or "anthropic" -> Anthropic API
# - "gemini" or "google" -> Gemini API
# - "local" or "llama" -> llama-swap at 127.0.0.1:8080
# - "openrouter" or "or" -> OpenRouter

# Keys loaded from ~/.config/claw-code/*.env files
# - ~/.config/claw-code/kimi.env -> KIMI_API_KEY
# - ~/.config/claw-code/anthropic.env -> ANTHROPIC_API_KEY
# - ~/.config/claw-code/openrouter.env -> OPENROUTER_API_KEY
# - ~/.config/claw-code/gemini.env -> GEMINI_API_KEY
# - ~/.config/claw-code/zai.env -> ZAI_API_KEY
```

## What OpenShark Adopted

### 1. Env-File Key Loading

```rust
// src/config/mod.rs
pub fn resolve_env_keys(&mut self) -> Result<()> {
    let config_dir = dirs::config_dir()
        .ok_or_else(|| anyhow!("Could not find config directory"))?
        .join("openshark");

    for provider in &mut self.providers {
        if let Some(ref env_file) = provider.env_file {
            let env_path = config_dir.join(env_file);
            if env_path.exists() {
                dotenvy::from_path(&env_path)?;
            }
        }

        // Expand ${VAR} references in api_key
        provider.api_key = shellexpand::env(&provider.api_key)
            .unwrap_or_else(|_| provider.api_key.clone().into())
            .to_string();
    }
    Ok(())
}
```

### 2. ProviderKind for Backend-Specific Formatting

```rust
pub enum ProviderKind {
    OpenAiCompatible,  // 90% of providers
    Anthropic,         // Claude native messages API
    Gemini,            // Google Gemini contents API
}
```

### 3. Custom Headers Support

```rust
pub struct Provider {
    pub name: String,
    pub base_url: String,
    pub api_key: String,
    pub kind: ProviderKind,
    pub headers: HashMap<String, String>,
    pub env_file: Option<String>,
    pub models: Vec<ModelConfig>,
}
```

### 4. Model Resolution

```rust
pub fn find_provider_for_model(
    &self,
    model_name: &str
) -> Option<(&Provider, &ModelConfig)> {
    for provider in &self.providers {
        for model in &provider.models {
            if model.name == model_name {
                return Some((provider, model));
            }
        }
    }
    None
}
```

## Provider Compatibility Matrix

| Provider | Kind | Auth | Custom Headers | Notes |
|---|---|---|---|---|
| **Kimi** | OpenAiCompatible | API key in `Authorization: Bearer` | `x-kimi-agent-name` | Via proxy at 127.0.0.1:8699 |
| **OpenAI** | OpenAiCompatible | API key in `Authorization: Bearer` | None | Standard |
| **OpenRouter** | OpenAiCompatible | API key in `Authorization: Bearer` | `HTTP-Referer`, `X-Title` | Required for routing |
| **Anthropic** | Anthropic | API key in `x-api-key` | `anthropic-version` | Native messages API |
| **Gemini** | Gemini | API key in query param `key=` | None | Contents API |
| **Local (llama-swap)** | OpenAiCompatible | `Authorization: Bearer *** or none | None | Self-hosted |
| **Z.AI** | OpenAiCompatible | API key in `Authorization: Bearer` | None | GLM models |

## Key Insight

**OpenAI-compatible API covers 90% of providers.** The only exceptions are Anthropic (different auth header + messages format) and Gemini (different endpoint structure). Everything else -- Kimi, OpenRouter, local models, Z.AI, Grok -- speaks OpenAI's `/v1/chat/completions` format.

This means:
1. Default to `OpenAiCompatible` for new providers
2. Only implement `Anthropic` or `Gemini` if explicitly needed
3. Use `headers` for provider-specific metadata (OpenRouter referrer, Kimi agent name)
4. Use `env_file` for clean key management

## Configuring for Maximum Compatibility

To make OpenShark work with "most API keys":

1. **Create env files** for each provider:
   ```bash
   mkdir -p ~/.config/openshark
   # User creates each .env file manually (tool masking prevents automated creation)
   ```

2. **Add providers to config.toml** with correct `kind`:
   - OpenAI-compatible -> `kind = "open_ai_compatible"`
   - Anthropic -> `kind = "anthropic"`
   - Gemini -> `kind = "gemini"`

3. **Set `default_model`** to your primary model (e.g., `kimi-for-coding`)

4. **Add custom headers** for providers that need them (OpenRouter, Kimi)

## Related

- `references/provider-config.md` -- Full config format and examples
- `references/kimi-proxy-quirks.md` -- Kimi-specific behavior
- `references/api-key-masking-pitfall.md` -- Why you can't write keys through tools
