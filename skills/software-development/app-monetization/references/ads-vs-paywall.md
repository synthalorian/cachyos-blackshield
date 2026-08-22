# Ads vs Paywall — Why Ads Lose on Niche Desktop Tools

Session case study (2026-08): user's friend suggested ads for the Albion Translator
(a packet-sniffing game overlay, Tauri desktop app). Verdict: wrong model.

## The supply problem (desktop)

There is no reputable programmatic ad network for desktop apps:
- **AdSense**: ToS forbids embedding in apps; it's for web content.
- **AdMob / Unity Ads / etc.**: mobile or in-game only.
- **What remains**: bottom-feeder networks whose JS trackers and obscure advertisers get
  installers flagged by antivirus. For a tool that ALREADY trips heuristics (packet capture,
  game overlay), one Windows Defender false positive = "don't install, it's malware" across
  every Discord server. Fatal.

## The math problem (niche)

Optimistic niche-tool numbers:
- 1,000 daily active users × 2 banner impressions × $2 CPM ≈ **$120/month**
- A $9.99 one-time license (≈$9 net after Lemon Squeezy fees) matches that with
  **12 sales. Total. Ever.**

Ads monetize at scale (tens of thousands of DAU minimum). Niche single-game tools top out
at hundreds-to-low-thousands of users — direct payment is worth 10–50× more per user.

## The UX problem

Ads in an overlay that floats over someone's game during combat are maximally intrusive.
The audience (competitive gamers) is exactly the cohort most hostile to it.

## Ad-flavored options that DO fit

1. **Affiliate links** — adjacent products the audience already buys (game VPNs like ExitLag,
   key shops). ~$1–5 per signup, no trackers, feels native. Tasteful single placement.
2. **Direct sponsor slot** — one small banner sold directly to a niche fansite/content site
   ($20–50/mo realistic). It's a relationship, not a network.
3. **Hybrid** — free/trial tier shows a small affiliate strip; paid removes it.
   "No ads" becomes one more reason to buy.

## When ads ARE the right answer

- Hundreds of thousands+ of free users (mobile apps, high-traffic websites)
- Content products where the content itself monetizes attention
- Never for: paid-adjacent utilities, security-sensitive tools, small-DAU niche software

## The general principle

Monetization model must match user-count reality:
| Users | Best model |
|---|---|
| 100s–1,000s | One-time license / direct payment |
| 1,000s–10,000s | Freemium + license, affiliates |
| 100,000s+ | Ads become viable |
| Any, immediately | Contract/freelance work (only guaranteed lane) |
