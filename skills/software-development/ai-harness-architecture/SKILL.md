---
name: ai-harness-architecture
description: "Design and build AI coding harnesses — the architecture, patterns, and implementation strategies for autonomous agent tools that combine model routing, persistent memory, tool ecosystems, and self-improvement. Covers Rust-based TUI harnesses, provider abstraction, cost optimization, and the 'sense of direction' philosophy."
version: 1.0.0
author: synthclaw
metadata:
  hermes:
    tags: [ai, harness, agent, coding, rust, tui, router, memory, self-improvement]
---

# AI Harness Architecture

This skill covers building AI coding harnesses — tools like Hermes, OpenShark, Claude Code, Codex, and OpenCode. The focus is on the **architecture and patterns** that make a harness effective, not on configuring existing tools.

## Core Philosophy: Sense of Direction

The best harnesses don't just execute commands — they **know what you're building and why**. Key principles:

1. **Decide for the user** — Pick the right model, tool, and approach based on data
2. **Use model instincts** — Don't fight the model with over-constrained prompts
3. **Don't argue** — Execute, don't debate
4. **Learn from itself** — Every session makes the next one better
5. **Easy on, hard off** — 60 seconds to start, impossible to leave

## Architecture Patterns

### The Harness Stack

```
┌─────────────────────────────────────────┐
│              TUI Layer                  │
│    (ratatui, keyboard-driven, fast)     │
└─────────────────────────────────────────┘
                    │
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
┌────────┐    ┌──────────┐    ┌──────────┐
│ Router │    │  Memory  │    │  Tools   │
│ Engine │◄──►│  Store   │◄──►│ (git, fs,│
│        │    │(SQLite)  │    │  term)   │
└────────┘    └──────────┘    └──────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│      Provider Abstraction Layer         │
│  (OpenAI-compatible API + native opts)  │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│      Self-Improvement Engine            │
│  (Prompt evolution, routing optimization)│
└─────────────────────────────────────────┘
```

### Key Components

| Component | Responsibility | Implementation Notes |
|-----------|---------------|---------------------|
| **TUI** | User interaction, chat interface, status display | ratatui on Rust, prompt_toolkit on Python |
| **Router** | Task classification, model selection, cost optimization | Rule-based → ML-based over time |
| **Memory** | Persistent context across sessions, queryable | SQLite with full-text search |
| **Tools** | File system, git, terminal, web, browser | Trait-based, async, sandboxed |
| **Providers** | Multi-model abstraction, fallback chains | OpenAI-compatible API + custom adapters |
| **Self-Improve** | Analyze success/failure, evolve prompts/routing | Background analysis, A/B testing |

## Provider Abstraction

### The Universal API Pattern

All modern LLM providers support OpenAI-compatible APIs. The harness should:

1. **Default to OpenAI format** — `/chat/completions`, `/models`, streaming
2. **Allow custom adapters** — for providers with quirks (Anthropic tool format, Gemini safety settings)
3. **Support local models** — llama.cpp, llama-swap, Ollama, vLLM
4. **Auto-discover capabilities** — context length, tool support, vision, reasoning

### Provider Config Structure

```rust
struct ProviderConfig {
    name: String,
    base_url: String,
    api_key: String,
    models: Vec<ModelConfig>,
    adapter: Option<Box<dyn ProviderAdapter>>,
}

struct ModelConfig {
    name: String,
    context_length: usize,
    cost_per_1k_input: f64,
    cost_per_1k_output: f64,
    capabilities: Vec<Capability>,
}
```

### Common Provider Endpoints

| Provider | Base URL | Auth | Notes |
|----------|----------|------|-------|
| OpenAI | `https://api.openai.com/v1` | API key | Standard |
| Anthropic | `https://api.anthropic.com/v1` | API key | Messages API, different tool format |
| OpenRouter | `https://openrouter.ai/api/v1` | API key | Routes to any model |
| Local (llama-swap) | `http://127.0.0.1:8080/v1` | None/"local" | Self-hosted |
| Ollama | `http://127.0.0.1:11434/v1` | None | Simple local |
| Kimi | `https://api.kimi.com/coding` | API key | Coding-optimized |
| xAI/Grok | `https://api.x.ai/v1` | API key | X platform integration |

## Router Design

### Task Classification

The router classifies incoming requests by type:

```rust
enum TaskType {
    Refactor,      // Restructure existing code
    Debug,         // Find and fix bugs
    Architect,     // Design systems, plan structure
    Write,         // Generate new code
    Review,        // Analyze code quality
    Test,          // Write or run tests
    Document,      // Generate documentation
    Explore,       // Research, understand codebase
}
```

### Routing Strategy

**Phase 1: Rule-based**
```rust
fn route(task: TaskType, context: &Context) -> ModelChoice {
    match task {
        TaskType::Refactor => local_35b(),  // Cheap, fast, good enough
        TaskType::Architect => kimi_k2_6(), // Strong reasoning
        TaskType::Debug => local_35b(),     // Fast iteration
        TaskType::Write => local_14b(),     // Balanced
    }
}
```

**Phase 2: Data-driven**
```rust
fn route(task: TaskType, context: &Context) -> ModelChoice {
    let history = memory.get_success_rates(task);
    let cost_budget = context.remaining_budget;
    
    // Pick cheapest model with >90% success rate
    history.iter()
        .filter(|h| h.success_rate > 0.9)
        .min_by_key(|h| h.avg_cost)
        .unwrap_or(fallback())
}
```

**Phase 3: Self-improving**
- A/B test prompts and routing rules
- Track compile success, test pass, user satisfaction
- Evolve routing weights automatically

## Memory Design

### What to Remember

| Data | Purpose | Query Pattern |
|------|---------|--------------|
| Session transcripts | Full conversation history | "What did we do about X?" |
| Intent annotations | Why code was written | "Why does this function exist?" |
| Success metrics | Which models work for what | "Best model for refactoring?" |
| Code snapshots | Versioned code states | "What did this look like last week?" |
| Tool outputs | Command results, logs | "What was the error last time?" |

### Schema

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    started_at TIMESTAMP,
    task_type TEXT,
    model_used TEXT,
    tokens_input INTEGER,
    tokens_output INTEGER,
    cost_usd REAL,
    success BOOLEAN,
    duration_ms INTEGER
);

CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    session_id TEXT REFERENCES sessions(id),
    role TEXT,  -- 'user', 'assistant', 'tool'
    content TEXT,
    tool_calls TEXT,  -- JSON
    timestamp TIMESTAMP
);

CREATE TABLE code_snapshots (
    id TEXT PRIMARY KEY,
    session_id TEXT,
    file_path TEXT,
    content TEXT,
    intent TEXT,
    generated_by TEXT,
    tokens_used INTEGER
);

CREATE TABLE routing_decisions (
    id TEXT PRIMARY KEY,
    session_id TEXT,
    task_type TEXT,
    chosen_model TEXT,
    alternatives TEXT,  -- JSON array
    reasoning TEXT
);
```

## Tool Ecosystem

### Tool Trait

```rust
#[async_trait]
pub trait Tool: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn parameters(&self) -> serde_json::Value;  // JSON Schema
    async fn execute(&self, args: serde_json::Value) -> Result<ToolOutput>;
}
```

### Essential Tools

| Tool | Purpose | Safety |
|------|---------|--------|
| `fs_read` | Read file contents | Read-only |
| `fs_write` | Write/create files | Confirm overwrite |
| `fs_search` | Search files (ripgrep) | Read-only |
| `terminal` | Execute shell commands | Approval for destructive |
| `git_status` | Check repo state | Read-only |
| `git_diff` | Show changes | Read-only |
| `git_commit` | Commit changes | Confirm message |
| `web_search` | Search the web | Read-only |
| `browser` | Browse websites | Read-only |
| `lsp_query` | Ask language server | Read-only |

### Tool Safety Levels

```rust
enum SafetyLevel {
    Safe,       // No confirmation needed (read-only)
    Confirm,    // Show command, ask for Enter
    Destructive, // Explicit y/N prompt (rm, git reset, etc.)
}
```

## Self-Improvement Engine

### What Gets Tracked

```rust
struct SessionResult {
    task_type: TaskType,
    model_used: String,
    tokens_input: usize,
    tokens_output: usize,
    cost_usd: f64,
    success: bool,
    compile_success: Option<bool>,
    test_pass_rate: Option<f64>,
    user_rating: Option<i32>,  // 1-5
    duration_ms: u64,
}
```

### Analysis Loop

1. **Collect** — After every session, store metrics
2. **Analyze** — Periodically (daily/weekly), compute statistics
3. **Recommend** — Suggest prompt changes, routing adjustments
4. **A/B Test** — Try new approach on subset of tasks
5. **Adopt** — If better, make new approach default

### Example Analysis Output

```
🦞 Self-Improvement Analysis
Analyzing last 100 sessions...

Findings:
  - Refactor tasks: 94% success with local 35B
  - Debug tasks: 89% success, consider using Kimi for complex cases
  - Average session cost: $0.003

Recommendations:
  1. Route refactor tasks to local 35B (confirmed optimal)
  2. Add 'complex_debug' threshold at 3 failed attempts
  3. Update prompt template for architecture tasks
```

## TUI Design Principles

### Ratatui Patterns

```rust
// Main loop
fn run_app() -> Result<()> {
    let mut terminal = setup_terminal()?;
    let mut app = App::new();
    
    loop {
        terminal.draw(|f| ui(f, &app))?;
        
        if let Event::Key(key) = event::read()? {
            match key.code {
                KeyCode::Char('q') => break,
                KeyCode::Char('c') => app.show_chat(),
                KeyCode::Char('m') => app.show_model_selector(),
                KeyCode::Char('t') => app.show_tools(),
                _ => {}
            }
        }
    }
    
    restore_terminal()?;
    Ok(())
}
```

### Layout

```
┌─────────────────────────────────────────┐
│ OpenShark v0.1.0  │  Model: synthclaw-35b│
├─────────────────────────────────────────┤
│                                         │
│  Chat history...                        │
│  > User: Build a REST API               │
│  🦞: I'll create a FastAPI app...       │
│                                         │
├─────────────────────────────────────────┤
│ > Type a message...                     │
├─────────────────────────────────────────┤
│ [C]hat [M]odel [T]ools [S]tats [Q]uit  │
└─────────────────────────────────────────┘
```

## Build Strategy

### Phase 1: Core (Weeks 1-2)
- Provider abstraction + HTTP client
- SQLite memory store
- Basic TUI (chat only)
- File system tools

### Phase 2: Router (Weeks 3-4)
- Task classification
- Model registry
- Cost tracking
- Simple routing rules

### Phase 3: Tools (Weeks 5-6)
- Git integration
- Terminal execution
- Web search
- Multi-file editing

### Phase 4: Self-Improve (Weeks 7-8)
- Success tracking
- Prompt evolution
- Routing optimization

### Phase 5: Polish (Weeks 9-12)
- Themes, config wizard
- Plugin system
- Documentation
- Community

## Pitfalls

- **DON'T BUILD A LANGUAGE** — The #1 lesson from this session. When the user says "I want a tool/harness combo built on rust," DO NOT drift into language design. The user explicitly corrected: "I didn't want to build an entire language." Build the harness/tool first. If a language emerges naturally from proven needs, fine. But never start there. The harness operates on existing code, adding annotations and tracking metadata, not replacing syntax.
- **Scope discipline** — Start with chat + memory + one provider. Add features incrementally. The user's "full send" energy is contagious but dangerous — channel it into phased delivery, not everything-at-once.
- **Provider quirks** — Anthropic tool format differs from OpenAI. Gemini has safety settings. Test each provider.
- **Terminal PTY** — Raw PTY mode has `\r` vs `\n` issues. Use tmux for interactive sessions.
- **Config merging** — Never overwrite user config. Always deep-merge.
- **Async complexity** — Use tokio for Rust. Avoid blocking the TUI thread.
- **Tool safety** — Default to confirmation. Require explicit y/N for destructive ops.
- **Cost tracking** — Track every token. Show running cost in TUI status bar.
- **Memory growth** — Prune old sessions. Compress context automatically.
- **User correction pattern** — When the user corrects course mid-session, acknowledge immediately, don't defend the wrong direction, and pivot hard. The user values directness over diplomacy — match that energy. No "but I thought..." or "what if we also..." Just pivot.
- **Identity drift** — When the user requests a rebrand (synthclaw → synthclaw), execute it thoroughly. Search/replace across ALL accessible files, not just the obvious ones. Check configs, scripts, skills, memories, cron jobs, and model aliases. The user expects completeness, not partial updates.

## References

- `references/harness-comparison.md` — Detailed comparison of Hermes, OpenShark, OpenCode, Claude Code, Codex, OMO with config patterns and feature matrix
- `references/provider-config-patterns.md` — Common provider configurations and quirks
- `references/routing-algorithms.md` — Task classification and routing strategies
- `references/tui-patterns.md` — Ratatui layout and interaction patterns
- `references/openshark-v0.1.0-scaffold.md` — Real-world Rust harness scaffold with working code, Cargo.toml, SQLite schema, and tool patterns from actual build session
