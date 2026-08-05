# Swarm + Code Mode Contention Fix

## Problem

When swarm mode is active and a user sends a regular chat message (or uses `agent:` mode), both the swarm agents AND the main TUI spawn LLM calls to the same provider. This causes:
- Provider overload (too many concurrent requests)
- Agent timeouts (120s default insufficient when requests queue)
- Confusing UX — user sees "Agents working..." but also gets a competing response

## Root Cause

The TUI's `process_user_input()` has no guard against regular chat while `app.swarm_running` is true. The swarm's `AgentRunner` uses `provider.chat()` (blocking call) with a 120s timeout. With 4 agents all hitting the same local proxy simultaneously, requests queue and timeout.

## Fix (3 parts)

### 1. TUI Swarm Guard

In `src/tui/mod.rs::process_user_input()`, after adding the user message but before spawning the model response:

```rust
app.add_user_message(input.clone());

// ── Swarm Guard: Block regular chat while swarm is working ─────────────
if app.swarm_running {
    app.add_system_message(
        "⏸ Swarm is active. Regular chat is paused while agents work.\n\
         Use `/swarm status` for progress or `/swarm stop` to halt agents."
            .to_string(),
    );
    return Ok(());
}
```

This blocks regular chat AND `agent:` mode (which comes after the guard).

### 2. Staggered Agent Starts

In `src/swarm/mod.rs::start()`, add a delay between agent spawn tasks:

```rust
for (i, (agent_id, runner)) in runners.iter().enumerate() {
    let delay_ms = (i * 2000) as u64; // 2s stagger per agent
    tokio::spawn(async move {
        if delay_ms > 0 {
            tokio::time::sleep(Duration::from_millis(delay_ms)).await;
        }
        // ... execute task
    });
}
```

Architect goes first, Implementer at +2s, Reviewer at +4s, Tester at +6s.

### 3. Increased Swarm Timeout

In `src/swarm/agent_runner.rs`, bump the LLM call timeout:

```rust
let response = match tokio::time::timeout(
    Duration::from_secs(180), // was 120s
    self.provider.chat_stream(request)
).await {
```

Update the error message to match: `"LLM call timed out after 180s"`.

## Verification

1. Start swarm: `/swarm init "prompt"` then `/swarm start`
2. Try typing a regular message — should see pause notice
3. In a second terminal, start another OpenShark TUI — swarm agents should not timeout
4. Check agent stagger: Architect starts immediately, others at 2s intervals

## Files Modified

- `src/tui/mod.rs` — Swarm guard in `process_user_input()`
- `src/swarm/mod.rs` — Staggered starts in `start()`
- `src/swarm/agent_runner.rs` — Timeout bump + `chat_stream` instead of `chat`
