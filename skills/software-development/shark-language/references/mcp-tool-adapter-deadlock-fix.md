# MCP Tool Adapter Deadlock Risk

## Problem

The MCP tool adapter (`src/tools/mcp.rs`) used `tokio::task::block_in_place` inside an async context to bridge sync `Tool::execute()` to async `McpManager::call_tool()`:

```rust
// BROKEN — can deadlock the tokio runtime
let rt = tokio::runtime::Handle::try_current();
match rt {
    Ok(handle) => {
        tokio::task::block_in_place(|| {
            handle.block_on(async move {
                let manager = manager.lock().await;
                manager.call_tool(&tool_name, arguments).await
            })
        })
    }
    Err(_) => {
        let rt = tokio::runtime::Runtime::new()?;
        rt.block_on(async move { ... })
    }
}
```

`block_in_place` blocks the current worker thread. If all tokio worker threads are blocked (e.g., during concurrent tool calls or high load), the runtime deadlocks — no progress can be made on any task.

## When It Deadlocks

- Multiple MCP tool calls execute simultaneously
- The tokio thread pool is small (default = number of CPU cores)
- All worker threads enter `block_in_place` waiting for each other's async operations
- No thread is available to drive the async executor forward

## Fix

Use `std::thread::scope` + a dedicated single-threaded tokio runtime, completely isolated from the main executor:

```rust
let result = std::thread::scope(|s| {
    s.spawn(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| anyhow::anyhow!("Failed to build MCP runtime: {}", e))?;
        rt.block_on(async move {
            let manager = manager.lock().await;
            manager.call_tool(&tool_name, arguments).await
        })
    })
    .join()
    .map_err(|e| anyhow::anyhow!("MCP tool thread panicked: {:?}", e))?
});
```

**Why this works:**
- New OS thread per call — never blocks a tokio worker
- Single-threaded runtime — no contention with the main executor
- `thread::scope` ensures the thread joins before returning
- Panic propagation via `join()` result handling

## Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| `block_in_place` | Low latency (same thread) | Deadlock risk under load |
| Dedicated thread + runtime | No deadlock risk | ~1ms thread spawn overhead |
| Spawn blocking task | Reuses tokio's blocking pool | Still consumes a thread, pool may saturate |

For MCP tools (typically called infrequently, not in hot loops), the dedicated thread approach is the safest.

## Prevention

- **Never use `block_in_place` in library code** that may be called from async contexts
- **Always consider thread pool exhaustion** when bridging sync → async
- **Use `tokio::task::spawn_blocking` only for CPU-bound work**, not for async I/O
- **For async I/O from sync code:** dedicated thread + single-threaded runtime is the safest pattern

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
