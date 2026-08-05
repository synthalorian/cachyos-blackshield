# Rust Async Trait Dyn Compatibility

## Problem

Rust traits with `async fn` methods are **not dyn-compatible** (cannot use `Box<dyn Trait>`):

```rust
#[async_trait]
pub trait Transport: Send + Sync {
    async fn send_request(&mut self, req: &JsonRpcRequest) -> Result<String>;
}

// ERROR: the trait `Transport` is not dyn compatible
let transport: Box<dyn Transport> = Box::new(StdioTransport::new());
```

Error: `method `send_request` is `async`` — async methods in traits don't have a vtable-compatible signature.

## Solutions

### Option 1: Enum Wrapper (Recommended)

Use an enum when you have a closed set of implementations:

```rust
pub enum McpTransport {
    Stdio(StdioTransport),
    Sse(SseTransport),
}

impl McpTransport {
    pub async fn send_request(&mut self, req: &JsonRpcRequest) -> Result<String> {
        match self {
            Self::Stdio(t) => t.send_request(req).await,
            Self::Sse(t) => t.send_request(req).await,
        }
    }
}
```

**Pros:** Zero-cost, no extra dependencies, type-safe
**Cons:** Closed set — adding a variant requires recompiling all users

### Option 2: async-trait Crate

Use the `async-trait` crate which transforms async methods into regular methods returning `Pin<Box<dyn Future>>`:

```rust
use async_trait::async_trait;

#[async_trait]
pub trait Transport: Send + Sync {
    async fn send_request(&mut self, req: &JsonRpcRequest) -> Result<String>;
}

// Now this works:
let transport: Box<dyn Transport> = Box::new(StdioTransport::new());
```

**Pros:** Open set, familiar async syntax
**Cons:** Extra dependency, heap allocation per call (Box<dyn Future>), slight overhead

### Option 3: Manual Future Boxing

Write the trait without async, box the future manually:

```rust
pub trait Transport: Send + Sync {
    fn send_request(&mut self, req: &JsonRpcRequest) -> Pin<Box<dyn Future<Output = Result<String>> + Send + '_>>;
}
```

**Pros:** No external crate
**Cons:** Verbose, easy to get lifetime bounds wrong

## When to Use Which

| Scenario | Recommendation |
|----------|---------------|
| Closed set of variants (stdio, SSE, TCP) | **Enum wrapper** — zero-cost, simple |
| Open plugin system (user-provided transports) | **async-trait** — extensible |
| No-dependency constraint | **Manual boxing** — full control |
| Performance-critical hot path | **Enum wrapper** — no heap alloc |

## OpenShark Pattern

OpenShark uses the **enum wrapper** for MCP transports:
- `StdioTransport` — spawns subprocess, communicates over stdin/stdout
- `SseTransport` — HTTP POST + SSE streaming
- Both implement a private `Transport` trait for shared logic
- `McpTransport` enum exposes the public API

This keeps the MCP client dependency-free (no `async-trait` crate needed) and avoids vtable overhead on every JSON-RPC call.
