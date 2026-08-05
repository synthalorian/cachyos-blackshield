# TUI Surgical Editing Pattern — OpenShark ratatui

Session: 2026-05-30. Multi-model comparison overlay feature added to `src/tui/mod.rs` (~1900 lines) via targeted patches, avoiding the full-file rewrite trap.

## The Trap

A prior attempt at this same feature did a full-file rewrite of `tui/mod.rs`. Result:
- Compilation broke due to non-existent methods
- Borrow checker regressions
- Lost context from the original file
- Had to revert to original and start over

**Rule: Never rewrite a large TUI file. Use surgical patches.**

## The Pattern

### 1. Read Before Cutting

Use `read_file` with offset/limit to see the exact target function. Don't guess line numbers.

```
read_file(path="src/tui/mod.rs", offset=60, limit=20)   // struct definition
read_file(path="src/tui/mod.rs", offset=250, limit=15)  // constructor
read_file(path="src/tui/mod.rs", offset=570, limit=20)  // event handler
```

### 2. Patch with Surrounding Context

Include 3-5 lines of context above and below the change. The fuzzy matcher handles minor whitespace drift.

**Good — struct field addition:**
```rust
// Old:
    multi_model_mode: bool,
    /// Secondary providers for multi-model mode.
    secondary_providers: Vec<(String, Provider)>,
    /// Security engine for guardrails.

// New:
    multi_model_mode: bool,
    /// Secondary providers for multi-model mode.
    secondary_providers: Vec<(String, Provider)>,
    /// Show the multi-model comparison overlay.
    show_comparison: bool,
    /// Selected response index in the comparison overlay.
    comparison_selected: usize,
    /// Security engine for guardrails.
```

**Good — constructor initialization:**
```rust
// Old:
            multi_model_mode: false,
            secondary_providers: Vec::new(),
            security_engine,

// New:
            multi_model_mode: false,
            secondary_providers: Vec::new(),
            show_comparison: false,
            comparison_selected: 0,
            security_engine,
```

### 3. Update All Constructors

When adding a field to a struct with multiple constructors, patch EVERY constructor. Missing one = compilation error.

For `ChatMessage` with 3 constructors:
- `add_user_message()` — user messages
- `add_assistant_message()` — assistant messages  
- `add_system_message()` — system/tool messages

All need `multi_model_responses: Vec::new()`.

### 4. Enum Variant + Handler + Background Task

When adding a `StreamEvent` variant, touch 3 places:
1. **Enum definition** — add the variant with its payload
2. **`apply_stream_event()`** — handle the variant in the match
3. **Background task** — the code that sends the event via `tx.send()`

Example: `MultiModelResponse` originally created truncated system messages. Fixed to attach to the last assistant message:

```rust
// BEFORE (broken — truncated system messages):
StreamEvent::MultiModelResponse { name, content, metrics } => {
    self.add_system_message(format!(
        "[{}] {}ms | {} tokens\n{}",
        name, metrics.total_latency_ms, metrics.tokens_generated,
        &content[..content.len().min(500)]
    ));
}

// AFTER (correct — attach to last assistant message):
StreamEvent::MultiModelResponse { name, content, metrics } => {
    if !content.is_empty() {
        if let Some(last_idx) = self.messages.iter().rposition(|m| m.role == "assistant") {
            self.messages[last_idx].multi_model_responses.push(SecondaryResponse {
                model_name: name, content, latency_ms: metrics.total_latency_ms,
                tokens: metrics.tokens_generated,
            });
        }
    }
}
```

### 5. Keybinding — Three Places

Every new keybinding needs:
1. **`handle_input()` match arm** — the actual key handler
2. **`draw_sidebar()` shortcuts** — sidebar display
3. **Help text** — `help` command output

Example for Ctrl+V:
```rust
// 1. Key handler:
KeyCode::Char('v') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    app.show_comparison = !app.show_comparison;
    app.comparison_selected = 0;
}

// 2. Sidebar shortcut (in draw_sidebar):
Line::from(vec![
    Span::styled("Ctrl+V  ", accent_style()),
    Span::styled("Compare models", muted_style()),
]),

// 3. Help text:
"• Ctrl+V            — Toggle model comparison"
```

### 6. Overlay Drawing Pattern

A modal overlay in ratatui:

```rust
fn draw_my_overlay(f: &mut Frame, app: &App) {
    let area = f.area();
    let popup_area = centered_rect(90, 85, area);  // 90% x 85%

    f.render_widget(Clear, popup_area);  // Clear background

    let block = Block::default()
        .title(" Title ")
        .borders(Borders::ALL)
        .border_style(focused_border_style())
        .style(bg_style());

    let inner = block.inner(popup_area);
    f.render_widget(block, popup_area);

    // Build content lines...
    let paragraph = Paragraph::new(Text::from(lines))
        .wrap(Wrap { trim: true })
        .style(bg_style());
    f.render_widget(paragraph, inner);
}
```

Wire into `draw_ui()`:
```rust
if app.show_comparison {
    draw_comparison_overlay(f, app);
}
```

### 7. Navigation in Overlay Mode

When an overlay is active, redirect navigation keys:

```rust
KeyCode::Up => {
    if app.show_comparison {
        app.comparison_selected = app.comparison_selected.saturating_sub(1);
    } else {
        app.scroll_up(3);
    }
}
KeyCode::Esc => {
    if app.show_comparison {
        app.show_comparison = false;
    } else {
        return Ok(true);  // quit app
    }
}
```

### 8. Chat Area Indicators

Add subtle indicators inline with message rendering:

```rust
// After rendering message content lines:
if msg.role == "assistant" && !msg.multi_model_responses.is_empty() {
    let count = msg.multi_model_responses.len();
    lines.push(Line::from(vec![
        Span::styled(
            format!("📊 {} alternate response{} — Ctrl+V to compare", 
                count, if count == 1 { "" } else { "s" }),
            muted_style().add_modifier(Modifier::ITALIC),
        ),
    ]));
}
```

### 9. Verify with cargo check

The `write_file` / `patch` lint checker runs without `--edition` context and produces false positives for `async fn` on Rust 2024 projects. **Always verify with `cargo check`:**

```bash
cd /home/synth/projects/openshark && cargo check
```

Ignore linter "Rust 2015" warnings. Trust the compiler.

## Checklist for TUI Feature Addition

- [ ] Struct field added to `App` or `ChatMessage`
- [ ] Field initialized in ALL constructors (`App::new`, `add_user_message`, etc.)
- [ ] `StreamEvent` variant added (if needed)
- [ ] Variant handled in `apply_stream_event()`
- [ ] Event sent from background task
- [ ] Keybinding in `handle_input()`
- [ ] Keybinding in sidebar shortcuts
- [ ] Keybinding in help text
- [ ] Draw function implemented
- [ ] Draw function wired into `draw_ui()`
- [ ] Navigation keys handle overlay mode
- [ ] Chat area indicator added (if relevant)
- [ ] `cargo check` passes
