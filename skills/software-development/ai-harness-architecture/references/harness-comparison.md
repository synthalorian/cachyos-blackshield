# Harness Comparison Reference

Detailed comparison of AI coding harnesses based on real usage patterns.

## Hermes Agent

**Architecture:** Python-based, gateway + CLI, tool-calling framework
**Strengths:** Persistent memory (skills, memories, cron), subagent delegation, session search, multi-tool ecosystem
**Config:** `~/.hermes/config.yaml` — providers, toolsets, gateway settings
**Model access:** OAuth providers (Nous, xAI), local proxies, OpenRouter
**Memory:** SQLite session DB, persistent skills/ directory, cron jobs
**Unique:** Skills system, kanban workers, webhook triggers, multi-platform delivery

## OpenShark

**Architecture:** TypeScript/Node, WebSocket gateway, TUI
**Strengths:** Fast spin-up, lightweight, good for quick hits
**Config:** `~/.config/openshark/config.yaml`
**Model access:** Via gateway, supports local + cloud
**Memory:** Session-based, less persistent than Hermes
**Unique:** Dual-config swap (cloud/local), `oc-cloud`/`oc-local` scripts

## OpenCode

**Architecture:** Node.js, TUI + web interface, plugin system
**Strengths:** Big planning, architecture vision, initial scaffolding
**Config:** `~/.config/opencode/opencode.json` — providers, plugins, models
**Model access:** npm-based provider adapters (@ai-sdk/openai-compatible)
**Memory:** Session export/import, stats tracking
**Unique:** Plugin ecosystem (`oh-my-openagent`), provider abstraction via npm

## Claw-Code

**Architecture:** Rust CLI, ACP protocol, terminal-based
**Strengths:** Autonomous workflows, refactoring, debugging, fast execution
**Config:** `~/.claw/` — sessions, plugins
**Model access:** Via wrapper script with model shorthand resolution
**Memory:** Session-based, plugin system
**Unique:** Model shorthand (`claw 35b`, `claw kimi`), local-first, fast

## Claude Code

**Architecture:** TypeScript, terminal UI, agentic coding
**Strengths:** Deep context understanding, multi-file editing, git integration
**Model access:** Anthropic Claude only
**Unique:** Agent loop with approval, `/` commands, project awareness

## Codex CLI

**Architecture:** TypeScript, terminal UI, OpenAI
**Strengths:** Fast, simple, good for quick tasks
**Model access:** OpenAI Codex only
**Unique:** Minimal setup, works out of the box

## OMO (Open Model Orchestrator)

**Architecture:** Local model bridge, llama-swap integration
**Strengths:** Local inference, privacy, cost-free
**Config:** `~/.config/opencode/.omo` or standalone
**Model access:** llama-swap at `127.0.0.1:8080`, Ollama at `11434`
**Unique:** Switches models without restarting, auto-eviction

## Common Config Patterns

### Local Provider (llama-swap)
```json
{
  "base_url": "http://127.0.0.1:8080/v1",
  "api_key": "local",
  "models": {
    "synthclaw-35b-128k": {
      "context": 128000,
      "output": 65536
    }
  }
}
```

### Kimi Provider
```json
{
  "base_url": "https://api.kimi.com/coding/v1",
  "api_key": "***",
  "models": {
    "kimi-k2.6": {
      "context": 128000,
      "output": 65536
    }
  }
}
```

## What OpenShark Combines

| Feature | Hermes | OpenShark | OpenCode | Claw-Code | OpenShark |
|---------|--------|----------|----------|-----------|-----------|
| Persistent memory | ✅ | ❌ | Partial | ❌ | ✅ |
| Multi-provider | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tool ecosystem | ✅ | Partial | ✅ | ✅ | ✅ |
| Self-improvement | ❌ | ❌ | ❌ | ❌ | ✅ |
| Cost optimization | ❌ | ❌ | ❌ | ❌ | ✅ |
| Auto-routing | ❌ | ❌ | ❌ | ❌ | ✅ |
| Open source | ✅ | ✅ | ✅ | ✅ | ✅ |
| TUI | Partial | ✅ | ✅ | ✅ | ✅ |
| Local models | ✅ | ✅ | ✅ | ✅ | ✅ |
