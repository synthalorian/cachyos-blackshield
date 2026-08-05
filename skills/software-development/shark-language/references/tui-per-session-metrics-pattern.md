# TUI Per-Session Performance Metrics

Pattern for tracking performance metrics per-session instead of globally, with session-local averages displayed in the sidebar.

## Problem

The default approach queries a global SQLite table (`performance_metrics`) and averages the last 100 entries across ALL sessions. This mixes data from previous sessions, making the sidebar performance numbers misleading when you start a new chat.

## Solution

Track metrics in a `SessionPerformance` struct on the `App` struct, recording data as events arrive.

## Implementation

### 1. Define SessionPerformance

```rust
#[derive(Debug, Clone, Default)]
struct SessionPerformance {
    first_token_ms: Vec<u64>,
    total_latency_ms: Vec<u64>,
    tool_exec_ms: Vec<u64>,
    requests: usize,
    tools: usize,
}

impl SessionPerformance {
    fn record_response(&mut self, metrics: &StreamMetrics) {
        self.first_token_ms.push(metrics.first_token_latency_ms);
        self.total_latency_ms.push(metrics.total_latency_ms);
        self.requests += 1;
    }

    fn record_tool_exec(&mut self, duration_ms: u64) {
        self.tool_exec_ms.push(duration_ms);
        self.tools += 1;
    }

    fn avg_first_token(&self) -> u64 {
        if self.first_token_ms.is_empty() { 0 }
        else { self.first_token_ms.iter().sum::<u64>() / self.first_token_ms.len() as u64 }
    }

    fn avg_total_latency(&self) -> u64 {
        if self.total_latency_ms.is_empty() { 0 }
        else { self.total_latency_ms.iter().sum::<u64>() / self.total_latency_ms.len() as u64 }
    }

    fn avg_tool_exec(&self) -> u64 {
        if self.tool_exec_ms.is_empty() { 0 }
        else { self.tool_exec_ms.iter().sum::<u64>() / self.tool_exec_ms.len() as u64 }
    }
}
```

### 2. Add to App struct

```rust
struct App {
    // ... existing fields ...
    session_perf: SessionPerformance,
}
```

Initialize in `App::new()`:
```rust
session_perf: SessionPerformance::default(),
```

### 3. Record on ResponseComplete

In `apply_stream_event()` when `StreamEvent::ResponseComplete` fires:

```rust
StreamEvent::ResponseComplete { content, metrics } => {
    self.is_streaming = false;
    self.session_perf.record_response(&metrics);
    // ... also save to DB for persistence ...
}
```

### 4. Record tool execution time

Tool execution happens in background tasks. The `AsyncToolExecutor::execute_with_timeout()` returns `ToolExecutionMetrics` with `duration_ms`, but the simple wrapper discards it. Options:

**Option A: Add a StreamEvent variant for tool timing**
```rust
enum StreamEvent {
    // ... existing variants ...
    ToolExecTime(u64),
}
```

In the background task:
```rust
let tool_start = Instant::now();
match executor.execute_with_timeout_simple(...).await {
    Ok(result) => {
        let tool_duration = tool_start.elapsed().as_millis() as u64;
        let _ = tx.send(StreamEvent::ToolExecTime(tool_duration));
        // ...
    }
}
```

In `apply_stream_event()`:
```rust
StreamEvent::ToolExecTime(ms) => {
    self.session_perf.record_tool_exec(ms);
}
```

**Option B: Change execute_with_timeout_simple to return metrics**
Modify `execute_with_timeout_simple` to return `(String, ToolExecutionMetrics)` instead of just `String`.

### 5. Render in sidebar

Replace the global DB query with session-local data:

```rust
let perf_lines = if app.session_perf.requests > 0 {
    vec![
        Line::from(vec![
            Span::styled("First token: ", muted_style()),
            Span::styled(format!("{}ms", app.session_perf.avg_first_token()), text_style()),
        ]),
        Line::from(vec![
            Span::styled("Total latency: ", muted_style()),
            Span::styled(format!("{}ms", app.session_perf.avg_total_latency()), text_style()),
        ]),
        Line::from(vec![
            Span::styled("Tool exec: ", muted_style()),
            Span::styled(format!("{}ms", app.session_perf.avg_tool_exec()), text_style()),
        ]),
        Line::from(vec![
            Span::styled("Requests: ", muted_style()),
            Span::styled(app.session_perf.requests.to_string(), text_style()),
        ]),
    ]
} else {
    vec![
        Line::from(vec![Span::styled("No performance data yet", muted_style())]),
    ]
};
```

## Benefits

- Metrics reset with each new session — no stale data
- No DB query on every frame render
- Instant feedback — numbers update as events arrive
- Still save to DB for long-term analytics (optional)

## Trade-offs

- Lost on app restart (unless persisted separately)
- No cross-session trend analysis in the TUI (could add a separate "all-time" view)
