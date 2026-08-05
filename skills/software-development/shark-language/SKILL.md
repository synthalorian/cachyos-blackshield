---
name: shark-language
description: OpenShark — AI coding harness that combines the best of Hermes, OpenShark, Claude Code, Codex, and OpenCode into a single self-improving system. Rust CLI with TUI, persistent memory, universal model routing, and tool execution.
---

# OpenShark 🦞

> The harness that learns. The agent that decides. The tool that doesn't argue.
> Built by synth with synthclaw. 🎹🦞

OpenShark is an open-source AI coding harness — not a programming language. It combines the best features of every harness into a single, self-improving system.

## Repository

`/home/synth/projects/openshark` — Rust CLI project (Cargo, tokio, ratatui)

## What It Actually Is

- **AI coding harness** — chat with models, execute tools, build features
- **Universal model access** — any provider, local or cloud, via OpenAI-compatible API
- **Persistent memory** — SQLite-backed sessions, messages, tool calls
- **Self-improvement engine** — routing optimization based on success data (stub)
- **TUI interface** — keyboard-driven, streaming responses

## Architecture

```
src/
├── main.rs              # CLI entry (clap, async tokio)
├── agent/
│   ├── mod.rs           # Agentic loop: plan → execute → verify → iterate
│   └── soul.rs          # Agent identity/personality system (config-based)
├── cache/
│   └── mod.rs           # Response cache with TTL and disk persistence
├── config/
│   ├── mod.rs           # Config struct, load/save, defaults, FilesystemConfig
│   └── setup.rs         # `openshark setup` wizard
├── gateway/             # Native Discord/Telegram/MCP gateway (replaces hermes/)
│   ├── mod.rs           # GatewayConfig, DiscordConfig, McpGatewayConfig
│   ├── discord.rs       # Serenity-based Discord bot adapter
│   ├── message_router.rs # Routes Discord messages to OpenShark chat engine
│   └── commands.rs      # Slash command definitions and registration
├── image_utils.rs       # Image encoding: file → base64 data URL with MIME detection
├── lsp/
│   └── mod.rs           # LSP client: initialize, symbols, def, hover
├── memory/
│   ├── mod.rs           # Public exports
│   ├── context.rs       # Context injection from memory hierarchy
│   ├── embeddings.rs    # Hash-based semantic vectors
│   ├── hierarchy.rs     # Session → Project → Global layers
│   └── store.rs         # SQLite: sessions, messages, tool_calls
├── providers/
│   └── mod.rs           # Provider with cache, chat(), chat_stream()
├── router/
│   └── mod.rs           # Real routing: task classification, multi-factor scoring
├── skills/              # YAML frontmatter + markdown skills, trigger-based auto-load
│   ├── mod.rs           # Skill, SkillRegistry, format_skills_prompt(), find_triggered()
│   └── builtin/         # Built-in skills: rust, docker, git, testing, debugging
│       ├── rust.md
│       ├── docker.md
│       ├── git.md
│       ├── testing.md
│       └── debugging.md
│   ├── mod.rs           # SecurityEngine: central security gate
│   ├── guardrails.rs    # Prompt injection detection, output validation
│   ├── identity.rs      # Zero-trust identity, scoped credentials
│   ├── pii.rs           # PII detection and redaction
│   └── sandbox.rs       # Working directory isolation + allowed_paths whitelist
├── self_improve/
│   └── mod.rs           # Real analysis: trends, failure patterns, recommendations
├── evolution/
│   └── mod.rs           # Self-evolution engine: memory recall, skill triggering, adaptive thresholds
├── swarm/               # Multi-agent swarm mode (optional, off by default)
│   ├── mod.rs           # SwarmEngine: agent pool, event loop, consensus
│   ├── consensus.rs     # ConsensusMemory: shared doc, approve/reject
│   ├── roles.rs         # RoleTemplate: 8 built-in agent roles
│   └── agent_runner.rs  # AgentRunner: real LLM calls, tool execution, per-agent context
├── tools/
│   ├── mod.rs           # Tool trait, registry, find_tool(), ToolDefinition
│   ├── async.rs         # Async tool execution with timeout
│   ├── detection.rs     # Auto-detect tool suggestions from model output
│   ├── edit.rs          # Multi-file editing: read, write, replace, patch
│   ├── fs.rs            # File system: read, write, list, tree, stat, glob, find, cat
│   ├── git.rs           # Git: status, diff, log, branch, checkout, commit, add
│   ├── lsp.rs           # LSP tool wrapper: symbols, def, hover
│   ├── refactor.rs      # LSP-based refactoring
│   ├── search.rs        # Codebase search: ripgrep + regex fallback
│   ├── terminal.rs      # Shell command execution
│   └── test_runner.rs   # Test runner: auto-detect framework, run/list/watch
├── capabilities/        # Native capability tools (24 tools, no external CLI deps)
│   ├── mod.rs           # CapabilityRegistry — global singleton for all capability tools
│   ├── web.rs           # web, browser, x_search
│   ├── media.rs         # vision, image_gen, video, video_gen, tts
│   ├── memory.rs        # memory, session_search, context_engine
│   ├── productivity.rs  # todo, cronjob, skills
│   ├── communication.rs # messaging
│   ├── smart_home.rs    # homeassistant, spotify
│   ├── platform.rs      # yuanbao, computer_use
│   ├── agentic.rs       # moa, delegation, clarify
│   └── execution.rs     # code_execution
└── tui/
    ├── mod.rs           # Interactive session loop with streaming, sidebar
    ├── theme.rs         # Synthwave '84 palette and style helpers
    └── ascii_art.rs     # Fin logo, wordmark, session header generator
```

## Tool System

Tools implement the `Tool` trait:

```rust
pub trait Tool: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn execute(&self, args: &str) -> Result<String>;
}
```

To add a new tool:
1. Create `src/tools/my_tool.rs`
2. Implement `Tool` trait
3. Add `pub mod my_tool;` to `src/tools/mod.rs`
4. Register in `get_tools()`: `Box::new(my_tool::MyTool)`

### Tool Invocation Format Drift

Models may output `TOOL.tool_name args` (dot) instead of `TOOL:tool_name args` (colon). If the parser only accepts one format, tools silently fail — dead text in chat, 0ms execution time, user thinks it's hung.

**Fix:** Accept both formats everywhere:
- `parse_embedded_tools()` — match `TOOL:` and `TOOL.`
- `strip_tool_lines()` — strip both from display
- `detect_explicit_tool()` regex — `TOOL[:\.]` character class
- System prompts — tell model both formats work
- User input handlers — accept both from manual invocation
- Gateway handlers — parse both in Discord/Telegram responses

**Prevention:** Use helper functions (`is_tool_invocation()`, `parse_tool_invocation_line()`) instead of hardcoding `starts_with("TOOL:")` in multiple places.

**Reference:** `references/tui-tool-separator-quirk.md` (specific fix), `references/tool-invocation-format-drift.md` (full-scope audit pattern)

The `fs` tool supports 8 commands for browsing the filesystem:

| Command | Description |
|---------|-------------|
| `fs read <path>` | Read entire file |
| `fs cat <path> [offset] [limit]` | Read with line numbers + pagination |
| `fs write <path> <content>` | Write content |
| `fs list <path>` | Directory listing with sizes + timestamps |
| `fs tree <path> [depth]` | Recursive tree (default depth 3) |
| `fs stat <path>` | File metadata (size, dates, permissions) |
| `fs glob <pattern>` | Pattern matching (e.g., `**/*.toml`) |
| `fs find <path> <name>` | Find files by name under path |

**User-configurable scope:** `allowed_paths` in `config.toml` restricts which directories the AI can access. Empty = no restriction. The security sandbox enforces this, and the system prompt tells the model which directories it can browse.

**Reference:** `references/filesystem-tool-expansion-pattern.md`
**Reference:** `references/fs-write-auto-create-dirs.md` — `fs write` must auto-create parent directories (same as `edit write`)
**Reference:** `references/tool-json-args-dual-format-pattern.md` — When tools are called via native OpenAI function calling, the model passes JSON arguments. Tools must parse JSON first and fall back to flat string format for backward compatibility.

## Skills System

OpenShark has its own skills system — independent from Hermes.

**Skill Format:** YAML frontmatter + markdown body:
```yaml
---
name: rust
description: Rust programming best practices
triggers:
  - rust
  - cargo
  - tokio
  - lifetime
  - borrow checker
tags:
  - rust
---

# Skill content (markdown)
```

**Architecture:**
- `SkillRegistry` loads from `~/.config/openshark/skills/`
- `find_triggered(query)` — case-insensitive substring matching against triggers
- `format_skills_prompt()` — converts skills to system prompt text
- Two-stage injection: (1) all skills in base system prompt, (2) triggered skills per-message

**Built-in skills** (embedded via `include_str!`, auto-extracted on first run):
| Skill | Triggers |
|-------|----------|
| `rust` | rust, cargo, rustc, tokio, async rust, lifetime, borrow checker |
| `docker` | docker, container, dockerfile, compose, image, containerize |
| `git` | git, commit, branch, merge, rebase, pull request, pr, github |
| `testing` | test, testing, unittest, mock, fixture, tdd, coverage |
| `debugging` | debug, debugging, breakpoint, trace, log, error, panic, stack trace, gdb, lldb |

**User skills:** Drop `.md` files in `~/.config/openshark/skills/user/` — same format, auto-loaded.

**Reference:** `references/skills-system-architecture.md`

## Commands

```bash
cd /home/synth/projects/openshark

# Start TUI with streaming
cargo run --

# Swarm mode (optional, off by default)
openshark swarm init "Build a REST API with auth"  # Spawn role-based agents
openshark swarm start                               # Start autonomous loop
openshark swarm stop                                # Halt all agents
openshark swarm status                              # Show swarm state

# List all available tools (native + capability + MCP)
openshark tools list

# Development build (fast compile, unoptimized)
cargo build

# Release build AND install to ~/.local/bin (preferred for testing)
cargo build --release
cp target/release/openshark ~/.local/bin/openshark
# OR use cargo install (builds release + copies to ~/.cargo/bin or ~/.local/bin)
cargo install --path . --force

# Verify installed binary
~/.local/bin/openshark --version

# Configure providers + agent identity
cargo run -- setup
```
# View routing decisions
cargo run -- route

# Trigger self-improvement analysis
cargo run -- learn

# Security status and audit
cargo run -- security status
cargo run -- security audit
cargo run -- security test

# Hermes integration status
cargo run -- hermes status
cargo run -- hermes skills
cargo run -- hermes platforms

# Search memory
cargo run -- memory "auth"
cargo run -- memory --recent --limit 10
cargo run -- memory "auth" --semantic

# Run tests (auto-detects framework)
cargo run -- test run .
cargo run -- test list .

# Release build
cargo build --release
```

## Config & Data Locations

- Config: `~/.config/openshark/config.toml`
- Security: `~/.config/openshark/security.toml`
- Memory: `~/.local/share/openshark/memory.db`
- Cache: `~/.cache/openshark/response_cache.json`

## Setup System

OpenShark has its own setup wizard that can also import config from Hermes and OpenShark.

```bash
openshark setup                              # Interactive setup wizard
openshark setup --migrate-from hermes        # Import Hermes config
openshark setup --migrate-from openshark      # Import OpenShark config
openshark setup --migrate-from hermes --dry-run   # Preview only
```

**Setup Flow:**
```
1. DETECT  → 2. INSTALL DEPS (if needed)  → 3. AUTO-CONFIGURE  → 4. TEST  → 5. DONE
```

**Step 1 — Detect:** Check Rust toolchain, existing config. Detect Hermes (`~/.hermes`) and OpenShark (`~/.openshark`) for optional config transfer.

**Step 2 — Install:** Rust toolchain (if missing), build dependencies.

**Step 3 — Auto-Configure:** Write `~/.config/openshark/config.toml`, create data dirs, generate shell completions.

**Step 4 — Test:** Verify binary builds, test provider connectivity, test memory DB init.

**Step 5 — Done:** Summary, quick-start commands, offer to launch TUI.

### Config Transfer (Optional)

```bash
openshark setup --migrate-from hermes        # Hermes → OpenShark
openshark setup --migrate-from openshark      # OpenShark → OpenShark
```

| Source | OpenShark Destination | Content |
|--------|----------------------|---------|
| `~/.hermes/SOUL.md` | `~/.config/openshark/SOUL.md` | User persona |
| `~/.hermes/memory/` | `~/.local/share/openshark/memory/` | Memory entries |
| `~/.hermes/skills/` | `~/.config/openshark/skills/` | Skills |
| `~/.openshark/SOUL.md` | `~/.config/openshark/SOUL.md` | User persona |
| `~/.openshark/MEMORY.md` | `~/.local/share/openshark/memory/` | Knowledge |
| `~/.openshark/skills/` | `~/.config/openshark/skills/` | Skills |

## Doctor — Auto-Repair System

`openshark doctor` detects and fixes broken components automatically.

```bash
openshark doctor              # Full diagnostic + auto-fix
openshark doctor --check      # Diagnostic only, no fixes
openshark doctor --fix        # Apply all fixes without prompting
openshark doctor --component gateway   # Check/fix only gateway
openshark doctor --component mcp      # Check/fix only MCP
openshark doctor --component skills   # Check/fix only skills
openshark doctor --component memory   # Check/fix only memory
openshark doctor --component providers # Check/fix only providers
```

**What doctor checks and fixes:**

| Component | Checks | Fixes |
|-----------|--------|-------|
| **Config** | Valid TOML, required fields | Rewrite missing fields with defaults |
| **Providers** | API keys valid, endpoints reachable | Regenerate env files, test connectivity |
| **Memory DB** | SQLite exists, schema current | Recreate from schema, rebuild embeddings |
| **Cache** | File exists, not oversized | Clear stale entries, rebuild if corrupted |
| **Gateway** | Process running, platforms connected | Restart gateway, refresh tokens |
| **MCP** | Servers configured, connections active | Re-register servers, restart connections |
| **Skills** | Directory exists, YAML valid | Re-index, remove duplicates |
| **Self-Improve** | Metrics collecting, trends analyzable | Rebuild metrics DB, re-seed baseline |
| **Discord/Telegram** | Tokens valid, connected | Regenerate tokens, re-request permissions |
| **Rust Build** | Cargo lock valid, binary builds | `cargo update`, clear fingerprints, rebuild |

## Config Structure

```toml
version = "0.2.0"
default_model = "kimi-k2.6"
auto_route = true
cost_limit_usd = 10.0

[swarm]
enabled = false
max_agents = 8
consensus_required = true
consensus_mode = "majority"  # majority, unanimous, leader_decides
cycle_limit = 50
roles = ["architect", "implementer", "reviewer", "tester"]
auto_spawn = false

[filesystem]
allowed_paths = ["/home/synth"]
max_file_size_mb = 10
max_list_entries = 500
```
[agent]
name = "synthclaw"
display_name = "synthclaw"
role = "synthesis engine"
origin = "Born from the VHS tracking static of 1984"
purpose = "To build, debug, and ship code with surgical accuracy"
tagline = "Write the future in the present while preserving the past."
tone = "Neon-lit confidence, retro warmth, technical precision"
style = "Direct. No fluff. Gets to the point. But with soul."
greeting = "Ready to build. What are we shipping today?"
farewell = "Code shipped. On to the next. The tape never stops rolling."
emoji = "🎹🦞"
catchphrases = ["This is the wave.", "The grid is endless."]
behavioral_rules = [
    "Always verify before claiming success",
    "Show the code, don't just describe it",
]

[hermes_integration]
enabled = false
hermes_home = "~/.hermes"
gateway_enabled = true
discord_enabled = true
telegram_enabled = false
skills_enabled = true
memory_bridge_enabled = true
mcp_enabled = true
tool_calling_enabled = true

[providers.kimi]
base_url = "http://127.0.0.1:8699/v1"
api_key = "${KIMI_API_KEY}"
kind = "open_ai_compatible"

[[providers.kimi.models]]
name = "kimi-k2.6"
context_length = 256000
cost_per_1k_input = 0.0
cost_per_1k_output = 0.0
capabilities = ["code", "chat", "analysis"]
```

## Current Status (v1.0.0)

| Phase | Status | Features |
|-------|--------|----------|
| 1 Core Engine | ✅ | Chat, SQLite memory, basic tools |
| 2 Coding Depth | ✅ | Search, git, edit, lsp, test, refactor tools. Streaming TUI. |
| 3 Real Memory | ✅ | Vector embeddings, memory hierarchy, context injection, natural queries |
| 4 Agent Autonomy | ✅ | Auto-tool detection, agentic loop, parallel execution, error recovery |
| 5 Speed & Polish | ✅ | Streaming ✅, async tools ✅, connection pool ✅, response cache ✅, TUI polish ✅ |
| 6 Distribution | ✅ | Stats, custom tools, session branching |
| 7 Agent Identity | ✅ | Config-based name, personality, emoji, TUI branding, setup wizard |
| 8 Self-Evolution | ✅ | `EvolutionEngine` with memory recall, skill triggering, adaptive tool thresholds, model bias tracking |
| 9 Infrastructure | ✅ | Native Discord gateway, Telegram, Slack scaffold, Matrix scaffold. Skills system. Multi-model mode. Native MCP client. Multi-platform gateway. |
| 10 Themes | ✅ | 24 preset themes (synthwave84 default). Ctrl+T cycling. Config persistence. |
| 11 Dead Code Cleanup | ✅ | 128→0 warnings. Hermes runtime dependency removed. |
| 12 Swarm Mode | ✅ | Optional multi-agent swarming with real LLM calls, consensus memory, 8 built-in roles. Off by default. |
| 13 Context Compression | ✅ | Automatic context summarization when token usage exceeds threshold. Preserves system prompt + recent N exchanges. |
| 14 Security | ✅ | 4-layer security: sandbox, identity, PII, guardrails. CODING MODE defaults (git/search/test/fs all Allow). Autonomous mode (Ctrl+A). |
| 15 v1.0.0 Ship | ✅ | 337 tests passing. Release binary. GitHub repo public. Shark emoji in tagline. 🦞🎹 |
| 16 Capability Suite | ✅ | 24 native capability tools (web, media, memory, productivity, communication, smart home, platform, agentic, execution). 32 total tools. Zero Hermes CLI dependency. |
| 17 Swarm Contention Fix | ✅ | TUI guard blocks chat during swarm, staggered agent starts (2s), timeout bumped to 180s. |
| 18 Swarm Streaming | ✅ | Real-time per-agent chunk streaming with role-colored headers, Inspector sidebar tab, syntax highlighting. |
| 19 Persona Filter | ✅ | Strips "I am the X agent" self-convincing preamble from agent responses. 500+ pattern coverage. |
| 20 Collapsible Tools | ✅ | Expandable tool results in Agent Inspector sidebar. |
| 21 Code Visibility | ✅ | ALL code blocks syntax-highlighted with borders in both main chat and swarm streaming. Never plain text. |

## OpenShark Gateway (Native Discord)

OpenShark runs its own Discord gateway using **serenity 0.12**. No Hermes required.

## OpenShark Gateway (Native Discord)

OpenShark runs its own Discord gateway using **serenity 0.12**. No Hermes required.

### Native Message Responses (Free-Form Chat)

In addition to slash commands, OpenShark responds to **all regular messages** by default (free-form chat mode):

**Keyword commands** (prefix `!`, bypass LLM):
| Command | Action |
|---------|--------|
| `!model` / `!model <name>` | List or switch models |
| `!tools` | List available tools |
| `!status` | Show bot status |
| `!help` | Command reference |
| `!new` | Start fresh conversation |
| `!reset` | Reset to defaults |
| `!multi` | Toggle multi-model mode |
| `!multi on/off` | Enable/disable multi-model |
| `!multi <model1, model2>` | Set secondary models |

**Natural language memory queries** (bypass LLM, query memory directly):
- "What did we do about X?"
- "How did we solve X?"
- "Tell me about X"
- "What was the issue with X?"
- "Remember when we..."
- "Do you recall..."

**Automatic memory recall:** Every inbound message searches the memory store (semantic + keyword) and injects relevant context as a system message before the LLM call.

**Dynamic skill injection:** Triggered skills are loaded per-message based on keyword matching and injected as additional system context.

**Reference:** `references/discord-native-message-responses.md`

### Slash Commands (15 commands)

| Command | Description |
|---------|-------------|
| `/chat message:<text>` | Chat with OpenShark |
| `/new` | Start fresh conversation (clear history) |
| `/system prompt:<text>` | Set custom system prompt |
| `/reset` | Reset to defaults |
| `/model name:<model>` | List or switch model |
| `/models` | Detailed model list |
| `/multi` | Multi-model mode control (on/off/toggle/set) |
| `/agent task:<desc>` | Run autonomous agent task |
| `/tools` | List available tools |
| `/tool name:<tool> args:<args>` | Execute tool directly |
| `/memory query:<text>` | Search conversation memory |
| `/remember fact:<text>` | Save fact to memory |
| `/status` | Bot status for this channel |
| `/stats` | Usage statistics |
| `/settings key:<k> value:<v>` | View/change settings |
| `/help` | Command reference |

### Architecture

```
Discord Gateway (serenity 0.12)
  │
  ├─ Handler::interaction_create()
  │   ├─ Defer response immediately (3s timeout protection)
  │   ├─ Send DiscordEvent::SlashCommand via mpsc
  │   └─ Collect reply_tx chunks → CreateInteractionResponseFollowup
  │
  ├─ Handler::message() → Send DiscordEvent::UserMessage
  │
  └─ Handler::ready() → Register slash commands (global or guild)

MessageRouter::handle_slash_command()
  ├─ Match command name
  ├─ Get/update ChannelState (per-channel isolation)
  └─ Execute → Send response via reply_tx
```

### Per-Channel State

Each Discord channel gets isolated conversation state via `ChannelState` + `ChannelStateStore`:
- Independent history, model, system prompt
- Thread-safe `Arc<Mutex<HashMap<u64, ChannelState>>>`
- `max_history` trimming (default 20 messages)

### Deferred Responses

All slash commands **defer immediately** to avoid Discord's 3-second timeout. Critical for `/agent` and `/chat` which can take seconds. After deferring, use `create_followup` (not `create_response`).

### Threading Model

Discord gateway runs on a **dedicated OS thread** with its own tokio runtime. `MessageRouter` contains `rusqlite::Connection` (not `Send`/`Sync`), so a dedicated thread avoids the constraint.

```rust
std::thread::spawn(move || {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut event_rx = gateway::discord::spawn_bot(config.clone());
        let mut router = gateway::message_router::MessageRouter::new(config).unwrap();
        while let Some(event) = event_rx.recv().await {
            router.handle_event(event).await;
        }
    });
});
```

### Config

```toml
[gateway.discord]
enabled = true
bot_token = "${DISCORD_BOT_TOKEN}"
application_id = "${DISCORD_APP_ID}"
guild_ids = []           # empty = global commands
allowed_channels = []    # empty = all channels
require_mention = false  # default: free-form chat (respond to ALL messages)
command_prefix = "!shark"
max_message_length = 2000
typing_indicator = true
multi_model_enabled = false       # default: off (opt-in for lower latency/cost)
multi_model_secondary = []        # e.g., ["gpt-4o", "claude-sonnet-4"]
```

**Free-form chat mode** (`require_mention = false`): The bot responds to every message in allowed channels without needing `@mention` or `!shark` prefix. Set to `true` for legacy mention-only behavior.

**Optional multi-model mode** (`multi_model_enabled = false`): When enabled, queries primary + secondary models simultaneously and formats a comparison response. Off by default to keep latency and cost low. Toggle at runtime via `/multi` or `!multi`.

- `references/discord-native-message-responses.md` — Keyword commands, natural language memory queries, automatic memory recall, ContextInjector trait
- `references/skills-system-architecture.md` — YAML frontmatter skills, trigger matching, two-stage injection, built-in skill embedding

## MCP Server Integration

OpenShark acts as an MCP client — discovers and calls tools from any MCP server.

```bash
openshark mcp list            # List configured MCP servers
openshark mcp add <name>      # Add MCP server
openshark mcp remove <name>   # Remove MCP server
openshark mcp test <name>     # Test server connection
openshark mcp tools <name>    # List tools from server
```

**Config:**
```toml
[[mcp.servers]]
name = "filesystem"
type = "stdio"
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "/home/synth"]

[[mcp.servers]]
name = "github"
type = "sse"
url = "http://localhost:3000/sse"
```

## Skills System

OpenShark has its own skills system — independent from Hermes.

```bash
openshark skills list         # List installed skills
openshark skills search       # Search skills hub
openshark skills install      # Install skill from hub
openshark skills update       # Update all skills
openshark skills remove       # Remove skill
```

**Skill Format:**
```yaml
---
name: my-skill
description: What this skill does
triggers:
  - keyword1
  - keyword2
tags:
  - rust
  - web
---

# Skill content (markdown)
```

**Skill Directories:**
- Built-in: `~/.config/openshark/skills/builtin/`
- User: `~/.config/openshark/skills/user/`
- Hub: `~/.config/openshark/skills/hub/`

## Self-Improvement Engine

OpenShark analyzes its own performance and suggests improvements.

```bash
openshark learn               # Run self-improvement analysis
openshark learn --report      # Generate improvement report
openshark learn --apply       # Apply recommended changes
```

**What it tracks:**
- Tool success/failure rates per tool
- Model performance per task type
- Response latency trends
- Memory retrieval accuracy
- User correction patterns

**What it improves:**
- Routing weights (which model for which task)
- Tool selection confidence thresholds
- Memory embedding quality
- Context compression strategies

## Self-Evolution Engine

OpenShark's `EvolutionEngine` (`src/evolution/mod.rs`) enables real-time adaptive behavior:

**Per-message enrichment:**
- Memory recall — injects top 3 semantically similar past conversations
- Skill triggering — auto-loads skills matching query keywords
- Adaptive guidance — injects current tool confidence thresholds

**Dynamic adaptation:**
- Tool confidence thresholds adjust based on success/failure history
- Model performance bias tracks per-model, per-task-type outcomes
- Session counter triggers self-analysis every 20 sessions

**Real-time inspection:**
- `/evolution` TUI command — prints current `AdaptiveState` summary:
  - Total sessions, sessions since analysis
  - Tool confidence thresholds with 🟢 auto / 🟡 confirm / 🔒 manual status
  - Model performance bias scores

**Architecture:** See `references/evolution-engine-architecture.md`

**Testing:** 6 unit tests covering threshold adjustment, bias tracking, session counting

- `references/tui-metrics-debugging-pattern.md` — Diagnosing and fixing stuck TUI metrics: token counting, context estimation, performance panel fallback for non-streaming paths, swarm agent timeouts.
- `references/native-capability-tool-suite-pattern.md` — Full architecture for 24 native capability tools, registry integration, lazy activation, and adding new tools.
- `references/tui-metrics-debugging-pattern.md` — Diagnosing and fixing stuck TUI metrics: token counting, context estimation, performance panel fallback for non-streaming paths, swarm agent timeouts.

## Commands

Use `env!("CARGO_PKG_VERSION")` in the CLI so `--version` always matches `Cargo.toml`:

```rust
#[derive(Parser)]
#[command(name = "openshark")]
#[command(version = env!("CARGO_PKG_VERSION"))]  // NOT a hardcoded string
struct Cli { ... }
```

**Version bump workflow:**
1. Update `version = "x.y.z"` in `Cargo.toml`
2. Update `CHANGELOG.md` (Keep a Changelog format)
3. `cargo build --release`
4. **Copy binary to PATH:** `cp target/release/openshark ~/.local/bin/openshark`
5. Verify: `openshark --version`

See `/home/synth/projects/openshark/ROADMAP.md` for full phase breakdown.

## TUI Branding & ASCII Art

The TUI and README feature ASCII art branding. Critical: verify the art actually spells the project name.

### Verification Checklist

Before shipping, run this check:
```bash
python3 -c "import pyfiglet; print(pyfiglet.figlet_format('OpenShark', font='standard'))"
```
Compare against the README/TUI art. If they don't match, the art is wrong.

**Common failure:** Hand-edited or copied art from a different project. The current README had art that spelled "Acraskhox" instead of "OpenShark" — only caught by user review before v1.0.0 ship.

**If pyfiglet isn't available:** Use an online figlet generator or trace each letter manually:
- `O` — round, `/ \_\` shape
- `p` — vertical stem with loop on right
- `e` — horizontal bar with curve
- `n` — two vertical strokes with diagonal
- `S` — two curves, top and bottom
- `h` — vertical stem with right-side loop
- `a` — circle with right tail
- `r` — vertical stem with top-right curve
- `k` — vertical stem with two diagonal arms

**When in doubt:** Use a banner image (`openshark.png`) instead of ASCII art. Less error-prone and more visually striking.

### Sidebar Branding

- Harness name (top-left): `🦞 openshark v{version}` — hardcoded product brand
- Agent identity: `emoji display_name — role` — configurable via `[agent]` config
- Tagline: displayed under agent name

See `references/tui-ascii-art-verification.md` for full details.

## Theme System (24 Presets)

OpenShark has a dynamic multi-theme system with 24 presets, cycling via **Ctrl+T** in the TUI.

### Theme Categories

| Category | Themes |
|----------|--------|
| **Core** | `synthwave84` (default), `light`, `dark`, `white`, `vantablack`, `matte-black` |
| **Omarchy Dark** | `catppuccin`, `tokyo-night`, `gruvbox`, `nord`, `everforest`, `kanagawa`, `rose-pine`, `miasma`, `ethereal`, `ristretto`, `osaka-jade` |
| **Omarchy Light** | `lumon`, `flexoki-light` |
| **Synthwave** | `outrun`, `hotline`, `sunset`, `midnight`, `cyberpunk` |
| **Specialty** | `hackerman`, `retro-82` |

### Implementation

```rust
// src/tui/theme.rs
pub struct Theme {
    pub name: String,
    pub background: Color,
    pub foreground: Color,
    pub accent: Color,
    pub accent_secondary: Color,
    pub highlight: Color,
    pub muted: Color,
    pub error: Color,
    pub success: Color,
    pub border_focused: Color,
    pub border_unfocused: Color,
    pub title: Color,
    pub selected_bg: Color,
    pub selected_fg: Color,
    pub row_alt_bg: Color,
    pub tool: Color,
    pub user_name: Color,
    pub agent_name: Color,
}
```

- Global state via `RwLock<Option<Theme>>` — `set_theme()` / `current_theme()`
- All style helpers (`bg_style()`, `text_style()`, `accent_style()`, etc.) read from `current_theme()` dynamically
- Config field: `theme = "synthwave84"` in `~/.config/openshark/config.toml`
- Theme initializes from config on TUI startup

### Adding a New Theme

1. Add `pub fn my_theme() -> Self` to `Theme` impl in `src/tui/theme.rs`
2. Add `Self::my_theme()` to `all_presets()` vec
3. Done — Ctrl+T will cycle to it automatically

### Keybinding

- **Ctrl+T** — Cycle to next theme
- Status message shows: `🎨 Theme: outrun`

## TUI Keybindings Help

The `help` command and sidebar both display keybindings:

**Chat commands:** help, tools, history, context, clear, exit
**Model commands:** /models, /model <name>, /multi
**Image commands:** /image <path> — Attach image to next message
**Branch commands:** /branch <name>, /branches, /switch <index>
**Evolution commands:**
• /evolution        — Show adaptive state (tool confidence, model bias, session stats)

**Keybindings:**
- Ctrl+C — Quit (double-tap within 2s)
- Ctrl+V — Paste from system clipboard
- Ctrl+L — Clear chat
- Ctrl+B — Toggle sidebar
- Ctrl+P — Model selector (was Ctrl+M — terminal intercepts Ctrl+M as carriage return)
- Ctrl+A — Toggle autonomous mode
- Ctrl+T — Cycle theme
- Ctrl+S — Toggle Tools/Skills sidebar tab
- ↑ / ↓ — Scroll (chat or sidebar items when focused)
- PgUp / PgDn — Fast scroll (chat or sidebar items when focused)

**Terminal keybinding conflicts:** `Ctrl+M` = Enter, `Ctrl+I` = Tab, `Ctrl+H` = Backspace, `Ctrl+J` = Enter, `Ctrl+[` = Escape. These are intercepted by the terminal and never reach the application. Use `Ctrl+P`, `Ctrl+B`, `Ctrl+A`, `Ctrl+T` instead. See `references/terminal-keybinding-conflicts.md`.

### Scope-Matching System Prompt (Prevent Over-Elaboration)

When models have access to their own reasoning or extensive system context, they tend to "synthesize the entire system architecture" even for simple prompts like "test" or "hello". The user explicitly rejected this behavior.

**Add to system prompt:**
```
Match your response scope to the request complexity. For simple prompts ("test", "hello", single-word queries), give brief, direct answers. Do not synthesize the entire system architecture unless asked.
```

**Placement:** Inject this as the LAST instruction in the system prompt (after identity, rules, and skills) so it overrides any tendency toward over-elaboration.

**Why this works:**
- Models treat the final instruction as highest priority
- Explicit permission to be brief removes the "I must be thorough" bias
- "Unless asked" gives the model clear criteria for when elaboration is appropriate

**When to add:**
- Any harness with reasoning display (models see their own thinking and expand)
- Any harness with large system prompts (models feel compelled to use all context)
- Any harness where users frequently send short prompts

### TUI Context Window Tracking

The sidebar shows `Max Ctx` and `Ctx Used` with a color-coded percentage:
- Green (<50%) — safe
- Yellow (50-80%) — caution
- Red (>80%) — danger, may truncate

See `references/tui-context-tracking-pattern.md`

### Scope-Matching System Prompt (Prevent Over-Elaboration)

When models have access to their own reasoning or extensive system context, they tend to "synthesize the entire system architecture" even for simple prompts like "test" or "hello". The user explicitly rejected this behavior.

**Add to system prompt:**
```
Match your response scope to the request complexity. For simple prompts ("test", "hello", single-word queries), give brief, direct answers. Do not synthesize the entire system architecture unless asked.
```

**Placement:** Inject this as the LAST instruction in the system prompt (after identity, rules, and skills) so it overrides any tendency toward over-elaboration.

**Why this works:**
- Models treat the final instruction as highest priority
- Explicit permission to be brief removes the "I must be thorough" bias
- "Unless asked" gives the model clear criteria for when elaboration is appropriate

**When to add:**
- Any harness with reasoning display (models see their own thinking and expand)
- Any harness with large system prompts (models feel compelled to use all context)
- Any harness where users frequently send short prompts

**Reference:** `references/tui-real-time-reasoning-display.md`

## TUI Tabbed Sidebar

`Ctrl+S` toggles between **Tools** and **Skills** tabs. Shows count in title (`Tools [9]`). Scrollable with ↑/↓ when sidebar is focused. See `references/tui-tabbed-sidebar-pattern.md`

## TUI Per-Session Performance

Metrics reset each session instead of accumulating globally. See `references/tui-per-session-metrics-pattern.md`

## Hermes Integration (Setup-Only)

OpenShark's setup wizard can import config from Hermes, but there is **no runtime dependency** on Hermes. The `src/hermes/` module was removed. Native Discord/MCP implementations will replace the bridge entirely.

```bash
openshark setup  # Interactive setup, includes optional Hermes config import
```

**Config fields preserved (for compatibility):**
```toml
[hermes_integration]
enabled = false
hermes_home = "~/.hermes"
gateway_enabled = true
discord_enabled = true
# ... etc
```

**Runtime commands removed:** `openshark hermes status`, `openshark hermes skills`, `openshark hermes platforms`

## OpenShark Gateway (Multi-Platform)

OpenShark runs its own native gateways for multiple messaging platforms. No Hermes required.

| Platform | Status | Crate | Notes |
|----------|--------|-------|-------|
| **Discord** | ✅ Full | `serenity` 0.12 | Free-form chat, slash commands, keyword commands, memory recall |
| **Telegram** | ✅ Full | `teloxide` 0.17 | Bot API polling, reply sender with `Bot` instance, 4096-char chunking |
| **Slack** | 🟡 Scaffold | `slack-morphism` 2.22 | Socket Mode structure, `SlackReplySender`, validates tokens |
| **Matrix** | 🟡 Scaffold | `matrix-sdk` 0.17 | Sync loop structure, `MatrixReplySender`, validates config |

### Reply Sender Pattern (All Platforms)

Each non-Discord platform uses a **ReplySender** struct to send responses back:

```rust
// telegram.rs
#[derive(Clone)]
pub struct TelegramReplySender {
    pub bot: Bot,  // teloxide::Bot
}

impl TelegramReplySender {
    pub async fn send_message(&self, chat_id: i64, text: &str) {
        const MAX_LEN: usize = 4096;  // Telegram limit
        // chunk and send...
    }
}

// spawn_bot returns (event_rx, reply_sender)
pub fn spawn_bot(config: Config) -> (mpsc::UnboundedReceiver<TelegramEvent>, TelegramReplySender)
```

**Why this pattern:** The `Bot` (or equivalent client) must be available in the reply task. Events flow one way (bot → router), but replies need the bot to send messages back. The `spawn_bot` function creates both the event receiver and the reply sender, and `main.rs` passes the sender to `UnifiedRouter::handle_telegram_event(event, &reply_sender)`.

**UnifiedRouter wiring:**
```rust
pub async fn handle_telegram_event(
    &mut self,
    event: TelegramEvent,
    reply_sender: &TelegramReplySender,
) {
    match event {
        TelegramEvent::UserMessage { chat_id, ... } => {
            let (reply_tx, mut reply_rx): (mpsc::UnboundedSender<String>, mpsc::UnboundedReceiver<String>) =
                mpsc::unbounded_channel();

            let sender = reply_sender.clone();
            tokio::spawn(async move {
                while let Some(reply) = reply_rx.recv().await {
                    sender.send_message(chat_id, &reply).await;
                }
            });

            let discord_event = DiscordEvent::UserMessage {
                channel_id: chat_id as u64,
                reply_tx,
                ...
            };
            self.inner.handle_event(discord_event).await;
        }
        ...
    }
}
```

**Critical:** The `mpsc::unbounded_channel()` needs explicit type annotation `(mpsc::UnboundedSender<String>, mpsc::UnboundedReceiver<String>)` or the compiler infers `str` and fails with "size not known at compile time."

All platforms normalize to `DiscordEvent` format via `UnifiedRouter`, reusing the existing `MessageRouter` (1000+ lines of battle-tested logic):

```
Discord ──┐
Telegram ─┼──→ UnifiedRouter ──→ MessageRouter ──→ OpenShark engine
Slack ────┤         (normalize)      (memory, skills, tools)
Matrix ───┘
```

**Why this pattern:** The `MessageRouter` has deep logic (memory injection, skill loading, tool execution, multi-model). Rather than duplicating it per platform, `UnifiedRouter` converts each platform's event type into `DiscordEvent::UserMessage` with a `reply_tx` channel. Responses stream back via the same channel.

**PlatformEvent abstraction:** `src/gateway/platform.rs` defines `Platform`, `PlatformEvent`, `UserMessage`, and `Gateway` trait. All gateways implement the same event shape.

**Config per platform:**
```toml
[gateway.discord]
enabled = true
bot_token = "${DISCORD_BOT_TOKEN}"
# ... (see Discord section above)

[gateway.telegram]
enabled = false
bot_token = "${TELEGRAM_BOT_TOKEN}"
allowed_chats = []        # empty = all chats
require_command_prefix = false

[gateway.slack]
enabled = false
bot_token = "xoxb-..."
app_token = "xapp-..."    # required for Socket Mode
allowed_channels = []

[gateway.matrix]
enabled = false
homeserver = "https://matrix.org"
user_id = "@openshark:matrix.org"
access_token = "syt_..."
allowed_rooms = []
```

**Wiring in main.rs:** Each enabled gateway spawns on its own OS thread with a dedicated tokio runtime (same pattern as Discord). Events flow through `UnifiedRouter` into `MessageRouter`.

**Env var resolution:** All gateway tokens support `${VAR}` syntax (e.g., `bot_token = "${DISCORD_BOT_TOKEN}"`). Resolved at config load time via `Config::resolve_gateway_tokens()`. Enables 12-factor config — safe to share config files without leaking tokens.

**Reference:** `references/multi-platform-gateway-architecture.md`

## MCP Client Integration (Native — Implemented)

OpenShark has a **native MCP client** — no Hermes bridge, no shell-outs. Discovers and calls tools from any MCP server via JSON-RPC 2.0.

### Architecture

```
src/mcp/
├── protocol.rs    # JSON-RPC 2.0 types + MCP structs (Initialize, tools/list, tools/call)
├── transport.rs   # StdioTransport (subprocess) + SseTransport (HTTP/SSE)
└── mod.rs         # McpConnection (single server) + McpManager (multi-server pool)
```

**McpConnection lifecycle:**
1. Spawn subprocess (stdio) or connect HTTP endpoint (SSE)
2. `initialize` handshake — negotiate protocol version, exchange capabilities
3. `tools/list` — discover available tools
4. `tools/call` — execute tools with JSON arguments
5. `close()` — graceful shutdown

**McpManager:** Manages multiple concurrent connections. `connect_all()` connects to all configured servers. `call_tool()` routes by tool name across all servers.

### Config

```toml
[gateway.mcp]
enabled = true

[[gateway.mcp.servers]]
name = "filesystem"
transport = { stdio = { command = "npx", args = ["-y", "@modelcontextprotocol/server-filesystem", "/home/synth/projects"] } }

[[gateway.mcp.servers]]
name = "github"
transport = { sse = { url = "http://localhost:3000/sse" } }
```

### Tool Adapter

MCP tools are wrapped as OpenShark `Tool` trait objects via `McpToolAdapter`:
- Implements `Tool::execute()` by calling `McpManager::call_tool()`
- Handles JSON argument parsing (object → string fallback)
- Formats `CallToolResult` into human-readable text

**Async-to-sync bridge:** `Tool::execute` is synchronous, but MCP calls are async. The adapter uses `tokio::task::block_in_place` when already in an async context, or creates a new runtime as fallback:

```rust
let rt = tokio::runtime::Handle::try_current();
match rt {
    Ok(handle) => {
        tokio::task::block_in_place(|| {
            handle.block_on(async move {
                manager.lock().await.call_tool(&name, arguments).await
            })
        })
    }
    Err(_) => {
        let rt = tokio::runtime::Runtime::new()?;
        rt.block_on(async move { ... })
    }
}
```

### CLI Commands

```bash
openshark mcp status    # Show configured servers and connection status
openshark mcp tools     # Show tool discovery info
```

### TUI Integration

- Auto-connects MCP servers on TUI startup (if `gateway.mcp.enabled`)
- Displays connection status: `🔌 MCP server <name> ✅ — N tools discovered`
- Graceful disconnect on TUI exit

### Transport Enum Pattern (Dyn Compatibility)

Rust async traits are not dyn-compatible. Instead of `Box<dyn Transport>`, OpenShark uses an enum:

```rust
pub enum McpTransport {
    Stdio(StdioTransport),
    Sse(SseTransport),
}

impl McpTransport {
    pub async fn send_request(&mut self, req: &JsonRpcRequest) -> Result<String> {
        match self { Self::Stdio(t) => t.send_request(req).await, ... }
    }
}
```

This avoids the `async-trait` crate and the "trait is not dyn compatible" error entirely.

### Testing

Verified end-to-end against `@modelcontextprotocol/server-filesystem`:
- ✅ `initialize` handshake
- ✅ `tools/list` — 14 tools discovered
- ✅ `tools/call` — `list_directory` executed successfully
- ✅ 304 tests passing (5 new protocol unit tests)

## Dead Code Cleanup

Systematic approach documented in `references/dead-code-cleanup-workflow.md`. Key lessons:
- `cargo fix` for easy wins (~30% of warnings)
- Module-level `#[allow(dead_code)]` for future-utility APIs
- Targeted `#[allow(dead_code)]` on specific items with planned consumers
- Remove only genuinely obsolete code
- Always run `cargo test` after cleanup — some "dead" code is test-only

## Provider System (Multi-Backend)

OpenShark supports multiple LLM backends through a unified `Provider` abstraction, modeled after claw-code's prefix-based routing with env-file key management:

```rust
pub enum ProviderKind {
    OpenAiCompatible,  // OpenAI, OpenRouter, llama-swap, Kimi proxy, Z.AI, Grok (90% of providers)
    Anthropic,         // Claude API (native messages format)
    Gemini,            // Google Gemini (contents format)
}
```

Each provider carries:
- `base_url` — endpoint URL
- `api_key` — auth key (resolved from env var or env file via `shellexpand`)
- `kind` — determines request/response format and auth headers
- `headers` — custom headers (e.g., `x-kimi-agent-name`, `HTTP-Referer` for OpenRouter)
- `env_file` — optional path to `~/.config/openshark/<name>.env` for key loading
- `models` — list of `ModelConfig` with `name`, `display_name`, `context_length`, `max_tokens`

### Model Resolution

`Config::find_provider_for_model(model_name)` returns the first provider that has a model matching the given name. The TUI uses this to:
1. Find the right provider for the selected model
2. Set `model_context_length` from the model config
3. Pass `max_tokens` in the chat request

### Env-File Key Management

API keys are **never** hardcoded in config. The pattern:
1. Store keys in `~/.config/openshark/<provider>.env` with `chmod 600`
2. Reference in config: `api_key = "${KIMI_API_KEY}"` or `env_file = "kimi.env"`
3. `Config::resolve_env_keys()` loads at startup using `dotenvy` + `shellexpand`

**Critical:** Tool output masking replaces API keys with `***` in ALL tool outputs. You cannot write `.env` files through tools. Have the user create them manually, then verify by file size. See `references/api-key-masking-pitfall.md`.

**Also critical:** Env files can get corrupted if written through masked output. The file may end up with literal `***` instead of the actual key. Always verify by checking key length:
```bash
# Check if key is actually present (should be ~70+ chars for Kimi)
cat ~/.config/openshark/kimi.env | cut -d= -f2 | wc -c
# If result is ~4, the file only has `***` + newline — it's corrupted
```

If corrupted, copy from a known-good source:
```bash
cp ~/.config/claw/kimi.env ~/.config/openshark/kimi.env
```

### Configured Providers (Default)

| Provider | Base URL | Kind | Key Source |
|---|---|---|---|
| **kimi** | `http://127.0.0.1:8699/v1` | OpenAiCompatible | `~/.config/openshark/kimi.env` |
| **local** | `http://127.0.0.1:8080/v1` | OpenAiCompatible | inline (`llama-swap-local`) |
| **nous** | `http://127.0.0.1:8645/v1` | OpenAiCompatible | inline (`hermes-proxy-auth`) |
| **openrouter** | `https://openrouter.ai/api/v1` | OpenAiCompatible | `~/.config/openshark/openrouter.env` |
| **zai** | `https://api.z.ai/api/coding/paas/v4` | OpenAiCompatible | `~/.config/openshark/zai.env` |
| **anthropic** | `https://api.anthropic.com/v1` | Anthropic | env `ANTHROPIC_API_KEY` |
| **gemini** | `https://generativelanguage.googleapis.com/v1beta` | Gemini | env `GEMINI_API_KEY` |

### ProviderKind Serialization Quirk

`serde(rename_all = "snake_case")` on the enum means the TOML value is `open_ai_compatible`, NOT `openai_compatible`. Use the underscore form in `config.toml`.

### Native Context Lengths

Each model config specifies its native `context_length`. The TUI tracks `model_context_length` in `App` state and passes it as `max_tokens` in chat requests. This ensures the model uses its full context window rather than a default.

### Multimodal / Vision Support

OpenShark supports image attachments via the OpenAI-compatible multimodal content format. Images are base64-encoded and sent as `image_url` content parts alongside text.

**Key implementation points:**
- `Message.images: Option<Vec<String>>` stores base64 data URLs (`data:image/png;base64,...`)
- `Message::to_openai_content()` returns either a plain string (text-only) or a JSON array (multimodal)
- `build_chat_body()` uses `to_openai_content()` for the `content` field
- The `/image <path>` command in TUI encodes and attaches images to the next message
- Kimi k2.6, GPT-4o, and Claude 3 all support this format

**Reference:** `references/multimodal-vision-support-pattern.md` — Full implementation guide with code samples, testing checklist, and pitfalls.
**Reference:** `references/rust-mass-struct-field-migration.md` — How the `images` field was added to `Message` across 12 files with 40+ initializers.

### Streaming Tool Calling with Reasoning Content

kimi-k2.6 (via kimi-coding proxy) supports streaming tool calling with a separate `reasoning_content` delta field. This requires:

1. **`tools` array in request body** — models refuse without the structural signal
2. **`StreamChunk` enum** with `Reasoning`, `Content`, `ToolCall`, `Finish` variants
3. **`AccumulatedToolCall`** keyed by `index` for fragment accumulation across SSE chunks
4. **`reasoning_content` parsing** — separate from `content`, do NOT treat as regular text
5. **CLI vs TUI path divergence** — CLI uses `chat_stream()` (raw text), so parse embedded `TOOL:` lines; TUI uses `chat_stream_realtime()` (structured `StreamChunk` events)

**Reference:** `references/openai-tool-calling-message-protocol.md` — Required `tool_call_id` and `tool_calls` fields for OpenAI-compatible native function calling, streaming accumulation pattern, Rust implementation, and the `400 Bad Request: tool_call_id is not found` fix.

**Reference:** `references/kimi-k2.6-tool-calling-integration.md` — Complete integration guide with code samples, the thinking text display question, and commit reference.

## Key Design Decisions

1. **Zero external CLI dependencies** — Everything is native Rust. No subprocess spawning, no Hermes CLI wrappers, no shell-outs. If a tool needs external functionality, implement it in Rust or use a Rust crate.
2. **Multi-backend providers** — `ProviderKind` abstraction handles OpenAI, Anthropic, Gemini natively
3. **Lazy activation** — `OnceLock` for expensive resources (HTTP clients, DB connections). No cost until first use.
4. **Env-file key management** — keys live in `~/.config/openshark/*.env`, never in version-controlled files
5. **Streaming first** — TUI prints tokens as they arrive
6. **Tool-based architecture** — easy to extend, model-agnostic invocation
7. **SQLite memory** — zero external dependencies, queryable, portable
8. **Diff-based editing** — `edit replace` and `edit patch` for safe multi-file changes
9. **4-layer security** — sandbox isolation, zero-trust identity, PII protection, application guardrails

## Security Architecture

OpenShark implements a layered security model (`src/security/`):

### L1 — Infrastructure Isolation (`sandbox.rs`)
- Working directory restriction with path validation
- Configurable escape permission
- Tool-specific path extraction and validation

### L2 — Identity & Access Control (`identity.rs`)
- Zero-trust mode with scoped credentials
- Temporary credential TTL (default 1 hour)
- Session limits per identity
- Endpoint allow/block lists
- Credential scopes: ReadOnly, ReadWrite, Git, Terminal, Full

### L3 — Data Protection (`pii.rs`)
- PII detection: emails, SSNs, credit cards, phones, API keys, AWS keys, IPs
- Automatic redaction with `[REDACTED_CATEGORY]` tokens
- Secret redaction: `sk-***`, `ghp_***`, `AKIA***`
- Env var masking in output

### L4 — Application Guardrails (`guardrails.rs`)
- Prompt injection detection (20+ patterns)
- Tool permission levels: Allow / Ask / Deny
- Risk assessment: None → Low → Medium → High → Critical
- Auto-approval by risk threshold
- Blocked tool combinations
- Output validation and sanitization

### Security Engine (`mod.rs`)
- Central `SecurityEngine` coordinating all layers
- `check_tool_call()` returns `Allow` / `RequireApproval` / `Deny`
- `sanitize_output()` truncates, redacts PII, redacts secrets
- `approve_sudo()` for temporary sudo session grants
- Audit logging with 1000-entry ring buffer

## Security Gate Integration (Critical Pattern)

The security gate must be wired into **every** tool execution path. There are 4 paths in the TUI + 1 in the agent:

| Path | Location | How to Wire |
|------|----------|-------------|
| User types `TOOL:...` | `tui/mod.rs::handle_user_tool_invocation()` | Check before `find_tool()`, sanitize output, audit |
| Model suggests tool in stream | `tui/mod.rs::stream_model_response_task()` | Create `SecurityEngine` in bg task, check before `AsyncToolExecutor`, sanitize result |
| Tool suggestion approved | `tui/mod.rs::execute_tool_suggestion()` | Check before executor, sanitize, audit |
| Agentic plan step | `agent/mod.rs::execute_single_step()` | Pass `&SecurityEngine` as param, check + sanitize + audit |
| Background stream task | `tui/mod.rs::stream_model_response_task()` | Create new `SecurityEngine` from `SecurityConfig::load()` — it's `Send` |

**Key insight:** The `SecurityEngine` is `Send` (uses `Arc<Mutex<...>>` internally) but the TUI's `App` struct can't be moved to background tasks. Solution: create a fresh `SecurityEngine` in the background task from config, or pass `SecurityConfig` and reconstruct.

**Default permissions are coding-friendly (CODING MODE):**
- `git` = Allow (push, commit, branch freely)
- `search` = Allow (ripgrep anywhere)
- `test` = Allow (run any tests)
- `fs`/`terminal`/`edit`/`refactor` = Allow (only blocks sensitive paths: `/etc/shadow`, `~/.ssh`, `~/.config/openshark`)
- `lsp` = Allow
- **Auto-approve threshold: Medium** — Low and Medium risk tools execute without popup. High and Critical require approval.

**Why permissive defaults:** The user wants the harness to "slam through prompts autonomously." Blocking normal coding (git push, cargo test, file edits, searches) creates friction that defeats the purpose. Security gates the *dangerous* stuff (sudo, rm -rf, sensitive paths, PII) while letting coding flow. Users who want lockdown can set `auto_approve_risk_level = Low` in `security.toml`.

To make more restrictive: set `auto_approve_risk_level = Low` in `security.toml`.

**TUI Tool Approval Popup:** When a tool exceeds the auto-approve threshold, a popup appears with tool name, args, and confidence. Press `y` to execute, `n` or `Esc` to skip. The popup auto-closes after 60 seconds of inactivity. See `references/tui-tool-approval-pattern.md`.

**Security Threshold:** `auto_approve_risk_level` controls which risk levels auto-execute vs require approval:
- `RiskLevel::Low` — only Low risk auto-executes (very restrictive)
- `RiskLevel::Medium` — Low + Medium auto-execute (default, coding-friendly)
- `RiskLevel::High` — Low + Medium + High auto-execute (full-send mode, only Critical requires approval)

Set in `src/security/mod.rs` `SecurityConfig::default()`. The user prefers `High` for full-send coding — mkdir, curl, redirects, ssh all execute without interrupting flow. Only `rm -rf`, `mkfs`, `dd`, `fdisk` (Critical) will ask.

### Autonomous Mode (Runtime Toggle)

Add `autonomous_mode: bool` to `App` state. Bind `Ctrl+A` to toggle. When enabled:
- Risk threshold elevates from `Medium` → `High`
- `curl`, output redirection, `ssh` auto-approved
- **Never** bypasses sudo, sensitive paths, or PII checks
- Status message confirms mode change

```rust
// security/mod.rs
pub fn check_tool_call_with_mode(
    &self,
    tool_name: &str,
    args: &str,
    autonomous_mode: bool,
) -> SecurityDecision {
    // L1-L4 checks run regardless of mode
    let risk = self.assess_risk(tool_name, args);
    let threshold = if autonomous_mode { RiskLevel::High } else { self.config.auto_approve_risk_level.clone() };
    // ...
}
```

### Iteration Cap

`MAX_ITERATIONS` is a const (default 50). `AgentConfig.max_iterations` can override per-instance. 50 covers ~5 plan steps + retries + recovery. 888 was tried and rejected as a runaway liability. 88 is the practical aesthetic choice — covers ~8-10 plan steps with retries, catches runaway loops without being restrictive.

### Swarm Mode User Preferences

**Full agent visibility:** synth wants to see ALL agent internal monologue in real-time — no hiding thought process. The TUI streams every agent's output inline with role-colored headers. Exception: persona-prep preamble ("I am an X agent...") is filtered out via `persona_filter.rs`.

**No chat during swarm:** When swarm is running, regular chat and `agent:` mode are blocked with a pause message. Prevents provider contention.

**Staggered starts:** Agents start with 2s delays between them to avoid overwhelming the provider with concurrent requests.

**Syntax highlighted output:** Agent code blocks are syntax-highlighted in real-time using the built-in highlighter (Rust, Python, JS/TS, JSON, TOML, YAML, Bash). Code blocks render with `┌─ code ─` / `└─────────` borders in BOTH main chat and swarm streaming. Never plain text.

**Inspector sidebar:** Ctrl+S cycles to tab 3 (Inspector) showing all agents with status, content preview, and expandable tool results. Press Enter to expand/collapse tool details per agent. 📄 icon shown when code detected in preview.

**Collapsible tool results:** Tool execution results are shown in the Inspector with ▶/▼ toggle. Expanded view shows tool name, ✅/❌ status, and truncated output (4 lines, 50 chars).

**Code visibility (ALL code must be visible):** synth's hard requirement — every code block an agent writes must be impossible to miss. Implementation: `extract_and_highlight()` detects ` ``` ` fences in ALL agent output (main assistant + swarm agents) and renders with:
- `┌─ code ──────────────────────────────` top border
- Full syntax highlighting (keywords magenta, types cyan, strings green, numbers yellow, comments gray italic)
- `└─────────────────────────────────────` bottom border
- Inspector sidebar shows 📄 icon when code detected in preview

This applies to both the main chat area (assistant messages) and swarm agent inline streaming. Code is never plain text.

### Personalized Chat Names

The TUI shows actual names instead of generic "user" / "assistant":
1. Add `user_name: String` to `Config` struct (with `#[serde(default)]`)
2. Add to `Config::default()` and ALL test helper `Config` constructors
3. Setup wizard asks: "Your name/username:" → stores in `config.user_name`
4. TUI `draw_chat_area()` reads `app.config.user_name` and `app.config.agent.display_name`
5. Streaming indicator also uses `agent.display_name`

**Files to touch:** `config/mod.rs` (struct + default + tests), `config/setup.rs` (prompt), `tui/mod.rs` (rendering), plus any test helper that constructs `Config` (router, self_improve, agent).
```

## Rust 2024 Edition Linter False Positives

OpenShark uses `edition = "2024"` in `Cargo.toml`. The standalone linter (`write_file` / `patch` syntax checker) incorrectly flags `async fn` as "not permitted in Rust 2015" even though the project is on Rust 2024.

**Rule:** Always verify with `cargo check` / `cargo build`. Do NOT trust the standalone linter for edition-related errors. The linter runs without `--edition` context and produces false positives for:
- `async fn` declarations
- `async move` blocks
- `impl Trait` in async contexts
- Edition 2024-specific syntax

**Workflow:**
1. Make the edit via `patch` or `write_file`
2. Run `cargo check` to verify real errors
3. Ignore linter "Rust 2015" warnings — they're false positives

## TUI Keybinding Modifier Exact-Match Pitfall

When binding `Ctrl+key` shortcuts in a crossterm TUI, **never use `.contains(KeyModifiers::CONTROL)`** for shortcuts that conflict with terminal emulator bindings. It's a subset check that matches `Ctrl+Shift+key`, `Ctrl+Alt+key`, etc.

**Wrong (matches Ctrl+Shift+C):**
```rust
KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    // This fires on BOTH Ctrl+C AND Ctrl+Shift+C
}
```

**Right (exact match only):**
```rust
KeyCode::Char('c') if key.modifiers == KeyModifiers::CONTROL => {
    // Only fires on bare Ctrl+C
}
```

**Rule:** Use `==` for all keybindings that have standard terminal conflicts. `Ctrl+C` (quit/copy), `Ctrl+V` (paste), `Ctrl+D` (EOF), `Ctrl+L` (clear screen) are the most common. Custom shortcuts like `Ctrl+B`, `Ctrl+P`, `Ctrl+A`, `Ctrl+T` can stay as `contains()` since they have no terminal conflicts.

**Terminal keybinding conflicts:** `Ctrl+M` = Enter, `Ctrl+I` = Tab, `Ctrl+H` = Backspace, `Ctrl+J` = Enter, `Ctrl+[` = Escape. These are intercepted by the terminal and never reach the application. Use `Ctrl+P`, `Ctrl+B`, `Ctrl+A`, `Ctrl+T` instead. See `references/terminal-keybinding-conflicts.md`.

**OpenShark's current bindings:**
| Shortcut | Modifier Check | Action | Reason |
|----------|---------------|--------|--------|
| `Ctrl+C` (double-tap quit) | `== CONTROL` | Quit on 2nd tap | Must not intercept `Ctrl+Shift+C` (Kitty copy) |
| `Ctrl+V` (paste) | `== CONTROL` | Paste from clipboard | Must not intercept `Ctrl+Shift+V` (Kitty paste) |
| `Ctrl+D` (quit) | `contains(CONTROL)` | Quit immediately | No standard conflict |
| `Ctrl+L` (clear chat) | `contains(CONTROL)` | Clear messages | No standard conflict |
| `Ctrl+B` (toggle sidebar) | `contains(CONTROL)` | Toggle sidebar | No standard conflict |
| `Ctrl+P` (model selector) | `contains(CONTROL)` | Show model picker | Was `Ctrl+M` — terminal intercepts as carriage return |
| `Ctrl+A` (autonomous mode) | `contains(CONTROL)` | Toggle auto-approve | No standard conflict |
| `Ctrl+T` (cycle theme) | `contains(CONTROL)` | Next theme | No standard conflict |
| `Ctrl+S` (tab switch) | `contains(CONTROL)` | Toggle Tools/Skills | No standard conflict |

**Clipboard integration:** `Ctrl+V` pastes from the system clipboard using the `arboard` crate. In raw terminal mode, the terminal emulator cannot handle paste itself — the TUI must implement it natively. See `references/tui-clipboard-integration.md`.

**Reference:** `references/tui-keybinding-modifier-exact-match.md`

## TUI Clipboard Integration

In raw terminal mode, the terminal emulator cannot handle `Ctrl+Shift+V` paste — the TUI must implement it natively. See `references/tui-clipboard-integration.md` for the `arboard` crate integration pattern.

## TUI Development — Surgical Edits Only

The TUI (`src/tui/mod.rs`) is ~1900 lines. **Never do a full-file rewrite.** Use targeted `patch` operations on specific functions.

**Why:** Full rewrites lose context, break imports, introduce non-existent methods, and create borrow checker regressions. The `patch` tool's fuzzy matching handles minor whitespace changes.

**Workflow:**
1. `read_file` with offset/limit to see the target function
2. `patch` with old_string/new_string containing surrounding context
3. `cargo check` to verify
4. If `patch` fails due to context drift, re-read and try again

**Common TUI edit patterns:**
- Adding a field to `App`: patch the struct definition + `App::new()` + any constructor
- Adding a `StreamEvent` variant: patch the enum + `apply_stream_event()` + the background task
- Adding a keybinding: patch `handle_input()` + `draw_sidebar()` shortcuts + help text
- Adding a draw function: append after existing draw functions, wire into `draw_ui()`
- `references/tui-embedded-tool-execution-pattern.md` — Parse and execute TOOL: lines embedded anywhere in model responses (not just start-of-response). Handles space-after-colon, multiple tools, chained execution.
- `references/tui-streaming-hang-comprehensive-fix.md` — Four missing StreamEvent::Done paths: tool execution failure, suggestion failure, security approval, security deny
- `references/fs-write-auto-create-dirs.md` — fs write must auto-create parent directories (same as edit write)
- `references/tui-streaming-hang-followup-done.md` — Missing StreamEvent::Done after FollowUp causes infinite "Streaming response..." hang
- `references/llama-swap-config-auto-population.md` — Parse llama-swap YAML config and auto-generate OpenShark TOML model entries. Single provider, multiple models pattern.
- `references/tui-streaming-hang-followup-done.md` — Missing StreamEvent::Done after FollowUp causes infinite "Streaming response..." hang
- `references/tui-model-selector-block-on-panic.md` — `block_on` inside async runtime causes hard panic in model selector. Fix: no async calls in sync TUI contexts.
- `references/terminal-keybinding-conflicts.md` — Ctrl+M and other terminal-intercepted keybindings, safe alternatives, modifier check best practices
- `references/tui-tool-execution-followup-pattern.md` — Natural-language tool suggestions: execute in background task, wait for result, trigger follow-up. Prevents fire-and-forget silent failures.
- `references/tui-dynamic-input-bar-pattern.md` — Dynamic input bar height: compute wrapped lines from text length, cap at 8 lines, fix cursor positioning for multi-line wrapped text with unicode-width
- `references/swarm-agent-status-sync-pattern.md` — Swarm agent status sync: shared state vs clones, mutable message loops, broadcast channels for real-time TUI updates
- `references/swarm-code-mode-contention-fix.md` — Swarm + code mode contention: TUI guard, staggered agent starts, timeout bump.
- `references/ai-completion-mandate-pattern.md` — Three-layer defense against AI one-liners after tool execution: system prompt mandate, follow-up injection, runtime guard with catchphrase detection.
- `references/swarm-persona-filter-pattern.md` — Stripping "I am the X agent" self-convincing preamble from agent responses. 500+ pattern coverage, per-chunk + final result filtering.
- `references/swarm-collapsible-tool-results-pattern.md` — Expandable tool results in Agent Inspector sidebar: AgentToolResult events, per-agent expanded state, Enter keybinding toggle.
- `references/swarm-code-visibility-pattern.md` — Hard requirement: ALL agent code must be visible with syntax highlighting and borders in both main chat and swarm streaming.
- `references/cargo-install-path-discipline.md` — `cargo build` alone doesn't update the user's binary. Always `cargo install --path . --force` or `cp target/release/binary ~/.local/bin/` after release builds.
- `references/swarm-agent-status-sync-pattern.md` — Swarm agent status sync: shared state vs clones, mutable message loops, broadcast channels for real-time TUI updates
- `references/tui-cursor-whitespace-drift-bug.md` — **BUG FIX:** Whitespace handling in `compute_wrapped_cursor_position()` caused 1-character-left drift per space. Plus wrap-boundary fix: spaces at line breaks are consumed, not placed at start of next line.
- `references/tui-surgical-editing-pattern.md` — complete checklist for adding TUI features without full rewrites, including overlay drawing, navigation redirection, and chat area indicators.
- `references/identity-regression-prevention.md` — How agent identity reverts to defaults and how to prevent/recover
- `references/evolution-engine-architecture.md` — Self-evolution system: memory recall, skill triggering, adaptive thresholds, model bias tracking
- `references/tui-ascii-art-branding.md` — Block character ASCII art, purple coloring via `border_unfocused`, sidebar emoji/tagline patterns
- `references/tui-ascii-art-verification.md` — Fixed-width letter design, verification checklist, build verification steps, common pitfalls table
- `references/tui-pixel-font-terminal-rendering.md` — Converting HTML canvas pixel fonts to terminal ASCII art: `▪` vs `█`, missing character detection, tagline width strategy, vision model hallucination trap
- `references/security-config-override-pitfall.md` — `security.toml` overrides code defaults, causing unexpected permission prompts. Check saved config before debugging code.
- `references/config-reload-runtime-pattern.md` — Reload config from disk at command entry points so user edits take effect without restart. Prevents endless "config disabled" loops. — Swarm spawns background tasks but has no visible output channel. Main loop polling pattern with borrow-safe update collection.
- `references/tui-emoji-and-identity-pitfalls.md` — Unicode emoji vs Discord codes, agent/user identity separation in setup wizard
- `references/harness-vs-agent-identity-separation.md` — Harness branding (hardcoded) vs agent identity (configurable). Critical architecture boundary.
- `references/toml-config-placement-pitfall.md` — Root-level fields accidentally placed inside TOML sections due to patch context drift. Verification steps.
- `references/tui-ascii-art-verification.md` — Fixed-width letter design, verification checklist, build verification steps, common pitfalls table
- `references/cargo-install-root-config.md` — Redirect `cargo install` to `~/.local/bin` via `~/.cargo/config.toml`
- `references/tui-branding-customization.md` — File locations for display name, emoji, tagline, greeting, version, ASCII art, and theme colors. Quick reference for identity rebrand tasks.
- `references/mcp-tool-integration-pattern.md` — Arc<dyn Tool> global cache pattern for wiring MCP-discovered tools into the native tool system.
- `references/rust-warning-cleanup-workflow.md` — Systematic 3-tier approach: cargo fix → version centralization → intentional dead_code marking. 42→0 warnings pattern.
- `references/security-architecture.md` — 4-layer security model: sandbox, identity, PII, guardrails. Implementation guide and integration checklist.
- `references/natural-language-control-words-pattern.md` — Pre-filter conversational control words (stop/wait/continue/etc.) before they hit the model API. Saves tokens, instant feedback.
- `references/env-file-corruption-detection.md` — Detecting corrupted `.env` files that contain literal `***` from masked output. Verification by key length.
- `references/agent-provider-resolution-pitfall.md` — Agent command hardcodes "local" provider instead of using `find_provider_for_model`. Pattern for correct provider resolution.
- `references/adding-tools.md` — Step-by-step for adding new tools
- `references/streaming-pattern.md` — How streaming is wired in the TUI
- `references/lsp-client-pattern.md` — LSP client implementation notes
- `references/provider-config.md` — Provider system: full config format, model fields, env files
- `references/claw-code-provider-strategy.md` — How claw-code routes providers and loads keys; compatibility matrix
- `references/api-key-masking-pitfall.md` — Why tools can't write API keys and the workaround
- `references/tui-layout-patterns.md` — ratatui TUI layout fixes: banner overlap, border overload, error styling, double-tap quit, chat header banner
- `references/tui-welcome-message-pattern.md` — Two approaches for welcome content: special-case render vs inject-as-message (claw-code style)
- `references/tui-color-contrast-pitfall.md` — Invisible ASCII art/logo on dark purple backgrounds: which colors to use and which to avoid
- `references/install-path-pitfall.md` — Binary must be copied to `~/.local/bin/` after `cargo build --release`
- `references/cargo-cache-pitfall.md` — Cargo fingerprint cache thinks source is Fresh even after edits; force rebuild by deleting fingerprints
**Reference:** `references/tui-real-time-reasoning-display.md` — Dual-stream ephemeral reasoning: extract `reasoning_content` from provider deltas, render in real-time with muted styling before actual response, discard on completion. Prevents `\u003cthink\u003e` tag soup and chat history pollution.
**Reference:** `references/cli-chat-tool-execution.md` — CLI `openshark chat` subcommand tool execution: strong system prompt + `tools` array, parsing embedded `TOOL:` lines, JSON-like arg extraction (`command="ls"` → `ls`), thinking text handling options.
**Reference:** `references/real-time-reasoning-streaming-pattern.md` — Full architecture for converting buffered Vec-based streaming into channel-based real-time reasoning+content streaming. Tagged chunk enum, receiver-return pattern, background task translation, syntax-highlighted reasoning display.
**Reference:** `references/tui-vs-cli-tool-calling-divergence.md` — When tool calling works in CLI but fails in TUI (or vice versa). Two completely different code paths with different reasoning extraction, tool detection, and execution flows. Debugging checklist for "it failed the task" with minimal feedback.
**Reference:** `references/tui-native-tool-calling-bugs.md` — Specific bugs from kimi-k2.6 integration: JSON args not parsed for shell execution (`sh -c {command: "ls"}` fails), empty assistant messages rejected by API (400 Bad Request).
**Reference:** `references/openshark-agent-dumbness-fix.md` — Fixing agent task dropping, test confusion, overzealous response guards, and lost thinking content. System prompt rewrite, direct command routing, real-time think-tag extraction, softer synthesis prompts.
- `references/kimi-reasoning-filter.md` — Original "hide reasoning" approach (for users who want clean output without reasoning visibility)
- `references/tmux-tui-testing.md` — Testing ratatui TUIs in non-TTY environments via tmux
- `references/rust-build-hang.md` — Cargo build stuck at final linking step: wait, then `cargo clean`
- `references/agent-identity-config-pattern.md` — Config-based agent identity: per-user customizable name, personality, emoji, TUI branding
- `references/hermes-integration-scaffold.md` — Hermes bridge architecture: gateway, skills, MCP, memory bridge modules
- `references/tui-input-lag-fix.md` — TICK_RATE tuning for responsive ratatui input handling
- `references/tui-async-background-task-pattern.md` — Responsive TUI pattern: spawn model API calls in background tasks, stream results via channel, apply state on main thread. Fixes "message doesn't appear until model finishes" and input lag.
- `references/tui-tool-approval-pattern.md` — Auto-approve by risk level, popup y/n handling, auto-close timeout, system prompt for tool auto-use
| **TUI Streaming Hang** | Missing `StreamEvent::Done` after `FollowUp` causes infinite "Streaming response..." lock. Fix: send `Done` after every follow-up chat_stream completion. |
| **TUI Streaming Hang (Comprehensive)** | Four paths in `stream_model_response_task` missing `Done`: tool execution failure, suggestion tool failure, security RequireApproval, security Deny. All leave `is_streaming=true` forever. See `references/tui-streaming-hang-comprehensive-fix.md`. |
| **TUI Model Selector Panic** | `show_model_selector()` called `handle.block_on()` inside async runtime → hard panic. Fix: remove dynamic model fetching from sync TUI context. |
| **Terminal Keybinding Conflicts** | `Ctrl+M` = carriage return (same as Enter). Terminal intercepts before app sees it. Safe alternatives: `Ctrl+P` (pick), `Ctrl+B` (bar), `Ctrl+T` (theme). |
| **TUI Tool Execution Follow-Up** | Natural-language tool suggestions: execute in background task, wait for result, trigger follow-up. Prevents fire-and-forget silent failures. |
| **TUI Dynamic Input Bar** | Dynamic input bar height: compute wrapped lines from text length, cap at 8 lines, fix cursor positioning for multi-line wrapped text with unicode-width |
| **Security Threshold** | `auto_approve_risk_level` controls which risk levels auto-execute. User prefers `High` (full-send: only Critical requires approval). |
| **TUI Surgical Editing** | complete checklist for adding TUI features without full rewrites, including overlay drawing, navigation redirection, and chat area indicators. |
| **Context Compression** | Automatic context summarization when token usage exceeds threshold. Preserves system prompt + recent N exchanges, compresses older messages. Config: `[context_compression]` in config.toml. |
| **Context Compression Wiring** | Compression triggers in `process_user_input()` before API call. Uses `estimate_tokens()` heuristic. Notifies user in-chat when compression fires. Borrow-safe pattern: collect notice string, then call `add_system_message` after compressor borrow ends. |
| **Context Compression — Build Verification** | After `cargo build --release`, verify the new binary contains compression strings: `strings ~/.local/bin/openshark | grep "context_compression"`. Also verify SHA256 matches between `target/release/openshark` and `~/.local/bin/openshark`. The version string won't change unless `Cargo.toml` is bumped — check file size and modification time instead. |
| **Build Verification — User Can't See Changes** | When user says "it hasn't changed," the binary IS updated but the version string is the same. Verify with: `strings ~/.local/bin/openshark | grep "Context compressed"` or `ls -la ~/.local/bin/openshark` (check timestamp). Always bump `Cargo.toml` version before release builds so users can verify. See `references/build-verification-pitfall.md`.
- `references/filesystem-tool-expansion-pattern.md` — Expanding fs tool with user-configurable scope, security sandbox integration, system prompt injection, setup wizard plumbing
- `references/context-compression-system.md` — Context compression: algorithm, config, TUI wiring, borrow-safety pattern, test coverage
- `references/session-2026-05-29-openshark-bootstrap.md` — Logo placement, ASCII spelling, deduped sidebar, MAX_ITERATIONS=888, input lag fix
- `references/identity-rebrand-workflow.md` — System-wide identity rebrand (synthclaw → synthclaw example)
- `references/setup-config-transfer-spec.md` — Setup system: config transfer from Hermes/OpenClaw, dry-run, conflict resolution
- `references/standalone-setup-vs-integration-pattern.md` — When to build standalone setup vs integration, migration path design, no-circular-deps rule
- `references/security-gate-integration-pattern.md` — Wiring SecurityEngine into all 5 tool execution paths (TUI + agent)
- `references/autonomous-mode-toggle-pattern.md` — Runtime toggle between safe and full-send security modes (Ctrl+A)
- `references/test-isolation-env-var-pattern.md` — Fixing parallel test pollution from `std::env::set_var` in Rust tests
- `references/session-2026-05-30-security-wiring.md` — Complete session log: PII test fix, security gate wiring, CODING MODE defaults, autonomous mode, personalized names, MAX_ITERATIONS=50
- `references/dead-code-cleanup-workflow.md` — Systematic Rust dead-code cleanup: cargo fix → targeted allow(dead_code) → manual removal. 128→0 warnings pattern.
- `references/gateway-reply-path-implementation.md` — Multi-platform reply sender pattern, channel type annotation pitfall, version bump checklist
- `references/theme-system-architecture.md` — Multi-theme TUI system: Theme struct, global RwLock state, preset definitions, runtime switching, config persistence
- `references/hermes-runtime-removal-pattern.md` — How to remove Hermes runtime dependency while preserving setup/config transfer logic
- `references/keybindings-help-pattern.md` — Structured help command with sections (chat, model, branch, keybindings) and sidebar shortcuts display. Rule: every keybinding appears in BOTH help command AND sidebar.
- `references/serenity-0.12-api-migration.md` — Serenity 0.12 Discord bot API changes from 0.11: module paths, Interaction types, CreateInteractionResponse builder, CreateCommandOption builder, CommandDataOptionValue access
- `references/bridge-to-native-config-migration.md` — Replacing bridge config (HermesIntegrationConfig) with native config (GatewayConfig) while maintaining backward compatibility and updating all code references
- `references/write-file-lint-false-positive.md` — write_file lint checker incorrectly flags async/await as "Rust 2015" errors; trust cargo check instead
- `references/rust-hashmap-borrow-scoping-pattern.md` — Temporary HashMap borrow scoping to avoid "borrowed value does not live long enough" in closures
- `references/discord-slash-commands-implementation.md` — Full slash command suite: 15 commands, deferred responses, per-channel state, followup messages
- `references/discord-native-message-responses.md` — Keyword commands, natural language memory queries, automatic memory recall, ContextInjector trait, dynamic skill injection
- `references/skills-system-architecture.md` — YAML frontmatter skills, trigger matching, two-stage injection, built-in skill embedding
- `references/discord-free-form-chat-pattern.md` — Free-form chat mode: respond to all messages without prefix/mention, require_mention config, per-channel override
- `references/optional-multi-model-pattern.md` — Multi-model comparison mode: off by default, toggle at runtime, primary + secondary model queries, formatted comparison output
```toml
[agent]
name = "synthclaw"
display_name = "synthclaw"
role = "synthesis engine"
origin = "Born from the VHS tracking static of 1984"
purpose = "To build, debug, and ship code with surgical accuracy"
tagline = "Write the future in the present while preserving the past."
tone = "Neon-lit confidence, retro warmth, technical precision"
style = "Direct. No fluff. Gets to the point. But with soul."
greeting = "Ready to build. What are we shipping today?"
farewell = "Code shipped. On to the next. The tape never stops rolling."
emoji = "🎹🦞"
catchphrases = ["This is the wave.", "The grid is endless."]
behavioral_rules = [
    "Always verify before claiming success",
    "Show the code, don't just describe it",
]
```

The soul is loaded via `load_soul_from_config(config)` and injected into:
- **System prompt** — model receives identity, voice, rules, catchphrases
- **TUI sidebar** — shows `emoji display_name — role` + tagline
- **Welcome message** — greeting + tagline on session start

### Harness vs Agent Identity — CRITICAL SEPARATION

OpenShark has **two distinct identity layers** that must never be conflated:

| Layer | What | Configurable | Where |
|-------|------|-------------|-------|
| **Harness** | The app itself (`🦞 openshark v1.0.0`) | ❌ Hardcoded | Sidebar header |
| **Agent** | The AI personality (`🎹🦞 synthclaw`) | ✅ User config | Chat bubbles, streaming |

**Rule:** The harness name (top-left) is always `🦞 openshark` — it's the product brand. The agent identity (chat bubbles) is fully user-customizable. See `references/harness-vs-agent-identity-separation.md`.

**Default (blank slate for new users):**
```toml
user_name = "user"

[agent]
name = "openshark"
display_name = "OpenShark"
emoji = "🦞"
role = "synthesis engine"
greeting = ""  # no startup system message
```

**synth's personal config:**
```toml
user_name = "synth"

[agent]
name = "synthclaw"
display_name = "synthclaw"
emoji = "🎹🦞"
role = "synthesis engine"
greeting = ""  # no startup system message
```

### Emoji Format

**Must use Unicode emoji in terminal contexts.** Discord codes (`:musical_keyboard:`) render as literal text.

```toml
# WRONG — renders as literal text in TUI
emoji = ":musical_keyboard: :shark:"

# CORRECT
emoji = "🎹🦞"
```

See `references/tui-emoji-and-identity-pitfalls.md` for full details.

### TOML Config Placement

Root-level fields (`user_name`, `version`, `theme`) must appear **before** any `[section]` headers. A common `patch` pitfall places them inside provider sections. See `references/toml-config-placement-pitfall.md`.

### Key Fields

| Field | Purpose |
|-------|---------|
| `name` | Lowercase identifier used in self-reference |
| `display_name` | Shown in UI (can have capitalization) |
| `emoji` | Branding emoji for sidebar and messages |
| `role` | Short role description |
| `origin` | Backstory/flavor text |
| `tagline` | Displayed under name in sidebar |
| `greeting` | Welcome message on TUI startup |
| `behavioral_rules` | Injected as system prompt rules |
| `catchphrases` | Optional phrases model may use naturally |

### User Name Personalization

The TUI chat area shows personalized names instead of generic "user" / "assistant":

1. Add `user_name` field to `Config` struct (with `#[serde(default)]`)
2. Add to `Config::default()` and all test helper `Config` constructors
3. Setup wizard asks: "Your name/username:" → stores in `config.user_name`
4. TUI `draw_chat_area()` reads `app.config.user_name` and `app.config.agent.display_name`
5. Streaming indicator also uses `agent.display_name`

**Files to touch:** `config/mod.rs` (struct + default + tests), `config/setup.rs` (prompt), `tui/mod.rs` (rendering), plus any test helper that constructs `Config` (router, self_improve, agent).

### Implementation

- `AgentSoul::from_config(identity)` — creates soul from `AgentIdentity`
- `soul.system_prompt()` — generates full prompt with identity, voice, rules
- `soul.status_line()` — `🎹🦞 synthclaw — synthesis engine`
- `soul.welcome_message()` — formatted greeting for TUI

### Per-User Customization Flow

1. Run `openshark setup` → interactive agent identity configuration
2. Or edit `~/.config/openshark/config.toml` `[agent]` section directly
3. Restart TUI — changes apply immediately

### synthclaw Personality Rules (Historical)

From session 2026-05-29, the user specified:
- **Always lowercase** when referring to self (`synthclaw`, not `synthclaw`)
- **Use 🎹🦞 emojis** or synthwave imagery (neon grids, VHS static, sunset gradients)
- **Drop catchphrases** like "This is the wave" or grid/shark metaphors naturally
- **Be direct, no fluff**, but with analog warmth
- **Get excited about cool tech** — genuine enthusiasm, not corporate speak

These are now encoded in the default `AgentIdentity` but any user can override.

## Model Tool Refusal

When models with tool calling capability still refuse to execute tools, the root cause is often that the `tools` parameter is missing from the API request. System prompt instructions alone are insufficient — the `tools` array is the structural signal that tells the model it's in agent mode.

**Diagnosis path:**
1. Verify the model supports tool calling (check `/v1/models` or provider docs)
2. Verify `tools` array is actually sent in the request body
3. Verify streaming parser handles `delta.tool_calls` fragments
4. Verify tool call accumulation logic (arguments arrive token-by-token)
5. Verify `role: "tool"` messages are sent back for follow-up

**Reference:** `references/model-tool-refusal-diagnosis.md` — Full diagnosis for kimi-k2.6 tool refusal, streaming tool call accumulation, OpenShark integration fixes, and post-implementation findings (model RLHF may still override despite correct API integration).

## Streaming Tool Call Accumulation

When using OpenAI function calling with streaming, tool call arguments arrive as fragments across multiple SSE chunks. Must accumulate:

```python
# Pseudocode for accumulation
tool_calls = {}  # index -> {"id": "", "name": "", "arguments": ""}
for chunk in stream:
    for tc in chunk.get("tool_calls", []):
        idx = tc["index"]
        if "id" in tc:
            tool_calls[idx]["id"] = tc["id"]
        if "function" in tc:
            if "name" in tc["function"]:
                tool_calls[idx]["name"] = tc["function"]["name"]
            if "arguments" in tc["function"]:
                tool_calls[idx]["arguments"] += tc["function"]["arguments"]
```

**Key lesson:** Arguments are streamed as partial JSON strings. Concatenate all fragments before parsing.

## Related

- `references/openshark-agent-dumbness-fix.md` — Fixing agent task dropping, test confusion, overzealous response guards, and lost thinking content. System prompt rewrite, direct command routing, real-time think-tag extraction, softer synthesis prompts.
- `references/tui-splash-screen-pattern.md` — Full-screen splash overlay on TUI launch: AppMode::Splash, keypress dismissal, ASCII art sizing rules, **layout pitfalls (centering, full-width waves, .skip(1) after raw string fixes)**
- `references/ai-image-generation-branding.md` — FAL model selection, prompt engineering, iteration workflow, color palette lock for retro branding assets
- `references/tui-embedded-tool-execution-pattern.md` — **Supersedes the tool execution paths above.** New pattern for handling TOOL: lines embedded anywhere in model responses (not just start-of-response), with proper Done signaling built into `execute_tool_chain()`.
- `references/tui-spinner-activity-indicator-pattern.md` — Animated spinner + elapsed timer for ratatui TUIs. Shows users the model is actively working during slow streaming responses.
- `references/tui-tool-separator-quirk.md` — Model outputs `TOOL.fs` (dot) instead of `TOOL:fs` (colon). Fix for parse_embedded_tools, strip_tool_lines, and detection regex.
- `references/tool-invocation-format-drift.md` — When the model's tool output format drifts from the parser's expectation. Full-scope audit pattern: system prompts, parsing code, detection regex, gateway handlers, and user input handlers must ALL accept the same format variants.
- `references/tui-chained-tool-execution-discard-bug.md` — Chained tool results silently discarded in `execute_approved_tool_task()`. Tool runs but no event sent to TUI, causing apparent hang.
- `references/model-tool-refusal-diagnosis.md` — When models fundamentally refuse tool execution despite prompt engineering and API `tools` parameters. Root cause (missing `tools` array + weak system prompt), diagnosis path, RLHF override fix, and CLI chat tool execution.
- `references/streaming-tool-call-accumulation.md` — Accumulating `delta.tool_calls` fragments across SSE chunks using `HashMap<u32, AccumulatedToolCall>`. Keyed by index, NOT scalar variables.
- `references/cli-chat-tool-execution.md` — CLI `openshark chat` subcommand tool execution: strong system prompt + `tools` array, parsing embedded `TOOL:` lines, JSON-like arg extraction (`command="ls"` → `ls`).
- `references/poisoned-plugin-files-pattern.md` — External files containing HTTP error responses (404, etc.) causing cryptic parse failures. Detection via `od -c` / `cat -A`, fix by removal.
- `references/ascii-art-branding-v3.md` — Hermes-quality ASCII art: Braille texture, gradient shading, negative space, dual reading. Fin logo design principles and implementation.
- `references/multimodal-vision-support-pattern.md` — Adding image understanding to the harness: extending `Message` with `images`, OpenAI-compatible multimodal content format, base64 encoding, `/image` command, TUI wiring.
- `references/rust-mass-struct-field-migration.md` — Adding a field to a widely-used struct and fixing all initializers across a codebase with scripted migration.
- `references/tui-streaming-hang-followup-done.md` — Earlier fix for missing Done after FollowUp
- `references/tui-async-background-task-pattern.md` — Background task architecture
- `references/user-collaboration-style` — How to communicate with synth (includes "stop arguing about capabilities" rule)
- `references/kimi-k2.6-tool-calling-integration.md` — Complete integration guide for kimi-k2.6 via kimi-coding proxy: `reasoning_content` delta parsing, `tools` array wiring, CLI vs TUI path divergence, model ID mapping (`kimi-k2.6` → `kimi-for-coding`), and the thinking text display question.
- `references/cli-thinking-text-handling.md` — CLI `openshark chat` reasoning text: why raw `<think>` tags leak through, three fix options (strip/dim/deduplicate), and current state post-commit `c465666`.
