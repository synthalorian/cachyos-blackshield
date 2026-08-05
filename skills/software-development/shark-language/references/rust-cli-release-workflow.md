# Rust CLI Release Workflow

End-to-end pattern for building, installing, and releasing a Rust CLI project — captured from OpenShark v1.0.0 ship.

## When to Use

Any time the user says "rebuild and install" or "push to GitHub" for a Rust CLI project with local uncommitted changes.

## Critical Pitfall: Dirty Working Tree vs. Git

**NEVER assume `git pull` gets the latest code.** If the user has been iterating locally, the uncommitted changes in the working tree may be ahead of `origin/main`.

**Wrong:**
```bash
git stash && git pull origin main  # You just threw away the latest work
git stash pop  # Maybe, but now you're confused about state
```

**Right:**
```bash
git status  # See what's modified/untracked FIRST
git diff --stat  # Understand the scope of local changes
# If local changes ARE the latest work, build from them directly
cargo build --release
```

**Rule:** Ask or check before stashing. The user's working tree is often the source of truth during active development.

## Build & Install Sequence

```bash
cd /path/to/project

# 1. Check state first
git status
git log --oneline -5

# 2. Build release
cargo build --release 2>&1

# 3. Install to local bin
cp target/release/<binary> ~/.local/bin/<binary>
chmod +x ~/.local/bin/<binary>

# 4. Verify
~/.local/bin/<binary> --version
```

## Release Commit & Push Sequence

```bash
cd /path/to/project

# 1. Update CHANGELOG.md (Keep a Changelog format)
# Add [x.y.z] section with Added/Changed/Fixed subsections

# 2. Stage everything
git add -A

# 3. Commit with detailed message
git commit -m "feat(vX.Y.Z): summary line

Detailed bullet points of what changed:
- Feature A: what it does
- Feature B: what it does
- Fix C: what was broken and how it's fixed

Refs: reference-file-1, reference-file-2"

# 4. Push
git push origin main
```

## Commit Message Format

Use conventional commits with scope:
```
feat(v1.0.0): short summary under 50 chars

Body:
- Bullet points for each major change
- Group by category (Swarm, TUI, CLI, etc.)
- Include metric changes (test count, warning count)

Refs: skill-reference-1, skill-reference-2
```

## Verification Checklist

| Check | Command |
|-------|---------|
| Binary installed | `~/.local/bin/<name> --version` |
| Binary is fresh | `ls -la ~/.local/bin/<name>` (check timestamp) |
| Binary contains new strings | `strings ~/.local/bin/<name> \| grep "new_feature_string"` |
| Commit pushed | `git log origin/main --oneline -3` |
| CHANGELOG updated | `head -40 CHANGELOG.md` |

## Cargo Version Bump

If bumping version in `Cargo.toml`:
1. Edit `Cargo.toml`: `version = "x.y.z"`
2. Update `CHANGELOG.md`
3. `cargo build --release`
4. Verify: `target/release/<binary> --version` outputs new version
5. Copy to `~/.local/bin/`
6. Commit with version bump note

**Note:** `env!("CARGO_PKG_VERSION")` in code auto-picks up `Cargo.toml` version. No hardcoded strings needed.
