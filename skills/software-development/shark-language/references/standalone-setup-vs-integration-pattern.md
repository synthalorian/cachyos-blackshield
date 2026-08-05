# Standalone Setup vs Integration Pattern

## Lesson from Session 2026-05-30

When building a tool that has its own setup system AND can import config from other tools, the distinction matters critically. Getting it wrong produces confusing architecture where projects bleed into each other.

## The Pattern

### ✅ Correct: Standalone Tool with Optional Import

```
mytool setup                              # Standalone setup
mytool setup --migrate-from other-tool    # Optional import
```

**Rules:**
1. The tool has its OWN setup, config, doctor, gateway, skills system
2. Config transfer is OPTIONAL — a flag, not the default
3. The tool NEVER depends on the source tool for normal operation
4. Each tool only reads from source, never writes to another tool's config
5. No circular dependencies between tools

### ❌ Wrong: Integration-First Design

```
# DON'T DO THIS
mytool setup --integrate-with other-tool   # Makes mytool dependent
```

This creates confusion about which tool owns what. The user asked:
> "I don't want to integrate with Hermes. I want everything that Hermes setup does for Hermes done the same way that OpenSynth will do for OpenSynth *separately*."

## Real Examples

### OpenSynth (Synthesizer App)
- `opensynth setup` → configures Flutter, PortAudio, audio settings
- NO config transfer to other tools — it's a music app, not an agent platform
- Completely standalone

### OpenShark (AI Harness)
- `openshark setup` → configures Rust build, providers, memory DB
- `openshark setup --migrate-from hermes` → OPTIONAL import
- `openshark setup --migrate-from openclaw` → OPTIONAL import
- Has its OWN gateway, MCP, skills, doctor — no Hermes dependency

### Hermes (Agent Framework)
- `hermes setup` → configures Hermes
- `hermes claw migrate` → OpenClaw → Hermes import
- Maintains its own migration path

## Migration Paths (No Circular Deps)

```
OpenClaw ──► Hermes        (hermes claw migrate)
     │
     ├──► OpenShark        (openshark setup --migrate-from openclaw)

Hermes ────► OpenShark     (openshark setup --migrate-from hermes)
```

**Critical rule:** Each arrow is ONE-WAY. No tool writes to another tool's config directory. No tool requires another tool to be installed for its own setup to work.

## Doctor Design Principle

`mytool doctor` should be an auto-repair function, not just diagnostic:

```bash
mytool doctor              # Detect + fix everything
mytool doctor --check      # Detect only
mytool doctor --fix        # Fix without prompting
mytool doctor --component X # Fix only one subsystem
```

**What doctor handles:**
- Config corruption → rewrite with defaults
- Service not running → restart
- Token expired → regenerate
- DB schema outdated → migrate
- Build artifacts stale → clean rebuild

## When to Apply This Pattern

**Use standalone setup with optional import when:**
- Your tool is a platform/harness (not a library)
- Users may be migrating from another tool
- You want to own the full user experience
- The tool has its own config format

**Use direct integration when:**
- Your tool is a plugin/extension
- You want to live inside another tool's ecosystem
- The host tool provides the setup/config infrastructure

## Pitfalls

1. **Naming confusion:** Don't call it `--integrate-with` if it's really `--import-from`. Integration implies ongoing coupling.

2. **Default-on imports:** Don't auto-detect and auto-import. Ask the user explicitly.

3. **Writing to source:** Never write back to the source tool's config. Read-only import.

4. **Blurring project boundaries:** OpenSynth (music app) should NOT have config transfer to OpenShark (AI harness). They're different products for different purposes.

5. **Assuming dependencies:** Setup should work on a clean machine with zero other tools installed.
