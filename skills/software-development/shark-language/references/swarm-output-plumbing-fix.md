# Swarm Output Plumbing Fix

Background task results must be polled and surfaced to the user.

## The Problem

Swarm mode spawns agents as `tokio::spawn` background tasks. The `start()` method returns immediately, leaving tasks running invisibly. Results never appear in chat.

## Root Cause

Two separate issues:
1. **CLI mode:** Process exits immediately after `start()`, killing background tasks
2. **TUI mode:** Background tasks run but no polling mechanism injects results into chat

## The Fix: Main Loop Polling

Add swarm status polling to the TUI's main event loop (every tick):
- Poll agent snapshot
- Compare against cached state  
- Detect transitions (Working→Completed, →Error)
- Inject chat messages for transitions
- Detect swarm completion

## Critical: swarm_running Flag

`start()` must set `swarm_running = true` AND initialize the agent cache, or polling never activates.

## Config Reload Pattern

Reload config from disk on `/swarm init` so edits take effect without restart:
`let fresh_config = Config::load_or_default().unwrap_or_else(|_| app.config.clone());`
