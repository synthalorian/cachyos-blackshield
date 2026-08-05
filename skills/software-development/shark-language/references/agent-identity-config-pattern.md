# Config-Based Agent Identity Pattern

Session: 2026-05-29 — OpenShark v0.5.0 agent identity refactor

## Problem

The agent personality was hardcoded in `soul.rs` as `AgentSoul::synthclaw()` — every user got synthclaw's identity regardless of their preference. The TUI sidebar showed "OpenShark" as a hardcoded string. The welcome logo was ASCII art that couldn't be customized.

## Solution

Move agent identity into the config (`Config::agent: AgentIdentity`) so each user configures their own agent name, personality, emoji, and branding.

## Implementation

### 1. Config Struct

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentIdentity {
    pub name: String,           // lowercase identifier
    pub display_name: String,   // UI display (can be capitalized)
    pub role: String,
    pub origin: String,
    pub purpose: String,
    pub tagline: String,
    pub tone: String,
    pub style: String,
    pub greeting: String,
    pub farewell: String,
    pub emoji: String,
    pub catchphrases: Vec<String>,
    pub behavioral_rules: Vec<String>,
}

impl Default for AgentIdentity {
    fn default() -> Self {
        // synthclaw identity as default
        Self {
            name: "synthclaw".to_string(),
            display_name: "synthclaw".to_string(),
            // ... rest of default fields
        }
    }
}
```

### 2. Soul Refactor

Old: `load_soul()` — hardcoded, env-var based
New: `load_soul_from_config(config: &Config)` — reads from `config.agent`

```rust
pub struct AgentSoul {
    pub identity: AgentIdentity,
}

impl AgentSoul {
    pub fn from_config(identity: AgentIdentity) -> Self {
        Self { identity }
    }

    pub fn system_prompt(&self) -> String {
        // Dynamically builds prompt from config fields
        // Includes identity, voice, rules, catchphrases, tagline
    }

    pub fn status_line(&self) -> String {
        format!("{} {} — {}",
            self.identity.emoji,
            self.identity.display_name,
            self.identity.role
        )
    }

    pub fn welcome_message(&self) -> String {
        format!("\n{} {}\n{}\n\n{}",
            self.identity.emoji,
            self.identity.display_name,
            self.identity.tagline,
            self.identity.greeting
        )
    }
}
```

### 3. TUI Integration Points

**Sidebar title:**
```rust
let sidebar_block = Block::default()
    .title(format!(" {} ", app.config.agent.emoji))
```

**Sidebar header:**
```rust
let header_lines = vec![
    Line::from(vec![
        Span::styled(format!("{} ", app.config.agent.emoji), shark_style()),
        Span::styled(app.config.agent.display_name.clone(), highlight_style()),
        Span::styled(" v0.2.0", muted_style()),
    ]),
    Line::from(vec![
        Span::styled(app.config.agent.tagline.clone(), muted_style()),
    ]),
];
```

**Welcome message (replaces hardcoded ASCII art):**
```rust
let welcome = format!(
    "\n{} {}\n{}\n\n{}",
    config.agent.emoji,
    config.agent.display_name,
    config.agent.tagline,
    config.agent.greeting
);
app.add_system_message(welcome);
```

**System prompt generation:**
```rust
let soul = crate::agent::soul::load_soul_from_config(&config);
let system_msg = Message {
    role: "system".to_string(),
    content: format!(
        "{}\n\nYou have access to tools:\n{}\n...",
        soul.system_prompt(),
        // tool list
    ),
};
```

### 4. Setup Wizard Integration

The `openshark setup` command now includes an agent identity section:

```rust
println!("🎭 Agent Identity");
let agent_name = prompt("Agent name (lowercase, no spaces):", Some("synthclaw"))?;
let display_name = prompt("Display name:", Some(&capitalize_first(&agent_name)))?;
let emoji = prompt("Emoji:", Some("🎹🦞"))?;
// ... more fields

config.agent = AgentIdentity {
    name: agent_name,
    display_name,
    emoji,
    // ...
};
```

### 5. Test Config Updates

Every test `Config` initializer must include the new fields:

```rust
Config {
    version: "0.1.0".to_string(),
    // ... other fields ...
    agent: AgentIdentity::default(),
    hermes_integration: HermesIntegrationConfig::default(),
}
```

**Pitfall:** Forgetting to add `agent` and `hermes_integration` to test configs causes `E0063: missing fields` errors.

## Migration Path

Existing configs without `[agent]` section work fine — `serde(default)` fills in synthclaw's identity. Users can run `openshark setup` to reconfigure interactively, or edit config.toml directly.

## Result

- TUI sidebar shows user's agent (e.g., "🤖 MyAgent — coding assistant")
- Welcome message uses user's greeting and tagline
- System prompt dynamically builds from user's configured identity
- Fully per-user without code changes
