# Tokio Async Deadlock: `block_in_place` in Async Context

## Problem

Using `tokio::task::block_in_place` inside an async context to bridge sync → async code can deadlock the tokio runtime when all worker threads become blocked.

**Real case (OpenShark MCP tool adapter):**
```rust
// BROKEN — can deadlock
let handle = tokio::runtime::Handle::try_current()?;
tokio::task::block_in_place(|| {
    handle.block_on(async move {
        let manager = manager.lock().await;
        manager.call_tool(&tool_name, arguments).await
    })
});
```

## When It Deadlocks

- Multiple concurrent calls enter `block_in_place`
- The tokio thread pool is small (default = number of CPU cores)
- All worker threads are blocked waiting for async operations
- No thread is available to drive the executor forward
- Result: complete runtime stall, no progress on any task

## Fix: Dedicated Thread + Single-Threaded Runtime

```rust
let result = std::thread::scope(|s| {
    s.spawn(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| anyhow::anyhow!("Failed to build runtime: {}", e))?;
        rt.block_on(async move {
            async_operation(args).await
        })
    })
    .join()
    .map_err(|e| anyhow::anyhow!("Thread panicked: {:?}", e))?
});
```

**Why this works:**
- New OS thread per call — never blocks a tokio worker
- Single-threaded runtime — no contention with the main executor
- `thread::scope` ensures the thread joins before returning
- Panic propagation via `join()` result

## Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| `block_in_place` | Low latency (same thread) | Deadlock risk under load |
| Dedicated thread + runtime | No deadlock risk | ~1ms thread spawn overhead |
| `spawn_blocking` | Reuses tokio's blocking pool | Pool may saturate; still consumes threads |

## Rule

**Never use `block_in_place` in library code that may be called from async contexts.** Use dedicated threads for async I/O from sync code.

## General Pattern: Sync → Async Bridge

```rust
fn sync_api_that_needs_async(args: Args) -> Result<Output> {
    std::thread::scope(|s| {
        s.spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()?;
            rt.block_on(async_move { async_operation(args).await })
        })
        .join()
        .map_err(|e| anyhow::anyhow!("Thread panicked: {:?}", e))?
    })
}
```

## Affected Versions

OpenShark v1.0.0 — fixed in post-v1.0.0 commit.
