# Purging Sensitive Data from Git History

When secrets, session files, or other sensitive data have been committed to git (even if later removed from the working tree), they remain in the repository history. A standard `git rm` and commit does NOT remove them from past commits. Anyone with a clone or fork still has the data.

## When This Applies

- API keys, tokens, or passwords committed in config files or scripts
- AI session logs (`.claw/`, `.claude/`, agent conversation history) accidentally committed
- Large binary files that should never have been tracked
- `.env` files or `secrets/` directories committed before `.gitignore` was added
- Test keys or identity files committed in `tmp/` or test directories

## Pre-Flight: Scan Before You Purge

Before rewriting history, know exactly what you're looking for. Use the secret scanner:

```bash
python3 ~/.hermes/skills/devops/reproducible-setup/scripts/scan-repo-secrets.py /path/to/repo
```

Or scan all your public GitHub repos:

```bash
python3 ~/.hermes/skills/devops/reproducible-setup/scripts/scan-repo-secrets.py --github-owner synthalorian --limit 100
```

This produces a JSON report with file paths, line numbers, and the actual matched strings. Use the matched strings to build your `--replace-text` expressions.

## Method 1: git-filter-repo (Recommended)

`git-filter-repo` is the modern, fast, safe replacement for `git filter-branch`. Install it if missing:

```bash
pip install git-filter-repo --break-system-packages
```

### 1a. Remove a file or directory from ALL history

```bash
cd /path/to/repo

# Remove a single file
git filter-repo --path path/to/secret.file --invert-paths --force

# Remove a directory (e.g. test artifacts with keys)
git filter-repo --path tmp/ReticulumLink.CryptoTest/ --invert-paths --force

# Remove multiple paths
git filter-repo --path secrets/ --path .env.local --path tmp/ --invert-paths --force
```

**After filter-repo runs:**
- The `origin` remote is automatically removed (safety feature)
- All branches and tags are rewritten in-place
- The working tree is updated

Re-add the remote and force-push:

```bash
git remote add origin https://github.com/OWNER/REPO.git
git push --force --all origin
git push --force --tags origin
```

### 1b. Replace a secret string across ALL history

For API keys, tokens, or passwords embedded in file contents (not just file paths):

```bash
# Create a replacements file
cat > /tmp/replacements.txt <<'EOF'
ACTUAL_SECRET_KEY_1==>YOUR_PLACEHOLDER_HERE
ACTUAL_SECRET_KEY_2==>YOUR_PLACEHOLDER_HERE
EOF

# Run replacement across all commits
git filter-repo --replace-text /tmp/replacements.txt --force
```

**Critical:** The replacements file uses `==>` as the delimiter (literal string, not regex). The left side is the exact string to find; the right side is the replacement.

**For multi-line secrets or complex patterns**, use `--replace-text` with a callback script (see `git-filter-repo` docs for `--replace-text` with callbacks).

**After replacement:**
```bash
git remote add origin https://github.com/OWNER/REPO.git
git push --force --all origin
git push --force --tags origin
```

### 1c. Verify the purge

```bash
# Should return nothing (exit code 1 = no matches = success)
git log --all --full-history --name-only -- path/to/purged/file

# For string replacements, grep the fresh clone
git clone --depth 1 https://github.com/OWNER/REPO.git /tmp/verify
 grep -r "ACTUAL_SECRET_KEY" /tmp/verify/ || echo "CLEAN"
```

## Method 2: git filter-branch (Fallback)

Use only if `git-filter-repo` is unavailable. Slower, more error-prone, but ships with git-core.

```bash
# Stash uncommitted changes
git stash

# Remove a path from all commits
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch \
  --force \
  --index-filter "git rm -rf --cached --ignore-unmatch <PATH>" \
  --prune-empty \
  --tag-name-filter cat \
  -- --all

# Clean up backup refs
git update-ref -d refs/original/refs/heads/main
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Verify
git log --all --full-history --name-only -- <PATH>  # should return nothing

# Force-push
git push --force --all
git push --force --tags
```

## Post-Purge Checklist

1. **Rotate the exposed secret immediately** — History rewriting does NOT invalidate the secret. Anyone who cloned/forked before the purge still has it. Go to the provider and revoke/regenerate.
2. **Check for forks** — `gh repo fork-list OWNER/REPO` or check GitHub web UI. Forks retain the old history unless their owners update.
3. **Add to `.gitignore`** — Prevent recurrence:
   ```bash
   echo "tmp/" >> .gitignore
   echo ".env*" >> .gitignore
   echo "*.key" >> .gitignore
   git add .gitignore
   git commit -m "security: add sensitive paths to .gitignore"
   git push
   ```
4. **Install pre-commit hooks** — `gitleaks` or `git-secrets` to catch future leaks:
   ```bash
   # gitleaks
   gitleaks protect --staged --verbose

   # git-secrets
   git secrets --install
   git secrets --register-aws
   ```

## Common Pitfalls

| Pitfall | Cause | Fix |
|---------|-------|-----|
| Secret still in history after filter-repo | String didn't match exactly (encoding, whitespace) | Verify with `git show COMMIT:file` and `od -c` or `cut -d'"' -f2` to get the exact bytes |
| `origin` remote missing after filter-repo | filter-repo removes it as a safety feature | `git remote add origin URL` |
| Force-push rejected | Remote has newer refs | `git fetch origin` first, then `git push --force` |
| `.gitignore` not committed | Forgot post-purge step | Commit `.gitignore` separately after force-push |
| Forks still have the secret | Forks are independent repos | Contact fork owners or accept residual risk |
| Filter-repo not found | Not installed | `pip install git-filter-repo --break-system-packages` |
| Large repo, filter-repo slow | Repo has many commits/large files | Use `--partial` or increase `--replace-text` batch size |

## What NOT To Do

- ❌ `git rm -r --cached secrets/ && git commit` — Only removes from latest commit; history still contains the files
- ❌ `git revert` — Creates a new commit that undoes changes, but the original commit with secrets still exists
- ❌ `git reset --hard HEAD~1` — Only rewinds one commit; doesn't purge from deeper history
- ❌ Force-push without verifying locally — Always confirm clean before pushing
- ❌ Skip secret rotation — History rewriting is NOT enough; the secret is still valid

## See Also

- `scripts/scan-repo-secrets.py` in this skill — Automated secret scanner for local repos or GitHub orgs
- `github-repo-management` skill — For managing remotes, releases, and repo settings
