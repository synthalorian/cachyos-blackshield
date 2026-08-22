---
name: project-readme-polish
description: "Batch README polish across repos. One sentence trigger."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Documentation, Polish, Batch, README]
    related_skills: [github-repo-management, github-auth]
---

# Project README Polish

Batch-improve READMEs across many repos in one session. Goal: every notable repo gets license/status/engine badges + a build/run section.

## Trigger

- User says "polish READMEs across repos", "batch polish", "README polish pass", "push all repos"
- Resume/handoff script targets README/docs polish

## Repo Discovery

Local clones live in category subfolders, NOT flat — a maxdepth-2 find misses everything:

```bash
find ~/Projects -mindepth 3 -maxdepth 3 -name .git -type d 2>/dev/null \
  | grep -v -e '_deps' -e '/libs/' | sed 's|/\.git||' | sort
```

Categories: `active/`, `archived/`, `faith/`, `forks/` (forks are usually NOT targets — confirm ownership).

Cross-reference with GitHub truth — local layout drifts from remote state:

```bash
gh repo list --visibility public --limit 100 \
  --json name,defaultBranchRef,isArchived,isFork
```

Skip up front: `isArchived=true` (GitHub rejects pushes with 403) and `isFork=true` (not the user's project). `gh repo clone` any public repo missing a local copy into the matching category folder.

For each repo, collect: name, branch, badge count, README/LICENSE/CONTRIBUTING existence.

## Badge Taxonomy

Add missing shields badges at README top:
- **License** — from LICENSE file: MIT → `license-MIT-green`, GPL-3.0 → `GPL_3.0-blue`, Apache-2.0 → `Apache_2.0-blue`, private → `PRIVATE-red`
- **Status** — `status-active-brightgreen` for tooling, `status-prototype-yellow` for games
- **Engine/platform** — only if not obvious
- **Contributing** — only if CONTRIBUTING.md exists and no contributing badge already
- **Meta** — for personal sites / GitHub Pages repos, still badge them; do NOT delete silently unless the user explicitly says so

Prefer Shields URLs with repo as link target.

## Build/Run Section

Ensure README has at least one of these with a fenced code block: `## Build`, `## Run`, `## Usage`, `## Install`.

Rules by type:
- Unity: keep existing `File -> Build Settings` notes, add section if missing
- Rust/Odin/Sonic Pi: add `make run` or equivalent
- Flutter: add `flutter run` / `flutter build apk` if missing
- Config/tooling: add one-liner install/restore command
- Games (VoidEngine, etc.): add `make run-<example>` and `make test`

## Support/Donation Sections

When asked to add support links across repos, use this canonical block (appended at README bottom — the conventional fitting place):

```markdown
---

## ☕ Support the Developer

If this project saved you time, solved a problem, or just made your day a little more neon, you can fuel the next one:

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/synthalorian)
```

Commit message: `docs: add Buy Me a Coffee support section to README` + `Made by synth with synthclaw` trailer.

**User override (2026-08): NEVER add support/donation links to `synthalorian.github.io`** — the portfolio site README stays clean. User had it removed after a batch run.

## Commit/Push Pattern

**Never hardcode `main`.** Resolve branch dynamically:
```bash
git -C "$repo" rev-parse --abbrev-ref HEAD
git -C "$repo" add README.md
git -C "$repo" commit -m "docs: polish README badges + build/run section"
git -C "$repo" push origin "$branch"
```

## Parallel Execution

### Identical mechanical edits: script beats delegation
When the change is byte-identical across repos (e.g., appending the same support/donation section to 80+ READMEs), skip subagents entirely. One script doing `pull --ff-only → check absent → append → commit → push` per repo is faster, deterministic, and trivially verifiable. Run in background with notify_on_complete; ~86 repos finishes in minutes. Delegation is for repos needing per-repo judgment.

### 3-subagent batches (per-repo judgment calls)
- Split repos into groups of 5
- Each subagent handles exactly one group
- Strict scope: `README.md`, `CONTRIBUTING.md`, docs only — no `src/`, `lib/`, assets
- Provide exact commit message string

### Rate-Limit Fallback
If `delegate_task` returns HTTP 429, switch to manual immediately:
```bash
for d in ~/Projects/...; do
  # patch README, commit, push
done
```
Do NOT keep retrying delegation after a 429 — it consumes turns with no progress.

### Trust-but-Verify After Delegation
Some delegation results land as “completed” but only committed locally because the push was blocked, rolled back, or never issued. After each batch, verify the actual remote state:

```bash
for d in ~/Projects/...; do
  git -C "$d" log --oneline -1
  git -C "$d" status --short
  git -C "$d" rev-parse --abbrev-ref HEAD
done
```

If a repo is dirty or local-only, claim only the verified pushes, not the delegation’s claimed count.

## Scoped-Policy Repos

Repos containing `AGENTS.md` may restrict doc changes. Examples:
- `openclaw-upstream/AGENTS.md` mandates codebase review before doc changes
- `openclaw-workspace/AGENTS.md` is identity-critical

**Rule:** If `AGENTS.md` exists, read it first. If it requires exhaustive review for doc changes, skip that repo in bulk mode and note it for manual review.

## Skippable Artifacts

Do NOT bulk-commit:
- `.gradle/` caches, `node_modules/`, `target/`, `build/`
- Generated `.spv`, `.o`, `.pyc`
- IDE directories (`.idea/`, `.vscode/`)

Commit only README/docs.

## Verification After Batch

Local checks are not enough — verify the REMOTE content directly:

```bash
for r in $(gh repo list --visibility public --limit 100 --json name,isArchived,isFork \
    --jq '.[] | select(.isArchived==false and .isFork==false) | .name'); do
  gh api "repos/synthalorian/$r/readme" -H "Accept: application/vnd.github.raw" 2>/dev/null \
    | grep -q "NEEDLE" || echo "MISSING $r"
done
```

Badge-count sweep (local):

```bash
find ~/Projects -mindepth 3 -maxdepth 3 -name .git -type d 2>/dev/null \
  | grep -v -e '_deps' -e '/libs/' \
  | while read d; do \
      repo="${d%/.git}"; \
      [ -f "$repo/README.md" ] || continue; \
      badges=$(grep -c "img.shields.io" "$repo/README.md" 2>/dev/null || echo 0); \
      echo "$(basename $repo): $badges"; \
    done
```

Target: 0 repos with README and 0 badges.

## References

- `references/bulk-readme-ref.md` — badge URL patterns and per-engine/ecosystem conventions
- `references/bulk-readme-pitfalls.md` — rate limits, scoped AGENTS.md pitfalls, repeated task failure modes, repo deletion and manifest drift
