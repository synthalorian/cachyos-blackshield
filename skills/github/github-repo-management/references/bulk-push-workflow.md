# Bulk Push Workflow — All-Haul Pattern

Reference for pushing all local repos to GitHub in one session. Derived from 2026-05-30 session pushing 64 repos.

## The Five-Phase Pipeline

### Phase 1: Discovery

```bash
find /home/synth/projects -maxdepth 2 -type d -name .git | sed 's|/.git||' | sort
```

Categorize into:
- **Needs commit** — `git status --porcelain` returns non-empty
- **Needs push** — `git rev-list --count --left-right HEAD...@{u}` shows ahead
- **Needs remote** — `git remote -v` returns empty
- **Clean** — none of the above

Use `execute_code` with Python for batch scanning across 10+ repos.

### Phase 2: Commit + Push

For repos with uncommitted changes:
```bash
cd $REPO && git add -A && git commit -m "Sync: update from local development" && git push
```

### Phase 3: Handle "Fetch First" Failures

When push fails with "fetch first":
```bash
git pull --no-rebase   # prefer merge for bulk ops
git push
```

If pull has merge conflicts (common on README.md):
```bash
git checkout --ours .   # keep local changes
git add -A
git commit -m "Merge: resolve conflicts (keep local)"
git push
```

For specific files only:
```bash
git checkout --ours README.md
git add README.md
git commit -m "Merge: resolve README conflict"
```

### Phase 4: Push Already-Committed Repos

```bash
for repo in gridos janus reticulum-beacon unity-mcp; do
  git -C /home/synth/projects/$repo push
done
```

### Phase 5: Create New Remotes

For repos with no remote:
```bash
gh repo create OWNER/REPO_NAME --public --description "..." --source=. --push
```

If `--push` fails (no commits yet):
```bash
git commit -m "Initial commit"
git remote add origin https://github.com/OWNER/REPO_NAME.git
git push -u origin main
```

## Common Failure Modes

| Error | Cause | Fix |
|-------|-------|-----|
| "fetch first" | Remote has newer commits | `git pull --no-rebase` then push |
| "Permission denied" | Fork of someone else's repo | Skip — can't push to upstream |
| "Repository not found" | Remote deleted/renamed | Commit locally, flag for user |
| "no tracking information" | Branch has no upstream | `git branch --set-upstream-to=origin/main main` |
| "Unable to add remote" | Remote already exists | Just `git push` directly |
| Merge conflicts in README | GitHub auto-generated README vs local | `git checkout --ours README.md` |
| Detached HEAD | No branch checked out | `git checkout -b main` or `git branch main` then push |

## Verification

After all phases, re-run discovery. Expected state:
- All owned repos: clean
- Forks: may show ahead (expected, can't push)
- Any remaining dirty repos: investigate individually
