---
name: forge
description: Forge — CLI + Hub monorepo. Rust CLI and Rails 8 web GUI for crafting your digital future. Git backup engine, AI agent harness, scripture, system management, creative tools, and integrations.
version: 1.4.0
tags: [rust, cli, forge, backup, ai-agents, scripture, themes]
---

# Forge — Craft Your Digital Future

**Location:** `~/projects/forge/`
**Language:** Rust (edition 2021)
**Binary:** `forge` (clap CLI)
**License:** Apache 2.0

## What Forge Is

A CLI platform built on a blacksmith metaphor. Six pillars, each a subcommand group. The existing backup engine (Phase 1, done) is the foundation. The vision expands it into a unified tool for code, AI, faith, system, creativity, and connections.

## Current State (v1.4.0 — All Six Pillars + Visual Pipeline Builder + Mobile Responsive)

~10,000 lines of Rust (src/) + Rails 8 Hub (hub/). Monorepo at `~/projects/forge/`. Compiles clean. Released as **v1.4.0** on GitHub. `cargo check` and `cargo clippy` both clean (0 errors, 0 warnings). **116 Rust tests (91 unit + 17 integration + 8 spirit) + 230 Hub specs — all green.**

**30 CLI commands** across all six pillars + workshop verbs + fractal generator + git hooks + reading plans + backup diff. The Hub has functional views for all seven pages plus archive browser, visual pipeline builder, drag-and-drop palette upload, Action Cable progress streaming, and mobile responsive layout.

### What's Implemented (v1.4.0)

| Module | File | Lines | Notes |
|--------|------|-------|-------|
| CLI | `src/cli.rs` | ~435 | clap derive, **25 top-level commands** — added Fractal + Hooks |
| Config | `src/config.rs` | 93 | TOML load/save, XDG dirs, retention policy, `llama_swap_config` path |
| Models | `src/models.rs` | 67 | BackupEntry, RepoSnapshot, ArchiveManifest, ChunkEntry, ScheduleConfig |
| Errors | `src/error.rs` | 33 | thiserror ForgeError enum |
| DB | `src/db.rs` | 451 | SQLite schema (backups, schedules, chunks, archive_chunks), CRUD, indexes |
| Backup | `src/backup.rs` | 390 | Repo discovery, bare git clone, ChunkStore integration, progress bars |
| Archive | `src/archive.rs` | 354 | tar→zstd pipeline via subprocess, HashingWriter for SHA-256, verify mode |
| Restore | `src/restore.rs` | 196 | DB lookup, extract, optional ref checkout, dry-run |
| Scheduler | `src/scheduler.rs` | 180 | Cron validation, crontab file generation, add/remove/list |
| ChunkStore | `src/chunkstore.rs` | 81 | Content-addressable 4MB chunks, SHA-256, zstd, sharded paths |
| Theme | `src/theme.rs` | ~370 | 12 themes × 12 color slots, custom `StyledString` emitting raw 24-bit truecolor |
| Theme Cmd | `src/theme_cmd.rs` | ~526 | list, preview, set, create, **export (alacritty/kitty/ghostty)**, **--write flag** |
| **Anvil Cmd** | `src/anvil.rs` | 727 | **temper, prune, search, health** — all implemented |
| **Bridge** | `src/bridge.rs` | 275 | **status, hooks, notify** — all implemented |
| **Crucible** | `src/crucible.rs` | ~1,150 | **chords, palette, diagram, from-image, fractal (7 presets)** |
| **Mind Engine** | `src/mind.rs` | 544 | Agent detection (Hermes, llama-swap, OpenCode, Codex), task routing |
| **Mind Cmd** | `src/mind_cmd.rs` | ~590 | `forge breathe` (status, models, vault, prompts, **pipe**) + `forge strike` |
| **Spirit Core** | `src/spirit.rs` | 718 | Bible DB loading, daily verse, verse search, passage lookup, abbreviation resolution |
| **Spirit Cmd** | `src/spirit_cmd.rs` | 412 | CLI dispatch for word, reflect, rest subcommands |
| **Reflect** | `src/reflect.rs` | 610 | Encrypted prayer journal (AES-256-GCM), entry CRUD, search, pagination |
| **Tongs** | `src/tongs.rs` | ~900 | `forge grip` — dashboard, dotfiles, diagnose, **hooks (install/list)**, services |
| **Workshop** | `src/workshop.rs` | 824 | **heat, anneal, alloy, cast, grind, polish** — all implemented |
| Utils | `src/utils.rs` | ~30 | Shared helper functions |
| Bible DB Gen | `src/bin/generate_bible_db.rs` | ~100 | Build-time Bible SQLite database generator |
| App Icon | `assets/forge-icon.png` | — | Synthwave blacksmith icon (1254×1254 PNG) |

### Key Dependencies

- `clap` 4 (derive) — CLI
- `git2` 0.20 — **CONFIRMED USED** (7 calls in backup.rs: branch/tag/stash/commit metadata)
- `rusqlite` 0.33 (bundled) — SQLite
- `zstd` 0.13 — compression
- `sha2` 0.10 — chunk hashing
- `serde`/`serde_json`/`toml` — serialization
- `chrono` — timestamps
- `indicatif` — progress bars
- `colored` 3 — **REMOVED** (see Pitfalls below) — theme output now uses custom `StyledString` with raw 24-bit ANSI
- `anyhow`/`thiserror` 2 — error handling
- `walkdir` 2 — filesystem traversal
- `dirs` 6 — XDG paths
- `aes-gcm` 0.10 / `rand` 0.8 — encrypted prayer journal (reflect.rs)
- `regex` 1 — verse reference parsing (spirit.rs)

### Build

```bash
cd ~/projects/forge
cargo build --release    # binary at target/release/forge
cargo install --path .   # install to ~/.cargo/bin/
```

### Architecture

- Data dir: `~/.forge/` (configurable)
- Config: `~/.forge/config.toml`
- Config struct fields: `archive_dir`, `data_dir`, `forge_bin`, `repo_paths`, `retention`, `theme`, `llama_swap_config` (PathBuf, `#[serde(default)]` falls back to `~/llama.cpp/llama-swap/config.yaml`)
- SQLite DBs: `~/.forge/db/forge.db`
- Archives: `~/.forge/archives/*.tar.zst`
- Chunks: `~/.forge/chunks/<2-hex>/<rest>.zst` (content-addressable, sharded)
- Schema: `backups`, `schedules`, `chunks`, `archive_chunks` tables with indexes

## The Six Pillars (All Active)

The blacksmith metaphor maps every command to a workshop action.

| Pillar | Subcommand | Metaphor | Implementation |
|--------|-----------|----------|----------------|
| Code | `forge anvil` | The Anvil — shape projects | ✅ `anvil.rs` (727 lines): search, temper, health, prune, verify |
| Mind | `forge breathe` / `forge strike` | The Bellows — AI agent harness | ✅ `mind.rs` + `mind_cmd.rs` (822 lines): status, models, vault, prompts, task routing |
| Spirit | `forge word` / `forge reflect` / `forge rest` | The Flame — scripture & journal | ✅ `spirit.rs` + `spirit_cmd.rs` + `reflect.rs` (2,400 lines): verse, search, reference, journal CRUD, Sabbath mode, **reading plans** |
| System | `forge grip` | The Tongs — system management | ✅ `tongs.rs` (~900 lines): dashboard, dotfiles, diagnose, **hooks** |
| Create | `forge melt` | The Crucible — creative tools | ✅ `crucible.rs` (~1,150 lines): chords, palette, diagram, **fractal (7 presets)**, **from-image** |
| Connect | `forge bridge` | The Bridge — integrations | ✅ `bridge.rs` (275 lines): status, hooks, notify |

### Workshop Verbs (Top-Level Actions — All Implemented)

- `forge heat` — spin up AI agents ✅ `workshop.rs` `run_heat()`
- `forge strike <task>` — execute via best agent ✅ `mind_cmd.rs` `run_strike()`
- `forge quench [path]` — backup (alias for `forge backup`) ✅ backup engine
- `forge restore <id>` — restore from backup ✅ restore engine
- `forge temper` — verify backup integrity (re-hash & compare) ✅ `anvil.rs` `run_temper()`
- `forge anneal` — deep work / do-not-disturb mode ✅ `workshop.rs` `run_anneal()`
- `forge alloy` — merge multi-agent outputs ✅ `workshop.rs` `run_alloy()`
- `forge cast` — deploy/release ✅ `workshop.rs:319-688` (GitHub release with binary + hub tarball + icon)
- `forge grind` — lint/test ✅ `workshop.rs` `run_grind()`
- `forge polish` — format/document ✅ `workshop.rs` `run_polish()`

> **Alias pattern:** When implementing a new workshop verb, add `alias = "..."` to the existing clap `#[command()]` attribute on the enum variant in `cli.rs`. Example: `#[command(alias = "quench")]` on `Backup(BackupArgs)`. The alias routes to the same handler — no extra code.

## Known Issues & Technical Debt

### Resolved

1. **❌ tokio removed (May 2026)** — Was declared with "full" features, zero async code anywhere. Deleted from Cargo.toml. If async is needed later, add it back explicitly with only the required features.
2. **✅ git2 confirmed used** — 7 calls in `backup.rs` (branch type enumeration, tag collection, stash counting, dirty-check, commit counting). Keep it.
3. **✅ 247 tests passing** — 91 unit tests + 9 integration tests in `tests/integration.rs` + 8 integration tests in `tests/spirit.rs` + 230 Hub specs (request specs + service specs + system test) + unit tests across `spirit.rs`, `reflect.rs`, `theme.rs`, `archive.rs`, `db.rs`, `config.rs`, `anvil.rs`. CI enforces `cargo test` + `cargo clippy` on push.

### Security Audit (v0.9.0 — May 2026, consolidated in v1.0.0)

Full surgical audit performed on AI-generated code (GLM-5.1 output). 34 issues identified, 14 fixed across 13 files (v0.3.0), then v0.9.0 release consolidated all fixes + new features + updated specs. v1.0.0 added localhost-only restriction, atomic cache dedup with `unless_exist: true`, input sanitization in flame_controller, `llama_swap_config` in Rust Config struct (no hardcoded paths), `safe_command_args` shell-injection-free alternative, and remaining unwrap elimination. All 230 Hub specs + 17 Rust tests green.

**Critical fixes applied:**
- Rust: `format!` + `sh -c` shell injection → `std::process::Command` with `.args()` (bridge.rs, tongs.rs)
- Ruby: backtick interpolation → `Open3.capture3` with argv arrays (tongs_controller.rb, bridge_controller.rb, flame_controller.rb, bellows_controller.rb)
- Ruby: `safe_command` / `safe_forge_command` helpers eliminated — they only gsub'd double quotes, leaving backticks/$()/;/newlines exploitable
- Ruby: HTTP basic auth added (env-gated via `FORGE_HUB_USERNAME`/`FORGE_HUB_PASSWORD`, uses `ActiveSupport::SecurityUtils.secure_compare`)

**Correctness fixes applied:**
- Rust: `.unwrap()` panics → `if let Ok()` / `.unwrap_or()` / match (bridge.rs, mind.rs, anvil.rs)
- Rust: `Box::leak` + `OnceLock` in theme.rs → `Mutex<HashMap>` with working `reload_custom_themes()`
- Rust: hardcoded `/home/synth/` paths → `LLAMA_SWAP_CONFIG` env var with sensible default
- Rust: UTF-8 byte slicing `[..10]` → `.chars().take(10).collect()`
- Ruby: SQLite connection leaks → `ensure db.close` in every code path
- Ruby: SQL N+1 in statistics.rb → SQL `GROUP BY` / `OVER()` / `FILTER()` aggregates
- Ruby: backup race condition → atomic cache write sentinel before enqueue (`unless_exist: true` eliminates check-then-set race window)
- Ruby: localhost-only access restriction (`before_action :restrict_to_localhost` in ApplicationController)
- Ruby: input sanitization in flame_controller (query length cap + character blacklist for `;&|`$(){}`
- Rust: `llama_swap_config` field added to `Config` struct with `#[serde(default)]` — eliminates all hardcoded `/home/synth/` paths
- Rust: `safe_command_args(program, args)` in tongs.rs — shell-injection-free alternative to `safe_command` that uses `Command::new().args()` instead of `sh -c`

**Verification:** `cargo check` + `cargo clippy` both clean — 0 errors, 0 warnings.

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `LLAMA_SWAP_CONFIG` | Path to llama-swap config (bridge.rs, mind.rs, config.rs) | `~/llama.cpp/llama-swap/config.yaml` |
| `FORGE_HUB_USERNAME` | Enable HTTP basic auth for Hub | (unset = no auth) |
| `FORGE_HUB_PASSWORD` | Password for Hub basic auth | (unset = no auth) |

### Still Open

1. **colored crate ban** — Never reintroduce `colored`. It silently downgrades TrueColor to ANSI 8-bit, turning `#8f00ff` electric purple into magenta/blue. Use `StyledString` from `theme.rs` instead.
2. **Additional CLI aliases** — Only `quench` is aliased. Other workshop verbs could get shorter aliases if desired.
3. **`forge cast` now functional** — Creates GitHub releases with binary + hub tarball + icon upload. See `workshop.rs:319-688`.

### Resolved (shipped in v1.0.0–v1.4.0)

1. **`forge theme export`** ✅ — CLI `Export { name, format }` → `run_export()` → `export_alacritty()`, `export_kitty()`, `export_ghostty()`. v1.2.0 added `--write` flag for direct-to-config write. Source: `theme_cmd.rs:261-522`.
2. **`forge breathe pipe`** ✅ — `BreatheAction::Pipe { path }` → `run_pipe()` with `PipelineDef`/`PipelineStep` TOML parsing, multi-step execution, inter-step context passing via `input_keys`. Source: `mind_cmd.rs:272-421`.
3. **`forge melt palette from-image`** ✅ — `--file` flag on `Palette` → `extract_palette_from_image()` with Lanczos3 resize to 200px, 32-step quantization buckets, top-8 dominant colors, output in terminal/CSS/Tailwind. Source: `crucible.rs:896-1001`.
4. **Test coverage** ✅ — v1.2.0 added 8 integration tests covering chunkstore, scheduler, restore, and backup discovery. 116 total Rust tests, all green.
5. **`forge melt fractal`** ✅ — L-system generator with 7 presets (Koch, Dragon, Sierpinski, Plant, Hilbert, Gosper, Weed), custom axiom/rule support, ASCII art + SVG output. Source: `crucible.rs:~1150`.
6. **`forge grip hooks`** ✅ — `install` (writes post-commit hook running `forge quench`) and `list` (checks hook status). Source: `tongs.rs:860-988`.
7. **`forge anvil diff <id1> <id2>`** ✅ — v1.3.0. Compares file lists between two backups via tar listing. Shows added/removed/changed files with size deltas. Source: `anvil.rs:637-780`.
8. **`forge word plan`** ✅ — v1.3.0. Reading plans for psalms-30, proverbs-month, gospels-40, new-testament-90. Const-array plan definitions, SQLite state tracking in spirit.db. Source: `spirit_cmd.rs:415-665`.
9. **`forge cast` GitHub release** ✅ — v1.3.0. Detects project (git + Cargo.toml), builds binary, creates `gh release create` with release notes, uploads hub tarball and icon. Source: `workshop.rs:319-688`.
10. **Hub image upload palette extraction** ✅ — v1.3.0. Drag-and-drop drop zone in Crucible palette tab, preview thumbnail, async upload to forge CLI. Stimulus controller: `palette_upload_controller.js`.
11. **Visual pipeline builder (Hub Bellows)** ✅ — v1.4.0. Step cards with presets (Code Review, Research & Write, Code Gen + Test, Data Pipeline), add/remove/reorder, collapsible UI, TOML serialization. Stimulus controller: `pipeline_builder_controller.js` (278 lines).
12. **Mobile responsive Hub** ✅ — v1.4.0. Sidebar slides in/out with dark overlay on screens < 640px. Responsive padding (p-4 sm:p-6 lg:p-8), grid breakpoints on stat cards across all views.

## Design Decisions

- **Streaming archive pipeline** — tar stdout → zstd stdin → HashingWriter (SHA-256 + file I/O). No temp files.
- **Content-addressable chunks** — 4MB blocks, SHA-256, sharded by first 2 hex chars. Enables dedup across all projects.
- **Subprocess git** — Uses `git clone --bare` via `Command` rather than libgit2 for the actual clone. Simpler, more reliable, but requires git on PATH.
- **Theme as data** — 12 color slots per theme, const structs, no runtime parsing overhead. Colors rendered via custom `StyledString` with raw 24-bit ANSI escape codes (`\x1b[38;2;R;G;Bm`) — guarantees exact truecolor on Kitty/Alacritty/Ghostty without any crate dependency.
- **SQLite over custom format** — instant querying, indexes on repo_name and created_at, familiar tooling.

## Style Notes

- The README uses the blacksmith metaphor heavily — every section maps to workshop terminology
- Scripture references are woven into the Spirit pillar (Proverbs 27:17, Ephesians 2:10, Genesis 4:22)
- The sign-off is 🔨 (hammer) not 🎹🦞 for the README — it's the forge's identity, not synthclaw's
- Theme names: synthwave84 is default, stays true to the aesthetic
- The README embeds the app icon at top via `<picture>` tag for GitHub dark/light mode compatibility
- Top-level commands in README are organized by "Workshop Verbs" (heat, strike, quench, temper, etc.) and "Six Pillars" (anvil, breathe, word, grip, melt, bridge)
- **Workshop verb aliases** use clap's `alias = "..."` attribute on the enum variant. Example: `#[command(about = "Create a backup", alias = "quench")]` on `Backup(BackupArgs)`. This keeps the code path singular while the CLI surface is metaphorical. Add the alias at implementation time, not as a stub.
- **Test discipline:** Every module has unit tests in a `#[cfg(test)] mod tests` block at the bottom of the file. Integration tests in `tests/integration.rs` cover backup→restore round-trips, dry-run, and CLI interface. Module-specific integration tests (e.g. `tests/spirit.rs`) cover CLI commands that need a fully initialized forge environment (forge init, config file, data dirs) but don't need git repos. CLI integration tests use `TempDir` with isolated `XDG_CONFIG_HOME`/`XDG_DATA_HOME` env vars so they never touch the user's `~/.forge/`. CI (`cargo test + cargo clippy`) runs on every push.
- **Dependency discipline:** No unused deps. Every crate in Cargo.toml has at least one `use` statement in src/. If adding a dep, check it's actually imported. If removing, verify zero remaining imports.

## Reference Files

- `references/source-map.md` — module dependency graph, function signatures, SQLite schema (quick navigation without re-reading source)
- `references/six-pillars-spec.md` — detailed Phase 2/3 specification for all six pillars with data stores, commands, and design concepts
- `references/hub-pillar-wiring-pattern.md` — architectural pattern for wiring a Hub pillar with Turbo Streams + forge CLI bridge (controller, view, partial, routes, Stimulus controller). Use this when adding or extending any pillar's web UI.

## Icon & README Pattern

The Forge README embeds the app icon at the top using a `<picture>` element with dark-mode support:

```markdown
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/forge-icon.png">
  <img src="assets/forge-icon.png" alt="Forge" width="600">
</picture>
```

The icon lives at `assets/forge-icon.png` (1254×1254 PNG). When regenerating or replacing:
1. Save the new image to `assets/forge-icon.png`
2. Ensure the `width="600"` is preserved for consistent README layout
3. The `<picture>` wrapper ensures the icon renders on GitHub regardless of theme

## Forge Hub — Rails Web GUI

**Location:** `~/projects/forge/hub/` (subdirectory of the monorepo)
**GitHub:** Merged into `synthalorian/forge` — the old `synthalorian/forge-hub` repo is deleted
**Stack:** Rails 8.1.3, Propshaft, Tailwind v4 (`tailwindcss-rails`), SQLite, Stimulus + Turbo (importmap), Action Cable
**Purpose:** Browser dashboard for the Forge CLI — visualizes backups, schedules, stats, and pillar status.

### Architecture

- **Services** bridge the GUI to the CLI:
  - `app/services/forge/client.rb` — shells out to the `forge` binary
  - `app/services/forge/database.rb` — reads `~/.forge/db/forge.db` directly via SQLite
  - `app/services/forge/statistics.rb` — aggregates stats for the dashboard
- **Controllers** map to the six pillars + dashboard
- **Views** use Tailwind utility classes with custom theme color tokens (see below)
- **Jobs** (`BackupJob`, `RestoreJob`) run async CLI operations via Solid Queue
- **Action Cable** streams backup progress in real-time (`BackupProgressChannel`)
- **Coming Soon pages** (`app/views/engines/coming_soon.html.erb`) use inline CSS — separate from the main Tailwind theme

### CSS Pipeline

All paths relative to `hub/` within the monorepo.

- **Source:** `hub/app/assets/tailwind/application.css` — Tailwind v4 `@import "tailwindcss"` + `@theme` block + theme CSS variables + global effects
- **Output:** `hub/app/assets/builds/tailwind.css` (served by Propshaft)
- **Rebuild:** from monorepo root: `cd hub && bin/rails tailwindcss:build` (or `tailwindcss:watch` for dev via Procfile.dev)
- **Fallback rebuild** (if bundler is broken): run the tailwindcss binary directly from the monorepo root:
  ```
  ~/.local/share/gem/ruby/3.4.0/gems/tailwindcss-ruby-4.3.0-x86_64-linux-gnu/exe/x86_64-linux-gnu/tailwindcss \
    --input hub/app/assets/tailwind/application.css \
    --output hub/app/assets/builds/tailwind.css
  ```
- **Stylesheet tag** in layout: `<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>` — NOT `:app`
- The HTML element must carry `data-theme="synthwave84"` as a default so the theme applies before JS loads

### Theme System

- 4 themes: `synthwave84` (default), `midnight`, `ocean`, `light`
- CSS variables defined in `@theme {}` block referencing `--theme-*` custom properties per theme selector
- Theme colors used in ERB: `text-neon-purple` (primary), `text-neon-cyan` (success), `bg-bg-panel`, `border-border-faint`, `text-text-muted`, etc. Purple (`#8f00ff`) is the primary brand color, not cyan.
- Theme switching via Stimulus `theme_controller.js` — sets `data-theme` on `<html>`, persists to cookie
- Global effects: grid overlay (`body::before`), horizon glow (`.horizon-glow`), CRT scanlines (`body::after`)

### View Components

Partial helpers in `app/helpers/components_helper.rb`:
- `stat_card(label:, value:, icon:, icon_color:, href:)` — metric card with neon glow
- `card(title:, icon:, icon_color:, &block)` — generic panel
- `badge(label:, variant:, size:)` — colored status badge (success/warning/error/info/default)
- `empty_state(icon:, message:, description:, action_text:, action_path:)` — CTA for empty lists

### Pitfalls

1. **Stale CSS build** — if the tailwind output looks empty (white page, raw text), the build is stale. Rebuild it. The built file should be ~50KB, not 4KB.
2. **Controller written ahead of views** — the crucible controller was rewritten with full `chords`, `palette`, `diagram` actions but the view is still the old "coming soon" stub, no sub-action routes exist, and the `_command_output` partial doesn't exist. When a controller is unstaged/untracked in git, always check `routes.rb` + view files to see if the wiring is complete.

### Mid-Session Resumption — Picking Up Unfinished Work

When re-entering the forge monorepo mid-stream, follow this checklist to identify what's pending:

**Step 1: Git History Scan**
```bash
git log --oneline -20          # What was the last agent working on?
git status --short             # Staged (M), unstaged ( M), untracked (??)
git diff --stat HEAD~1..HEAD   # What did the last commit change?
```

**Step 2: Version State Check**
```bash
git show HEAD:Cargo.toml | grep version   # committed version
head -5 Cargo.toml                        # working-tree version
```
If they differ, the version was bumped but the change is uncommitted.

**Step 3: Release Asset Integrity**
```bash
gh release view vX.Y.Z --json assets  # check binary + hub.tar.gz + icon attached
```
Three assets must be present: `forge`, `forge-hub.tar.gz`, `forge-icon.png`.

**Step 4: Controller-View-Route Triangulation (Rails Hub)**
```bash
# List all controller actions
grep -n 'def ' hub/app/controllers/*_controller.rb

# Check routes cover all actions
cat hub/config/routes.rb

# Check views exist for each action
ls hub/app/views/crucible/   # also check other pillars

# Check for partials referenced by controller
grep -rn 'partial:' hub/app/controllers/*_controller.rb | grep -v '.git'
```
A controller with `def chords; def palette; def diagram` but only `GET /crucible` in routes, no partial for `_command_output`, and no view template means wiring is incomplete. Also check that any output container `id` referenced by Turbo Stream (`turbo_stream.replace("id")`) has a matching `<div id="...">` in the view — without it, the Turbo Stream renders into a target that doesn't exist.

**Step 5: Tailwind Build Freshness**
```bash
ls -la hub/app/assets/builds/tailwind.css  # should be ~50KB
```
If stale (4KB or missing), rebuild using the tailwindcss binary directly.

**Step 6: Cross-Reference with Session History**
```bash
# Use session_search to find the last active session on forge
```
This reveals what the last agent was doing and what decisions were made.

**Common patterns of unfinished work:**
- **Version bump staged but uncommitted** — `Cargo.lock` staged, `Cargo.toml` version change unstaged. Release exists on GitHub but the commit was never made.
- **Controller logic written ahead of views** — full actions in the controller, but views are stub "Coming Soon" pages and sub-action routes don't exist.
- **Turbo Stream controller lacks output container** — controller has `render turbo_stream: turbo_stream.replace("crucible-output", ...)` but the view has no `<div id="crucible-output">`. The Turbo Stream silently fails with no rendered output.
- **Integration tests written but untracked** — `tests/*.rs` files in `git status` as `??`. These need `git add` before they can run in CI.

### Other Hub Pitfalls

3. **`stylesheet_link_tag :app` is wrong** — Propshaft serves `tailwind.css`, not `app.css`. Use `stylesheet_link_tag "tailwind"`.
4. **Missing `data-theme` on `<html>`** — without it, the CSS variable cascade has no selector to match, so all theme colors resolve to nothing.
5. **`bundle install` may fail** — the Gemfile has dev deps (web-console, capybara, selenium-webdriver) that can fail to install on this system. Use `BUNDLE_WITHOUT=development:test` or rebuild CSS directly with the binary.
6. **Coming Soon pages** are standalone HTML with inline `<style>` — they don't share the Tailwind pipeline. If updating them, consider migrating to the main layout.

### Spec Migration After Controller Rewrites

When a Rails controller is rewritten (e.g., removing helper methods like `safe_forge_command`, adding `run_forge_argv`), **all specs that stub the old method must be updated in the same commit**. The pattern:

1. Search for `safe_forge_command` or `safe_command` across `hub/spec/`
2. Replace stubs with the new method name and signature
3. If the new method takes an argv array instead of a shell string, update `expect().to receive().with()` to match the array form

Example:
```ruby
# BEFORE (stubbing old shell-string helper):
allow_any_instance_of(TongsController).to receive(:safe_forge_command).and_return("...")
expect_any_instance_of(TongsController).to receive(:safe_forge_command).with('forge grip dotfiles track "~/.bashrc"')

# AFTER (stubbing new argv-array method):
allow_any_instance_of(TongsController).to receive(:run_forge_argv).and_return("...")
expect_any_instance_of(TongsController).to receive(:run_forge_argv).with(["grip", "dotfiles", "track", "~/.bashrc"])
```

### Delegating to OpenCode (OmO)

Forge plans written to `.hermes/plans/` follow the `writing-plans` skill format and are designed for OpenCode (OmO) execution. The workflow:

1. Hermes writes the plan with bite-sized tasks, exact file paths, complete code, and verification commands
2. OpenCode implements each task sequentially
3. Hermes reviews the resulting diff and patches anything missed or done wrong
4. Final `cargo check` + `cargo clippy` + full test suite verification, then tag and push

**Post-OpenCode review checklist (v1.0.0 lesson):**
- `git diff` all unstaged changes — OpenCode often leaves hardening fixes unstaged
- Run `bundle exec rspec` in hub/ — specs may be stale if OpenCode refactored service classes but didn't update test stubs
- Check `Cargo.toml` version matches intended release version
- Verify all test Config structs include new fields (e.g., `llama_swap_config`) — compiler catches this, but only if you `cargo check`
- Look for TODO comments or `.hermes/plans/` files that reference future work — they may be stale

### Starting the Server

```bash
cd ~/projects/forge/hub
bin/dev    # starts both rails server + tailwindcss:watch via Procfile.dev
# or manually:
bin/rails server -p 3000    # standard Rails default; pass -p 3001 if port is taken
```

## Monorepo Structure

As of v0.2.0, Forge is a monorepo containing both CLI and Hub:

```
~/projects/forge/
├── src/              → Forge CLI (Rust)
├── hub/              → Forge Hub (Rails 8 web app)
├── assets/           → App icon, branding
├── Cargo.toml        → CLI build config
└── hub/Gemfile       → Hub dependencies
```

- The old `synthalorian/forge-hub` GitHub repo is deleted — all code lives in `synthalorian/forge`
- Hub was merged via `git subtree add --prefix=hub forge-hub/main --squash` — history preserved
- `.gitignore` covers both projects (Rust `/target/` + Rails `hub/log`, `hub/tmp`, `hub/app/assets/builds/tailwind.css`)

## Release Process

Can be done automatically via `forge cast` (from the monorepo root) or manually:

1. Build the CLI binary: `cd ~/projects/forge && cargo build --release`
2. Package the Hub: `tar czf forge-hub.tar.gz --exclude='hub/log' --exclude='hub/tmp' --exclude='hub/storage' hub/`
3. Create release with all three assets:
   ```
   gh release create vX.Y.Z \
     target/release/forge \
     forge-hub.tar.gz \
     assets/forge-icon.png \
     --repo synthalorian/forge \
     --title "Forge vX.Y.Z — <subtitle>" \
     --notes "<release notes>"
   ```
4. Verify at `https://github.com/synthalorian/forge/releases/tag/vX.Y.Z`

### Pitfall: Deleting GitHub repos needs a special scope
`gh repo delete` requires the `delete_repo` scope. If you get a 403, run:
```
gh auth refresh -h github.com -s delete_repo
```
This requires browser-based device auth (one-time code). Cannot be done headless.

### Pitfall: `gh release create` fails when tag already exists
If you push tags with `git push --tags` before creating the release, GitHub auto-creates an empty draft release. `gh release create vX.Y.Z` will then fail with `HTTP 422: Release.tag_name already exists`. Fix: use `gh release edit vX.Y.Z --title "..." --notes "..."` instead. Alternatively, create the release before pushing the tag, or use `--draft` flag and publish after.

### Pitfall: Interrupted sub-agent leaves partial changes that break compilation

When a `delegate_task` sub-agent is interrupted (model timeout, rate limit, user message mid-flight), its partial work remains in the working tree as unstaged changes. These changes may compile correctly individually, but the sub-agent was mid-edit — function signatures may not match their call sites, or a CLI enum variant was added but the handler wasn't updated (the most common failure mode).

**Recovery pattern:**
1. `git diff --stat` to see which files the sub-agent touched
2. `git diff -- src/<file>` to see the exact changes
3. `cargo check` to find compile errors
4. The most common break: call site updated (e.g. `run_export(a, b, c)`) but function signature not updated (`fn run_export(a, b)`). Fix the signature/handler.
5. Also check: enum variant added in `cli.rs` but no match arm in handler, or vice versa.

### Pitfall: Pre-existing lint warnings in sub-agent output

Sub-agents may `cargo check` or apply rustfmt changes that produce "Pre-existing lint errors" in the patch tool output. These are format/style changes the sub-agent introduced alongside functional changes — they don't break compilation but make the diff noisy. Verify with `cargo check` (actual compile errors) vs `cargo clippy` (lint suggestions). Both should be clean before committing.

### Pitfall: Stale spec stubs after refactoring to SQL aggregates

When a service class is refactored from loading rows into Ruby and computing in-memory (e.g., `database.backups(limit: 10_000)` → group/sort in Ruby) to delegating to SQL aggregate methods (e.g., `database.top_repos_by_count`, `database.backup_frequency_weeks`, `database.disk_usage_trend`, `database.weekly_backup_counts`), **all specs must be updated to stub the new method names**. The old stubs (`allow(database).to receive(:backups).with(limit: 10_000)`) silently fall through — the double never receives the new method, producing "unexpected message" errors. Fix pattern:
```ruby
# BEFORE (in-memory approach):
allow(database).to receive(:backups).with(limit: 10_000).and_return(raw_rows)
# test asserts on in-memory aggregation of raw_rows

# AFTER (SQL aggregate approach):
allow(database).to receive(:top_repos_by_count).and_return([{name: "alpha", count: 3, total_size: 4500}])
# test asserts on the pre-computed aggregate result
```

### Pitfall: Removing GitHub contributors
`gh api repos/owner/repo/collaborators/username -X DELETE` removes a collaborator, but the "Contributors" section on the GitHub page is cached from commit author history and cannot be force-refreshed. If the person has zero actual commits (all authored by someone else), they'll disappear from the page within hours. If they do have commits, the only way to remove them is rewriting git history.

### Pitfall: Working tree must be clean for git subtree
`git subtree add` refuses if there are uncommitted changes. Stage and commit everything first, then run the subtree command.

- `references/forge-hub-architecture.md` — full file map, key view/controller/service breakdown
- `references/omarchy-palette.md` — canonical Synthwave84 color palette with hex values, CLI mapping, and design rules. Use this when theming Forge Hub or Forge CLI — do not re-extract from Omarchy config files.
- `references/security-audit-v0.3.md` — full surgical audit findings (34 issues) and fix details from GLM-5.1 code review. Use when reviewing new AI-generated code in Forge or auditing similar monorepos.
- `references/rust-panic-audit-methodology.md` — search queries, severity classification, and workflow for auditing Rust panic-safety
- `references/reading-plans.md` — architecture, data structure, and adding new reading plans for `forge word plan` across src/. Use for v0.10.0 remaining fixes and future audits.
- `references/hub-stimulus-patterns.md` — Stimulus controller patterns from the Hub: visual pipeline builder, drag-and-drop upload, and mobile sidebar overlay. Use when adding new Hub interactions.

## GitHub Repo Workflow

Repo is `synthalorian/forge` (monorepo with CLI + Hub).

### Daily workflow
1. Verify `gh auth status` — must be logged in as synthalorian
2. Stage, commit, push from `~/projects/forge/` — Conventional Commits format
3. Verify on GitHub that README renders correctly with icon, tables, code blocks

### Creating a release
See the **Release Process** section above — use `gh release create` with binary + hub tarball + icon.

### Adding a sub-project (future)
If adding another surface (e.g., a TUI), use `git subtree add --prefix=<dir> <remote> <branch> --squash` to merge with history. Ensure working tree is clean first.
