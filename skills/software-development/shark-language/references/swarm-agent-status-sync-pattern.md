# Swarm Agent Status Sync Pattern

## Problem

When agents run in background tokio tasks, their status updates must propagate back to the master `agents` HashMap for the TUI to display current state. Two common bugs:

1. **Cloned agent trap**: Creating `Arc::new(RwLock::new(agent.clone()))` gives the runner a COPY of the agent. Status updates on the clone never reach the original in the HashMap.
2. **Message loop variable not reassigned**: Using `let messages = ...` inside a loop creates a shadowed local that dies at iteration end. The outer `messages` never gets updated with tool results.

## Solution

### Pass Shared State Directly

```rust
// WRONG — clone into new Arc
let agent_ref = {
    let agents_lock = agents.read().await;
    if let Some(agent) = agents_lock.get(&agent_id) {
        Arc::new(RwLock::new(agent.clone()))  // COPY!
    } else { return; }
};
runner.execute_task(task, &agent_ref).await;

// RIGHT — pass the shared map + id
runner.execute_task(task, &agents, &agent_id).await;

// Inside execute_task, update the REAL agent:
let mut agents_lock = agents.write().await;
if let Some(agent) = agents_lock.get_mut(agent_id) {
    agent.status = AgentStatus::Working { task: task.to_string() };
}
```

### Mutable Message Accumulation

```rust
// WRONG — immutable outer, shadowed inner
let messages = ctx.messages.clone();  // immutable
loop {
    // ... LLM call, get response ...
    let messages = ctx.messages.clone();  // shadows, dies here
    // next iteration uses original messages
}

// RIGHT — mutable, reassigned each iteration
let mut messages = ctx.messages.clone();
loop {
    // ... LLM call, get response ...
    messages = ctx.messages.clone();  // reassigns outer variable
    // next iteration uses updated messages
}
```

## Broadcast Channel for Real-Time Updates

Add a `tokio::sync::broadcast` channel to `SwarmEngine` so the TUI can subscribe to live agent activity:

```rust
pub struct SwarmEngine {
    // ... other fields ...
    broadcast_tx: tokio::sync::broadcast::Sender<SwarmEvent>,
}

impl SwarmEngine {
    pub fn subscribe(&self) -> tokio::sync::broadcast::Receiver<SwarmEvent> {
        self.broadcast_tx.subscribe()
    }
}
```

In the event loop, broadcast every event before processing:
```rust
while let Some(event) = rx.recv().await {
    let _ = broadcast_tx.send(event.clone());
    match event { /* ... */ }
}
```

In the TUI, poll the receiver without holding the borrow:
```rust
let mut updates = Vec::new();
if let Some(ref mut rx) = app.swarm_event_rx {
    while let Ok(event) = rx.try_recv() {
        updates.push(format!("🐝 {:?}", event));
    }
}
for update in updates {
    app.add_system_message(update);  // borrow app here, not inside the loop
}
```

## Activity Event Types

Add granular events for visibility:
- `AgentActivity { agent_id, activity }` — "starting work", "planning"
- `AgentToolCall { agent_id, tool_name, args }` — tool invocation
- `AgentThinking { agent_id, thought }` — intermediate reasoning

These let users see what agents are doing instead of waiting for completion.
