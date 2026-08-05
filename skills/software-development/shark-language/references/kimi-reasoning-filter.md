# Kimi Reasoning Content Filter

**Session:** 2026-05-29
**Status:** Superseded by `references/tui-real-time-reasoning-display.md` for users who want reasoning visibility. Still valid for "clean output" default behavior.

## The Problem

Kimi k2.6 (and other reasoning models) return a `reasoning_content` field in the streaming delta alongside `content`. This contains the model's internal chain-of-thought — visible to the user as raw thinking text like:

> "The user is asking 'what is your name'. I need to respond as synthclaw (always lowercase), with the retro-futuristic personality described in the system prompt..."

This leaks the model's internal planning and looks broken to users.

## Root Cause

In `src/providers/mod.rs`, the streaming parser was checking `reasoning_content` BEFORE `content`:

```rust
// WRONG — reasoning_content leaks to user
event.get("choices")
    .and_then(|c| c.get(0))
    .and_then(|c| c.get("delta"))
    .and_then(|d| d.get("reasoning_content"))  // ← leaks thinking
    .and_then(|c| c.as_str())
    .or_else(|| {
        event.get("choices")
            .and_then(|c| c.get(0))
            .and_then(|c| c.get("delta"))
            .and_then(|d| d.get("content"))
            .and_then(|c| c.as_str())
    })
```

## Fix (Hide Reasoning — Default Behavior)

Only stream `content`. The `reasoning_content` is for internal use only (if ever needed for debugging, log it separately).

```rust
// CORRECT — only content reaches user
event.get("choices")
    .and_then(|c| c.get(0))
    .and_then(|c| c.get("delta"))
    .and_then(|d| d.get("content"))
    .and_then(|c| c.as_str())
```

## When to Show vs Hide Reasoning

| Scenario | Action | Rationale |
|----------|--------|-----------|
| **Default TUI chat** | **Hide** — filter out `reasoning_content` | Users want clean responses, not raw chain-of-thought |
| **Debug/diagnostic mode** | Show — log `reasoning_content` to file | Developers need to see model reasoning for debugging |
| **Explicit user request** | Show — if user says "show me your thinking" | Respect user intent |
| **Swarm agent inspector** | Hide — same as main chat | Consistency across all output channels |
| **Real-time reasoning display** | **Show** — see `references/tui-real-time-reasoning-display.md` | User wants transparency into model thinking as it streams |

## Non-Streaming Path

For non-streaming `chat()` method, the same issue exists. The fix there extracts `content` directly from `message.content`:

```rust
// In chat() response parsing:
let content = raw["choices"][0]["message"]["content"]
    .as_str()
    .unwrap_or("");
```

The `reasoning_content` at `raw["choices"][0]["message"]["reasoning_content"]` should be ignored for user-facing output.

## Testing

After the fix, asking "what is your name" should return clean output like:
> "synthclaw. 🎹🦞 Born from the VHS tracking static of 1984..."

Not the raw chain-of-thought.

## Related

- `references/tui-real-time-reasoning-display.md` — For users who WANT to see reasoning in real-time (dual-stream ephemeral rendering)
