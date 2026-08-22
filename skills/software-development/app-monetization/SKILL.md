---
name: app-monetization
description: "Use when monetizing an app or OSS fork: paywall, pricing."
---

# App Monetization — Turning Projects into Income

**Class**: Advising on and implementing monetization for the user's existing software projects (paywalls, pricing, payment plumbing, license keys).

## Step 0 — Check the license BEFORE designing anything

If the project is a fork or builds on someone else's code, read the LICENSE file first. It shapes every later decision. See `references/gpl-fork-monetization.md` for the full landscape; the short version:

- **MIT/BSD/Apache**: do whatever, sell it, no constraints.
- **GPL (any version)**: you CAN charge ("free as in freedom, not price"), BUT recipients are entitled to source and may legally redistribute — including a version with your paywall deleted. A client-side feature lock in GPL code is a toll booth, not a vault.
- **A "rewrite" of GPL code you have read is still legally a derivative work** — retyping the same logic in new clothes copies structure/sequence/organization. True clean-room requires spec-writer ≠ implementer.
- **Dependency audit**: a lib with NO LICENSE file = all rights reserved. Do not ship commercially on it. Fix: open an issue/PR asking the author to add MIT/Apache (solo devs almost always say yes), or replace the component.

## Step 1 — Pick the model (strong defaults for niche tools)

| Model | When it wins | Math to remember |
|---|---|---|
| **One-time license ($9.99–14.99)** | Niche tools, hundreds–thousands of users | DEFAULT. Users impulse-buy at ≤$10 |
| Freemium feature gate | Large free funnel feeds paid upgrades | Keep upstream-derived features free; paywall only features YOU built |
| Ads / ad networks | Only at tens of thousands of DAU | 1k DAU × 2 imp × $2 CPM ≈ $120/mo — **12 one-time sales beat a year of ads** |
| Affiliate links | Niche audiences that buy adjacent products (VPNs, game keys) | Pays per signup, no trackers, survives small scale |
| Contract/freelance work | Money needed in weeks, not months | The only guaranteed-paycheck lane |

**Ads on desktop apps specifically**: there is no good desktop ad network (AdSense forbids app embedding; AdMob is mobile-only; the rest get your installer flagged by AV — fatal for any tool already triggering heuristics, like packet sniffers). If the user wants ad-flavored revenue, steer to affiliate links or a direct sponsor slot instead. See `references/ads-vs-paywall.md`.

**The #1 anti-pattern**: starting N new projects to make money when the user has near-finished projects. Revenue comes from finishing and shipping, not starting. If asked to "start 5 money-making projects", push back and triage existing work for the most sellable asset first.

## Step 2 — Payment + licensing plumbing

For one-time desktop-app licenses, **Lemon Squeezy** is the default: built-in license-key generation, validate/activate/deactivate API that needs NO API token (safe to call from a distributed client), merchant-of-record (they handle global sales tax/VAT), ~5% + 50¢ per sale, no monthly fee. Gumroad is the fallback. Full integration pattern (Rust/Tauri implementation, trial clock, offline grace): `references/lemonsqueezy-license-keys.md`.

Key design rules:
- **7-day full-feature trial → hard paywall** converts better than crippled free tiers for small tools.
- **Offline grace** (7 days since last successful validation) — people play offline; draconian DRM costs more paying users than piracy does.
- **24h revalidation cadence**, not per-launch phone-home.
- **3 machine seats** per key for desktop apps (PC + laptop reality).
- Accept piracy: at $9.99 the price is below the hassle threshold; 98% of users can't patch a binary.

## Step 3 — Ship sequence

1. License/deps audit resolved (Step 0) — do not skip
2. Payment account + product created (this is USER homework — account creation, payout details, tax forms can't be automated; write them a checklist)
3. License service + feature gate (see references)
4. 100%-off test code → buy → activate → verify paywall clears → wipe local license → verify paywall returns
5. Landing page/listing + installer build + private repo release

## For synth specifically

- Free companion/community tools stay free and spread goodwill; the PAID product is always the feature synth built from scratch. Never let the free fork's feature set overlap the paid product — strip overlap ruthlessly.
- Default price anchor: **$9.99 one-time**, "no subscription, ever" messaging.
- Credit convention: 'Made by synth with synthclaw 🎹🦞' in docs/READMEs.

## References

- `references/lemonsqueezy-license-keys.md` — LS API endpoints, response shapes, complete Rust/Tauri LicenseManager pattern (trial, activation, offline grace), Svelte gate component sketch, pre-launch test loop
- `references/gpl-fork-monetization.md` — GPL selling rights, derivative-work/clean-room cautions, repo-privacy compliance posture, dependency license audit workflow
- `references/ads-vs-paywall.md` — the math and network landscape for why ads lose on niche desktop tools; affiliate/direct-sponsor alternatives
