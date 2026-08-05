# Hermes Integration Scaffold Pattern

Session: 2026-05-29 — OpenShark v0.5.0 Hermes bridge modules

## Architecture

Four bridge modules under `src/hermes/` that wrap Hermes Agent CLI commands:

```
hermes/
├── mod.rs           # discover_hermes_home(), is_hermes_available(), get_status(), initialize()
├── gateway.rs       # is_running(), get_state(), get_platforms(), send_message(), start/stop/restart()
├── skills.rs        # list_skills(), load_skill(), search_skills(), get_skills_by_category(), skill_to_prompt_extension()
├── mcp.rs           # list_servers(), count_servers(), call_tool(), test_server(), mcp_tools_to_openshark()
└── memory_bridge.rs # query_memories(), save_memory(), get_status(), count_memories()
```

## Design Decisions

### 1. CLI-Based Integration (Not Direct DB/API)

All modules shell out to `hermes` CLI rather than reading Hermes's internal SQLite or calling its Python APIs directly. This is **intentional**:

- Hermes internals change frequently — CLI is the stable interface
- No Python dependency in OpenShark (pure Rust)
- Hermes handles auth, retries, formatting
- Easier to maintain — if Hermes changes, only CLI args need updating

**Trade-off:** Slightly higher latency than direct DB reads. Acceptable for non-real-time operations (status checks, skill listing).

### 2. Async Shell Commands

All Hermes CLI calls use `tokio::process::Command`:

```rust
let output = tokio::process::Command::new("hermes")
    .args(["mcp", "list", "--json"])
    .output()
    .await?;
```

This keeps OpenShark responsive during Hermes operations.

### 3. Graceful Degradation

Every module handles "Hermes not installed" gracefully:

```rust
pub fn discover_hermes_home() -> Option<PathBuf> {
    // 1. Check HERMES_HOME env var
    // 2. Check ~/.hermes default
    // 3. Return None if neither exists
}
```

When `discover_hermes_home()` returns `None`, all operations return empty results rather than failing. The TUI continues working without Hermes.

### 4. Gateway State File Parsing

The most reliable way to check gateway status is reading `~/.hermes/gateway_state.json`:

```json
{
  "gateway_state": "running",
  "platforms": {
    "discord": { "state": "connected", "error_code": null },
    "telegram": { "state": "retrying", "error_code": "telegram_connect_error" }
  }
}
```

This is more accurate than `systemctl is-active` because it shows per-platform state.

### 5. Skill Frontmatter Parsing

Hermes skills are markdown files with YAML frontmatter:

```markdown
---
name: hermes-agent
description: Configure, extend, or contribute to Hermes Agent.
version: 2.1.0
tags: [hermes, setup, configuration]
---

# Hermes Agent
...
```

The skills module parses this with a simple `---` delimiter split:

```rust
fn parse_frontmatter(content: &str) -> Result<(SkillFrontmatter, &str)> {
    if !content.starts_with("---") {
        return Ok((default_frontmatter(), content));
    }
    let end = content[3..].find("---").context("missing closing ---")?;
    let yaml_str = &content[3..3 + end];
    let body = &content[3 + end + 3..];
    let frontmatter: SkillFrontmatter = serde_yaml::from_str(yaml_str)?;
    Ok((frontmatter, body))
}
```

**Note:** Requires `serde_yaml` dependency in Cargo.toml.

### 6. MCP Tool Conversion

MCP tools are converted to OpenShark's `ToolDefinition` struct:

```rust
pub fn mcp_tools_to_openshark(mcp_tools: &[McpTool]) -> Vec<ToolDefinition> {
    mcp_tools.iter().map(|t| ToolDefinition {
        name: format!("mcp:{}", t.name),
        description: format!("[MCP] {}", t.description),
        parameters: t.parameters.clone(),
    }).collect()
}
```

The `mcp:` prefix prevents naming collisions with native tools.

## Config Integration

```rust
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct HermesIntegrationConfig {
    pub enabled: bool,
    pub hermes_home: Option<String>,
    pub gateway_enabled: bool,
    pub discord_enabled: bool,
    pub telegram_enabled: bool,
    pub skills_enabled: bool,
    pub memory_bridge_enabled: bool,
    pub mcp_enabled: bool,
    pub tool_calling_enabled: bool,
}
```

All fields have `#[serde(default)]` so existing configs without `[hermes_integration]` work (defaults to disabled).

## CLI Commands

```rust
// main.rs
Hermes {
    #[arg(default_value = "status")]
    cmd: String,
},

// Handler
Some(Commands::Hermes { cmd }) => {
    match cmd.as_str() {
        "status" => { /* print HermesStatus */ }
        "skills" => { /* list skills */ }
        "platforms" => { /* show platform states */ }
        _ => { /* help text */ }
    }
}
```

## Testing Strategy

Each module has unit tests for JSON/YAML parsing:

```rust
#[test]
fn test_gateway_state_parsing() {
    let json = r#"{ "gateway_state": "running", ... }"#;
    let state: GatewayState = serde_json::from_str(json).unwrap();
    assert_eq!(state.gateway_state, "running");
}
```

Integration tests (actual Hermes CLI calls) are skipped if Hermes isn't installed.

## Future Wiring

The scaffold is complete but not yet wired into the TUI startup flow. Next steps:

1. Call `hermes::initialize()` on TUI startup when `hermes_integration.enabled`
2. Inject loaded skills into system prompt via `skill_to_prompt_extension()`
3. Register MCP tools in `get_tools()` when `mcp_enabled`
4. Bi-directional gateway: receive Discord messages in TUI
