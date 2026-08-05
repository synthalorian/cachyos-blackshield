# Session 2026-05-29 — Duplicate Kimi Models Causing Silent Fallback

## Problem

User reports OpenClaw "overriding" the chosen model to a local model they didn't select. Two Kimi K2.6 entries exist in config, causing confusion about which is the real cloud model and which is local fallback.

## Config State Found

```json
// ~/.openclaw/openclaw.json — models.providers.kimi.models[]
{
  "id": "kimi-k2.6",
  "name": "Kimi K2.6 Kimi for Coding (direct)",
  "reasoning": true,
  "compat": { "thinkingFormat": "deepseek" }
},
{
  "id": "kimi-for-coding",
  "name": "Kimi Code",
  "reasoning": true,
  "input": ["text", "image"],
  "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
  "contextWindow": 262144,
  "maxTokens": 32768
}
```

**Key differences:**
- `kimi-k2.6`: Has `compat.thinkingFormat: deepseek`, no vision, no cost fields
- `kimi-for-coding`: Has `input: [text, image]` (vision), all costs set to 0, no `compat`

The `kimi-for-coding` entry appears stale or auto-added — cost: 0 suggests it was populated by a setup wizard or template.

## Default Model Chain

```json
// agents.defaults.model
{
  "primary": "kimi/kimi-k2.6",
  "fallbacks": [
    "llama-swap/synthclaw-35bkimi-512k",
    "llama-swap/synthclaw-35bkimi-256k",
    ...
  ]
}
```

The `synthclaw-35bkimi-*` models are **local Qwen3.6-35B distilled with Kimi reasoning** — NOT actual Kimi K2.6. When the primary fails or is unavailable, OpenClaw silently falls back to these local models.

## Root Cause

1. **Duplicate entries:** Two models with similar purposes but different configs
2. **Silent fallback:** The fallback chain includes local distilled models that impersonate the cloud model name-wise
3. **Naming confusion:** `synthclaw-35bkimi-*` sounds like "Kimi" but is actually Qwen

## Diagnostic Commands

```bash
# Check which models are configured for a provider
python3 -c "
import json
with open('/home/synth/.openclaw/openclaw.json') as f:
    d = json.load(f)
for m in d['models']['providers']['kimi']['models']:
    print(f\"ID: {m['id']}, name: {m.get('name')}, reasoning: {m.get('reasoning')}\")
"

# Check the active default model and fallbacks
python3 -c "
import json
with open('/home/synth/.openclaw/openclaw.json') as f:
    d = json.load(f)
print('DEFAULT PRIMARY:', d['agents']['defaults']['model']['primary'])
print('FALLBACKS:', d['agents']['defaults']['model']['fallbacks'])
for a in d['agents']['list']:
    if a.get('default'):
        print(f\"AGENT {a['id']} PRIMARY: {a['model']['primary']}\")
"

# Check if local llama-swap is running and what models it serves
curl -s http://127.0.0.1:8080/v1/models | python3 -c "import sys,json; d=json.load(sys.stdin); [print(m['id']) for m in d.get('data',[])]"

# Check if Kimi proxy is running (claw wrapper uses this)
systemctl --user status kimi-proxy.service
curl -s http://127.0.0.1:8699/v1/models  # returns auth error without key, but proves it's up
```

## Fix

1. **Remove stale entry:** Delete `kimi-for-coding` from `models.providers.kimi.models[]`
2. **Audit fallbacks:** Decide if local fallback is desired. If yes, keep it but know it's Qwen distilled, not Kimi. If no, remove `llama-swap/synthclaw-35bkimi-*` from fallbacks.
3. **Align claw wrapper with OpenClaw config:** The claw wrapper at `~/.local/bin/claw` routes through `http://127.0.0.1:8699/v1` (Kimi proxy). OpenClaw config uses `https://api.kimi.com/coding/` (direct). These are two paths to the same model — decide which is canonical and align both.

## Model Identity Reference

| Name | What it actually is | Location |
|------|---------------------|----------|
| `kimi/kimi-k2.6` | Real Kimi K2.6 via Kimi Coding API | Cloud |
| `kimi/kimi-for-coding` | Stale/alias entry, possibly from wizard | Cloud (same API) |
| `llama-swap/synthclaw-35bkimi-*` | Qwen3.6-35B + Kimi reasoning distillation | Local (llama.cpp) |
| `llama-swap/synthclaw-35b-*` | Qwen3.6-35B base model | Local (llama.cpp) |
