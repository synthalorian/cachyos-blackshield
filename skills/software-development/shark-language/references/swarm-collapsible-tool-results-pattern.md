# Swarm Collapsible Tool Results Pattern

## Problem

Agents in swarm mode execute tools, but the TUI inspector only shows a raw tool count ("🔧 3 tools") with no detail. Users need to see WHAT tools were called and whether they succeeded, without cluttering the default view.

## Solution

Expandable/collapsible tool results in the Agent Inspector sidebar tab, with per-agent state tracking.

## Implementation

### 1. Add Tool Result Event

```rust
// src/swarm/mod.rs
pub enum SwarmEvent {
    // ... existing variants ...
    AgentToolResult {
        agent_id: AgentId,
        tool_name: String,
        result: String,
        success: bool,
    },
}
```

### 2. Broadcast from AgentRunner

```rust
let (tool_result, success) = match executor.execute_with_timeout(...) {
    Ok((result, metrics)) => {
        let success = metrics.success;
        let _ = self.event_tx.send(SwarmEvent::AgentToolResult {
            agent_id: self.agent_id.clone(),
            tool_name: suggestion.tool_name.clone(),
            result: result.clone(),
            success,
        });
        (formatted, success)
    }
    Err(e) => {
        let err = format!("Tool execution error: {}", e);
        let _ = self.event_tx.send(SwarmEvent::AgentToolResult {
            agent_id: self.agent_id.clone(),
            tool_name: suggestion.tool_name.clone(),
            result: err.clone(),
            success: false,
        });
        (err, false)
    }
};
```

### 3. Store in AgentStreamState

```rust
pub struct AgentStreamState {
    pub agent_id: String,
    pub agent_name: String,
    pub role: String,
    pub content: String,
    pub is_streaming: bool,
    pub tool_results: Vec<(String, String, bool)>, // (name, result, success)
}
```

### 4. TUI State Tracking

```rust
// In App struct
agent_tool_expanded: HashSet<String>, // agent_ids that are expanded
```

### 5. Render in Inspector Tab

```rust
if !state.tool_results.is_empty() {
    let expanded = app.agent_tool_expanded.contains(&state.agent_id);
    let icon = if expanded { "▼" } else { "▶" };
    lines.push(Line::from(vec![
        Span::styled(format!("  {} 🔧 {} tools", icon, state.tool_results.len()), tool_style()),
    ]));
    if expanded {
        for (tool_name, result, success) in &state.tool_results {
            let status = if *success { "✅" } else { "❌" };
            lines.push(Line::from(vec![
                Span::styled(format!("    {} {}", status, tool_name), muted_style()),
            ]));
            for line in result.lines().take(4) {
                lines.push(Line::from(vec![
                    Span::styled(format!("      {}", line.chars().take(50).collect::<String>()), muted_style()),
                ]));
            }
        }
    }
}
```

### 6. Keybinding

```rust
KeyCode::Enter => {
    if app.focused_pane == 0 && app.sidebar_tab == 3 { // Inspector tab
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

## UX Design

- **Collapsed (default):** `▶ 🔧 3 tools` — compact, shows count only
- **Expanded:** `▼ 🔧 3 tools` followed by each tool with status icon and truncated output
- **Status icons:** ✅ success, ❌ failure
- **Output truncation:** 4 lines max, 50 chars per line — prevents overflow
- **Per-agent state:** Each agent independently expandable

## Integration Points

- Event loop: handle `AgentToolResult` in TUI swarm polling
- Inspector tab: tab index 3 (after Tools, Skills, Swarm)
- Sidebar scroll: ↑/↓ navigates agents, Enter toggles expansion
