# Swarm Mode Architecture Reference

## Overview

OpenShark's swarm mode is an **optional, off-by-default** multi-agent system where role-based agents call LLMs in parallel with isolated contexts, automatic cross-agent review, and consensus memory.

**Key principle:** When `swarm.enabled = false`, zero swarm code runs. No agents spawned, no providers created, no LLM calls made. Regular OpenShark code mode works exactly as before.

## Enabling Swarm Mode

```toml
# ~/.config/openshark/config.toml
[swarm]
enabled = true           # Master switch
max_agents = 8
consensus_required = true
consensus_mode = "majority"  # majority | unanimous | leader_decides
cycle_limit = 50
roles = ["architect", "implementer", "reviewer", "tester"]
auto_spawn = false
```

## Files

| File | Purpose |
|------|---------|
| `src/swarm/mod.rs` | `SwarmEngine` — agent pool, event loop, consensus, task distribution |
| `src/swarm/consensus.rs` | `ConsensusMemory` — shared doc, approve/reject/majority logic |
| `src/swarm/roles.rs` | `RoleTemplate` — 8 built-in roles with system prompts |
| `src/swarm/agent_runner.rs` | `AgentRunner` — real LLM calls, tool execution, per-agent context |

## Agent Roles (8 Built-in)

| Role | Short Name | Task Prompt |
|------|-----------|-------------|
| Architect | `architect` | "Design the system architecture for: {seed}" |
| Implementer | `implementer` | "Implement the core functionality for: {seed}" |
| Reviewer | `reviewer` | "Review the approach for: {seed}. What are the risks?" |
| Tester | `tester` | "Design test cases and verify requirements for: {seed}" |
| DevOps | `devops` | "Design deployment and CI/CD strategy for: {seed}" |
| Security | `security` | "Perform security audit of the design for: {seed}" |
| Documentation | `documentation` | "Write documentation outline for: {seed}" |
| Project Manager | `pm` | "Break down the project into tasks and milestones for: {seed}" |

## Architecture

```
SwarmEngine
  ├── Agent Pool (HashMap<AgentId, SwarmAgent>)
  ├── Runner Pool (HashMap<AgentId, Arc<AgentRunner>>)  ← NEW: per-agent LLM runners
  ├── ConsensusMemory (shared document)
  ├── Event Bus (mpsc channels)
  └── Background Loop (tokio::spawn)

AgentRunner (per agent)
  ├── Provider (cloned from global config)
  ├── AgentContext (isolated conversation history)
  ├── event_tx (emits SwarmEvents back to engine)
  └── max_iterations: 10

Cross-Agent Review Flow:
  1. Agent completes work → WorkCompleted event
  2. SwarmEngine finds Reviewer agent → ReviewRequested event
  3. Reviewer calls LLM: "Review this work..."
  4. Reviewer emits ReviewCompleted (APPROVED/REJECTED)
  5. ConsensusMemory updated
```

## AgentRunner Execution Loop

```rust
// AgentRunner::execute_task()
1. Set status → Working
2. Add task to AgentContext
3. Trim context to 20 messages (sliding window)
4. Call provider.chat() with full context
5. Check response for TOOL:<name> <args> suggestions
6. If tools found → execute via AsyncToolExecutor (30s timeout)
7. Feed tool result back into context
8. Re-call LLM (max 10 iterations)
9. Set status → Completed or Error
10. Emit WorkCompleted event
```

## TUI Integration

| Command | Action |
|---------|--------|
| `/swarm init <prompt>` | Spawn agents, create runners, initialize contexts |
| `/swarm start` | Dispatch role-specific tasks to all agents (parallel LLM calls) |
| `/swarm stop` | Halt all agents, clear state |
| `/swarm status` | Show swarm state |
| `Ctrl+W` | Toggle swarm mode / switch to Swarm sidebar tab |
| `Ctrl+S` | Cycle sidebar tabs: Tools → Skills → Swarm |

**Swarm Sidebar (tab 2):**
- Status: 🟢 Running / ⏹ Idle
- Agent list with status icons:
  - ⏸ Idle | 🟡 Working | 👁 Reviewing | ⏳ WaitingForConsensus | ❌ Error | ✅ Completed
- Cycle counts per agent

## Critical Pattern: Cached State for Sync Rendering

The TUI `draw_sidebar()` is synchronous — cannot use `.await`. Solution: cache swarm state in `App`:

```rust
struct App {
    swarm: Option<SwarmEngine>,           // async operations
    swarm_agents: Vec<SwarmAgent>,        // cached for sync rendering
    swarm_running: bool,                  // cached for sync rendering
}
```

After async init/start operations, update cached fields:
```rust
app.swarm_agents = engine.agent_snapshot().await;
app.swarm_running = engine.is_running().await;
```

The sync `draw_sidebar()` reads only cached fields:
```rust
for agent in app.swarm_agents.iter().skip(scroll).take(6) {
    // render agent row
}
```

## System Prompt Per Agent

Each agent gets a composite system prompt:
```
{role_system_prompt}

You are part of a multi-agent swarm working on: {seed_prompt}
You have access to tools. When you need to use a tool, output it as: TOOL:<tool_name> <args>
Be concise and direct. Focus on your specific role.
```

## Provider Sharing

All agents share a cloned `Provider` from the same global config provider. Context isolation is achieved via per-agent `AgentContext` (conversation history), not per-agent providers.

```rust
let provider = build_agent_provider(global_config)?;  // once
for role in roles {
    let runner = AgentRunner::new(id, provider.clone(), model, event_tx, system_prompt);
}
```

## Consensus Modes

| Mode | Behavior |
|------|----------|
| `majority` | Entry approved if approvals > rejections |
| `unanimous` | Entry approved only if zero rejections |
| `leader_decides` | PM agent's vote overrides all |

## CLI Commands

```bash
openshark swarm init "Build a REST API with auth"
openshark swarm start
openshark swarm stop
openshark swarm status
```

## Testing

14 unit tests in `src/swarm/`:
- `test_swarm_init` — agents spawned correctly
- `test_swarm_start_stop` — lifecycle
- `test_swarm_events` — event processing
- `test_consensus_*` — approve/reject/majority logic
- `test_role_*` — role template resolution

Run: `cargo test swarm`
