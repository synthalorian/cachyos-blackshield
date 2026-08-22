# Bulk README Polish — Pitfalls

Observed failure modes from multi-repo README polish sessions. Read before batching.

## Delegation claiming success without pushing

A completed delegation can still leave changes only in local commits while claiming "pushed." Symptoms:
- Remote branch shows older commit than local.
- Git status shows clean but `git log --oneline -1` differs from claimed output.
- Often caused by archive-readonly GitHub repos returning 403, auth tokens missing `delete_repo` or `repo` write scopes, or push just flat-out not being run.

**Mitigation:** always verify with `git -C "$repo" log --oneline -1` after any claimed batch. Only report counts you verified yourself.

## Archive-readonly GitHub repos

Repos that are archived on GitHub reject pushes with HTTP 403. Don't try to force-push polish commits to archived repos. Options:
- Ask user whether to unarchive and polish, or leave alone.
- If the repo is obsolete, delete it via GitHub settings or `gh repo delete` with `delete_repo` scope.

## `gh auth refresh` requires browser approval

`gh auth refresh -h github.com -s delete_repo` returns a one-time device code and spawns a browser flow. It's not headless. Plan for that if you actually need it; don't recurse retries without telling the user.

## 429 rate limits from delegate_task

High-frequency parallel `delegate_task` calls can exhaust the API key rate limit. The symptom is HTTP 429 buried in the delegation transcript. The correct behavior is immediate manual fallback, not another retry wave.

## AGENTS.md policy repos

Repos with root `AGENTS.md` may impose review requirements for doc changes. If it blocks bulk doc edits, mark the repo as manual-review only and move on.

## User-repo vs upstream confusion

Some repos under `~/Projects/active/` are clones or mirrors of upstream projects (e.g., `openclaw-upstream`). Do not dress up upstream mirrors as if they were the user's product repos. Confirm ownership before committing cosmetic changes.

## Manifest drift

When adding/removing repos from `~/Projects`, also update any manifest files that hardcode paths, especially:
- `cachyos-blackshield/manifest/projects.tsv`
- Any install/bootstrap scripts that clone by name

## User override: delete repos on request

If the user asks to delete repos, push through once `gh` has the right scopes, or fall back to manual deletion if `gh` can't obtain `delete_repo`. After deletion, purge local copies and clean manifests.

## `.git` substring inside repo names breaks URL matching

`synthalorian.github.io` contains `.git` as a substring (`.github`). Any sanity check like `url.replace(".git","")` mangles the repo name, and naive `"/{name}" in url` substring checks misfire. Match on the trailing `/{name}.git` / `/{name}` at end-of-URL instead, or skip URL parsing and trust the directory→repo-name map from `gh repo list`.

## Batch script safety rails that worked (86-repo support-link run, 2026-08)

Per repo, in order: confirm origin matches the intended repo name → `git pull --ff-only` (diverged = flag for manual, never force) → skip if needle already present (idempotent re-runs) → append section → commit only the README → `git push origin "$(git rev-parse --abbrev-ref HEAD)"` → verify remote via `gh api repos/<owner>/<repo>/readme -H "Accept: application/vnd.github.raw" | grep needle`. Result: 81 pushed, 4 already-done, 3 intentional skips, 1 false failure (the `.github.io` bug above). Mid-batch user edits arrive — stay idempotent so a re-run is always safe.