---
name: desktop-app-monetization
description: Use when making an app paid — license keys, trials, GPL.
---

# Desktop App Monetization

How to pick and implement a revenue model for synth's desktop apps and game tools. Born from the 2026-08 Albion Translator monetization session.

## Step 0: License audit BEFORE anything commercial

- **Check every dependency's LICENSE, including transitive and git-pinned ones.** `beemerwt/albion-network-lib` had NO license file (= all rights reserved) while being the commercial product's core decode path. Fix: politely ask the author for MIT/Apache-2.0 via a GitHub issue (offer to PR the LICENSE file; solo devs usually say yes), or replace the dependency. Do not ship paid software on unlicensed deps.
- **GPL fork constraints:** GPLv3 explicitly permits SELLING binaries, but recipients are entitled to source and may legally recompile with your paywall removed and redistribute. A client-side feature lock in a GPL app is a **toll booth, not a vault** — acceptable (most users can't compile), but go in eyes-open. Private repo + source-on-request to buyers stays GPL-compliant.
- **"Rewrite the GPL fork to own it" is usually a trap.** Retyping GPL logic in new clothes is still legally a derivative work — true clean-room requires the spec-writer to never touch the implementation. If the agent reads the GPL codebase daily, a "rewrite" doesn't deliver clean ownership. Estimate honestly (LOC + embedded reverse-engineered knowledge), compare against building on the code the user already owns, and expect the rewrite to lose.

## Model selection for niche desktop tools

**One-time license key ($9.99-ish) is the default winner for niche game tools.** The deciding math:

- Ads: no legitimate ad network serves desktop apps (AdSense ToS forbids app embedding; AdMob is mobile-only). Bottom-feeder networks ship tracker JS that gets game overlays flagged by antivirus — fatal for a packet-sniffing tool. Even idealized: 1,000 DAU × 2 impressions × $2 CPM ≈ $120/mo, beaten by ~12 one-time sales. Ads need 10k+ DAU scale a single-game tool never reaches.
- Subscriptions: unjustifiable ongoing value for a utility; users resent it.
- Freemium paywall: works, but only gate features the user BUILT (not upstream/fork features — community backlash).
- Affiliate links (VPN, ExitLag, game-key shops): the only "ad-flavored" revenue worth layering on later — per-signup payouts, no trackers, native fit. Keep out of v1.
- Paid binaries of open source (Ardour model): source stays free, convenience costs money. Valid for GPL projects.

## Implementation: Lemon Squeezy license keys (recommended)

Why Lemon Squeezy: built for one-time digital goods, auto-generates license keys, **its license endpoints need NO API token** (safe to call from a distributed client), and it handles global VAT/sales tax as merchant of record. ~5% + 50¢ per sale, no monthly fee. Gumroad licenses are the fallback.

The architecture that worked (Rust/Tauri, but the shape is language-agnostic):

- **7-day full trial** from a `first_seen` timestamp persisted on first launch → hard lock with upgrade screen. Converts better than feature-gated free tiers for single-feature tools.
- **Activate** → store key + instance_id + `last_validated` timestamp in config-dir JSON.
- **Revalidate** online when stale (>24h); distinguish network failure from server-says-dead (refunded/disabled key → lock).
- **Offline grace:** honor a previously-validated license for 7 days since last successful validation. Never-validated + unreachable server → locked. Players go offline; don't be draconian, don't be naive.
- **Gate at the backend event/emit layer**, not just the UI — a UI-only gate is a prompt, not a paywall.
- Endpoint shapes + response fields: `references/lemonsqueezy-license-api.md`.

## Pitfalls

1. **Don't run 5 revenue projects in parallel.** When synth asks to "start N money-making projects," the honest first move is triaging what already exists for ship-readiness (money comes from finishing, not starting) — then sequencing: fastest-cash lane (contract work) + hottest-momentum lane, rest as fire-and-forget.
2. **Pricing for niche game tools:** $9.99 impulse-buy beats $14.99 test-later. One-time pricing demands near-zero marginal cost per user — avoid routing features through your own paid server (e.g. paid translation APIs) or the server bill slowly eats the $9.99 forever.
3. **Overlap cannibalization:** if a free sibling app ships the same flagship feature, strip it from the free one before launching the paid one (synth's own reasoning).
4. **Game publisher ToS:** verify the publisher's third-party tool policy before charging for anything game-adjacent; packet-read-only stats/translation tools have generally been tolerated in Albion, but check before money changes hands.

## Support files

- `references/lemonsqueezy-license-api.md` — endpoint request/response shapes, offline-grace design, Rust implementation notes
