# OpenShark v0.1.0 — Real-World Scaffold Reference

This reference captures the actual project structure, patterns, and working code from the OpenShark build session. Use it as a template for future Rust harness projects.

## Project Structure

```
openshark/
├── Cargo.toml              # Dependencies: tokio, clap, ratatui, reqwest, rusqlite, etc.
├── README.md               # Vision, quickstart, architecture diagram
├── ROADMAP.md              # Phased plan with weekly milestones
├── STATUS.md               # Session handoff doc for continuity
└── src/
    ├── main.rs             # CLI entry (clap subcommands, async tokio)
    ├── config/
    │   ├── mod.rs          # Config struct with serde, load/save, defaults
    │   └── setup.rs        # Interactive setup wizard
    ├── memory/
    │   ├── mod.rs          # Public exports
    │   └── store.rs        # SQLite: sessions, messages, tool_calls tables
    ├── providers/
    │   └── mod.rs          # Provider struct, chat(), chat_stream(), list_models()
    ├── router/
    │   └── mod.rs          # Routing decisions (task → model mapping)
    ├── self_improve/
    │   └── mod.rs          # Analysis engine, success tracking
    ├── tools/
    │   ├── mod.rs          # Tool trait, registry, find_tool()
    │   ├── fs.rs           # File system: read, write, list
    │   └── terminal.rs     # Shell command execution
    └── tui/
        └── mod.rs          # Interactive session loop with tool invocation
```

## Key Patterns

### 1. Provider Abstraction (OpenAI-Compatible)

```rust
pub struct Provider {
    pub name: String,
    pub base_url: String,
    pub api_key: String,
}

impl Provider {
    pub async fn chat(&self, request: ChatRequest) -> Result<ChatResponse> {
        let client = reqwest::Client::new();
        let url = format!("{}/chat/completions", self.base_url.trim_end_matches('/'));
        
        let response = client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.api_key))
            .json(&request)
            .send()
            .await?;
        
        let chat_response: ChatResponse = response.json().await?;
        Ok(chat_response)
    }
}
```

### 2. Tool Trait Pattern

```rust
pub trait Tool: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn execute(&self, args: &str) -> Result<String>;
}

pub fn get_tools() -> Vec<Box<dyn Tool>> {
    vec![
        Box::new(fs::FsTool),
        Box::new(terminal::TerminalTool),
    ]
}
```

### 3. SQLite Memory Schema

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    started_at TEXT NOT NULL,
    model TEXT NOT NULL,
    task_type TEXT NOT NULL DEFAULT 'general'
);

CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TEXT NOT NULL,
    tokens_used INTEGER
);

CREATE TABLE tool_calls (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    tool_name TEXT NOT NULL,
    args TEXT NOT NULL,
    result TEXT NOT NULL,
    success INTEGER NOT NULL,
    created_at TEXT NOT NULL
);
```

### 4. TUI Session Loop

```rust
pub async fn run(config: Config) -> Result<()> {
    let provider = Provider { ... };
    let memory = MemoryStore::new(&config.memory_db_path)?;
    let session_id = Uuid::new_v4().to_string();
    
    memory.create_session(&session_id, &model, "general")?;
    
    let mut messages: Vec<Message> = vec![system_prompt()];
    
    loop {
        // Read user input
        // Handle commands (help, tools, history, exit)
        // Handle TOOL: invocations
        // Call provider.chat()
        // Check for model-initiated tool use
        // Persist to memory
    }
}
```

### 5. Config with Defaults

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub version: String,
    pub default_model: String,
    pub providers: HashMap<String, ProviderConfig>,
    pub memory_db_path: PathBuf,
    pub tools_enabled: Vec<String>,
    pub auto_route: bool,
    pub cost_limit_usd: f64,
}

impl Default for Config {
    fn default() -> Self {
        let mut providers = HashMap::new();
        providers.insert("local".to_string(), ProviderConfig {
            base_url: "http://127.0.0.1:8080/v1".to_string(),
            api_key: "local".to_string(),
            models: vec![ModelConfig { ... }],
        });
        Config { ... }
    }
}
```

## Cargo.toml Dependencies

```toml
[dependencies]
tokio = { version = "1.44", features = ["full"] }
clap = { version = "4.5", features = ["derive"] }
ratatui = "0.29"
crossterm = "0.29"
reqwest = { version = "0.12", features = ["json", "stream"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
rusqlite = { version = "0.34", features = ["bundled", "chrono"] }
toml = "0.8"
dirs = "6.0"
anyhow = "1.0"
thiserror = "2.0"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.16", features = ["v4", "serde"] }
walkdir = "2.5"
regex = "1.11"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
```

## Working Commands

```bash
# Start TUI
openshark

# Setup config
openshark setup

# Use tools directly in chat
> TOOL:terminal ls -la
> TOOL:fs read README.md

# Check routing decisions
openshark route

# Trigger self-improvement analysis
openshark learn
```

## Config Locations

- Config: `~/.config/openshark/config.toml`
- Memory: `~/.local/share/openshark/memory.db`

## Lessons from Build

1. **Start simple** — Chat loop first, then add tools, then add TUI
2. **SQLite for memory** — rusqlite with bundled feature, no external deps
3. **reqwest for HTTP** — Handles OpenAI-compatible APIs natively
4. **clap for CLI** — Derive macros make subcommands trivial
5. **Tool pattern** — Trait-based, sync execution (terminal, fs), async for network
6. **Session persistence** — Every message and tool call saved to SQLite
7. **System prompt** — Tell the model about available tools so it can suggest them
