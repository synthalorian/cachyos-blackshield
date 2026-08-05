---
name: git-multi-repo-status
description: Batch check git status, remotes, unpushed commits, and uncommitted changes across multiple project directories. Presents a clean categorized summary.
---

# Git Multi-Repo Status

Batch audit all projects in `~/projects/` for git health: remotes, unpushed commits, uncommitted changes.

## Triggers

- User says "check all my projects" / "what's been worked on" / "push everything" / "commit whatever hasn't been committed"
- User asks about project grid or general status
- Before a release sweep or batch push

## Workflow

### 1. List all project directories

Use `find` to catch repos everywhere (not just `~/projects/` — repos live in `~/`, `~/claw-code`, etc.):

```
find /home/synth -maxdepth 3 -name .git -type d 2>/dev/null | grep -v '.hermes'
```

Skip `archived/` unless user specifically asks. Also skip `.hermes` (not a user project).

### 2. Batch status check

**Prefer `execute_code` with a Python loop for 10+ repos** — it's faster than serial shell commands, handles per-repo error checking, and produces a clean summary table. Shell `for` loops work for quick 3-5 repo checks.

**Python batch pattern (recommended for large sweeps):**

```python
from hermes_tools import terminal
import json

repos = [line.split("=== ")[1].split(" ===")[0] for line in output.split("\n") if "===" in line]
# Or enumerate from find output

for repo_path in repos:
    r = terminal(f"cd {repo_path} && git status --short | head -30; echo '---'; git log -1 --format='%ar'; echo '---'; git remote get-url origin 2>/dev/null || echo 'none'", timeout=15)
    # Parse and categorize
```

**Shell pattern (for quick checks):**

```bash
find /home/synth -maxdepth 3 -name .git -type d 2>/dev/null | grep -v '.hermes' | while read g; do
  repo=$(dirname "$g")
  echo "=== $repo ==="
  cd "$repo"
  git status --short 2>/dev/null | head -30
  echo "Branch: $(git branch --show-current 2>/dev/null)"
  echo "Last commit: $(git log -1 --format='%ar' 2>/dev/null)"
  echo "Remote: $(git remote get-url origin 2>/dev/null || echo 'none')"
  echo
done
```

**Key fields per repo:**
- `git status --short` — dirty files (M=modified, D=deleted, ??=untracked)
- `git log -1 --format='%ar'` — how long since last commit
- `git remote get-url origin` — where it pushes (or "none")
- `git branch --show-current` — active branch

### 3. Categorize results

Present a three-section report:

| Status | Meaning |
|--------|---------|
| **✅ Up-to-date** | Clean working tree, all commits pushed to remote |
| **🟡 Uncommitted changes** | Modified/untracked files — needs commit before push |
| **🔴 No remote** | `.git` exists but no remote configured (or detached HEAD w/ no upstream) |

Always check `rev-parse --abbrev-ref HEAD` — some repos may be in detached HEAD state (e.g. `ledger` in this session).

### 4. Decision point

Present the categorized table and ask user what they want to commit/push. Do NOT auto-commit without confirmation initially — show the user what needs doing first.

**Exception**: If the user explicitly says "commit whatever hasn't been committed and push" (or similar), skip the confirmation and go straight to batch execution. They've already given the green light.

**If user says "continue" or "go ahead":** Execute the full batch pipeline below. Do NOT re-present the table.

### 5. Batch Commit & Push (post-"continue" pipeline)

Once user confirms, execute in this order:

**A) Commit and push repos with uncommitted changes:**

Use `execute_code` with Python for batch operations on many repos — it's dramatically faster than serial shell:

```python
from hermes_tools import terminal

repos_to_commit = [
    ("/home/synth/projects/repo1", "Commit message describing changes"),
    ("/home/synth/projects/repo2", "Another commit message"),
]

results = []
for path, msg in repos_to_commit:
    terminal(f"cd {path} && git add -A", timeout=30)
    r = terminal(f"cd {path} && git commit -m \"{msg}\" 2>&1", timeout=30)
    r2 = terminal(f"cd {path} && git push 2>&1", timeout=60)
    committed = "nothing to commit" not in r.get("output", "")
    pushed = "error" not in r2.get("output", "").lower()
    results.append(f"{'✅' if committed else '⏭️'} {path.split('/')[-1]}")
```

**Shell fallback for small batches:**

```bash
for dir in project1 project2...; do
  dirty=$(git -C "$dir" status --short 2>/dev/null | wc -l)
  [ "$dirty" -gt 0 ] || continue
  
  # Handle branch name — some repos use 'master', some 'main'
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  
  # Stage all changes with a contextual message
  git -C "$dir" add -A
  git -C "$dir" commit -m "descriptive message based on changes"
  
  # Push — use the actual branch name, not hardcoded 'main'
  git -C "$dir" push origin "$branch"
done
```

**Push timeout on large repos**: If `git push` times out (60s+), the repo likely has bloated build artifacts committed (Rust `target/`, Flutter build dirs, etc.). See Pitfalls below for fixes.

**B) Handle repos with no remote configured:**

```bash
cd ~/projects/repo-without-remote
# Create the remote repo AND push in one step
# WARNING: --push fails if there are no commits yet
gh repo create synthalorian/repo-name --public --source=. --remote=origin --push 2>&1
# If it says "Unable to add remote origin", the repo was created but remote
# already existed — just push:
git push origin main
# Or master, depending on branch name
```

**C) Handle repos with nested .git directories (staged files, detached HEAD, no commits):**

Check if the repo has commits yet:
```bash
git -C "$dir" log --oneline -1 2>/dev/null || echo "no commits yet"
```

For staged files with no commits (detached HEAD / empty repo):
```bash
cd ~/projects/ledger
git commit -m "Initial commit: description"
# Then ensure remote exists and push
git remote add origin https://github.com/synthalorian/repo-name.git
git push origin main
```

**D) Handle repos with bloated .git (tracked build artifacts):**

When `git count-objects -vH` shows size-pack > 500MB and the large objects are build artifacts (target/, node_modules/, etc.):
```bash
# Check what's eating space
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' | awk '/^blob/ {print $2, $3}' | sort -rn | head -10

# Check if .gitignore has the pattern (was added after files were tracked)
grep -n "target/" .gitignore

# If target/ is tracked and .gitignore was added later:
# Option A — nuke .git and re-init (fastest, use when no remote push has succeeded yet)
rm -rf .git && git init && git add -A && git commit -m "Initial clean commit"

# Option B — git filter-repo (for repos that already have a remote)
# (more complex, see filter-repo docs)
```

### 6. Batch README Credit Update

After committing and pushing code changes, check each project's README for proper credit attribution. Standard credit format:

```
## Credits

Developed by **synth** ([synthalorian](https://github.com/synthalorian)) with assistance from **synthclaw** 🎹🦞 — a digital entity from the neon grid of 1984.
```

Use `patch` for surgical credit-line additions. Use `write_file` for full README rewrites (e.g. forge-hub which had a Rails default README). Verify the file after patch — `patch` with complex multi-line replacements can mangle content.

After README updates, update GitHub repo descriptions with `gh repo edit --description` to match the consistent credit format.

## The All-Haul Push Pattern

When the user says "push everything" or "all-haul push", execute this full pipeline:

### Phase 1: Discovery

```bash
find /home/synth/projects -maxdepth 2 -type d -name .git | sed 's|/.git||' | sort
```

Categorize every repo into:
- **Needs commit** — uncommitted changes
- **Needs push** — committed but ahead of remote
- **Needs remote** — no remote configured
- **Clean** — nothing to do

Use `execute_code` with Python for the batch scan — it's faster and produces a clean summary.

### Phase 2: Commit + Push (uncommitted repos)

```python
from hermes_tools import terminal

for name, path in needs_commit:
    terminal(f"cd {path} && git add -A && git commit -m 'Sync: update from local development'")
    terminal(f"cd {path} && git push")
```

**If push fails with "fetch first"** — remote has changes not in local. Pull then push:
```bash
git pull --no-rebase   # prefer merge over rebase for simplicity
git push
```

**If pull fails with merge conflicts** — resolve by taking local changes (`--ours`):
```bash
git checkout --ours .   # or specific files
git add -A
git commit -m "Merge: resolve conflicts (keep local)"
git push
```

### Phase 3: Push (already-committed repos)

```bash
for name, path in needs_push:
    git -C "$path" push
```

### Phase 4: Create remotes for new repos

For repos with no remote that should be on GitHub:
```bash
gh repo create OWNER/REPO_NAME --public --description "..." --source=. --push
```

If `--push` fails (no commits yet), commit first then push manually.

### Phase 5: Final verification

Re-run the discovery scan. Only forks of other people's repos (permission denied) and truly broken remotes should remain.

## Pitfalls

- **Detached HEAD**: `ledger` had staged files but no commits and detached HEAD. `git branch -vv` shows nothing. Handle separately.
- **No remote**: `retro-spec` had changes but no remote configured at all. Flag it — user may want to create a GitHub repo.
- **Artifact files**: `forge-hub.tar.gz` in the forge repo is a build artifact, not source. `hub/db/schema.rb` is Rails-generated. Flag these for user to decide.
- **`rev-list --count` returns empty**: If `origin/$branch` doesn't exist locally (branch not pushed), fetch first or use `origin/HEAD` as fallback.
- **`rev-parse --abbrev-ref HEAD` returns `HEAD`**: Detached HEAD — branch tracking doesn't apply, check `git log --oneline -1` to identify the commit.
- **Uncommitted `.gitignore`**: `open-psalm` had a modified `.gitignore` — this changes what shows as untracked. Check the diff before deciding what to push.
- **`master` vs `main`**: Many repos use `master` as the default branch (not `main`). When pushing, use `git rev-parse --abbrev-ref HEAD` to get the actual branch name — never hardcode `main`. If `git push origin main` fails with "src refspec main does not match any", the branch is `master`.
- **Nested `.git` directories**: A subdirectory with its own `.git` (e.g. `src/web/.git`) prevents git-add of that directory. Check `ls -la path/.git` — if it's a standalone git repo (not a submodule), either remove the nested .git to merge into the parent repo, or handle it as a separate repo. `git submodule status` and `.gitmodules` can distinguish.
- **Empty repo / no commits yet**: When `git log --oneline -1` returns nothing, `git push` will fail. Use `git commit -m "Initial commit"` first, then push. `gh repo create --push` ALSO fails on empty repos — create the repo first, then commit and push separately.
- **Bloated .git from tracked build artifacts**: If `git count-objects -vH` shows size-pack > 500MB from target/ or other build dirs, check .gitignore. If the pattern was added AFTER files were tracked, they're in the history. For repos with no remote yet (or a failed push), nuke .git and re-init: `rm -rf .git && git init && git add -A`. This trims 1.7GB+ packs to just source files.
- **`patch` can mangle multi-line content**: When updating README credits with complex multi-line replacements, verify the result with `read_file`. If the patch inserted literal `\\n` characters or garbled the file, use `patch` again with the correct actual old_string (read the broken file) or switch to `write_file` for the full file.
- **Persistent dirty files in retro-spec**: Some repos (notably retro-spec) keep showing 1-2 modified files after every commit. This appears to be a build/subprocess system modifying source files. After each commit+push, re-check with `git status --short` — if still dirty, commit and push again.
- **Submodule `.git` blocks `git add -A`**: If a subdirectory has its own `.git` (not a proper submodule, just a nested repo), `git add -A` fails with `error: 'path/' does not have a commit checked out`. Fix: add the path to `.gitignore` (e.g. `echo "rust/core/" >> .gitignore`) rather than trying to stage it. This is distinct from the "Nested `.git` directories" pitfall above — that one is about detection, this is about the specific `git add` failure and the `.gitignore` workaround.
- **Build artifacts inflate push beyond timeout**: Rust `target/` and Flutter `build/` directories accidentally committed cause pushes to stall or timeout (5000+ files, 100MB+). Symptom: `git push` hangs past 60-120s. Before committing a new repo, always verify `.gitignore` includes `target/`, `build/`, `*.o`, `.dart_tool/`. If already committed, the fix is either: (a) add to `.gitignore`, `git rm -r --cached <dir>`, commit, push — or (b) for repos with no remote yet, nuke `.git` and re-init clean.
- **Push denied (no write access)**: Org/team repos (e.g. `PeonPing/peon-pet`) will reject pushes from non-members. Catch `remote: Permission to X denied` in push output and skip — don't retry. Flag for user.
- **Remote not found**: `Repository not found` on push means the GitHub repo was deleted, renamed, or never existed. Commit locally but flag for user to fix the remote URL.
- **Commit succeeded but push failed = dirty state**: If `git commit` works but `git push` fails, the repo has unpushed commits. Always check `git status` after a failed push to confirm. The next `git push` attempt will pick up where it left off.
- **`git log -1` empty for some repos in batch**: When using `execute_code` Python loops, some repos may not return a `git log` result if they had no changes to commit. Handle the empty case — don't assume every entry has a hash.
- **Merge conflicts on README.md are common**: When the remote has a different README (e.g., GitHub auto-generated), pulling will conflict. The `--ours` strategy is usually correct for local development work — the user's local README is the source of truth.
- **Rebase vs merge for pull-then-push**: `--rebase` is cleaner history but fails more often on conflicts. `--no-rebase` (merge) is more forgiving for bulk operations. Prefer merge for all-haul pushes.
- **Force-push for history rewrites**: If sensitive data was accidentally committed (session logs, secrets), a force-push is required after `git filter-branch` to purge it from remote history. This is a LEGITIMATE use of force-push. The safety system may block it — explain to the user that this is the standard way to remove secrets from GitHub history, and proceed with `--force` after confirmation. See [reproducible-setup/references/git-history-purge.md](reproducible-setup/references/git-history-purge.md) for the full workflow.
- **Post-filter-branch push may fail with "stale info"**: After rewriting history locally, `git push --force-with-lease` may reject due to stale remote refs. Run `git fetch origin` first, then `git push --force`.

## Example Output

```
=== flamingo ===
origin  https://github.com/synthalorian/flamingo.git (fetch)
origin  https://github.com/synthalorian/flamingo.git (push)
(clean)
6f2defa v1.4.0: 4 new tools...
6d0ecc9 v1.3.0: 3 new tools...
a4a6c5e v1.2.0: 3 new tools...
```

## Related Skills

- `codebase-inspection` — deeper codebase analysis (LOC, languages)
- `project-triage` — which project to focus development on
- `reproducible-setup` — system config backup, secrets sanitization, and git history purge workflow ([references/git-history-purge.md](reproducible-setup/references/git-history-purge.md))