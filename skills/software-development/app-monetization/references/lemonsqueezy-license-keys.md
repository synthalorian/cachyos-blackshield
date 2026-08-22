# Lemon Squeezy License Keys — Integration Pattern

Validated 2026-08 in a Tauri 2 (Rust + Svelte) desktop app. Production reference:
`~/Projects/active/AlbionOnline-Translator/src-tauri/src/license.rs`.

## Why Lemon Squeezy

- License-key generation built in (auto-issued per order when enabled on the product)
- License API endpoints need NO API token — only the customer's key — safe from a distributed binary
- Merchant of record: handles global sales tax/VAT (the #1 reason not to hand-roll with Stripe)
- ~5% + 50¢ per sale, no monthly fee. Gumroad = fallback (its license API is similar but weaker).

## License API (no auth header required)

Base: `https://api.lemonsqueezy.com/v1/licenses` — all POST, form-encoded:

| Endpoint | Fields | Purpose |
|---|---|---|
| `/activate` | `license_key`, `instance_name` | Claims a machine seat; returns `instance.id` |
| `/validate` | `license_key`, `instance_id` | Checks key+seat still valid |
| `/deactivate` | `license_key`, `instance_id` | Frees the seat (best-effort call) |

Response shape (all three):
```json
{
  "success": true,
  "error": null,
  "license_key": { "status": "active", "key": "..." },
  "instance": { "id": "..." },
  "meta": { "store_id": 0, "order_id": 0, "customer_email": "..." }
}
```
`success: false` + `error` string = invalid/disabled key. `license_key.status` values include
`active`, `expired`, `disabled`, `inactive`.

## Client architecture (as built)

- **Trial**: stamp `first_seen` in a local JSON on first launch; trial = 7 days from that stamp.
  (Client-clock games possible; accept them at $9.99 price points.)
- **States**: `Trial { days_remaining }` | `Licensed { status }` | `Locked`. Serialized with
  `#[serde(tag = "mode", rename_all = "lowercase")]` + `#[serde(flatten)]` for clean frontend JSON.
- **Revalidation**: only when `now - last_validated > 24h`. On network failure during
  revalidation, stay unlocked if last success < 7 days ago (offline grace). Server-reported
  dead key (refund/disable) = Locked immediately.
- **Persistence**: `<config_dir>/<app-name>/license.json` — key, instance_id, status,
  last_validated, first_seen. Requires `chrono` with the `serde` feature for `DateTime<Utc>`
  fields (without it: E0277 Deserialize bound errors).
- **Gating**: do it on the backend hot path (e.g., drop messages in the forwarder loop), not
  just the UI — and emit a throttled `license-locked` event (send-once flag) so the frontend
  re-polls status instead of spamming.
- **Tauri 2 notes**: custom commands need no capability entries (`core:default` covers invoke);
  opening the checkout URL from Svelte needs `tauri-plugin-opener` (Rust) +
  `@tauri-apps/plugin-opener` (JS `openUrl`) + `opener:default` permission.
- **Frontend**: full-screen overlay for `locked` (fixed inset-0, high z-index), slim dismissible
  banner for `trial` with "N days left" + buy button + inline key entry. Style off the app's
  existing CSS vars so it themes for free.

## Store setup (user homework — cannot be automated)

1. Create store at lemonsqueezy.com, complete payout details
2. Product: one-time price, enable **license key generation**, activation limit **3**
3. Copy checkout URL into the client (keep it a `const`, e.g. `BUY_URL`)
4. Test loop: 100%-off discount code → "buy" → real key by email → activate in-app →
   paywall clears → delete local license.json → trial/paywall returns

## Pitfalls

- `activate` needs a stable-ish `instance_name` (hostname + short hash suffices — no uuid dep needed).
- Set a reqwest timeout (~10s) or a hung LS API blocks your gate check forever.
- `deactivate` is best-effort: fire-and-forget, always clear local state regardless of result.
- Never store an LS API token in the client. You don't need one for these three endpoints.
