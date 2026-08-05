# TUI Metrics Debugging Pattern

**Session:** 2026-05-31 — Swarm metrics not updating, performance panel empty
**Context:** User reported tokens, context used, performance data, and tool counts were all stuck at initial values during swarm operation. Agents showed "working" but no visible progress.

## Root Causes & Fixes

### 1. Token Count Stuck at 0

**Cause:** Slash commands (`/swarm`, `/agent`, etc.) bypassed `add_user_message()`, which was the only place incrementing `tokens_used`.

**Fix:** Count tokens at `process_user_input()` entry — before any command routing:
```rust
// In process_user_input(), at the very start:
app.tokens_used += input.len() as u64 / 4;
```

This ensures ALL input (regular chat, `/swarm` commands, `/agent` tasks) counts toward tokens.

### 2. Context Used Unrealistic (Word Count)

**Cause:** `context_used()` used `split_whitespace().count()` — ~335 words for the system prompt, but tokens are ~4 chars each in English.

**Fix:** Use character-based estimation:
```rust
// Before (wrong):
let words: Vec<&str> = content.split_whitespace().collect();
words.len() as u64

// After (better):
content.len() as u64 / 4
```

`len() / 4` is a standard heuristic (~4 chars/token for English text with code). Not perfect (no tiktoken) but far more realistic than word count.

### 3. Performance Panel Empty During Swarm

**Cause:** `session_perf` only records metrics from streaming `chat_stream()` calls. Swarm uses non-streaming `provider.chat()`, so no metrics accumulate.

**Fix:** Show swarm stats as fallback when swarm is active but streaming metrics are empty:
```rust
if app.swarm_running && app.session_perf.requests == 0 {
    // Show swarm agent counts instead of empty metrics
    let working = agents.iter().filter(|a| matches!(a.status, Working{..})).count();
    let done = agents.iter().filter(|a| matches!(a.status, Completed{..})).count();
    let errors = agents.iter().filter(|a| matches!(a.status, Error{..})).count();
    // Render: "Swarm active — 3 working, 2 done, 0 errors (5 cycles)"
}
```

### 4. Tool Calls Not Counted for Swarm

**Cause:** `AgentToolCall` swarm events didn't increment `tool_calls_count`.

**Fix:** Add tool counting in the swarm event handler:
```rust
SwarmEvent::AgentToolCall { .. } => {
    app.tool_calls_count += 1;
    // ... existing handling
}
```

### 5. Agents Hanging Indefinitely

**Cause:** Swarm's `provider.chat()` (non-streaming) has no timeout. A slow or stuck LLM call blocks the agent forever.

**Fix:** Wrap with `tokio::time::timeout`:
```rust
use tokio::time::{timeout, Duration};

match timeout(Duration::from_secs(120), self.provider.chat(request)).await {
    Ok(Ok(response)) => { /* process response */ }
    Ok(Err(e)) => { /* provider error */ }
    Err(_) => { /* timeout — agent stuck for 120s */ }
}
```

120 seconds is generous enough for complex reasoning while preventing indefinite hangs.

## Verification Checklist

After fixing metrics, verify with:
1. Type regular chat → tokens should increment
2. Type `/swarm init "test"` → tokens should increment
3. Run swarm → performance panel should show agent counts
4. Watch context used → should reflect realistic token estimates
5. Let swarm run → tool calls count should increment when agents use tools

## Key Insight

**Non-streaming paths don't produce `StreamEvent` metrics.** Any feature using `provider.chat()` instead of `chat_stream()` needs its own metrics path, or the UI must show alternative data (like swarm agent status) when streaming metrics are absent.
