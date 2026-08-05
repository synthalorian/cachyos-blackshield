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

```bash
find ~/Projects -mindepth 2 -maxdepth 2 -name .git -type d 2>/dev/null \
  | sed 's|/\.git||' | sort
```

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

## Commit/Push Pattern

**Never hardcode `main`.** Resolve branch dynamically:
```bash
git -C "$repo" rev-parse --abbrev-ref HEAD
git -C "$repo" add README.md
git -C "$repo" commit -m "docs: polish README badges + build/run section"
git -C "$repo" push origin "$branch"
```

## Parallel Execution

### Preferred: 3-subagent batches
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

```bash
find ~/Projects -mindepth 2 -maxdepth 2 -name .git -type d 2>/dev/null \
  | while read d; do \
      [ -f "$d/README.md" ] || continue; \
      badges=$(grep -c "img.shields.io" "$d/README.md" 2>/dev/null || echo 0); \
      echo "$(basename $d): $badges"; \
    done
```

Target: 0 repos with README and 0 badges.

## References

- `references/bulk-readme-ref.md` — badge URL patterns and per-engine/ecosystem conventions
- `references/bulk-readme-pitfalls.md` — rate limits, scoped AGENTS.md pitfalls, repeated task failure modes, repo deletion and manifest drift
