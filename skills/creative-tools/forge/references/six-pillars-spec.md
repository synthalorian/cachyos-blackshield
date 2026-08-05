# Forge — Six Pillars Specification

The architectural vision for Forge beyond Phase 1. Each pillar is a subcommand group with its own metaphor and data store.

## I. Forge Code — The Anvil (`forge anvil`)

Shape projects with iron precision.

### Existing (Phase 1)
- Git backup & archive (zstd + dedup) — `forge anvil backup` / `forge anvil restore`
- Schedule management — `forge anvil schedule`
- Backup listing — `forge anvil list`

### Phase 2 Additions
- **Project scaffolding** — `forge anvil init <template>` generates full project structures for Unity, Unreal, Godot, Flutter, Rust, Rails. Templates are TOML definitions in `~/.forge/templates/`.
- **Multi-agent orchestration** — Route coding tasks to the best agent. Registry of agents (Claude Code, Codex, OpenCode, OpenClaw, Hermes) with capability tags. `forge strike <task>` analyzes the task and dispatches.
- **Cross-project code search** — ripgrep across all registered projects, results ranked by recency.
- **Dependency auditing** — scan Cargo.toml, package.json, pubspec.yaml across projects; flag outdated/vulnerable deps.

## II. Forge Mind — The Bellows (`forge breathe`)

Breathe life into your workflow with AI.

### Key Concepts
- **Agent Harness** — abstraction over multiple AI coding agents. Each agent is a struct implementing a trait: `spawn()`, `send()`, `receive()`, `shutdown()`.
- **Session Management** — agents write state to `agents.db`. `forge breathe` resumes last session.
- **Pipelines** — `forge breathe pipe research→draft→review` chains agent outputs. Each step is a (agent, prompt_template) pair.
- **Credential Vault** — `~/.forge/vault/` stores OAuth tokens and API keys. AES-256 encrypted at rest. Agents request creds through Forge, never directly.
- **Prompt Library** — `~/.forge/prompts/` holds versioned prompt templates. TOML frontmatter + markdown body.
- **Model Switching** — query `forge breathe models` for available local (llama-swap) and cloud models. `forge breathe switch <model>` mid-session.

### Data Store
- `~/.forge/db/agents.db` — agent registry, session state, pipeline history
- `~/.forge/vault/` — encrypted credentials
- `~/.forge/prompts/` — versioned prompt library

## III. Forge Spirit — The Flame (`forge word`, `forge reflect`)

The fire that tempers the steel.

### Key Concepts
- **Scripture Delivery** — `forge word` shows daily verse. Sources a local Bible database (no API dependency). Configurable translation.
- **Verse Search** — `forge word search <query>` — full-text search across books.
- **Cross-References** — `forge word xref <reference>` — linked passages.
- **Prayer Journal** — `forge reflect` opens an encrypted journal. Entries stored in `spirit.db` with AES-256 encryption. Nobody sees it but you and God.
- **Sabbath Mode** — `forge rest` kills every agent, daemon, and background process. Honors the command to rest.

### Scripture References Woven Into Forge
- Genesis 4:22 — Tubal-cain, first named craftsman, forger of tools
- Proverbs 27:17 — "As iron sharpens iron"
- Ephesians 2:10 — *poiēma* (handiwork/poem) — "You are a poem being written"

### Data Store
- `~/.forge/db/spirit.db` — journal entries, bookmarks, daily verse state
- Local Bible text file or embedded SQLite table

## IV. Forge System — The Tongs (`forge grip`)

Grip and shape your environment.

### Key Concepts
- **Theme Engine** (already built) — 12 themes × 12 color slots. `forge grip theme` subcommands.
- **Dotfile Management** — `forge grip dotfiles track <path>` adds to versioned set. `forge grip dotfiles restore` reinstalls. Stored as git repo in `~/.forge/dotfiles/`.
- **System Diagnostics** — `forge grip diagnose` checks CPU, RAM, GPU, disk, running services. Omarchy-inspired.
- **Service Orchestration** — `forge grip services` manages start/stop/restart with dependency ordering.
- **Package Health** — `forge grip health` audits package versions across all registered projects.

### Omarchy Influence
Omarchy manages Arch+Hyprland through a centralized config system. Forge Grip applies the same philosophy to the CLI — one place to see and manage your environment.

## V. Forge Create — The Crucible (`forge melt`)

Where raw material becomes something beautiful.

### Key Concepts
- **Music Helpers** — `forge melt chords <key>` generates progressions. `forge melt scales <key>` shows modes. Music theory from the terminal.
- **Image Generation** — `forge melt image <prompt>` routes to configured backend (ComfyUI, FAL, etc.)
- **ASCII/Diagrams** — `forge melt diagram` creates architecture diagrams. Leverages existing synthclaw ASCII/diagram skills.
- **Markdown Authoring** — `forge melt markdown` opens a markdown editor with live preview in terminal.
- **Transcoding** — `forge melt transcode <input>` converts video/audio formats via ffmpeg.
- **Color Palettes** — `forge melt palette` generates harmonious palettes from a seed color.

## VI. Forge Connect — The Bridge (`forge bridge`)

Link everything together.

### Key Concepts
- **Webhook Management** — `forge bridge hooks` registers/manages webhook endpoints.
- **Notification Hub** — `forge bridge notify` sends to Telegram, Discord, Slack, or desktop. Single interface, multiple backends.
- **API Gateway** — `forge bridge gateway` exposes local services to the network.
- **Calendar Integration** — `forge bridge calendar` reads/writes calendar events.
- **Task Sync** — `forge bridge sync` synchronizes tasks across platforms (Linear, GitHub Issues, Notion, etc.)

---

## Workshop Verbs (Top-Level Commands)

These are not pillar-specific — they're cross-cutting actions any smith would recognize:

| Command | Action | Maps To |
|---------|--------|---------|
| `forge heat` | Spin up agents | Mind → agent startup |
| `forge strike <task>` | Execute via best agent | Mind → task routing |
| `forge quench [path]` | Backup repos | Code → backup |
| `forge temper` | Review & refine | Code → review |
| `forge anneal` | Deep work mode | System → DND |
| `forge alloy <sources>` | Merge agent outputs | Mind → multi-agent |
| `forge cast` | Deploy/release | Code → deploy |
| `forge grind` | Lint & test | Code → quality |
| `forge polish` | Format & document | Code → polish |
