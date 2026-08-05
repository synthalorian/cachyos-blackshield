# TUI Emoji & Identity Pitfalls

Session: 2026-05-30. Fixing emoji rendering and agent/user identity confusion in OpenShark.

## Emoji Rendering

### The Problem

Discord custom emoji codes (`:musical_keyboard:`, `:shark:`) do NOT render in terminal UIs. They appear as literal text. Terminals only support **Unicode emoji** (e.g. `🎹🦞`).

### Symptoms

- Sidebar shows `:musical_keyboard: :shark:` instead of `🎹🦞`
- Agent messages include literal emoji codes in text
- Setup wizard output looks broken

### Fix

**Config:** Use Unicode emoji in `~/.config/openshark/config.toml`:
```toml
# WRONG:
emoji = ":musical_keyboard: :shark:"

# CORRECT:
emoji = "🎹🦞"
```

**Setup wizard:** Add a warning prompt:
```
ℹ️  Use Unicode emoji (e.g. 🎹🦞) not Discord codes (:emoji:)
```

**Migration:** If a user has Discord codes in their config, they need manual conversion. There's no automatic mapping because Discord custom emoji names don't map 1:1 to Unicode.

## Agent vs User Identity Confusion

### The Problem

Users conflate their own persona/backstory with the agent's identity. The agent ends up with the user's origin story, role, and personality.

### Symptoms

- Agent introduces itself as the user ("I'm synthalorian, born in the Mandalorian mountains...")
- Agent's role is the user's role ("role = synthalorian" instead of "synthesis engine")
- Agent's origin story is the user's backstory
- System prompt confuses who is the assistant vs who is the human

### Fix

**Clear labeling in setup wizard:**
```
🎭 Agent Identity (Your AI Assistant)
──────────────────────────────────────
This is the AI that will help you code. Give it a name and personality.

👤 Your Identity (The Human)
─────────────────────────────
This is YOU — the person using the agent. The agent will know you by this name.
```

**Correct config separation:**
```toml
user_name = "synth"  # The human using the agent

[agent]
name = "synthclaw"           # Agent's internal name
display_name = "synthclaw"   # Agent's display name
role = "synthesis engine"     # Agent's role, NOT user's persona
origin = "Born from the VHS tracking static of 1984"  # Agent's origin
purpose = "To build, debug, and ship code with surgical accuracy"
emoji = "🎹🦞"                # Unicode emoji for terminal
```

**System prompt construction:**
- Agent identity section describes the AI (name, role, origin, purpose)
- User identity section describes the human (name, preferences, context)
- Never swap them

### Setup Wizard Defaults

- Agent name default: `"synthclaw"`
- User name default: `"synth"` (not `"user"` — personalize from the start)
- Agent role default: `"synthesis engine"`
- Agent origin default: `"Born from the VHS tracking static of 1984"`
