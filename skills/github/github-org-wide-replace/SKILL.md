---
name: github-org-wide-replace
description: Search and replace strings across all repositories in a GitHub organization or user account. Handles cloning, grep-based discovery, batch file processing, commit/push orchestration, and verification.
version: 1.0.0
author: synthclaw
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Bulk, Search-and-Replace, Multi-Repo, Organization]
    related_skills: [github-repo-management, git-multi-repo-status]
---

# GitHub Org-Wide Search and Replace

Replace strings, names, or emojis across every repository owned by a GitHub user or organization. This is a bulk operation — treat it with care.

## Triggers

- User says "replace X with Y across all my repos" / "scour all repos for Z" / "rebrand everything"
- User wants to update credit lines, package names, bundle identifiers, or branding org-wide
- User wants to rename a project codename or identity across their GitHub presence

## Workflow

### 1. List all repos

```bash
gh repo list OWNER --limit 200 --json name,owner,description,url \
  | jq -r '.[] | "\(.owner.login)/\(.name)"'
```

Use `--limit 200` (max for `gh repo list`). For orgs with more repos, paginate or use the REST API.

### 2. Clone repos to a temp workspace

```bash
mkdir -p /tmp/org-replace && cd /tmp/org-replace
for repo in repo1 repo2 repo3; do
  gh repo clone OWNER/$repo $repo 2>/dev/null || echo "skip $repo"
done
```

Clone in batches of 10-15 to avoid overwhelming the network. For 50+ repos, use a background loop or `xargs -P`.

### 3. Search for targets locally (NOT via GitHub code search)

**GitHub code search (`gh search code`) is unreliable for:**
- Emoji searches (🦞 returns empty or partial results)
- Rate-limited org-wide queries
- Private repos without explicit scope

**Always grep locally after cloning:**

```bash
for repo in */; do
  echo "=== $repo ==="
  grep -rlI "TARGET_STRING\|TARGET_EMOJI" "$repo" 2>/dev/null \
    | grep -v ".git/" | head -20
done
```

Use `grep -rlI` (recursive, list filenames, ignore binary). The `-I` flag skips binary files automatically.

### 4. Process files with a SKIP-LIST (not an allow-list)

**PITFALL — Extension-based allow-lists miss files:**

Filtering by `text_extensions = {".md", ".dart", ".sh", ...}` will miss:
- `.gradle.kts` (Kotlin Gradle scripts)
- `.rc` (Windows resource files)
- `.xcconfig` (Xcode config)
- `.desktop` (Linux desktop entries)
- Extensionless shell scripts (`Makefile`, `Dockerfile`, `install`)
- Files in `dist/`, `build/`, or other non-standard paths

**Correct approach:** Use a SKIP-LIST of patterns to exclude, then process EVERYTHING else:

```python
SKIP_PATTERNS = [
    ".git/",
    ".gitignore",        # Don't modify git's own config
    ".gitattributes",
    # Build artifacts and package manager caches
    "node_modules/", "build/", "dist/", ".dart_tool/", "target/",
    "package-lock.json", "yarn.lock", "pubspec.lock", "Cargo.lock",
    # Binary and media files
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".svg",
    ".mp3", ".wav", ".ogg", ".flac", ".mp4", ".webm", ".mov",
    ".pdf", ".zip", ".tar", ".gz", ".bz2", ".7z", ".rar",
    ".exe", ".dll", ".so", ".dylib", ".class", ".jar",
    # 3D and game assets
    ".uasset", ".umap", ".fbx", ".obj", ".blend", ".gltf", ".glb",
    # Fonts
    ".ttf", ".otf", ".woff", ".woff2",
    # Databases
    ".db", ".sqlite", ".sqlite3",
    # Historical / runtime artifacts (intentionally preserved)
    ".jsonl",            # Session transcripts
    "/claude/projects/", # Claude Code session logs
    "/claude/tasks/",
    "/.claw/sessions/",  # OpenClaw session transcripts
    "/hermes/migration/", # Hermes migration archives
    "/openclaw/cron/runs/", # Cron run logs
]

def should_process(filepath):
    for pat in SKIP_PATTERNS:
        if pat in filepath:
            return False
    return True
```

Then walk the tree and process every file that passes the skip-list:

```python
import os, re

for root, dirs, files in os.walk(repo_path):
    dirs[:] = [d for d in dirs if d != '.git']
    for filename in files:
        filepath = os.path.join(root, filename)
        if not should_process(filepath):
            continue
        # Process the file
```

### 5. Perform replacements

**Case-sensitive name replacement (three cases):**

```python
content = re.sub(r'synthclaw', 'synthclaw', content)      # lowercase
content = re.sub(r'Synthclaw', 'Synthclaw', content)      # Title case
content = re.sub(r'SYNTHCLAW', 'SYNTHCLAW', content)      # UPPERCASE
```

**Emoji replacement:**

```python
content = content.replace('🦞', '🦞')
```

**Always read with `errors='replace'` and write as UTF-8:**

```python
with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()
# ... modify ...
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
```

### 6. Commit and push per repo

**Batch commit/push pattern:**

```bash
for repo in */; do
  cd "/tmp/org-replace/$repo"
  if git diff --quiet; then
    echo "  $repo: no changes"
    continue
  fi
  git add -A
  git commit -m "rebrand: old → new, emoji → emoji"
  git push
done
```

**For repos with many changes, push in smaller batches** to avoid timeout on large commits.

### 7. Verification sweep

After the first pass, run a second grep to catch misses:

```bash
for repo in */; do
  hits=$(grep -rlI "OLD_STRING\|OLD_EMOJI" "$repo" 2>/dev/null | grep -v ".git/" | wc -l)
  if [ "$hits" -gt 0 ]; then
    echo "=== $repo ($hits hits) ==="
    grep -rlI "OLD_STRING\|OLD_EMOJI" "$repo" 2>/dev/null | grep -v ".git/" | head -10
  fi
done
```

Fix any remaining hits with follow-up commits. Do NOT force-push amended commits — this triggers safety blocks. Use normal follow-up commits:

```bash
git add -A
git commit -m "rebrand: fix missed files (gradle, dist scripts)"
git push
```

## Pitfalls

### 0. If the damage came from a known commit, REVERT it — don't search-replace

Before writing any replace script, check git history (`gh api repos/OWNER/REPO/commits`, or org-wide `gh api "search/commits?q=user:OWNER+keyword+from+message"`). If a bulk change was pushed as identifiable commits (e.g. a botched "rebrand" commit per repo), `git revert --no-edit <sha>` per repo restores EXACT originals — no heuristic collateral on paths, product names, or wordplay ("Synth Lead" → "synthalorian Lead"). Find follow-up "fix" commits the same way and revert them too (reverse-chronological order). Shallow clones need `git fetch --depth 100 origin` before reverting. If a remote "fix" commit lands mid-operation (non-fast-forward on push), `git rebase -X ours origin/<branch>` then re-run the cleanup pass.

### 0b. /tmp can be wiped mid-run — use a home-dir workspace

On some systems (observed on CachyOS), /tmp contents vanished within minutes during a long clone+scan job, destroying the workspace twice. For any bulk job lasting more than a few minutes, work under `~/org-replace` (or similar), never /tmp.

### 1. GitHub code search fails for emoji and large orgs

`gh search code "🦞" owner:synthalorian` often returns empty. `gh search code "synthclaw"` may be rate-limited or miss private repos. **Always clone and grep locally.**

### 2. Extension allow-lists miss active source files

A file like `android/app/build.gradle.kts` or `dist/package.sh` won't match typical `text_extensions` sets. Use a skip-list (exclude known binaries/history) and process everything else.

### 3. Force-pushing amended commits triggers safety blocks

If you amend a commit (`git commit --amend`) and then `git push --force-with-lease`, Hermes' safety system may block it. **Use follow-up commits instead:**

```bash
# BAD — may be blocked
git commit --amend -m "fixed"
git push --force-with-lease

# GOOD — always works
git add -A
git commit -m "rebrand: additional fixes"
git push
```

### 4. Historical session logs should not be rewritten

Files like:
- `claude/projects/*/session-*.jsonl`
- `.claw/sessions/*/*.jsonl`
- `hermes/migration/*/archive/`
- `openclaw/cron/runs/*.jsonl`

These are immutable session transcripts. Modifying them is revisionist — they record what was actually said. Skip them via the skip-list.

### 5. `_archive/` directories are context-dependent

Some `_archive/` dirs contain actual documentation that should be updated (e.g., archived setup guides). Others contain raw session dumps that should be skipped. **Inspect before processing.** When in doubt, grep the archive first:

```bash
grep -rI "synthclaw" repo/_archive/ | head -5
```

### 6. Bundle identifiers and package names need careful replacement

`com.synthclaw.appname` → `com.synthclaw.appname` is correct. But be careful not to break URLs like `https://github.com/synthalorian/synthclaw` — these are repo names, not package identifiers. If the repo itself is being renamed, that's a separate operation (see `github-repo-management`).

### 7. Large-scale operations need temp workspace cleanup

After completion, the temp directory may be large (gigabytes for 65 repos). Clean up when done:

```bash
rm -rf /tmp/org-replace
```

Or keep it if the user wants to verify before deletion.

## Related Skills

- `github-repo-management` — Individual repo CRUD, releases, secrets
- `git-multi-repo-status` — Batch status checking across local repos
- `codebase-inspection` — Deeper codebase analysis (LOC, languages)
