# TUI Tabbed Sidebar with Scrolling

Pattern for a tabbed sidebar that switches between Tools and Skills views with scrollable content.

## Problem

The sidebar shows only 5 tools with `.take(5)`, hiding the rest. Skills aren't displayed at all. Users need to see all available tools/skills without flooding the UI.

## Solution

Tabbed view (Tools/Skills) with scrollable content. `Ctrl+S` switches tabs. `↑/↓` scrolls when sidebar is focused.

## Implementation

### 1. Add state to App

```rust
struct App {
    // ... existing fields ...
    sidebar_tab: usize,      // 0=Tools, 1=Skills
    sidebar_scroll: usize,   // scroll offset
    skill_registry: Option<SkillRegistry>,
}
```

Initialize:
```rust
sidebar_tab: 0,
sidebar_scroll: 0,
skill_registry: {
    let skills_dir = dirs::config_dir()
        .unwrap_or_else(|| std::path::PathBuf::from("."))
        .join("openshark")
        .join("skills");
    SkillRegistry::new(skills_dir).ok()
},
```

### 2. Render tabbed content

```rust
let tab_title = if app.sidebar_tab == 0 {
    format!(" Tools [{}] ", get_tools().len())
} else {
    let skill_count = app.skill_registry.as_ref()
        .map(|r| r.all_skills().len())
        .unwrap_or(0);
    format!(" Skills [{}] ", skill_count)
};

let items: Vec<Line> = if app.sidebar_tab == 0 {
    let all_tools = get_tools();
    all_tools.iter().skip(app.sidebar_scroll).take(6).map(|t| {
        let desc = t.description();
        let desc_short = &desc[..desc.len().min(16)];
        Line::from(vec![
            Span::styled(format!("{:<8}", t.name()), tool_style()),
            Span::styled(desc_short.to_string(), muted_style()),
        ])
    }).collect()
} else {
    match &app.skill_registry {
        Some(registry) => registry.all_skills()
            .iter()
            .skip(app.sidebar_scroll)
            .take(6)
            .map(|s| {
                let desc = &s.description;
                let desc_short = &desc[..desc.len().min(16)];
                Line::from(vec![
                    Span::styled(format!("{:<8}", &s.name[..s.name.len().min(8)]), tool_style()),
                    Span::styled(desc_short.to_string(), muted_style()),
                ])
            }).collect(),
        None => vec![Line::from(vec![Span::styled("No skills loaded", muted_style())])],
    }
};

let items_para = Paragraph::new(Text::from(items))
    .block(
        Block::default()
            .title(tab_title)
            .title_style(title_style())
            .borders(Borders::TOP)
            .border_style(border_style()),
    )
    .style(bg_style());
```

### 3. Keybinding for tab switch

```rust
KeyCode::Char('s') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    app.sidebar_tab = (app.sidebar_tab + 1) % 2;
    app.sidebar_scroll = 0;
    let label = if app.sidebar_tab == 0 { "Tools" } else { "Skills" };
    app.add_system_message(format!("📂 Sidebar tab: {}", label));
}
```

### 4. Scroll handling

When sidebar is focused (`focused_pane == 0`), `↑/↓` and `PageUp`/`PageDown` scroll the sidebar instead of the chat:

```rust
KeyCode::Up => {
    if app.show_comparison {
        // ... comparison handling ...
    } else if app.focused_pane == 0 {
        app.sidebar_scroll = app.sidebar_scroll.saturating_sub(1);
    } else {
        app.scroll_up(3);
    }
}

KeyCode::PageUp => {
    if app.focused_pane == 0 {
        app.sidebar_scroll = app.sidebar_scroll.saturating_sub(3);
    } else {
        app.scroll_up(10);
    }
}
```

### 5. Layout constraints

Give the tools/skills section more vertical space:

```rust
let sidebar_layout = Layout::default()
    .direction(Direction::Vertical)
    .constraints([
        Constraint::Length(3),   // header
        Constraint::Length(8),   // session info (6 lines + padding)
        Constraint::Length(7),   // shortcuts
        Constraint::Length(8),   // tools/skills (was 6)
        Constraint::Min(3),      // performance
    ])
    .split(inner);
```

## Key Design Decisions

- **Count in title** — `Tools [9]` immediately shows how many exist
- **6 visible items** — fits in the 8-line constraint with padding
- **Reset scroll on tab switch** — avoids confusing offset when changing views
- **Skill names truncated to 8 chars** — kebab-case skill names fit fine

## Future Extensions

- Add a third tab for "MCP Tools" (dynamically discovered)
- Click/Enter on a tool/skill to show full description in a popup
- Filter/search within the tab
