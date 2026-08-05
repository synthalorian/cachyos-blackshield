# TUI Tool Execution → Result → Follow-Up Pattern

**Problem:** When the model responds with natural language like "Let me check what's in your projects folder...", the UI detects a tool suggestion and executes it. But if execution is fire-and-forget (spawns a task and never waits for the result), the user sees:
1. Assistant: "Let me check..."
2. System: "🔧 Auto-executing: fs list /path (low risk)"
3. *[silence — no result, no follow-up]*

The tool ran, but the result never fed back into the model context, so no follow-up response is generated. The user thinks OpenShark is stuck or lost its context.

**Root Cause:** The tool execution happened in the UI thread (`apply_stream_event`) via `tokio::spawn(async move { ... })` with the result discarded. The background streaming task (`stream_model_response_task`) had already completed and sent `StreamEvent::Done`.

**Solution:** Move ALL tool execution into the background streaming task. The UI thread should only:
- Display messages (assistant text, system notices)
- Handle approval-required tools (y/n popup)
- Never execute tools directly

The background task handles both `TOOL:...` format AND natural-language suggestions:

```
Background Task Flow:
  1. Stream model response chunks → UI shows streaming indicator
  2. ResponseComplete event → UI shows full assistant message
  3. Detect tool suggestion (TOOL: format OR natural language)
  4. Security gate check
  5. If Allow → execute tool → send ToolResult event → build follow-up messages → stream follow-up → send FollowUp event
  6. If RequireApproval → send Error event (UI shows popup)
  7. If Deny → send Error event
  8. Send Done event
```

**Implementation Details:**

1. **Remove fire-and-forget from UI:** In `apply_stream_event` → `ResponseComplete`, the `SecurityDecision::Allow` branch should do NOTHING. The background task handles it.

2. **Add natural-language suggestion handling to background task:** After the `TOOL:...` handling block, add an `else` branch that:
   - Calls `detect_tool_suggestions()` on the full response
   - If a high-confidence suggestion (≥0.6) is found, runs the same execute → result → follow-up flow
   - Sends `StreamEvent::SystemMessage` for the auto-execution notice

3. **Add `SystemMessage` variant to `StreamEvent`:**
   ```rust
   enum StreamEvent {
       // ... existing variants ...
       SystemMessage(String),  // Info/notice messages from background task
   }
   ```
   And handle it in `apply_stream_event`:
   ```rust
   StreamEvent::SystemMessage(msg) => self.add_system_message(msg),
   ```

4. **Follow-up message construction for natural-language path:**
   ```rust
   let mut follow_messages = model_messages.clone();
   follow_messages.push(Message {
       role: "assistant".to_string(),
       content: full_content.clone(),  // The natural language response
   });
   follow_messages.push(Message {
       role: "user".to_string(),
       content: format!("Tool result: {}", sanitized),
   });
   ```
   This preserves the conversation flow: assistant said it would check, tool result arrives, assistant responds to the result.

**Key Insight:** The model's natural-language response IS part of the context. Don't replace it with `TOOL:...` — append the tool result as the next user message. The model will see its own intent + the result and generate an appropriate follow-up.

**Files Modified:**
- `src/tui/mod.rs` — `StreamEvent` enum, `apply_stream_event()`, `stream_model_response_task()`

**Verification:**
1. Ask "what's in my projects folder?"
2. Should see: assistant message → system "auto-executing" → system "result" → assistant follow-up analyzing the results
3. All four messages appear as separate chat entries
