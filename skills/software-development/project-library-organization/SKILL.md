---
name: project-library-organization
description: Organize synth's ~/Projects library into category folders — moving repos between status folders, creating topical collections (e.g. faith/), and verifying ambiguous projects before categorizing.
---

# Project Library Organization

## Layout

~/Projects is sorted into top-level category folders:

- `active/` — currently developed
- `backburner/` — parked but alive
- `archived/` — shelved
- `finished/` — shipped/done
- `forks/` — external forks
- `faith/` — ALL faith-oriented projects regardless of dev status (games, apps, everything). Created 2026-07-23; topical collections like this override status folders for their domain.

## Workflow

1. List all category folders first (`ls ~/Projects/*/`) — a previous session may have partially done the work. Check before creating anything.
2. When the user says "continue where we left off", session_search may miss it if the prior session ran in OpenClaw (different session DB) — go straight to the filesystem to reconstruct state.
3. Find candidates: name-keyword grep across all category folders.
4. VERIFY every candidate (see below) before moving.
5. Move with plain `mv` — same filesystem, instant, and `.git` + remote tracking survive untouched. Verify after with `git -C <dir> status -sb`.
6. Re-scan README contents (not just names) for stragglers before declaring done.
7. Regenerate `~/Projects/INDEX.md` after any structural change so the ledger stays current.

## Pitfall: name-grep false positives

Project names lie. ALWAYS read the README head (and grep with context) before categorizing:

- `open_ascension` → WoW "Project Ascension" companion, NOT faith
- `Open-Lore` → "world bible" = worldbuilding term, NOT faith
- `forge`/`forge-hub` → list "scripture" as one managed domain among many, NOT faith projects
- Identity/meta repos (synthclaw-identity) mention faith as user context, NOT faith projects

Faith keywords that matter: bible, church, praise, worship, scripture, gospel, psalm, hymn, prayer, devotional — but only when the README confirms the project's PURPOSE is faith-oriented, not when the word appears incidentally.

## References

- `references/faith-folder-setup.md` — the 2026-07-23 faith/ folder completion: roster, and the full rejection pass showing why README verification matters.
- `references/readme-polish-standard.md` — badge minimums, build/run section standards, and hard rules for doc-only batch polish across many repos.

## Reporting

Report what was already there, what you moved, what you rejected and why (one line each). Users organizing a library want the rejections visible — it proves the sweep was real.

## Batch polish: rate-limit-safe execution

When polishing many repos in parallel via subagents:
- Prefer 3-4 concurrent subagent batches instead of one giant batch; smaller batches reduce the chance of total rate-limit failure.
- ALWAYS verify post-batch by inspecting `git -C <repo> log --oneline -1` and `git status --short`. Delegation summaries can report partial success after 429s.
- Docs-only boundary: docs, README, CONTRIBUTING, LICENSE. Do NOT push generated/local artifacts (`.gradle/`, `.spv`, build outputs), even if they appear dirty.
