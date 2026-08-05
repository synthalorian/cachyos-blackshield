# TUI Layout Patterns — OpenShark ratatui

Session: 2026-05-29. Fixing border overload, banner overlap, error styling, quit behavior, and chat header placement.

## Problem: ASCII Banner Overlapping Session Info

**Symptom:** Giant 6-line ASCII "OPENSHARK" banner rendered in `sidebar_layout[0]`, then session info ALSO rendered in `sidebar_layout[0]` — they overwrote each other, creating garbled text.

**Fix:** Remove the giant ASCII from sidebar. Use a compact 2-line header (`🦞 OpenShark v0.2.0` + tagline). Move the ASCII block text to the chat area header where horizontal space is abundant.

```rust
// Sidebar: compact
let header_lines = vec![
    Line::from(vec![
        Span::styled("🦞 ", shark_style()),
        Span::styled("OpenShark", highlight_style()),
        Span::styled(" v0.2.0", muted_style()),
    ]),
];

// Chat area: banner has room
fn draw_chat_header(f: &mut Frame, area: Rect) {
    let header_lines = vec![
        Line::from(vec![
            Span::styled("🦞 ", shark_style()),
            Span::styled("OpenShark", highlight_style()),
            Span::styled(" v0.2.0", muted_style()),
        ]),
        Line::from(vec![Span::styled(
            "█ █ █▀▀ █▄░█ ▀▄▀ █░█ █▀▀ █▄▀",
            Style::default().fg(RAT_PURPLE_1).add_modifier(Modifier::BOLD),
        )]),
        Line::from(vec![Span::styled(
            "The harness that learns. The agent that decides.",
            muted_style().add_modifier(Modifier::ITALIC),
        )]),
    ];
    // ...
}
```

## Problem: Border Overload

**Symptom:** Every sidebar section had `Borders::ALL` — nested magenta boxes creating visual noise.

**Fix:** Single outer border on the sidebar. Sections separated by `Borders::TOP` only.

```rust
let sidebar_block = Block::default()
    .title(" OpenShark ")
    .borders(Borders::ALL)
    .border_style(border_style());

// Inner sections:
Block::default()
    .title(" Session ")
    .borders(Borders::TOP)  // not ALL
    .border_style(border_style())
```

## Problem: Raw JSON Error Dumps

**Symptom:** API errors showed raw JSON: `{"error":{"message":"The API Key..."}}` in gray-on-purple.

**Fix:** Parse JSON in error handler, extract human-readable message, use `error_style()` (pink + bold).

```rust
let display_msg = if let Some(json_start) = error_msg.find('{') {
    if let Ok(json_val) = serde_json::from_str::<serde_json::Value>(&error_msg[json_start..]) {
        if let Some(msg) = json_val
            .get("error")
            .and_then(|e| e.get("message"))
            .and_then(|m| m.as_str())
        {
            format!("API Error: {}", msg)
        } else { error_msg }
    } else { error_msg }
} else { error_msg };
```

Chat rendering detects errors by content:
```rust
let is_error = msg.content.contains("Error:")
    || msg.content.contains("error:")
    || msg.content.contains("Failed")
    || msg.content.contains("failed");
if is_error {
    (error_style(), error_style(), "⚠ ")
} else {
    (muted_style(), muted_style(), "ℹ ")
}
```

## Problem: Ctrl+C Instantly Quits (Breaks Copy/Paste)

**Symptom:** Single Ctrl+C quit meant users couldn't highlight text without killing the app.

**Fix:** Double-tap quit with 2-second window. First press clears input and shows "Press Ctrl+C again to quit."

```rust
// In App struct:
ctrl_c_count: u8,
last_ctrl_c: Option<Instant>,

// In key handler:
let now = Instant::now();
let within_window = app.last_ctrl_c.map(|t| now.duration_since(t).as_secs() < 2).unwrap_or(false);

if within_window {
    app.ctrl_c_count += 1;
} else {
    app.ctrl_c_count = 1;
}
app.last_ctrl_c = Some(now);

if app.ctrl_c_count >= 2 {
    return Ok(true);  // quit
} else if !app.input.is_empty() {
    app.input.clear();
    app.add_system_message("Input cleared. Press Ctrl+C again to quit.".to_string());
} else {
    app.add_system_message("Press Ctrl+C again to quit.".to_string());
}
```

## Problem: Stale Binary in `~/.local/bin/`

**Symptom:** User runs `openshark` but gets old build. `cargo build --release` creates fresh binary in `target/release/` but `~/.local/bin/openshark` (in PATH) is stale.

**Fix:** After every release build, copy to `~/.local/bin/`:
```bash
cargo build --release
cp target/release/openshark ~/.local/bin/openshark
```

## Pattern: Welcome Message — Rendered Directly, Not as a Message

**Symptom:** ASCII banner rendered in a fixed header area above the chat box. Wastes 6 lines, doesn't scroll with chat, duplicates app name (sidebar title + header title + header content = triple "OpenShark").

**Attempt 1 (failed):** Inject welcome as a `system` role message into `messages` on app init. Problem: system messages get "ℹ system" prefix + muted styling, so the ASCII renders with a label and looks clipped/wrong.

**User correction:** "it needs to be IN the chatbox not in the top left corner clipped out of view" — no labels, no prefixes, just the ASCII centered in the chat area.

**Attempt 2 (failed — agent over-corrected):** Agent assumed the problem was color contrast (purple-on-purple invisible) and changed logo colors to cyan/white/pink. User had to correct: "no, it's in the top-left corner and is clipping" — the issue was placement/size, not color.

**Attempt 3 (failed — agent over-corrected again):** Agent kept the high-contrast colors. User corrected: "I can see the RAT_PURPLE_1 logo to begin with, the issue is the placement *of* the OpenShark ASCII" — they wanted the original color kept, just fixed structurally.

**Final fix:** Render welcome directly in `draw_chat_area()` when there are no real messages. Keep original `RAT_PURPLE_1` color per user preference. Trim logo to ~52 chars so it fits. Center dynamically using `chat_width`. No system message, no role prefix, no message history pollution.

```rust
fn draw_chat_area(f: &mut Frame, app: &App, area: Rect) {
    // ... block setup ...
    let mut lines: Vec<Line> = Vec::new();

    // Show welcome banner when chat is empty (no real messages yet)
    let real_messages = app.messages.iter()
        .filter(|m| m.role != "system" || !m.content.contains("█ █ █▀▀"))
        .count();
    
    if real_messages == 0 && !app.is_streaming {
        let logo_lines: Vec<&str> = vec![
            "  ██████  ██████  ███████ ███    ██ ██   ██ ██████  ",
            " ██    ██ ██   ██ ██      ████   ██ ██  ██  ██   ██ ",
            " ██    ██ ██████  █████   ██ ██  ██ █████   ██████  ",
            " ██    ██ ██      ██      ██  ██ ██ ██  ██  ██   ██ ",
            "  ██████  ██      ███████ ██   ████ ██   ██ ██   ██ ",
        ];

        let chat_width = inner.width as usize;
        lines.push(Line::from(""));
        for text in logo_lines {
            let padding = chat_width.saturating_sub(text.len()) / 2;
            let padded = " ".repeat(padding) + text;
            lines.push(Line::from(vec![Span::styled(
                padded,
                Style::default().fg(RAT_PURPLE_1).add_modifier(Modifier::BOLD),
            )]));
        }
        lines.push(Line::from(""));
        let tagline = "The harness that learns. The agent that decides.";
        let tag_padding = chat_width.saturating_sub(tagline.len()) / 2;
        lines.push(Line::from(vec![Span::styled(
            " ".repeat(tag_padding) + tagline,
            muted_style().add_modifier(Modifier::ITALIC),
        )]));
        lines.push(Line::from(""));
        let prompt = "Type a message to begin.";
        let prompt_padding = chat_width.saturating_sub(prompt.len()) / 2;
        lines.push(Line::from(vec![Span::styled(
            " ".repeat(prompt_padding) + prompt,
            muted_style(),
        )]));
    } else {
        // Normal message rendering...
    }
}
```

**Key insight:** Don't use messages for UI chrome. Messages are for conversation history. Welcome banners, empty states, and loading indicators should be rendered conditionally in the draw function.

**Agent pitfall to avoid:** When a user reports a UI visual issue (clipping, misplacement, wrong size), do NOT assume the color is the problem and change it unilaterally. Separate structural issues (position, size, clipping, alignment) from aesthetic issues (color, font, style). Fix structure first. Only change aesthetics if the user explicitly asks or the text is literally unreadable.

**Sidebar deduplication:** The sidebar block title `.title(" OpenShark ")` is the primary identifier. Content area should NOT repeat "OpenShark v0.2.0". Put the version + emoji in the sidebar content, or the tagline, but not both.

```rust
// Good: sidebar title = name, content = version + emoji
Block::default().title(" OpenShark ")
// Content:
Line::from(vec![
    Span::styled("🦞 ", shark_style()),
    Span::styled("OpenShark", highlight_style()),
    Span::styled(" v0.2.0", muted_style()),
]),

// Bad: title says "OpenShark", content ALSO says "OpenShark v0.2.0", chat header ALSO says it
```

## Testing TUI in Non-TTY Environment

Since the TUI requires a terminal, use tmux for automated testing:
```bash
# Start TUI in detached tmux session
tmux new-session -d -s test -c /project/dir "./target/release/openshark"

# Send input
tmux send-keys -t test "hello" Enter

# Capture output after delay
tmux capture-pane -t test -p | head -40

# Double Ctrl+C to quit
tmux send-keys -t test "C-c" && sleep 1 && tmux send-keys -t test "C-c"

# Clean up
tmux kill-session -t test
```
