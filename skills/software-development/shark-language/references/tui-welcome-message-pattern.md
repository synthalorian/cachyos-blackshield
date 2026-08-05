# TUI Welcome Message Pattern — Two Approaches

Session: 2026-05-29. Fixing OpenShark welcome logo placement and flow.

## The Problem

User reported the ASCII logo was "in the top-left corner and is clipping." The logo was rendered as a special-case banner in `draw_chat_area()` when `messages` was empty. It was hard-left aligned and too wide for the chat area when the sidebar was open.

## Approach A: Special-Case Render (Static, Non-Scrolling)

Render welcome directly in `draw_chat_area()` when `messages` is empty. The content is UI chrome, not conversation history. Good for fixed branding that disappears once the user starts chatting.

```rust
fn draw_chat_area(f: &mut Frame, app: &App, area: Rect) {
    let mut lines: Vec<Line> = Vec::new();

    if app.messages.is_empty() && !app.is_streaming {
        let logo_lines: Vec<&str> = vec![
            "  ██████  ██████  ███████ ███    ██ ██   ██ ██████  ",
            " ██    ██ ██   ██ ██      ████   ██ ██  ██  ██   ██ ",
            // ... more lines
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
        // tagline, prompt...
    } else {
        // Normal message rendering...
    }
}
```

**Trade-off:** Content disappears from view once messages arrive. User can't scroll back to see the welcome.

## Approach B: Inject as First Message (Flows with History) — claw-code Style

Add the welcome content as a system message at app init. It renders through the normal message path, so it scrolls with the conversation. Good when you want the welcome to persist and feel like part of the chat history.

```rust
// In run() after App::new():
let logo = "\n  ██████  ██████  ███████ ███    ██ ██   ██ ██████\n \
    ██    ██ ██   ██ ██      ████   ██ ██  ██  ██   ██\n \
    ██    ██ ██████  █████   ██ ██  ██ █████   ██████\n \
    ██    ██ ██      ██      ██  ██ ██ ██  ██  ██   ██\n \
     ██████  ██      ███████ ██   ████ ██   ██ ██   ██\n\n \
    The harness that learns. The agent that decides.\n\n \
    Type a message to begin.";
app.add_system_message(logo.to_string());
```

Then remove the special-case welcome banner from `draw_chat_area()` entirely — just render messages normally.

**Trade-off:** The message gets the normal system message prefix ("ℹ system") and muted styling. The logo ASCII renders as plain text without custom per-line colors. If you need custom colors, you need special-case rendering logic in the message loop for the welcome message.

**When to use which:**
- Use **Approach A** for fixed branding that should vanish once chat starts
- Use **Approach B** when the user explicitly says "like claw-code does it" or "flow through as the first message in the chat"

## Agent Pitfall: Don't Fix Colors the User Didn't Complain About

**What went wrong in this session:** The agent saw a screenshot of the logo in `RAT_PURPLE_1` on a deep purple background and *assumed* the color was the problem. Changed it to cyan/white/pink without asking. The user had to correct: "no, I can see the RAT_PURPLE_1 logo to begin with, the issue is the placement."

**Rule:** When a user reports a UI visual issue, separate structural problems (position, size, clipping, alignment) from aesthetic problems (color, font, style). Fix structure first. Only change aesthetics if:
1. The user explicitly asks, OR
2. The text is literally unreadable (contrast ratio < 3:1), OR
3. You have a screenshot proving the element is invisible

**Never** change colors, fonts, or styling unilaterally based on your own aesthetic judgment. The user chose those colors for a reason.

## Agent Pitfall: Rust Multi-Line String Literals Corrupt ASCII Art

When embedding multi-line ASCII art in a Rust string literal, **never** use `\` line continuations with indented continuation lines:

```rust
// WRONG — indentation becomes literal spaces in the string
let logo = "\n  ██████\n \
        ██    ██\n \
        ██    ██";  // "        " spaces are IN the string!
```

**Correct approaches:**

**Option 1:** Raw string with explicit newlines (no `\` continuations):
```rust
let logo = "\n\
  ██████  ██████  ███████\n\
 ██    ██ ██   ██ ██\n\
 ██    ██ ██████  █████";
```

**Option 2:** `include_str!` macro with a separate `.txt` file:
```rust
const LOGO: &str = include_str!("../../assets/logo.txt");
```

**Option 3:** `indoc` crate for indented string literals:
```rust
use indoc::indoc;
let logo = indoc! {r#"
    ██████  ██████  ███████
   ██    ██ ██   ██ ██
   ██    ██ ██████  █████
"#};
```

## Agent Pitfall: Verify the Binary Actually Changed

When the user says "it's the exact same" after a build, the binary may be stale. `cargo install --path .` can reuse cached artifacts.

**Verification steps:**
1. Run `cargo clean` to force a full rebuild
2. Run `cargo build --release`
3. Run `cargo install --path . --force`
4. Check the build timestamp: `ls -la ~/.cargo/bin/openshark`
5. If still suspect, grep the source to confirm the change is present: `grep -n "Inject welcome" src/tui/mod.rs`

**Never** tell the user "it's built" without verifying the binary timestamp changed or the source contains your edits.

## Agent Pitfall: User Says "Are You Sure It Changed?"

This is a **frustration signal** meaning the agent is asserting without verifying. When a user asks this:
- Stop asserting
- Actually verify (source grep, binary timestamp, or ask user to check)
- Do not say "yes I'm sure" without evidence
- The correct response is to investigate, not to reassure
