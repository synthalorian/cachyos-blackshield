# Monetizing GPL Forks — Legal Landscape

Session case study (2026-08): synth's AlbionOnline-Companion, a GPLv3 fork of Triky313's
Albion Online StatisticsAnalysisTool (~15K LOC Avalonia port).

## What GPL allows and forbids

- **Selling is explicitly allowed.** GPLv3 preamble: "free as in freedom, not price."
  You can charge any amount for binaries.
- **Source obligation**: anyone you distribute binaries to is entitled to corresponding source.
  A private repo + source-on-request to buyers IS compliant. You cannot use a private repo
  to withhold source from someone who bought/received the binary.
- **Redistribution is the killer**: any recipient may legally share your paid app — and may
  legally publish a fork with your feature-lock code deleted. You cannot prevent this with license terms.
- **Practical posture**: client-side lock = toll booth, not vault. Price below the hassle
  threshold ($9.99) and accept the leakage; ~98% of users of a niche game tool can't compile
  an Avalonia/Tauri app anyway.

## The clean-room trap

"I'll just rewrite it so it's 100% mine" — usually wrong:
- A rewrite where the same person (or same AI agent) reads GPL code and reimplements its logic
  copies **structure, sequence, and organization** → still a derivative work. Retyping ≠ clean.
- True clean-room: one party writes a spec from the GPL code, a DIFFERENT party implements
  from the spec only. An agent that swims in the fork's code every session cannot be the
  clean implementer.
- Full rewrite costs are dominated by embedded reverse-engineered KNOWLEDGE (protocol offsets,
  event codes, edge cases), not LOC. 15K LOC with dense protocol code ≈ 4–8 weeks AI-assisted
  to rough parity, months to bug-for-bug parity — while revenue waits.

## The better escape hatch: permissively-licensed components

The legally clean path to ownership is building on libraries that carry permissive licenses,
not re-deriving the knowledge yourself:
1. Identify the hard/knowledge-dense part (e.g., protocol decoding) and find a standalone
   MIT/Apache library for it.
2. Build YOUR app on top — every line of your app is yours; the lib's license permits commercial use.
3. Grow features incrementally (strangler fig) instead of big-bang rewrite.

## Dependency license audit (before ANY commercial ship)

- Check every direct dependency for a LICENSE file. GitHub API shortcut:
  `curl https://api.github.com/repos/<owner>/<repo>` → `.license.spdx_id`
- **No license = all rights reserved**, even if the repo is public and "obviously meant to be used."
  Do not ship commercially on it.
- Fix paths: open a polite issue/PR asking for MIT or Apache-2.0 (works most of the time;
  offer to PR the LICENSE file yourself), or replace the component.
- GPL dependencies transitively contaminate: one GPL lib in your dep tree makes YOUR app GPL.

## Community/politics notes

- Paywalling features in a fork of a beloved free tool invites backlash. Keep everything the
  upstream tool does FREE in your fork; only charge for features YOU built from scratch —
  ideally in a separate product so the fork stays untouched goodwill.
- Game-tool ecosystem: verify the game publisher's third-party tool policy before charging
  (packet-sniffing stats tools and translation overlays are generally tolerated in Albion's
  ecosystem; silver/RMT-adjacent anything is not).
