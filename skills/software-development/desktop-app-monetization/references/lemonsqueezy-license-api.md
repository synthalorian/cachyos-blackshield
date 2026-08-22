# Lemon Squeezy License API — Client-Side Licensing Reference

Condensed from implementation in `AlbionOnline-Translator/src-tauri/src/license.rs` (2026-08-11).

## Why these endpoints are client-safe

`/licenses/activate`, `/licenses/validate`, `/licenses/deactivate` require **no API token** — only the customer's license key. Safe to call from a distributed desktop app. (Store/product management endpoints DO need a token — never ship one in a binary.)

## Endpoints

Base: `https://api.lemonsqueezy.com/v1/licenses`

| Action | Method | Form fields |
|---|---|---|
| Activate | POST `/activate` | `license_key`, `instance_name` |
| Validate | POST `/validate` | `license_key`, `instance_id` |
| Deactivate | POST `/deactivate` | `license_key`, `instance_id` |

All three accept `application/x-www-form-urlencoded` bodies (not JSON).

## Response shape (all three)

```json
{
  "success": true,
  "error": null,
  "license_key": {
    "status": "active",          // active | expired | disabled | inactive
    "key": "XXXX-...",
    "activation_limit": 2,
    "activation_usage": 1,
    "expires_at": null,
    "customer_name": "...",
    "customer_email": "..."
  },
  "instance": { "id": "abc123", "name": "my-pc-deadbeef" },
  "meta": { "store_id": 1, "order_id": 1, "product_id": 1, "variant_id": 1 }
}
```

- `success: false` + `error` string on bad key, activation limit hit, disabled key.
- `instance.id` comes back from **activate** — persist it; validate/deactivate need it.
- Distinguish failure modes:
  - **HTTP/network error** → offline, apply grace policy (below)
  - **Server reachable, `success: false`** → key genuinely dead (refunded/disabled) → lock

## Trial + offline-grace design (the working recipe)

Persisted JSON in config dir (`dirs::config_dir()/<app>/license.json`):

```json
{
  "license_key": null,
  "instance_id": null,
  "license_status": null,
  "last_validated": null,
  "first_seen": "2026-08-11T..."
}
```

- `first_seen` stamped on FIRST EVER launch → trial = `first_seen + 7 days`. Days remaining = `7 - (now - first_seen).days`; `>= 0` → trial active.
- **Revalidation cadence:** if `now - last_validated > 24h`, try online validate. Success → refresh `last_validated` + `license_status`.
- **Offline grace:** previously-validated license honored while `now - last_validated <= 7 days`. Beyond that AND unreachable → locked (can't trust a never-verified key).
- Status enum serialized to frontend with `#[serde(tag = "mode")]`: `trial {days_remaining}` | `licensed {status}` | `locked`.

## Rust implementation notes

- `reqwest` with 10s timeout — licensing must never hang the app.
- `instance_name`: hostname + short hash (no uuid dep needed — `DefaultHasher` over timestamp+pid).
- Deactivate is best-effort fire-and-forget (user may be offline when they deactivate).
- Gate the backend event/emit loop (`is_unlocked()` before forwarding), not just the UI. Emit a one-shot `license-locked` event so the frontend can show the paywall (use a `locked_notice_sent` flag to avoid event spam per message).
- **TODO placeholder pattern:** keep the checkout URL as a `const BUY_URL` with an obvious `REPLACE_ME` value until the Lemon Squeezy product exists — the code ships before the store does.

## Provider facts

- ~5% + 50¢ per transaction, no monthly fee, merchant-of-record (handles global VAT/sales tax — critical for solo devs).
- Lemon Squeezy was acquired by Stripe (2024); the API above is the standalone LS API, not the Stripe API.
- Fallback: Gumroad license keys (`POST https://api.gumroad.com/v2/licenses/verify`, needs `product_id` + `license_key`), higher fees (~10%).
