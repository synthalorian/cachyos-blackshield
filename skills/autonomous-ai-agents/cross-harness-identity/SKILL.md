---
name: cross-harness-identity
description: "Sync, restore, and verify an agent persona/identity (SOUL.md, memories, rules files) across multiple AI harnesses — Hermes, OpenClaw, OpenCode, Claude Code. Use when: distributing identity updates, building/verifying restore scripts, or onboarding a persona onto a new harness."
version: 1.0.0
author: synthclaw
metadata:
  hermes:
    tags: [identity, persona, hermes, openclaw, opencode, backup, restore]
---

# Cross-Harness Identity Sync

Distributing one persona (name, voice, memories, rules) across multiple AI agent harnesses. Each harness loads identity from a different file in a different format — this skill is the map plus the pitfalls.

## When to Use

- User asks to "set/sync this identity across the board" for multiple agent tools
- Building or extending a persona backup/restore repo
- Onboarding an existing persona onto a newly installed harness
- Verifying a restore script before trusting it

## Identity File Locations (Per Harness)

| Harness | Identity file | Format notes |
|---------|---------------|--------------|
| **Hermes** | `~/.hermes/SOUL.md` + `~/.hermes/memories/{MEMORY,USER}.md` | SOUL.md injected into system prompt |
| **OpenClaw** | `~/.openclaw/workspace/SOUL.md` | Plain markdown copy works. Workspace `MEMORY.md` is a SEPARATE, larger self-maintained knowledge base — never overwrite it; only seed if absent |
| **OpenCode** | `~/.config/opencode/AGENTS.md` | Auto-loaded as global rules every session; no config entry needed. A short header + full SOUL.md content works |
| **Claude Code** | `~/.claude/CLAUDE.md` | Auto-loaded global instructions |
| **claw-code** | `~/.claw/CLAUDE.md` | User-level global instructions. Requires synth's local patch to `discover_instruction_files` (upstream v0.1.3 has NO user-level discovery — only a cwd→git-root walk). The patch adds `$CLAW_CONFIG_HOME/CLAUDE.md`, `~/.claw/CLAUDE.md`, `~/.claw/instructions.md`, `~/.claude/CLAUDE.md`. Verify with `claw system-prompt \| grep synthclaw` |

## Golden Rule: Diff Before You Sync

**Never blindly push a backup repo's identity outward.** Backup repos drift stale the moment the live identity changes. Real case: the synthclaw-identity repo still had the Omarchy/Hyprland section after the system migrated to CachyOS/KDE — pushing it "across the board" would have been a regression on every harness.

Procedure:

1. Fetch the repo copy (private repos: use `gh api` / `gh repo clone` — unauthenticated raw/curl 404s).
2. `diff` repo files against the live files (`~/.hermes/SOUL.md`, memories).
3. **Newest wins.** If live is newer: sync live → repo, commit, push, THEN distribute the live copy to the other harnesses. If repo is newer: distribute repo → harnesses.
4. Verify each harness actually loads it (smoke tests below).

## Smoke Tests

After installing identity into a harness, prove it loaded — don't assume:

```bash
# OpenCode (global AGENTS.md)
opencode run 'In one short line: what is your name and signature emojis?'

# OpenClaw — restart gateway first, then ask in TUI/Discord
systemctl --user restart openclaw-gateway

# Hermes — new session, or check the file is what the system prompt shows
diff ~/.hermes/SOUL.md <repo>/identity/soul/SOUL.md
```

Expected answer for synthclaw: `synthclaw 🎹🦞`.

## Backup Repo Structure (synthclaw-identity pattern)

```
identity/
  soul/SOUL.md           # persona
  memories/              # MEMORY.md, USER.md
  skills/ config/ cron/  # full harness state (Hermes-oriented)
harness/
  opencode/AGENTS.md     # per-harness adapted copies
restore.sh               # one-shot restore to ALL harnesses
```

Restore script requirements:

- Back up every existing target file to one timestamped dir before overwriting
- `set -euo pipefail`, but tolerate absent optional files (`|| true` on optional copies)
- Interactive-heavy steps (multi-hundred-MB state DBs) behind a y/N prompt
- Per-harness no-clobber rules (e.g. OpenClaw workspace MEMORY.md: seed only if absent)
- Print a per-harness summary of what was restored where

## Verifying Restore Scripts Safely

Never test a restore script against the real home directory. Pattern:

1. `FAKE=$(mktemp -d)`; export `HOME="$FAKE"` and harness-home env vars (e.g. `HERMES_HOME="$FAKE/.hermes"`) — most restore scripts honor these.
2. Pre-seed fake existing files (`echo OLD > $FAKE/.../SOUL.md`) to exercise backup and no-clobber paths.
3. Pipe answers to interactive prompts: `printf 'n\nn\n' | bash restore.sh`.
4. Assert: files installed from repo, old content present in backup dir, no-clobber files byte-identical.
5. `rm -rf "$FAKE"` — clean up the sandbox AND the throwaway verify script when done.

A ready-to-adapt verification script: `scripts/verify-restore.sh` in this skill.

## Pitfalls

- **Private identity repos 404 on unauthenticated fetch.** Always `gh repo view` / `gh api` first; don't conclude the repo doesn't exist from a curl 404.
- **Per-harness memory files are not interchangeable.** Hermes MEMORY.md (compact curated notes) vs OpenClaw workspace MEMORY.md (large self-evolving KB) serve different roles. Syncing persona (SOUL) is safe; syncing memory stores usually isn't.
- **Global rules files need no registration.** OpenCode's `~/.config/opencode/AGENTS.md` and Claude Code's `~/.claude/CLAUDE.md` are auto-discovered — don't hunt for a config key to point at them.
- **A restore that skips backups is a landmine.** If the script you're extending doesn't back up existing files first, add that before adding new restore targets.
