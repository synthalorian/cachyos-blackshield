# Swarm Output Plumbing Gap

The swarm runs background tasks but has no visible output channel to the TUI chat.

## The Problem

`SwarmEngine::start()` spawns agent tasks via `tokio::spawn` and returns immediately:

```rust
pub async fn start(&self) -> Result<()> {
    // Spawn all agent tasks
    for (agent_id, runner) in runners.iter() {
        tokio::spawn(async move {
            runner.execute_task(&task, &agent_ref).await
        });
    }
    
    // Spawn event loop
    tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event { ... }
        }
    });
    
    Ok(())  // Returns immediately — tasks run in background
}
```

In **CLI mode**, the process exits → background tasks die.
In **TUI mode**, tasks survive but results never appear in chat.

## Why Results Don't Surface

The event loop handles `WorkCompleted`, `ReviewCompleted`, etc. but:
1. Events are logged via `tracing::info!` — not shown to user
2. No code injects swarm results into the TUI chat history
3. `swarm status` only shows counts, not actual output

## What Users See

```
🐝 Swarm loop started.
[... nothing ...]
🐝 Swarm stopped.
```

## Fix Options

### Option 1: Stream to Chat (Recommended)

Add a background poller that checks swarm status and injects results:

```rust
// In TUI main loop
if app.swarm_running {
    if let Some(ref engine) = app.swarm {
        let agents = engine.agent_snapshot().await;
        for agent in agents {
            if let AgentStatus::Completed { result } = &agent.status {
                app.add_system_message(format!("🐝 {}: {}", agent.name, result));
            }
        }
    }
}
```

### Option 2: Block Until Done (CLI)

Make `swarm start` block and stream output:

```rust
pub async fn start_blocking(&self) -> Result<()> {
    self.start().await?;
    
    // Wait for all agents to complete
    while self.is_running().await {
        tokio::time::sleep(Duration::from_secs(1)).await;
        
        // Print status
        let status = self.status().await;
        println!("Cycles: {}/{}", status.cycles_completed, status.cycle_limit);
    }
    
    Ok(())
}
```

### Option 3: Swarm Log File

Write all agent outputs to a log file that users can tail:

```rust
// In event loop
SwarmEvent::WorkCompleted { agent_id, result, .. } => {
    let mut file = OpenOptions::new()
        .append(true)
        .create(true)
        .open("swarm.log")?;
    writeln!(file, "[{}] {}: {}", timestamp, agent_id, result)?;
}
```

## Current Workaround

Use `/swarm status` to check counts, but there's no way to see actual agent output. The swarm is effectively a "write-only" system right now.

## Architecture Note

The swarm event channel (`mpsc::UnboundedReceiver<SwarmEvent>`) is consumed by the event loop task. To stream to chat, you'd need to:
1. Either clone the receiver (not possible with mpsc)
2. Or add a callback/hook that the TUI can register
3. Or poll `agent_snapshot()` periodically

The cleanest fix is adding a `tokio::sync::broadcast` channel for UI updates alongside the internal mpsc channel.
