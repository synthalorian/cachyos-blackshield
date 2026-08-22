---
name: project-monetization
description: Use when monetizing projects — paywalls, licenses, pricing.
---

# Project Monetization — Turning the Portfolio into Income

## When to use
User wants to make money from their software: "make X paid", "monetize", "freemium", "paywall", "how do I sell this", "I need income from my projects".

## Rule zero: ship, don't start
Builders under money pressure instinctively start NEW projects — that's how you stay broke with style. Push back. Inventory what exists (git-log freshness per `project-triage`), rank by **distance-to-revenue**, and monetize the nearest shippable asset. Revenue comes from finishing and selling, not starting.

## Step 1 — License audit BEFORE designing anything
Check LICENSE of the repo, every upstream it forks/derives from, AND its dependencies.

- **GPL fork realities** (learned on AlbionOnline-Companion, GPLv3): selling GPL is explicitly allowed, but a client-side feature lock is legally bypassable — anyone can compile an unlocked build and redistribute it. A GPL paywall is a **toll booth, not a vault**. Acceptable when target users can't compile (game players); weak when users are developers.
- **Private repo is GPL-compatible**: distribute binaries, offer source on request to recipients. That's the pragmatic play for a paid GPL fork.
- **The "rewrite to own it" trap**: retyping GPL logic in fresh files is still a derivative work (structure/sequence copying). True clean-room requires spec-writer ≠ implementer — and an agent that reads the GPL codebase daily can't be the clean implementer. Cheaper escape: build on a permissively-licensed component that already encapsulates the hard IP (e.g. a protocol library) and write all features fresh on top.
- **Dependencies need licenses too**: a dependency with NO LICENSE file = all rights reserved = blocks commercial use. Fix: open an issue/PR asking the author to add MIT or Apache-2.0 (solo devs usually say yes within a day), or replace the dep. Verify with the GitHub API license field, not assumptions.

## Step 2 — Pick the monetization shape
- **One-time license key** for indie desktop tools: $9.99 is impulse-buy territory; ~$14.99 is the ceiling for gamer audiences. Test high later.
- **Provider: Lemon Squeezy** — built for one-time digital goods: automatic license-key generation, validation API, handles global VAT/sales tax (do NOT touch that yourself), ~5% + 50¢ per sale, no monthly fee. Fallback: Gumroad.
- **One-time pricing ⇒ zero marginal-cost features only.** Anything with per-user server cost (proxied APIs, hosted sync) bleeds money forever against a $10 one-time sale. Prefer client-side features (local processing, free scraping paths already working).
- **Free/premium split**: core functionality stays free so the tool spreads and upstream/community goodwill survives; premium = the features YOU added — differentiators, exports, alerts, vanity themes (theme packs are pure margin).

## Step 3 — Paywall architecture (client-side pattern)
- `LicenseService`: validate key against provider API on first activation → cache signed token locally → offline grace period (players go offline; don't be draconian).
- `FeatureGate` at ViewModel/UI level. Locked features show an **upgrade panel with buy link** — visible desire beats hidden features.
- Flip repo private when the paywall code merges; README content becomes the landing/listing copy.

## Step 4 — Sequencing under income pressure
Run 1–2 lanes max, never 5 in parallel:
1. **Fastest guaranteed cash** — freelance/contract work. Unsexy, but pays in weeks; fund the rest with it.
2. **Hottest momentum asset** — a repo whose latest commit is a breakthrough ("LIVE CHAT DETECTION WORKING!") ships NOW while hot.
3. **Ceiling flagship** — the big-payoff item (e.g. Steam game) as the main quest behind lanes 1–2.

## Pitfalls
- **Check publisher ToS before charging for game tools** — stat/overlay tools are generally tolerated (Albion's SBI allows them), but verify before money changes hands.
- **Don't promise un-crackable DRM** on desktop software. Frame the paywall honestly as a toll booth; most users of a $10 tool can't compile an Avalonia/Tauri app anyway.
- **Watch for overlapping free products undercutting the paid one** — if a free sibling app ships the same flagship feature, strip it from the free one or the paywall is dead on arrival.
- **Don't redesign the plan every session** — this user's monetization direction pivoted 3× in one conversation (standalone paid app → freemium fork → ownership rewrite), then RESOLVED it 2026-08-17: user said "fuck it" and open-sourced the Albion Translator entirely — paywall code (license.rs, license.js, LicenseGate.svelte, MONETIZATION.md) deleted, chat forwarder un-gated, relicensed MIT → Apache-2.0, repo flipped public, BMC coffee link in README instead of a price tag. **The "strip translator from AlbionOnline-Companion" action is CANCELLED — never execute it.** If the user reopens monetizing the Translator, the removed Lemon Squeezy architecture (one-time keys, 7-day trial, offline grace, feature gate) is in git history pre-2026-08-17 and Step 3 above — but confirm hard before re-paywalling a public Apache-2.0 app.

## Reverse direction: de-monetizing / open-sourcing a paid app
When the user kills a paywall ("fuck it, make it open source"), the excision checklist (validated on AlbionOnline-Translator, Tauri 2 + Rust + Svelte):
1. **Commit any uncommitted WIP first** as its own commit — don't tangle user work into the pivot commit.
2. **Find the whole surface**: license backend module, frontend glue, paywall UI component, gate checks in hot paths (message forwarders, feature gates), buy/trial commands in the invoke handler, MONETIZATION.md docs. `grep -ri "lemon|license|trial|buy" src src-tauri`.
3. **Delete + rewire**: drop the modules, remove gate checks so the hot path flows unconditionally, strip imports/state/listeners/UI blocks in the frontend.
4. **Relicense**: full LICENSE file (`curl https://www.apache.org/licenses/LICENSE-2.0.txt`), `Cargo.toml` + `package.json` license fields, README license section + badge.
5. **Verify before shipping**: `cargo check`, then binary audit (`strings binary | grep -ci lemonsqueezy` → 0), smoke-launch the release build.
6. **Ship**: push, `gh repo edit --visibility public`, confirm GitHub license detection via `gh api repos/<owner>/<repo>/license --jq .license.spdx_id`.
7. **Rebuild release binary with the asset-embedding path** (`npm run tauri build -- --no-bundle` for this user's Tauri apps) and reapply any setcap bits after every release build.

## References
- `references/albion-monetization-case.md` — the Albion Translator/Companion monetization case: repo states, LOC measurements, the albion-network-lib license gap, and the full decision history.
