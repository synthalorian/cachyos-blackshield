# Native Capability Tool Suite Pattern

**Session:** 2026-05-31 — OpenShark Hermes tool independence
**Context:** User wanted all 18+ Hermes tools available in OpenShark, but completely independent from Hermes CLI. Built 24 native Rust capability tools across 9 modules.

## Architecture

```
src/capabilities/
├── mod.rs          # CapabilityRegistry — global singleton, 24 tools
├── web.rs          # web, browser, x_search
├── media.rs        # vision, image_gen, video, video_gen, tts
├── memory.rs       # memory, session_search, context_engine
├── productivity.rs # todo, cronjob, skills
├── communication.rs# messaging
├── smart_home.rs   # homeassistant, spotify
├── platform.rs     # yuanbao, computer_use
├── agentic.rs      # moa, delegation, clarify
└── execution.rs    # code_execution
```

## Tool Trait

All tools implement the same `Tool` trait:

```rust
pub trait Tool: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn execute(&self, args: &str) -> Result<String>;
}
```

## Registry Integration

Capability tools are merged into the main tool registry in `src/tools/mod.rs`:

```rust
pub fn get_tools() -> Vec<Arc<dyn Tool>> {
    let mut tools = get_native_tools();  // 9 existing tools
    for cap_tool in crate::capabilities::get_capability_tools() {
        tools.push(cap_tool);  // 24 new tools
    }
    // + MCP tools if configured
    tools
}
```

## Lazy Activation

For native Rust tools, "lazy" means:
- No resource allocation until first `execute()` call
- HTTP clients use `OnceLock<reqwest::blocking::Client>`
- DB connections open on first query
- File system operations use `std::fs` directly

## Lazy Activation with OnceLock

For tools that need expensive resources (HTTP clients, DB connections), use `std::sync::OnceLock` to initialize on first use:

```rust
use std::sync::OnceLock;

fn http_client() -> &'static reqwest::blocking::Client {
    static CLIENT: OnceLock<reqwest::blocking::Client> = OnceLock::new();
    CLIENT.get_or_init(|| reqwest::blocking::Client::new())
}

// In Tool::execute():
let client = http_client();
let response = client.get(url).send()?;
```

Benefits:
- No startup cost if the tool is never used
- Thread-safe initialization without lazy_static crate
- Works with both sync and async contexts (use `tokio::sync::OnceCell` for async)

## Key Design Decisions

1. **No CLI subprocess spawning** — Everything is in-process Rust
2. **Unified tool detection** — `detect_tool_suggestions()` recognizes all 32 tool names
3. **Agent + Swarm compatible** — Both modes see all tools in system prompts
4. **Self-contained** — No runtime dependency on Hermes or any external CLI

## Tool Categories

| Category | Tools | Implementation Notes |
|----------|-------|---------------------|
| Web | web, browser, x_search | DuckDuckGo HTML scraping, reqwest-based |
| Media | vision, image_gen, video, video_gen, tts | Metadata/analysis only; generation requires provider config |
| Memory | memory, session_search, context_engine | Markdown files in `~/.local/share/openshark/memories/` |
| Productivity | todo, cronjob, skills | In-memory todo state; TOML cronjob files; markdown skills |
| Communication | messaging | Message queuing with platform guidance |
| Smart Home | homeassistant, spotify | Credential-guided (HASS_URL, SPOTIFY_CLIENT_ID) |
| Platform | yuanbao, computer_use | Platform-specific with setup guidance |
| Agentic | moa, delegation, clarify | Orchestration primitives for multi-agent workflows |
| Execution | code_execution | Python via temp file + `std::process::Command` |

## Adding a New Capability Tool

1. Create `src/capabilities/<category>.rs` (or add to existing)
2. Implement `Tool` trait for your struct
3. Register in `CapabilityRegistry::new()` in `src/capabilities/mod.rs`
4. Add tool name to `detect_tool_suggestions()` in `src/tools/detection.rs`
5. Run `cargo check` to verify

## CLI Integration

```bash
openshark tools list    # Show all 32 tools with descriptions
```

## Pitfalls

- **Media generation tools** (image_gen, video_gen, tts) return guidance messages, not actual generated content. They require configured providers (FAL, OpenAI, etc.) to produce real output.
- **Smart home / platform tools** require environment variables or config files. The tools provide helpful setup guidance when credentials are missing.
- **Code execution** runs Python via `python3` binary. Ensure Python is installed and accessible in PATH.
- **Web search** uses DuckDuckGo HTML endpoint. May break if DDG changes their HTML structure. Have a fallback search strategy.
