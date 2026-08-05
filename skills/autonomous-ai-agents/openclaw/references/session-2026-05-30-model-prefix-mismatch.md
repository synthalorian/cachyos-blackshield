# Session: Model Prefix Mismatch — `kimi/kimi-k2.6` vs `kimi-k2.6`

**Date:** 2026-05-30
**Symptom:** `Provider kimi is in cooldown (suspending lanes) (model_not_found)`
**Root cause:** Vendor-prefixed model slug (`kimi/kimi-k2.6`) used where bare ID (`kimi-k2.6`) was expected.

## Context

User installed the `kimi-claw` plugin via OpenClaw web UI to add a Telegram bot. This plugin rewrote the model config, changing the agent's `primary` model from `kimi-k2.6` (bare ID) to `kimi/kimi-k2.6` (vendor-prefixed slug).

## Provider Config

The `kimi` provider in `models.providers`:

```json
{
  "kimi": {
    "baseUrl": "https://api.kimi.com/coding/",
    "api": "openai-completions",
    "apiKey": "***",
    "models": [
      {
        "id": "kimi-k2.6",
        "name": "Kimi K2.6 (Kimi for Coding)",
        "reasoning": true,
        "compat": { "thinkingFormat": "deepseek" }
      }
    ]
  }
}
```

Note: `models[].id` is `kimi-k2.6` (bare), NOT `kimi/kimi-k2.6`.

## Broken Agent Config (after kimiclaw)

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "kimi/kimi-k2.6"
      }
    },
    "list": [
      {
        "id": "synthclaw",
        "default": true,
        "model": {
          "primary": "kimi/kimi-k2.6"
        }
      }
    ]
  }
}
```

## Fix Applied

1. Set `agents.defaults.model.primary` to `kimi-k2.6` (bare ID)
2. Set `agents.list[0].model.primary` to `kimi-k2.6` (bare ID)
3. Disabled `kimi-claw` plugin: `plugins.entries.kimi-claw.enabled = false`

Commands:
```bash
openclaw config set agents.defaults.model.primary kimi-k2.6
openclaw config set agents.list.0.model.primary kimi-k2.6
openclaw config set plugins.entries.kimi-claw.enabled false
```

## Lesson

The `kimi-claw` plugin (web UI bridge) writes vendor-prefixed model slugs even when the provider uses bare IDs. This is a plugin bug or mismatch. **Defense:** after any kimiclaw interaction, verify `agents.*.model.primary` matches the provider's `models[].id` exactly.

## User Frustration Signal

User had to correct the agent: "oh my dear god not hermes. openclaw" — the agent initially tried to fix Hermes config instead of OpenClaw config. This happened because the agent saw "model config" and defaulted to Hermes (the tool it was running in) rather than checking which tool the user was actually talking about.
