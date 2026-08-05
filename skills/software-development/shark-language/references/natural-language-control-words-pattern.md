# Natural Language Control Words Pattern

Intercept conversational control words **before** they hit the model API. Saves tokens, gives instant feedback, and makes the harness feel responsive.

## Why Pre-Filter

- **Saves API tokens** — "stop" doesn't need a round-trip to the model
- **Instant feedback** — no latency waiting for model to understand
- **Reliable** — model might ignore or misunderstand casual language
- **Conversational feel** — harness behaves like a human assistant that understands natural language

## Control Word Map

| User Says | Action |
|-----------|--------|
| "stop", "cancel", "abort", "cancel that" | Cancel current operation, clear streaming state |
| "wait", "hold on", "hold up", "pause" | Pause current operation, show "Paused — say 'continue' to resume" |
| "continue", "go", "proceed", "carry on" | Resume paused operation |
| "status", "what are you doing", "what's happening" | Show current operation status |
| "nevermind", "never mind" | Clear pending operation, return to idle |

## Implementation

Intercept in `process_user_input()` **before** the message is sent to the model:

```rust
fn process_user_input(&mut self, input: &str) {
    let trimmed = input.trim().to_lowercase();

    match trimmed.as_str() {
        "stop" | "cancel" | "abort" | "cancel that" => {
            self.cancel_current_operation();
            self.add_system_message("🛑 Operation cancelled.".to_string());
            return; // Don't send to model
        }
        "wait" | "hold on" | "hold up" | "pause" => {
            self.pause_current_operation();
            self.add_system_message("⏸️ Paused — say 'continue' to resume.".to_string());
            return;
        }
        "continue" | "go" | "proceed" | "carry on" => {
            self.resume_current_operation();
            self.add_system_message("▶️ Resuming...".to_string());
            return;
        }
        "status" | "what are you doing" | "what's happening" => {
            let status = self.get_current_status();
            self.add_system_message(format!("📊 Status: {}", status));
            return;
        }
        "nevermind" | "never mind" => {
            self.clear_pending();
            self.add_system_message("👍 Cleared. What next?".to_string());
            return;
        }
        _ => {}
    }

    // Normal path: send to model
    self.send_to_model(input);
}
```

## Key Design Decisions

1. **Exact match on trimmed lowercase** — avoids false positives on words embedded in sentences ("I want to stop by the store" should NOT cancel)
2. **Return early** — never reaches the model API for control words
3. **System message feedback** — confirms the action so user knows it worked
4. **Session-scoped** — control words affect the current operation, not persisted state

## Files Touched

- `src/tui/mod.rs` — `process_user_input()` pre-filter
