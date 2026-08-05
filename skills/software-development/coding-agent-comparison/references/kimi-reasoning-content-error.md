# Kimi K2.6 `reasoning_content` Error

## Error

```
error: api returned 400 Bad Request (invalid_request_error):
thinking is enabled but reasoning_content is missing in assistant tool call message at index 2
```

## Context

- **Model:** `kimi-k2.6` via Kimi Coding Plan proxy (`127.0.0.1:8699`) or direct API
- **Tool:** `claw analyze ~/projects/chronos-engine --depth full`
- **Trigger:** claw-code sends conversation history back to Kimi, but the assistant message containing a tool call lacks `reasoning_content`. Kimi expects it because "thinking" is enabled.

## Root Cause

`model_requires_reasoning_content_in_history()` in `crates/api/src/providers/openai_compat.rs` only returns `true` for `deepseek-v4` models. Kimi K2.6 (and K2.5) also sends `reasoning_content` in responses and expects it preserved in history on subsequent turns. When claw-code strips it, Kimi returns 400.

## Fix (Patch claw-code)

File: `~/claw-code/rust/crates/api/src/providers/openai_compat.rs`

```rust
// Before:
pub fn model_requires_reasoning_content_in_history(model: &str) -> bool {
    let lowered = model.to_ascii_lowercase();
    let canonical = lowered.rsplit('/').next().unwrap_or(lowered.as_str());
    canonical.starts_with("deepseek-v4")
}

// After:
pub fn model_requires_reasoning_content_in_history(model: &str) -> bool {
    let lowered = model.to_ascii_lowercase();
    let canonical = lowered.rsplit('/').next().unwrap_or(lowered.as_str());
    canonical.starts_with("deepseek-v4") || canonical.starts_with("kimi-k2")
}
```

This covers `kimi-k2.6`, `kimi-k2.5`, `kimi-k2`, and provider-prefixed variants like `kimi/kimi-k2.6`.

## Verification

```bash
cd ~/claw-code/rust && cargo build --release
claw analyze ~/projects/chronos-engine --depth full
```

Should show `🎹🦞 Cloud: kimi-k2.6 via Kimi direct` and proceed without 400.

## Pre-existing Build Issues

If `cargo build` fails with `missing field thought_signature` errors in `conversation.rs`, that's from an unfinished Gemini merge conflict (unrelated to this fix). Resolve the merge markers or build from a clean branch before testing.

## Related

- Kimi proxy service: `~/.config/systemd/user/kimi-proxy.service`
- Proxy binary: `~/.local/bin/kimi-proxy`
- Wrapper config: `~/synthclaw-ai-setup/configs/wrappers/claw`
