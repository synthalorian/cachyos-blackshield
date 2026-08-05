# Swarm Agent Streaming Pattern

## Overview

Real-time per-agent streaming in the TUI. Each swarm agent's LLM output appears live in the chat area with role-colored headers, plus an Inspector sidebar tab for deep inspection.

## Architecture

```
AgentRunner::execute_task()
  ├── provider.chat_stream(request)  ← streaming LLM call
  ├── For each chunk:
  │   └── event_tx.send(SwarmEvent::AgentChunk { ... })
  └── On completion: AgentChunk with is_final=true

SwarmEngine event loop
  ├── Receives AgentChunk
  └── broadcast_tx.send(event.clone())  ← TUI subscribers

TUI main loop
  ├── Polls swarm_event_rx (broadcast receiver)
  ├── Matches AgentChunk → updates app.agent_streams HashMap
  └── draw_chat_area() renders all agent streams inline
```

## SwarmEvent::AgentChunk

```rust
pub enum SwarmEvent {
    // ... other variants ...
    AgentChunk {
        agent_id: AgentId,
        agent_name: String,
        role: String,
        chunk: String,
        is_final: bool,
    },
}
```

Added to `src/swarm/mod.rs`. Must also be matched in the event loop's catch-all:
```rust
SwarmEvent::AgentActivity { .. }
| SwarmEvent::AgentToolCall { .. }
| SwarmEvent::AgentToolResult { .. }  // if using collapsible tools
| SwarmEvent::AgentThinking { .. }
| SwarmEvent::AgentChunk { .. } => {
    // Already broadcast above, no additional action needed
}
```

## AgentRunner Changes

Switch from `provider.chat()` to `provider.chat_stream()`:

```rust
let request = ChatRequest::new(self.model.clone(), messages.clone(), true); // stream=true

let (agent_name, agent_role) = {
    let agents_lock = agents.read().await;
    if let Some(agent) = agents_lock.get(agent_id) {
        (agent.name.clone(), agent.role.name.clone())
    } else {
        (self.agent_id.clone(), "Unknown".to_string())
    }
};

let response = match tokio::time::timeout(
    Duration::from_secs(180),
    self.provider.chat_stream(request)
).await {
    Ok(Ok((chunks, _metrics))) => {
        let mut full_content = String::new();
        for (i, chunk) in chunks.iter().enumerate() {
            full_content.push_str(chunk);
            // Apply persona filter before broadcasting
            let filtered = crate::swarm::persona_filter::strip_persona_preamble(chunk);
            if !filtered.is_empty() {
                let _ = self.event_tx.send(SwarmEvent::AgentChunk {
                    agent_id: self.agent_id.clone(),
                    agent_name: agent_name.clone(),
                    role: agent_role.clone(),
                    chunk: filtered,
                    is_final: i == chunks.len() - 1,
                });
            }
        }
        crate::swarm::persona_filter::strip_persona_preamble(&full_content)
    }
    // ... error handling ...
};
```

## TUI State

### AgentStreamState

```rust
#[derive(Debug, Clone)]
pub struct AgentStreamState {
    pub agent_id: String,
    pub agent_name: String,
    pub role: String,
    pub content: String,
    pub is_streaming: bool,
    pub tool_results: Vec<(String, String, bool)>, // (tool_name, result, success)
}
```

Stored in `App`:
```rust
agent_streams: HashMap<String, AgentStreamState>,
agent_tool_expanded: HashSet<String>, // which agents have tools expanded in inspector
```

### Event Handling

In the TUI's swarm polling loop (`run_app()`):

```rust
crate::swarm::SwarmEvent::AgentChunk { agent_id, agent_name, role, chunk, is_final } => {
    use std::collections::hash_map::Entry;
    match app.agent_streams.entry(agent_id.clone()) {
        Entry::Occupied(mut entry) => {
            let state = entry.get_mut();
            state.content.push_str(&chunk);
            state.is_streaming = !is_final;
        }
        Entry::Vacant(entry) => {
            entry.insert(AgentStreamState {
                agent_id: agent_id.clone(),
                agent_name: agent_name.clone(),
                role: role.clone(),
                content: chunk.clone(),
                is_streaming: !is_final,
                tool_results: Vec::new(),
            });
        }
    }
}

crate::swarm::SwarmEvent::AgentToolResult { agent_id, tool_name, result, success } => {
    if let Some(state) = app.agent_streams.get_mut(&agent_id) {
        state.tool_results.push((tool_name, result, success));
    }
}
```

### Rendering (with Code Visibility)

In `draw_chat_area()`, after the main streaming indicator:

```rust
// ── Swarm Agent Streaming ──────────────────────────────────────────────
for (_, state) in app.agent_streams.iter() {
    if state.is_streaming || !state.content.is_empty() {
        let role_color = match state.role.as_str() {
            "Architect" => current_theme().accent,
            "Implementer" => current_theme().success,
            "Reviewer" => current_theme().highlight,
            "Tester" => current_theme().error,
            "DevOps" => current_theme().accent_secondary,
            "Security" => current_theme().error,
            "Documentation" => current_theme().muted,
            "Project Manager" => current_theme().title,
            _ => current_theme().accent,
        };
        let role_style = Style::default().fg(role_color).add_modifier(Modifier::BOLD);

        lines.push(Line::from(vec![
            Span::styled("🐝 ", role_style),
            Span::styled(format!("{} — {}", state.agent_name, state.role), role_style),
        ]));

        // Syntax-highlighted code blocks with borders
        let highlighted = syntax_highlight::extract_and_highlight(&state.content);
        for (is_code, block_lines) in highlighted {
            if is_code {
                lines.push(Line::from(vec![
                    Span::styled("┌─ code ──────────────────────────────", muted_style()),
                ]));
                for hl_line in block_lines {
                    lines.push(hl_line);
                }
                lines.push(Line::from(vec![
                    Span::styled("└─────────────────────────────────────", muted_style()),
                ]));
            } else {
                for hl_line in block_lines {
                    lines.push(hl_line);
                }
            }
        }

        if state.is_streaming {
            lines.push(Line::from(vec![Span::styled("▌", role_style)]));
        }

        lines.push(Line::from(""));
    }
}
```

**Code visibility requirement:** ALL code blocks must be syntax-highlighted with `┌─ code ─` / `└─────────` borders. Never render agent content as plain text. See `references/swarm-code-visibility-pattern.md`.

## Inspector Sidebar Tab

Added as tab 3 (Ctrl+S cycles Tools → Skills → Swarm → Inspector):

```rust
KeyCode::Char('s') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    app.sidebar_tab = (app.sidebar_tab + 1) % 4;
    // ... tab names: 0=Tools, 1=Skills, 2=Swarm, 3=Inspector
}
```

Inspector content in `draw_sidebar()`:
- Agent name + role + status (streaming/done)
- Content preview (120 chars) with 📄 icon when code detected
- Tool count with ▶/▼ expandable toggle
- Expanded: tool name, ✅/❌ status, truncated output (4 lines, 50 chars)

**Toggle expansion:** Enter key when sidebar focused + Inspector tab:
```rust
KeyCode::Enter => {
    if app.focused_pane == 0 && app.sidebar_tab == 3 {
        let visible: Vec<String> = app.agent_streams.keys().cloned().collect();
        if let Some(agent_id) = visible.get(app.sidebar_scroll) {
            if app.agent_tool_expanded.contains(agent_id) {
                app.agent_tool_expanded.remove(agent_id);
            } else {
                app.agent_tool_expanded.insert(agent_id.clone());
            }
        }
    }
}
```

## Role Colors

| Role | Color | Theme Field |
|------|-------|-------------|
| Architect | Cyan | `accent` |
| Implementer | Green | `success` |
| Reviewer | Yellow | `highlight` |
| Tester | Red | `error` |
| DevOps | Secondary accent | `accent_secondary` |
| Security | Red | `error` |
| Documentation | Muted | `muted` |
| Project Manager | Title | `title` |

## User Preferences

**Full visibility:** synth wants ALL agent internal monologue visible — no truncation, no hiding. The only exception is persona-prep preamble ("I am an X agent..."), which is filtered out via `persona_filter.rs`.

**Code visibility (hard requirement):** Every code block an agent writes must be impossible to miss. Syntax-highlighted with borders in both main chat and swarm streaming. See `references/swarm-code-visibility-pattern.md`.

## Files Modified

- `src/swarm/mod.rs` — `AgentChunk` + `AgentToolResult` variants, event loop match
- `src/swarm/agent_runner.rs` — `chat_stream` + chunk broadcasting + persona filter
- `src/swarm/persona_filter.rs` — Preamble stripping module
- `src/tui/mod.rs` — `AgentStreamState`, `agent_tool_expanded`, event handling, rendering, Inspector tab, Enter keybinding
- `src/tui/syntax_highlight.rs` — `extract_and_highlight()` for code block detection
