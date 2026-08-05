# Evolution Engine Architecture

OpenShark's self-evolution system (`src/evolution/mod.rs`) enables the harness to learn from every interaction and adapt its behavior automatically.

## Architecture

```
User Message
    │
    ├─→ Memory Recall (inject relevant past context)
    ├─→ Skill Triggering (load relevant skills)
    ├─→ Model Routing (select best model based on historical performance)
    │
    ▼
Model Response
    │
    ├─→ Tool Execution (with security gate)
    ├─→ Performance Tracking (latency, success/failure)
    │
    ▼
Feedback Loop
    ├─→ Update routing weights
    ├─→ Update tool confidence thresholds
    ├─→ Trigger self-analysis every N sessions
    └─→ Auto-create skills from patterns
```

## Components

### `EvolutionEngine`

Central coordinator stored in `App::evolution` (Option, initialized in `App::new()`):

```rust
pub struct EvolutionEngine {
    pub memory: Arc<Mutex<MemoryStore>>,
    pub skill_registry: Arc<Mutex<SkillRegistry>>,
    pub adaptive_state: Arc<Mutex<AdaptiveState>>,
    pub config: Config,
}
```

### `AdaptiveState`

Serializable state persisted to memory DB as JSON:

```rust
pub struct AdaptiveState {
    pub tool_confidence: HashMap<String, f32>,  // tool_name → threshold
    pub model_bias: HashMap<String, f64>,       // "model:task" → performance multiplier
    pub sessions_since_analysis: usize,
    pub total_sessions: usize,
    pub auto_analysis_enabled: bool,
    pub analysis_threshold: usize,              // default: 20 sessions
}
```

**Default thresholds:**
| Tool | Initial Threshold | Auto-execute if |
|------|------------------|-----------------|
| `fs` | 0.70 | ≤ 0.70 |
| `terminal` | 0.80 | ≤ 0.70 |
| `git` | 0.60 | ≤ 0.70 |
| `search` | 0.60 | ≤ 0.70 |
| `edit` | 0.90 | > 0.70 (confirm first) |
| `lsp` | 0.70 | ≤ 0.70 |
| `refactor` | 0.90 | > 0.70 (confirm first) |
| `test` | 0.70 | ≤ 0.70 |

### Per-Message Enrichment

Before sending to the model, the system prompt is enriched:

1. **Memory Recall** — `ContextInjector::inject_relevant_context()` finds semantically similar past messages (top 3)
2. **Skill Loading** — `SkillRegistry::find_triggered()` loads skills matching query keywords
3. **Adaptive Guidance** — Injects current tool confidence thresholds and model performance notes

```rust
// In process_user_input(), before spawning background task:
let mut model_messages = app.model_messages.clone();
if let Some(ref evolution) = app.evolution {
    let enriched = evolution.build_enriched_prompt(
        &base_prompt, &input, &app.session_id
    );
    model_messages[0].content = enriched;
}
```

### Tool Outcome Tracking

After each tool execution, confidence is adjusted:

```rust
// Success → lower threshold (more auto-execute)
*threshold = (*threshold * 0.95).max(0.5);

// Failure → raise threshold (more confirmation)
*threshold = (*threshold * 1.05).min(0.95);
```

### Model Performance Tracking

Exponential moving average with α = 0.3:

```rust
let outcome = if success { 1.2 } else { 0.8 };
*bias = (*bias * (1.0 - alpha)) + (outcome * alpha);
```

## Integration Points

| Location | Action |
|----------|--------|
| `tui/mod.rs::App::new()` | Initialize `EvolutionEngine` |
| `tui/mod.rs::process_user_input()` | Enrich system prompt before model call |
| `tui/mod.rs::apply_stream_event()` | Track tool outcomes after execution |
| `main.rs` | Add `mod evolution;` |

## Testing

6 unit tests in `src/evolution/mod.rs`:
- `test_adaptive_state_default` — verify defaults
- `test_tool_confidence_adjustment` — success lowers threshold
- `test_tool_confidence_failure_adjustment` — failure raises threshold
- `test_model_bias_tracking` — EMA bias updates
- `test_session_counter` — analysis trigger at threshold
- `test_state_summary` — debug output formatting

## Future Extensions

- **Phase 3 (Meta-cognition):** Self-critique loop after plan failures — scaffolded but not wired
- **Auto-skill creation:** Detect repeated corrections and generate skills automatically
- **System prompt optimization:** A/B test prompt variants per task type
