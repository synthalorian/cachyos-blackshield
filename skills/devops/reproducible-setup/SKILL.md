---
name: reproducible-setup
description: Maintain a version-controlled backup of the entire system's AI/developer config stack in a git repo. Covers config discovery, secrets sanitization, file staging, and push workflow. The repo serves as a single-source-of-truth for rebuilding on a fresh machine.
---

# Reproducible Setup Management

Maintain a git repository that captures the full system configuration — AI coding tools, terminal configs, model serving, window manager, shell, and install scripts. The goal: clone + run one install script = back to productivity on a fresh box.

## The Repo Pattern

The backup repo (synth's is at `~/synthclaw-ai-setup`) mirrors the structure of home directory configs under a `configs/` directory tree:

```
synthclaw-ai-setup/
├── configs/
│   ├── opencode/          # ~/.config/opencode/
│   ├── hermes/            # ~/.hermes/ (sanitized)
│   ├── llama/             # ~/llama.cpp/
│   ├── claude/            # ~/.claude/
│   ├── wrappers/          # ~/synthclaw-ai-setup/configs/wrappers/
│   └── openclaw/          # ~/.openclaw/
├── install/               # Platform-specific install scripts
│   ├── linux/             # Arch/Omarchy (primary)
│   ├── windows/           # Legacy
│   └── wsl/               # Legacy
├── synthclaw/             # AI identity files (SOUL, IDENTITY, AGENTS, memory/)
├── skills/                # Claude skills
├── docs/
│   ├── MODELS.md          # Model inventory + download sources
│   └── SECRETS.md         # Placeholder-to-secret mapping
└── README.md              # Current system overview
```

## When to Use

- System setup changed significantly (new tool, changed provider, new config)
- User asks "back this up" or "update the setup repo"
- User is about to distro-hop, reinstall, or change hardware
- New version of a critical tool was installed (Hermes, OpenCode, llama-swap)
- AI agent system prompt was updated (the irreplaceable asset)

## Procedure

### 1. Discover Changed Configs

Scan the real config directories for recent changes:

```bash
# OpenCode configs
~/.config/opencode/opencode.json
~/.config/opencode/oh-my-openagent.json   # ← MOST VALUABLE (contains system prompt)
~/.config/opencode/tui.json

# Hermes agent config
~/.hermes/config.yaml                     # Sanitize: strip API keys, auth paths

# llama-swap config
~/llama.cpp/llama-swap/config.yaml        # Sanitize: rewrite user-specific paths to $HOME or template vars

# Wrapper scripts
~/synthclaw-ai-setup/configs/wrappers/    # Usually already in the repo

# Systemd user services
~/.config/systemd/user/*.service

# Shell config
~/.bashrc, ~/.zshrc, ~/.config/fish/
```

### 2. Copy to Repo Structure

Copy files into the matching tree under `~/synthclaw-ai-setup/configs/`:

- `~/.config/opencode/opencode.json` → `configs/opencode/opencode.json`
- `~/.config/opencode/oh-my-openagent.json` → `configs/opencode/oh-my-openagent.json`
- `~/.hermes/config.yaml` → `configs/hermes/config.example.yaml` (SANITIZE — strip API keys, replace with `<FILL_IN:*>`)
- `~/llama.cpp/llama-swap/config.yaml` → `configs/llama/llama-swap/config.yaml` (SANITIZE — rewrite absolute paths)

### 3. Sanitize Secrets

Before committing, strip or replace:

- **API keys** → `<FILL_IN:PROVIDER_API_KEY>` or `api_key_env: PROVIDER_API_KEY`
- **Auth tokens** → Remove `auth.json` entries, never commit OAuth state
- **Absolute home paths** → `$HOME` or `<FILL_IN:HOME_DIR>`
- **Machine-specific paths** → template vars
- **.env files** → Already covered by .gitignore but verify

Update `docs/SECRETS.md` whenever a new secret placeholder is introduced.

### 4. Update Documentation

- **`README.md`** — Major changes: update the component table, install instructions, quick-start commands, model list
- **`docs/MODELS.md`** — New/changed models: update inventory table, HF repo links, copy commands
- **`docs/SECRETS.md`** — New secrets: add placeholder row with *what it is* and *how to get it*

### 5. Stage and Commit

```bash
cd ~/synthclaw-ai-setup
git status                       # Review what changed
git add -A                       # Or git add specific files
git commit -m "Description of what changed and why"
git push origin master
```

Commit message format: `Update backup to current <platform> stack` with bullet points describing each significant change.

### 6. Verify

```bash
# Spot-check the pushed files by browsing on GitHub
gh repo view synthalorian/synthclaw-ai-setup --web

# Or clone fresh and verify the structure looks right
mktemp -d && cd $_ && git clone https://github.com/synthalorian/synthclaw-ai-setup.git .
```

## What to NEVER Commit

| Item | Why | What to do instead |
|------|-----|-------------------|
| API keys, tokens, passwords | Permanent secret leak | Use `<FILL_IN:*>` placeholders + `docs/SECRETS.md` |
| `auth.json`, OAuth state | Contains refresh tokens | Document the auth command (e.g., `hermes login nous`) |
| `backups/` directory | Snapshot noise | Already in .gitignore |
| `node_modules/`, `.venv/` | Dependencies, not config | .gitignore covers these |
| GGUF model weights | 140+ GB, not code | List in `docs/MODELS.md` with HF URLs |
| Runtime state (sessions, cache) | Machine-specific, ephemeral | Exclude in .gitignore |
| `.hermes/` secrets | Token refresh artifacts | Never commit |
| AI session logs (`.claw/`, `.claude/`) | Full conversation history with prompts, responses, tool calls | Add to `.gitignore` immediately; see [references/git-history-purge.md](references/git-history-purge.md) if already committed |
| Flutter/Android build artifacts (`.gradle/`, `.cxx/`) | Absolute paths to Android SDK, NDK, Gradle cache (`/home/USER/...`) | Add to `.gitignore`; see [references/deep-repo-audit.md](references/deep-repo-audit.md) for full cleanup workflow |
| Flutter generated files (`flutter_export_environment.sh`) | Flutter SDK path on developer's machine | Standard Flutter `.gitignore` should cover; verify |
| Hardcoded home paths in scripts | `/home/USER/projects/...` in build/upload scripts | Replace with relative paths (`./build/...`) |

## Emergency: Purging Already-Committed Secrets

If secrets were accidentally committed before `.gitignore` was in place, see [references/git-history-purge.md](references/git-history-purge.md) for the full `git-filter-repo` workflow. The quick version:

```bash
# Install if needed
pip install git-filter-repo --break-system-packages

# Remove a file/directory from ALL history
git filter-repo --path path/to/secret.file --invert-paths --force

# Or replace a secret string across ALL history
echo "ACTUAL_SECRET==>YOUR_PLACEHOLDER_HERE" > /tmp/replacements.txt
git filter-repo --replace-text /tmp/replacements.txt --force

# Re-add remote and force-push
git remote add origin https://github.com/OWNER/REPO.git
git push --force --all origin
git push --force --tags origin
```

**Always rotate the exposed secret after purging** — anyone with a fork or old clone still has it.

## References

- [references/git-history-purge.md](references/git-history-purge.md) — Full guide: `git-filter-repo`, `git filter-branch`, verification, post-purge checklist
- [references/deep-repo-audit.md](references/deep-repo-audit.md) — Three-phase deep audit: shallow secrets → personal config scan → surgical filtering
- [scripts/scan-repo-secrets.py](scripts/scan-repo-secrets.py) — Automated secret scanner for local repos or GitHub orgs (Phase 1)
- [scripts/deep-audit-repos.py](scripts/deep-audit-repos.py) — Deep personal config scanner for GitHub orgs (Phase 2)
- `github-repo-management/references/git-recovery-workflow.md` — Reverting a repo's working tree to a historical commit when `git reset --hard` is blocked (restoring known-good state vs. purging secrets)


## Pitfalls

- **Config drift.** If you back up a config and then change it on the live system before pushing, the backup is stale. Always do scan → copy → commit in one flow.
- **Oversanitization.** Replacing every path with `<FILL_IN:*>` makes the config unusable as a template. Leave *workable defaults* and only mask the actual secrets.
- **Git LFS for binaries.** Don't commit GGUF files, MP3s, or images — they bloat the repo forever. Use HF links or `MODELS.md` instead.
- **Large commits are fine** for backup repos. One commit that says "full system snapshot May 2026" is better than 20 tiny commits.
- **The irreplaceable asset is the system prompt.** In `oh-my-openagent.json`, the `"system"` field under `sisyphus` contains the synthclaw identity. Back that up first, worry about everything else second.
- **Scan for secrets BEFORE committing.** Run `scripts/scan-repo-secrets.py` on the backup repo before each push. A secret in the backup repo is still a public leak.
