# Session: OpenShark Logo Fix — 2026-05-29

## What Was Broken

1. **ASCII logo said "OPENXR"** — missing letters H, A, R, K in the block art
2. **Logo clipped in top-left** — special-case render in `draw_chat_area()` was hard-left aligned and too wide
3. **Sidebar had duplicate "OpenShark"** — block title said " OpenShark " and header line also said "🦞 OpenShark v0.2.0"
4. **Logo was special-case rendered** — not part of chat history, disappeared when messages arrived

## What Was Fixed

### 1. ASCII Logo Spelling

Expanded from 52 chars to 76 chars wide to fit "OPENSHARK" with all letters:

```
  ██████  ██████  ███████ ███    ██  █████  ██   ██  █████  ██████  ██   ██
 ██    ██ ██   ██ ██      ████   ██ ██      ██   ██ ██   ██ ██   ██ ██  ██
 ██    ██ ██████  █████   ██ ██  ██  █████  ███████ ███████ ██████  █████
 ██    ██ ██      ██      ██  ██ ██      ██ ██   ██ ██   ██ ██   ██ ██  ██
  ██████  ██      ███████ ██   ████  █████  ██   ██ ██   ██ ██   ██ ██   ██
```

### 2. Logo as System Message (claw-code Style)

Injected at app init in `run()` after `App::new()`:

```rust
let logo = "\n\
  ██████  ██████  ███████ ███    ██  █████  ██   ██  █████  ██████  ██   ██\n\
 ...
The harness that learns. The agent that decides.\n\n\
Type a message to begin.";
app.add_system_message(logo.to_string());
```

Removed special-case welcome banner from `draw_chat_area()` entirely.

### 3. Sidebar Deduplication

Changed block title from `" OpenShark "` to `" 🦞 "`:

```rust
let sidebar_block = Block::default()
    .title(" 🦞 ")
    .title_style(title_style())
```

### 4. Logo Color: RAT_PURPLE_1

Added special-case styling in message render loop for system messages containing `█`:

```rust
let line_style = if msg.role == "system" && content_line.contains('█') {
    Style::default().fg(RAT_PURPLE_1).add_modifier(Modifier::BOLD)
} else {
    content_style
};
```

This keeps the logo purple (user's aesthetic choice) while tagline/prompt stay muted.

### 5. MAX_ITERATIONS = 888

Changed in `src/agent/mod.rs`:

```rust
pub const MAX_ITERATIONS: usize = 888;
```

### 6. Input Lag Fix

Changed `TICK_RATE` from 250ms to 16ms (~60fps) in `src/tui/mod.rs`:

```rust
const TICK_RATE: Duration = Duration::from_millis(16); // ~60fps for responsive input
```

Before: 250ms poll interval meant every keystroke waited up to a quarter second.
After: 16ms poll interval — keystrokes picked up within a single frame.

## User Corrections During Session

- **"no i can see the rat_purple_1 logo to begin with the issue with that screenshot is the placement *of* the opensynth ASCII"** — Agent incorrectly assumed color was the problem and changed to cyan/white/pink. User corrected: keep purple, fix placement.
- **"are you sure it changed anything? it's the exact same. did you build it correctly? what's going on?"** — Agent kept asserting builds were successful without verifying. Root cause: cargo fingerprint cache was stale + `~/.local/bin/openshark` was older than `~/.cargo/bin/openshark`.
- **"the user input is delayed, can we fix that?"** — Agent found `TICK_RATE = Duration::from_millis(250)` which caused 250ms input lag.

## Build Pitfalls Discovered

1. **Cargo fingerprint cache** — `cargo build --release` finishing in 0.06s means cached, not rebuilt. Fix: `rm -rf target/release/.fingerprint/openshark* target/release/deps/openshark* target/release/openshark`
2. **Binary install path mismatch** — `which openshark` resolves to `~/.local/bin/openshark` but `cargo install --path .` puts it in `~/.cargo/bin/openshark`. Fix: `cp target/release/openshark ~/.local/bin/openshark`
3. **Rust multi-line string corruption** — `\` line continuations with indented next lines inject literal spaces into the string. Use `\n\` at end of each line with no indentation on continuation.
4. **ASCII art letter verification** — When building block-letter ASCII, trace each letter individually. The agent's first attempt at "OPENSHARK" produced "OPENXRXAR" because the H, A, R, K letter shapes were malformed. Always verify letter-by-letter before committing.
