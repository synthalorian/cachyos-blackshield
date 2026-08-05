# Skills System Architecture — OpenShark

Session: 2026-05-30, implementing YAML frontmatter + markdown skills with trigger-based auto-loading.

## Overview

OpenShark has its own skills system — independent from Hermes. Skills are YAML frontmatter + markdown body files that provide domain-specific guidance to the model when triggered by keywords.

## Skill Format

```yaml
---
name: rust
description: Rust programming best practices
triggers:
  - rust
  - cargo
  - rustc
  - tokio
  - async rust
  - lifetime
  - borrow checker
tags:
  - rust
  - systems
---

# Rust Programming Guide

## Ownership and Borrowing

Always prefer borrowing over cloning...
```

**Fields:**
| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (lowercase, no spaces) |
| `description` | Yes | Human-readable description |
| `triggers` | Yes | Keywords that activate this skill (case-insensitive) |
| `tags` | No | Categories for organization |

## Architecture

```
src/skills/
├── mod.rs              # Skill, SkillRegistry, format_skills_prompt()
└── builtin/            # Compiled-in skills (include_str!)
    ├── rust.md
    ├── docker.md
    ├── git.md
    ├── testing.md
    └── debugging.md
```

```rust
pub struct Skill {
    pub name: String,
    pub description: String,
    pub triggers: Vec<String>,
    pub tags: Vec<String>,
    pub content: String,      // markdown body (after frontmatter)
}

pub struct SkillRegistry {
    skills: Vec<Skill>,
    builtin_dir: PathBuf,
    user_dir: PathBuf,
}
```

## Loading Flow

```
SkillRegistry::new(skills_dir)
    │
    ├─ Auto-create skills_dir if missing
    ├─ Extract built-in skills from binary (include_str!)
    │   └─ Write to skills_dir/builtin/*.md
    ├─ Load all .md files from skills_dir/builtin/
    ├─ Load all .md files from skills_dir/user/
    └─ Parse YAML frontmatter + markdown body for each
```

## Built-in Skills

Embedded in binary via `include_str!`, auto-extracted on first run:

| Skill | Triggers |
|-------|----------|
| `rust` | rust, cargo, rustc, tokio, async rust, lifetime, borrow checker |
| `docker` | docker, container, dockerfile, compose, image, containerize |
| `git` | git, commit, branch, merge, rebase, pull request, pr, github |
| `testing` | test, testing, unittest, mock, fixture, tdd, coverage |
| `debugging` | debug, debugging, breakpoint, trace, log, error, panic, stack trace, gdb, lldb |

## Trigger Matching

```rust
pub fn find_triggered(&self, query: &str, limit: usize) -> Vec<&Skill> {
    let query_lower = query.to_lowercase();
    self.skills
        .iter()
        .filter(|s| s.triggers.iter().any(|t| query_lower.contains(t)))
        .take(limit)
        .collect()
}
```

**Case-insensitive:** Both query and triggers are lowercased before matching.
**Substring match:** Any trigger appearing anywhere in the query activates the skill.

## Two-Stage Injection

Skills are injected at two points:

### 1. Base System Prompt (All Skills)

When a `ChannelState` is created, ALL skills are loaded into the base system prompt:

```rust
// In ChannelState::new()
let skill_registry = SkillRegistry::new(skills_dir)?;
let skills_prompt = format_skills_prompt(&skill_registry.skills);
system_prompt.push_str("\n\n## Skills\n\n");
system_prompt.push_str(&skills_prompt);
```

This gives the model awareness of all available skills.

### 2. Dynamic Per-Message (Triggered Skills)

For each inbound message, find triggered skills and inject their full content:

```rust
// In handle_user_message()
let triggered = skill_registry.find_triggered(&msg.content, 3);
if !triggered.is_empty() {
    let skill_content: String = triggered
        .iter()
        .map(|s| format!("## {}\n{}\n", s.name, s.content))
        .collect();
    channel_state.history.push(Message::system(skill_content));
}
```

**Why both stages:** Base prompt gives the model awareness ("I know about Rust skills"). Dynamic injection gives detailed guidance only when relevant ("Here's the Rust skill content because you mentioned borrow checker").

## User Skills Directory

Users can add custom skills:

```bash
~/.config/openshark/skills/
├── builtin/          # Auto-populated from binary (DO NOT EDIT)
└── user/             # User-created skills
    ├── my-api.md
    └── team-style.md
```

Custom skills follow the same format and are loaded alongside built-ins.

## Integration with Memory

The full message flow with skills:

```
Inbound Message
    │
    ├─ 1. Keyword command? → Handle directly
    ├─ 2. Natural language query? → Memory answer directly
    │
    └─ 3. Regular message
        ├─ Search memory → inject as system message
        ├─ Find triggered skills → inject as system message
        ├─ Send to LLM with: base prompt + memory + skills + history
        └─ Stream response
```

## Files

- `src/skills/mod.rs` — `Skill`, `SkillRegistry`, `format_skills_prompt()`, `find_triggered()`
- `src/skills/builtin/*.md` — Built-in skill content
- `src/gateway/channel_state.rs` — Base skill loading in `ChannelState::new()`
- `src/gateway/message_router.rs` — Dynamic skill injection per-message
