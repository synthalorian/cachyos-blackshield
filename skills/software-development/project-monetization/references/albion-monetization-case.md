# Albion Monetization Case (Aug 2026)

Session-specific detail behind the `project-monetization` skill. The user's monetization direction pivoted 3× in one conversation — recap this before re-planning.

## The two repos

**AlbionOnline-Companion** (`~/Projects/active/AlbionOnline-Companion`)
- Fork/port of Triky313's AlbionOnline-StatisticsAnalysisTool → **GPLv3** (LICENSE confirmed in-repo)
- Already a trimmed Avalonia port: **~13.5K C# + 1.8K AXAML ≈ 15K LOC** (measured 2026-08-11; upstream is far larger)
- Breakdown: main app ~10.2K C#; Protocol18 ~1K; PhotonPackageParser ~0.4K; Network ~0.3K; Extractor dir exists but 0 LOC outside bin/obj
- Contains synth's own translator code: `Common/TranslationService.cs`, `ViewModels/TranslatorViewModel.cs`, `Views/TranslatorView.axaml`, chat handling in `Network/Handlers/ChatEventHandler.cs` — translation via free Google path (`sl=auto` detection, compose box)
- Stays free + public as the community-goodwill funnel

**AlbionOnline-Translator** (`~/Projects/active/AlbionOnline-Translator`)
- synth's OWN app: Tauri 2 + Rust + Svelte, package name `albion-translator`, not a fork of anything
- Latest commit 2026-08-10: "feat: LIVE CHAT DETECTION WORKING!" — momentum asset
- **Designated paid product** ($9.99 one-time discussed), repo to go private when paywall lands
- Translator feature to be stripped from the free Companion so the free app can't undercut it

## ⚠️ Open blocker: albion-network-lib has NO license
- Dep in `src-tauri/Cargo.toml`: `albion-network-lib = { git = "https://github.com/beemerwt/albion-network-lib.git", version = "0.1.0" }`
- GitHub API check 2026-08-11: `license: None`, 0 stars — "Rust library for Albion network handling"
- No LICENSE file = all rights reserved = **cannot ship commercially as-is**
- Fix path: open an issue/PR asking beemerwt to add MIT or Apache-2.0 (solo devs usually agree fast); otherwise re-implement the needed decode layer
- This library is also the legal escape hatch: it encapsulates the hard reverse-engineered protocol IP, so synth's app on top is 100% his without a clean-room rewrite

## Decision history (why the final plan is what it is)
1. User: make Translator paid, take private, strip translator from Companion → I began read-only recon → **user cancelled**
2. User pivot: freemium the stats fork instead, translator as flagship locked feature → I flagged GPLv3 realities (toll booth not vault)
3. User: "I want it 100% mine — how much work to rewrite?" → full rewrite estimated 4–8 wks AI-assisted (15K LOC) + derivative-work trap (retyped GPL logic is still derivative; agent reads the GPL code daily so can't clean-room)
4. **Agreed direction**: Translator app = the product (already 100% his), build on albion-network-lib once licensed, strip translator from free Companion, Lemon Squeezy license keys, $9.99, grow stats into his own app strangler-style later. Companion stays free/public GPL.

## Next actions queued (not yet started)
- Draft GitHub issue/PR to beemerwt re: license for albion-network-lib
- `LicenseService` + `FeatureGate` skeleton in the Tauri app (validate key vs Lemon Squeezy API on activation, cache signed token, offline grace; locked tabs show upgrade panel)
- Strip translator from AlbionOnline-Companion (only after paid app is ready to replace it — don't create a gap)
- Check SBI third-party tool policy before charging (stat tools tolerated; verify)
