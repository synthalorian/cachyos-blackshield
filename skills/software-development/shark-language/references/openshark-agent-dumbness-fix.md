# OpenShark Agent Dumbness Fix — Session Notes

## Problem

OpenShark TUI agent was:
- Dropping tasks (outputting TOOL: lines but not executing them)
- Confusing "test" with full test suite analysis instead of just running tests
- Not adapting to situation (always over-explaining, always synthesizing entire codebase)
- Thinking/reasoning from models like kimi-k2.6 was lost when embedded in `<think>` tags inside regular content deltas

## Root Causes

1. **System prompt was contradictory** — told model to "scale output to complexity" AND "synthesize everything" AND "output TOOL: lines" all at once. Model got confused and output preamble + TOOL lines mixed together, then the code stripped TOOL lines and left only catchphrases.

2. **No direct command routing** — "test" went through full LLM round-trip. Model would say "let me check what tests exist" instead of just running them.

3. **Overzealous "incomplete response" guards** — FollowUp handler re-prompted on ANY response under 15 words or starting with catchphrases. Created loops where model got scolded for brevity and overcorrected.

4. **Thinking extraction only worked for `reasoning_content` deltas** — When model embedded `<think>...</think>` inside regular `content` stream, the tags got stripped and the thinking was lost forever.

5. **Synthesis prompts were adversarial** — "COMPLETE response / One-liners unacceptable / No catchphrases" language made the model defensive and verbose.

## Fixes Applied

### 1. Direct System Prompt (tui/mod.rs)

OLD:
```
CRITICAL: When you use a tool, you MUST synthesize the result into a complete response.
Never output only a catchphrase, one-liner, or raw data dump.
Always explain what you found, what it means, and what the next step is.
Finish every thought. Incomplete responses are unacceptable.

IMPORTANT: Match your response scope to the user's request.
If the user says 'test', just run the test — don't explain the entire codebase.
```

NEW:
```
When you need to use a tool, output ONLY: TOOL:<tool_name> <args>
Do NOT say 'Let me', 'I will', 'Alright', or any preamble before the TOOL: line.
Just output the TOOL: line and nothing else.

After tool results come back, you will be prompted to synthesize.
When synthesizing: explain what was found, what it means, and the next step.
Be complete. No one-liners. No catchphrases.

If the user says 'test', run the test tool immediately.
If the user gives a one-line task, just do it. No manifesto.
```

### 2. Direct Command Routing (tui/mod.rs)

Added before `add_user_message`:
```rust
if input.trim().eq_ignore_ascii_case("test") {
    let project_path = std::env::current_dir().map(...).unwrap_or_else(|_| ".".to_string());
    app.add_user_message(input.clone());
    let test_tool = crate::tools::test_runner::TestTool;
    match crate::tools::Tool::execute(&test_tool, &format!("run {}", project_path)) {
        Ok(result) => { app.add_system_message(result.clone()); ... }
        Err(e) => app.add_system_message(format!("Test error: {}", e)),
    }
    return Ok(());
}
```

### 3. Removed Overzealous Guards (tui/mod.rs)

OLD FollowUp handler:
```rust
let is_incomplete = word_count < 15
    || (trimmed.len() < 100 && !trimmed.ends_with('.'))
    || trimmed.starts_with("The tape")
    || trimmed.starts_with("Alright")
    || trimmed.starts_with("Let's see")
    || trimmed.starts_with("Here we go");
if is_incomplete && !trimmed.is_empty() { re-prompt... }
```

NEW:
```rust
if trimmed.is_empty() { re-prompt... }
else { add_assistant_message(content); }
```

Same fix applied to all 3 follow-up paths in `stream_model_response_task` and `stream_model_response_task_legacy`.

### 4. Real-Time Thinking Extraction (tui/mod.rs)

Added `extract_thinking_from_chunk()`:
```rust
fn extract_thinking_from_chunk(chunk: &str) -> (Option<String>, String) {
    // Parses <think>...</think> blocks from ANY chunk
    // Handles partial tags across chunk boundaries
    // Returns (reasoning_text, remaining_content)
}
```

Wired into `StreamEvent::Chunk` handler:
```rust
StreamEvent::Chunk(chunk) => {
    let (reasoning, content) = extract_thinking_from_chunk(&chunk);
    if let Some(r) = reasoning {
        self.reasoning_content.push_str(&r);
        self.is_reasoning = true;
    }
    self.streaming_content.push_str(&content);
}
```

Reasoning messages now saved to BOTH chat history AND model context:
```rust
// In ResponseComplete handler
if !self.reasoning_content.is_empty() {
    self.messages.push(ChatMessage { content: format!("<think>{}</think>", ...), ... });
    self.model_messages.push(Message { content: format!("<think>{}</think>", ...), ... });
}
```

### 5. Softer Synthesis Prompts

Changed all instances of:
```
Synthesize the tool result into a COMPLETE response.
Explain what was found, what it means, and what to do next.
One-liners and raw data dumps are unacceptable.
```

To:
```
Synthesize the tool result into a complete response.
Explain what was found, what it means, and what to do next.
```

## Verification

- `cargo build` compiles successfully
- No new warnings introduced
- All changes are in `src/tui/mod.rs`

## Files Modified

- `/home/synth/projects/openshark/src/tui/mod.rs` — All fixes
