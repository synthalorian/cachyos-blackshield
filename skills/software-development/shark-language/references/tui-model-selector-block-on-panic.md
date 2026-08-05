# TUI Model Selector — `block_on` Panic in Async Runtime

## Problem

Pressing `Ctrl+P` (model selector) in the TUI causes a hard panic:

```
thread 'main' panicked at src/tui/mod.rs:540:32:
Cannot start a runtime from within a runtime. This happens because a function
like 'block_on' attempted to block the current thread while the thread is
being used to drive asynchronous tasks.
```

The model list never appears; the TUI crashes.

## Root Cause

`show_model_selector()` is called from the **synchronous** `handle_input()` context (the TUI main loop runs sync event polling). The function attempted to fetch dynamic models from local providers by calling `tokio::runtime::Handle::block_on()` inside the already-running async runtime:

```rust
// BEFORE (broken — panics)
if let Ok(handle) = tokio::runtime::Handle::try_current() {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        handle.block_on(provider_instance.list_models())  // ← PANIC
    }));
    // ...
}
```

Tokio strictly forbids `block_on` from within an async runtime. Even `catch_unwind` cannot catch this panic — it's a runtime abort.

## Fix

Remove the dynamic model fetching entirely from the sync TUI context. The static models from `config.toml` are sufficient for the selector:

```rust
// AFTER (fixed — no async calls in sync context)
// 2. Dynamic models from local provider's /v1/models endpoint
// Skip dynamic model fetching in the TUI — it requires async and we're in a sync context.
// The static models from config are sufficient for the selector.
// Dynamic models can be refreshed via the CLI `openshark models` command.
```

If dynamic model listing is needed, implement it as:
1. A **CLI command** (`openshark models`) that runs in its own async context
2. An **async TUI command** (`/models`) that spawns a background task and streams results via the event channel

## Key Rule

**Never call `block_on` from inside a Tokio runtime.** This includes:
- TUI key handlers (`handle_input`)
- Any function called from the main event loop
- Callbacks fired within async contexts

**Safe alternatives for async work from sync contexts:**
- Spawn a background task with `tokio::spawn` + channel
- Use `tokio::task::block_in_place` (only if already on a Tokio worker thread, NOT the main thread)
- Move the async call to a dedicated thread with its own runtime
- Use `futures::executor::block_on` (different executor, no conflict)

## Related

- `references/terminal-keybinding-conflicts.md` — `Ctrl+M` was the original binding; changed to `Ctrl+P` because terminals intercept `Ctrl+M` as carriage return
- `references/tui-async-background-task-pattern.md` — Correct pattern for async work in the TUI
