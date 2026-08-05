# Debugging Provider/Model Mismatch in OpenClaw Bundled Extensions

## Symptom

```
model set to kimi/kimi-k2.6
run error: All models failed (1): kimi/kimi-k2.6: Provider kimi is in cooldown (suspending lanes) (model_not_found)
```

Or: HTTP 404 on a model you believe exists.

## Root Cause

Bundled provider plugins define their own model catalogs. The `kimi-coding` extension registers provider `kimi` with alias `kimi-coding`, but its catalog only contains:
- `kimi-for-coding` (default)
- `kimi-code` (legacy)
- `k2p5` (legacy)

The model `kimi-k2.6` is NOT in this catalog. It may exist on a different endpoint or under a different provider plugin.

## Trace Technique

### 1. Find the extension directory

```bash
# Global install (mise/node)
ls ~/.local/share/mise/installs/node/*/lib/node_modules/openclaw/dist/extensions/ | grep -i <provider-name>

# Or search for the plugin JSON
find ~/.local/share/mise/installs/node -path "*openclaw*" -name "openclaw.plugin.json" | xargs grep -l '"id": "kimi"'
```

### 2. Read the plugin manifest

```bash
cat <extension-dir>/openclaw.plugin.json
```

Check:
- `"id"` — the plugin ID (may differ from directory name, e.g. `kimi` inside `kimi-coding/`)
- `"providers"` — which provider IDs this plugin registers
- `"providerRequest.providers.<id>.family"` — which API family it uses

### 3. Read the provider catalog

```bash
cat <extension-dir>/provider-catalog.js
```

This exports `buildKimiCodingProvider()` which returns the actual model list. Look for:
- `baseUrl` — the endpoint URL
- `models[].id` — the ONLY valid model IDs for this provider
- `normalizeKimiCodingModelId()` — any legacy ID remapping

### 4. Read the entry point (index.js)

```bash
cat <extension-dir>/index.js
```

Check:
- `PROVIDER_ID` — what the provider registers as
- `aliases` — alternate names that resolve to this provider
- `registerProvider({ id: ... })` — the canonical provider ID

### 5. Map provider ID → model IDs

| What you type | Provider ID | Model ID | Must match catalog? |
|---|---|---|---|
| `kimi/kimi-k2.6` | `kimi` | `kimi-k2.6` | YES — must be in `models[].id` |
| `kimi-coding/kimi-for-coding` | `kimi` (alias) | `kimi-for-coding` | YES |

The part before `/` is the provider ID (or alias). The part after `/` is the model ID. BOTH must be known to the provider's catalog.

## Common Mismatches

| Extension Dir | Plugin ID | Provider ID | Actual Models | User Might Try |
|---|---|---|---|---|
| `kimi-coding/` | `kimi` | `kimi` | `kimi-for-coding`, `kimi-code`, `k2p5` | `kimi-k2.6` ❌ |
| `moonshot/` | `moonshot` | `moonshot` | (varies) | `kimi-k2.6` ❌ |

## Fix

### Option A: Use the exact model ID from the provider catalog

```
# Wrong
model set to kimi/kimi-k2.6

# Right (for kimi-coding extension)
model set to kimi/kimi-for-coding
```

### Option B: Patch the provider catalog to add the missing model

If the endpoint actually supports the model (e.g. `kimi-k2.6` works on `api.kimi.com/coding/` even though the catalog doesn't list it), patch the compiled JS:

**File:** `~/.local/share/mise/installs/node/<version>/lib/node_modules/openclaw/dist/provider-catalog-nrg9oGFW.js`

Add the model ID to the `buildKimiCodingProvider()` models array and update `normalizeKimiCodingModelId()` to pass it through:

```javascript
const KIMI_ADDITIONAL_MODEL_IDS = ["kimi-k2.6"];

function buildKimiCodingProvider() {
  return {
    // ... existing fields ...
    models: [{
      id: KIMI_DEFAULT_MODEL_ID,
      // ...
    }, ...KIMI_ADDITIONAL_MODEL_IDS.map((id) => ({
      id,
      name: `Kimi Code (${id})`,
      reasoning: true,
      input: [...KIMI_CODING_INPUT],
      cost: KIMI_CODING_DEFAULT_COST,
      contextWindow: KIMI_CODING_DEFAULT_CONTEXT_WINDOW,
      maxTokens: KIMI_CODING_DEFAULT_MAX_TOKENS
    })), ...KIMI_LEGACY_MODEL_IDS.map((id) => ({
      // ... existing legacy map ...
    }))]
  };
}

function normalizeKimiCodingModelId(modelId) {
  if (KIMI_LEGACY_MODEL_IDS.includes(modelId)) return KIMI_DEFAULT_MODEL_ID;
  if (KIMI_ADDITIONAL_MODEL_IDS.includes(modelId)) return modelId;
  return modelId;
}
```

**Note:** This patches compiled/bundled JS. The change survives until the next `npm update` of openclaw. Re-apply after updates.

Or switch to a different provider/plugin that actually exposes `kimi-k2.6`.

## Key Files to Inspect

| File | What it tells you |
|---|---|
| `openclaw.plugin.json` | Plugin ID, provider IDs, API family |
| `provider-catalog.js` | Base URL, model list, normalization |
| `index.js` | Provider registration, aliases, auth |
| `api.js` | Request/response transformation |
| `stream.js` | Streaming wrapper logic |
