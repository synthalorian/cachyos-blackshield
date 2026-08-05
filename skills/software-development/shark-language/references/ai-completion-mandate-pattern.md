# AI Completion Mandate Pattern

**Problem:** AI models (especially fast ones like kimi-k2.6) often output a catchphrase or one-liner after tool execution instead of synthesizing results into a complete response. Example: "The tape never stops rolling." followed by silence — leaving the user with raw tool output and no analysis.

**Root cause:** System prompts that say "Be concise and direct. Don't overthink." give the model permission to bail early. Follow-up requests after tool execution don't explicitly demand synthesis.

**Solution:** Three-layer defense — system prompt mandate + follow-up injection + runtime guard.

---

## Layer 1: System Prompt Mandate

Replace permissive brevity instructions with an explicit completion requirement:

```rust
// BEFORE (permits one-liners):
"Be concise and direct. Don't overthink."

// AFTER (mandates completion):
"CRITICAL: When you use a tool, you MUST synthesize the result into a complete response. \
 Never output only a catchphrase, one-liner, or raw data dump. \
 Always explain what you found, what it means, and what the next step is. \
 Finish every thought. Incomplete responses are unacceptable."
```

**Location:** `src/tui/mod.rs` — the system message constructed in `App::new()`.

---

## Layer 2: Follow-Up Injection

After tool execution, inject an explicit user message demanding synthesis before the follow-up API call:

```rust
// In execute_tool_chain() and the natural-language suggestion path:
follow_messages.push(Message {
    role: "user".to_string(),
    content: "Based on the tool results above, provide a COMPLETE response. \
              Synthesize what you found, explain what it means, and state the next step clearly. \
              Do NOT output only a one-liner or catchphrase. Finish your thought fully."
        .to_string(),
    images: None,
});
```

**Locations:**
- `src/tui/mod.rs::execute_tool_chain()` — after collecting all tool results
- `src/tui/mod.rs::stream_model_response_task()` — natural-language suggestion follow-up path

---

## Layer 3: Runtime Guard

Detect incomplete follow-ups and auto-re-prompt:

```rust
// In StreamEvent::FollowUp handler:
let trimmed = content.trim();
let word_count = trimmed.split_whitespace().count();
let is_incomplete = word_count < 15
    || (trimmed.len() < 100 && !trimmed.ends_with('.'))
    || trimmed.starts_with("The tape")
    || trimmed.starts_with("Alright")
    || trimmed.starts_with("Let's see")
    || trimmed.starts_with("Here we go");

if is_incomplete && !trimmed.is_empty() {
    // Show warning, inject completion prompt, spawn new API call
    self.add_system_message(
        "⚠️ Response seems incomplete — synthesizing full answer...".to_string()
    );
    self.model_messages.push(Message {
        role: "assistant".to_string(),
        content: content.clone(),
        images: None,
    });
    self.model_messages.push(Message {
        role: "user".to_string(),
        content: "That response was too brief. Provide a COMPLETE synthesis of what was found, what it means, and the next step. No one-liners.".to_string(),
        images: None,
    });
    // Spawn stream_model_response_task with updated messages
}
```

**Location:** `src/tui/mod.rs` — `StreamEvent::FollowUp` match arm in `apply_stream_event()`.

---

## Heuristics for Incomplete Detection

| Signal | Threshold | Rationale |
|--------|-----------|-----------|
| Word count | < 15 | A complete thought needs at least a sentence or two |
| Character count | < 100 | Too short to contain analysis + meaning + next step |
| Missing terminal punctuation | No `.`/`!`/`?` at end | Sentence fragment indicator |
| Known catchphrase starts | "The tape", "Alright", "Let's see", "Here we go" | Model's habitual openers that precede bailing |

Adjust thresholds per model. Fast models (kimi-k2.6) may need stricter thresholds than slower reasoning models.

---

## Agent Planning Prompt

The same principle applies to agentic plan generation:

```rust
// In src/agent/mod.rs::generate_plan():
"CRITICAL: Every plan step must have a clear expected_result and verification_criteria. \
 Vague or one-line plans are unacceptable. Be thorough and specific."
```

---

## Layer 4: Empty Follow-Up Detection (Sender-Side)

The runtime guard (Layer 3) only catches non-empty but incomplete responses. Models can also return **literally nothing** — empty chunks or whitespace-only follow-ups. This slips past the `!trimmed.is_empty()` check.

**Fix at the source** — in `execute_tool_chain()` and the suggestion follow-up path, check before sending:

```rust
match provider.chat_stream(follow_up).await {
    Ok((follow_chunks, _metrics)) => {
        let follow_content: String = follow_chunks.join("");
        let trimmed = follow_content.trim();
        if trimmed.is_empty() {
            let _ = tx.send(StreamEvent::Error(
                "Model returned empty follow-up after tool execution. Re-prompting for synthesis...".to_string()
            ));
            // Re-prompt with stronger mandate
            let mut retry_messages = model_messages.to_vec();
            retry_messages.push(Message {
                role: "user".to_string(),
                content: "The previous response was empty. You MUST provide a complete synthesis of the tool results. \
                          Explain what was found, what it means, and the next step. Do not skip this.".to_string(),
                images: None,
            });
            let retry_req = ChatRequest::new(model.to_string(), retry_messages, true);
            match provider.chat_stream(retry_req).await {
                Ok((rc, _)) => { let _ = tx.send(StreamEvent::FollowUp(rc.join(""))); }
                Err(e) => { let _ = tx.send(StreamEvent::Error(format!("Retry failed: {}", e))); }
            }
        } else if trimmed.split_whitespace().count() < 15 {
            // Too short — same retry pattern with "too brief" message
            // ...
        } else {
            let _ = tx.send(StreamEvent::FollowUp(follow_content));
        }
        let _ = tx.send(StreamEvent::Done);
    }
    Err(e) => {
        let _ = tx.send(StreamEvent::Error(format!("Follow-up failed: {}", e)));
        let _ = tx.send(StreamEvent::Done);
    }
}
```

**Critical:** This applies to BOTH follow-up paths:
1. `execute_tool_chain()` — after explicit `TOOL:` command execution
2. `stream_model_response_task()` — after natural-language suggestion execution

---

## Visual Feedback

The user needs to know something is happening during tool execution and re-prompting:

```rust
// Before running tools:
let _ = tx.send(StreamEvent::SystemMessage(
    format!("🔧 Running {} tool(s)...", tools.len())
));

// On empty/short detection:
let _ = tx.send(StreamEvent::SystemMessage(
    "⚠️ Response seems incomplete — synthesizing full answer...".to_string()
));

// On retry:
let _ = tx.send(StreamEvent::Error(
    "Model returned empty follow-up after tool execution. Re-prompting for synthesis...".to_string()
));
```

Without these messages, the TUI appears frozen — the user can't tell if the model is thinking, stuck, or done.

---

## Install Pitfall: Text File Busy

When installing the release binary to `~/.local/bin/` while the TUI is running:

```bash
cp target/release/openshark ~/.local/bin/openshark
# cp: cannot create regular file '/home/synth/.local/bin/openshark': Text file busy
```

**Fix:** Kill the running process first:

```bash
pkill -f openshark
sleep 1
cp target/release/openshark ~/.local/bin/openshark
```

Or use `install` command which handles this:

```bash
install -Dm755 target/release/openshark ~/.local/bin/openshark
```

---

## Testing

Verify the fix by asking the model to inspect a codebase and report findings:

```
User: Inspect the Chronos engine and understand its architecture.
```

**Before fix:** "Alright, let's see what we're working with. The tape never stops rolling." + raw file listing.

**After fix:** Synthesized analysis — "The engine uses an ECS architecture with Bevy-inspired components. Key files: terrain.rs (procedural generation), mercenary.rs (entity behavior), navigation.r (pathfinding). Next step: examine the render pipeline in render.wgsl."

**Empty follow-up case:** If the model returns nothing, you should see:
1. "🔧 Running 4 tool(s)..."
2. Tool results displayed
3. "⚠️ Response seems incomplete — synthesizing full answer..."
4. Or: "Model returned empty follow-up after tool execution. Re-prompting for synthesis..."
5. Complete synthesis appears

---

## Related

- `references/tui-embedded-tool-execution-pattern.md` — Tool execution flow where completion mandate applies
- `references/tui-tool-execution-followup-pattern.md` — Natural-language tool suggestion follow-up
- `references/tui-streaming-hang-followup-done.md` — Ensuring Done signals after follow-up
- `references/cargo-install-path-discipline.md` — Binary must be copied to PATH after release builds
