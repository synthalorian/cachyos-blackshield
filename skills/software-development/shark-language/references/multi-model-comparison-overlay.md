# Multi-Model Comparison Overlay — Implementation Notes

Session: 2026-05-30. Multi-model comparison overlay added to OpenShark TUI.

## Architecture

When multi-model mode is enabled, the primary model streams first, then secondary models run in parallel. Secondary responses are attached to the primary assistant message rather than creating separate system messages.

### Data Model

```rust
/// A secondary model response attached to a primary assistant message.
#[derive(Debug, Clone)]
struct SecondaryResponse {
    model_name: String,
    content: String,
    latency_ms: u64,
    tokens: u32,
}

struct ChatMessage {
    role: String,
    content: String,
    timestamp: chrono::DateTime<Utc>,
    multi_model_responses: Vec<SecondaryResponse>,  // NEW
}
```

All 3 constructors (`add_user_message`, `add_assistant_message`, `add_system_message`) must initialize `multi_model_responses: Vec::new()`.

### Event Flow

```
Background Task (primary model)
  → StreamEvent::ResponseComplete { content, metrics }
    → Creates assistant message in chat history

Background Task (secondary models, parallel)
  → StreamEvent::MultiModelResponse { name, content, metrics }
    → Finds LAST assistant message via rposition
    → Pushes SecondaryResponse into its vector
```

**Key pattern — attaching to last assistant:**
```rust
StreamEvent::MultiModelResponse { name, content, metrics } => {
    if !content.is_empty() {
        if let Some(last_idx) = self.messages.iter().rposition(|m| m.role == "assistant") {
            self.messages[last_idx].multi_model_responses.push(SecondaryResponse {
                model_name: name,
                content,
                latency_ms: metrics.total_latency_ms,
                tokens: metrics.tokens_generated,
            });
        }
    }
}
```

Using `rposition` (reverse search) ensures we attach to the most recent assistant message, even if system messages or tool results were added after it.

### Overlay UI

- **Trigger:** `Ctrl+V` toggles overlay
- **Size:** 90% × 85% centered popup
- **Content:** Primary response (first 10 lines) + all secondary responses with model name, latency, token count
- **Navigation:** ↑/↓ selects secondary response; selected shows 20 lines, others show 3
- **Indicator:** "📊 N alternate responses — Ctrl+V to compare" appears below assistant messages in chat area

### Keybindings (3 places to update)

1. `handle_input()` — Ctrl+V toggle, ↑/↓ navigation when overlay active, Esc closes overlay
2. `draw_sidebar()` shortcuts — add "Ctrl+V  Compare models"
3. Help text — add to keybindings section

### State Fields

```rust
struct App {
    // ... existing fields ...
    show_comparison: bool,      // overlay visibility
    comparison_selected: usize, // which secondary response is highlighted
}
```

Both initialized in `App::new()`: `show_comparison: false, comparison_selected: 0`.
