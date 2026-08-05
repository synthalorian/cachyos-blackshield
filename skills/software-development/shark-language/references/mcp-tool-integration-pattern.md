# MCP Tool Integration — Global Cache Pattern

Session: 2026-05-30. Wired MCP-discovered tools into OpenShark's native tool system.

## Problem

MCP tools are discovered asynchronously (needs `McpManager` lock), but `get_tools()` is synchronous and called from multiple places (TUI sidebar, system prompts, tool execution). The `McpToolAdapter` implemented `Tool` but was never registered.

## Solution: Global Cache + Arc<dyn Tool>

### Step 1: Change tool system from Box to Arc

`Box<dyn Tool>` cannot be cloned. `Arc<dyn Tool>` can be shared across the system.

```rust
// tools/mod.rs — BEFORE
pub fn get_tools() -> Vec<Box<dyn Tool>> {
    vec![Box::new(EditTool), ...]
}

// tools/mod.rs — AFTER
static MCP_TOOLS: Mutex<Vec<Arc<dyn Tool>>> = Mutex::new(Vec::new());

pub fn register_mcp_tools(tools: Vec<Arc<dyn Tool>>) {
    if let Ok(mut guard) = MCP_TOOLS.lock() {
        guard.clear();
        guard.extend(tools);
    }
}

pub fn get_tools() -> Vec<Arc<dyn Tool>> {
    let mut tools: Vec<Arc<dyn Tool>> = vec![
        Arc::new(EditTool), Arc::new(FsTool), ...
    ];
    if let Ok(mcp) = MCP_TOOLS.lock() {
        for tool in mcp.iter() {
            tools.push(Arc::clone(tool));
        }
    }
    tools
}
```

### Step 2: Register after MCP discovery

In `App::init_mcp()`, after `connect_all()`:

```rust
let mcp_tools = mgr.all_tools().await;
let mut adapted = Vec::new();
for (server_name, tool) in mcp_tools {
    adapted.push(Arc::new(McpToolAdapter::new(
        tool, server_name, Arc::clone(&arc_manager)
    )));
}
if !adapted.is_empty() {
    crate::tools::register_mcp_tools(adapted);
}
```

### Step 3: Update all call sites

`find_tool()`, `get_tools()`, and any function returning `Box<dyn Tool>` must change to `Arc<dyn Tool>`. The compiler will show every call site.

## Key Insight

The `Arc<dyn Tool>` refactor enables any subsystem to register tools dynamically without changing the synchronous API. MCP tools, future plugin systems, and runtime-discovered tools all fit the same pattern.

## Async-to-Sync Bridge in McpToolAdapter

`Tool::execute` is sync, but MCP calls are async. The adapter handles both contexts:

```rust
fn execute(&self, args: &str) -> Result<String> {
    let rt = tokio::runtime::Handle::try_current();
    match rt {
        Ok(handle) => {
            tokio::task::block_in_place(|| {
                handle.block_on(async move {
                    manager.lock().await.call_tool(&name, args).await
                })
            })
        }
        Err(_) => {
            let rt = tokio::runtime::Runtime::new()?;
            rt.block_on(async move { ... })
        }
    }
}
```
