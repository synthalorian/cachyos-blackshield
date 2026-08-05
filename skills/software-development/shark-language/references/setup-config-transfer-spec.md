# OpenShark Setup System with Config Transfer

## Overview

OpenShark's setup wizard (`openshark setup`) is a standalone system that configures the harness and can optionally import configuration from existing AI agent setups (Hermes, OpenClaw).

## CLI Interface

```bash
openshark setup                           # Interactive setup wizard
openshark setup --migrate-from hermes     # Import Hermes config
openshark setup --migrate-from openclaw   # Import OpenClaw config
openshark setup --migrate-from hermes --dry-run   # Preview only
```

## Setup Flow

```
1. DETECT  → 2. INSTALL DEPS (if needed)  → 3. AUTO-CONFIGURE  → 4. TEST  → 5. DONE
```

### Step 1 — Detect
- Check Rust toolchain (cargo, rustc)
- Check for existing OpenShark config at `~/.config/openshark/`
- Detect Hermes installation at `~/.hermes` (offer config transfer)
- Detect OpenClaw installation at `~/.openclaw` (offer config transfer)

### Step 2 — Install Dependencies
- Rust toolchain (if missing, prompt for rustup install)
- Build dependencies (openssl, pkg-config)

### Step 3 — Auto-Configure
- Write `~/.config/openshark/config.toml` with defaults
- Create `~/.local/share/openshark/` for memory database
- Create `~/.cache/openshark/` for response cache
- Generate shell completions (bash, zsh, fish)

### Step 4 — Test
- Verify binary builds successfully
- Test provider connectivity (if API keys configured)
- Test memory database initialization

### Step 5 — Done
- Print summary of configured settings
- Show quick-start commands
- Offer to launch TUI

## Config Transfer from Hermes → OpenShark

### Command
```bash
openshark setup --migrate-from hermes
```

### Transferred Data

| Hermes Source | OpenShark Destination | Content |
|---------------|----------------------|---------|
| `~/.hermes/SOUL.md` | `~/.config/openshark/SOUL.md` | User persona / agent identity |
| `~/.hermes/memory/` | `~/.local/share/openshark/memory/` | Hermes memory entries |
| `~/.hermes/skills/` | `~/.config/openshark/skills/` | Skills (filtered for coding/dev) |
| `~/.hermes/config.yaml` | `~/.config/openshark/config.toml` | Provider configs (mapped to OpenShark format) |

### Mapping Rules
- Provider configs from Hermes YAML are mapped to OpenShark TOML format
- API key references are preserved (env var names, not values)
- Only coding/dev relevant skills are transferred (filter by tags)

## Config Transfer from OpenClaw → OpenShark

### Command
```bash
openshark setup --migrate-from openclaw
```

### Transferred Data

| OpenClaw Source | OpenShark Destination | Content |
|-----------------|----------------------|---------|
| `~/.openclaw/SOUL.md` | `~/.config/openshark/SOUL.md` | User persona / agent identity |
| `~/.openclaw/MEMORY.md` | `~/.local/share/openshark/memory/` | Long-term agent knowledge |
| `~/.openclaw/USER.md` | `~/.config/openshark/user_profile.md` | User profile |
| `~/.openclaw/workspace/tts/` | `~/.config/openshark/tts/` | TTS voice assets |
| `~/.openclaw/skills/` | `~/.config/openshark/skills/` | User skills (filtered for coding/dev) |
| `~/.openclaw/.env` | `~/.config/openshark/*.env` | API keys (Hermes-compatible providers only) |

### Mapping Rules
- OpenClaw's flat `.env` file is split into per-provider `.env` files
- Only providers that exist in both OpenClaw and OpenShark are transferred
- Skills are filtered by category (coding, devops, debugging pass through; creative, music are skipped)

## Migration Paths (No Circular Dependencies)

```
OpenClaw ──► Hermes        (hermes claw migrate)
     │
     ├──► OpenShark        (openshark setup --migrate-from openclaw)

Hermes ────► OpenShark     (openshark setup --migrate-from hermes)
```

**Critical rule:** Each tool only reads from source, never writes to another tool's config. No circular deps.

## Implementation Files

```
src/config/setup.rs           # Enhanced setup wizard with migration
src/config/migrate_hermes.rs  # Hermes → OpenShark migration logic
src/config/migrate_openclaw.rs # OpenClaw → OpenShark migration logic
scripts/setup.sh              # One-liner curl install script
```

## Dry-Run Mode

Both migration commands support `--dry-run`:

```bash
openshark setup --migrate-from hermes --dry-run
openshark setup --migrate-from openclaw --dry-run
```

Dry-run outputs:
- List of files that would be transferred
- List of files that would be skipped (with reason)
- List of conflicts (existing OpenShark files that would be overwritten)
- Estimated disk space used

## Conflict Resolution

When a destination file already exists:

1. **SOUL.md**: Prompt user — keep existing, overwrite, or merge
2. **Memory files**: Merge (append new entries, deduplicate)
3. **Skills**: Skip if identical, overwrite if different (with backup)
4. **Config**: Merge (OpenShark defaults + imported provider configs)
5. **.env files**: Never overwrite — append new keys, preserve existing

## Error Handling

| Error | Handling |
|-------|----------|
| Source directory not found | Skip migration, log warning, continue setup |
| Source file unreadable | Skip that file, log warning, continue |
| Destination write failed | Abort migration, rollback partial writes, report error |
| Invalid config format | Skip that config section, log warning, continue |
| Provider not supported | Skip that provider, log warning, continue |

## Testing

```bash
# Test Hermes migration
cargo test --test migrate_hermes

# Test OpenClaw migration
cargo test --test migrate_openclaw

# Test dry-run mode
cargo test --test migrate_dry_run

# Test conflict resolution
cargo test --test migrate_conflicts
```
