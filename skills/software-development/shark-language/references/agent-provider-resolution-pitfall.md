# Agent Provider Resolution Pitfall

**Problem:** `Agent::new()` hardcodes the "local" provider at `127.0.0.1:8080`, ignoring the user's configured default model and its associated provider.

**Symptom:** `openshark agent "some task"` fails with 404 because it tries to use `kimi-k2.6` (or `kimi-for-coding`) against the local llama-swap endpoint which doesn't have that model.

**Root Cause:** The agent constructor creates a `Provider` directly instead of looking up the provider from config:

```rust
// WRONG — hardcodes local provider
let provider = Provider::new(
    "local".to_string(),
    app_config.providers.get("local").map(|p| p.base_url.clone())
        .unwrap_or_else(|| "http://127.0.0.1:8080/v1".to_string()),
    "local".to_string(),
    crate::config::ProviderKind::OpenAiCompatible,
    std::collections::HashMap::new(),
);
```

**Fix:** Use `Config::find_provider_for_model()` like the chat command does:

```rust
// CORRECT — resolves provider from config
let (provider_name, provider_config) = app_config
    .find_provider_for_model(&app_config.default_model)
    .unwrap_or_else(|| {
        // Fallback to first configured provider
        app_config.providers.iter().next()
            .map(|(name, cfg)| (name.clone(), cfg.clone()))
            .unwrap_or_else(|| ("local".to_string(), /* default config */))
    });

let provider = Provider::new(
    provider_name.clone(),
    provider_config.base_url.clone(),
    provider_config.api_key.clone(),
    provider_config.kind.clone(),
    provider_config.headers.clone(),
);
```

**Also fix:** Update `AgentConfig::default()` to use the correct default model name:
```rust
// Was: "kimi-k2.6" (doesn't exist in config)
// Should be: "kimi-for-coding" (matches config)
default_model: "kimi-for-coding".to_string(),
```

**Verification:**
```bash
cd /home/synth/projects/openshark
cargo test agent::
openshark agent "list files"  # Should work with correct provider
```

**Session:** 2026-05-30
