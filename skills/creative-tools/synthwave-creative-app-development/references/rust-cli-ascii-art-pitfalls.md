# Rust CLI ASCII Art Pitfalls in TUI Apps

Session-derived reference from OpenShark v1.0.0 TUI development. Covers block-character rendering, monospace assumptions, and the cargo install path problem.

## The Core Problem

Terminal emulators (kitty, alacritty, etc.) and TUI frameworks (ratatui) do NOT guarantee that Unicode block characters (`█` U+2588) render at the same width as ASCII spaces. The result: ASCII art that looks correct in a text editor becomes garbled in the terminal — letters merge, spacing collapses, and "OPENSHARK" becomes "OENSKARK" or "DPEKFARK".

## What Went Wrong (OpenShark Case Study)

**Attempt 1 — Variable-width letters with inconsistent gaps:**
```
 ██████  ███████ ███    ██ ███████ ██   ██  █████  ██████  ██   ██
██    ██ ██      ████   ██ ██      ██  ██  ██   ██ ██   ██ ██  ██
```
Result: "DPEKFARK" — the `O` looked correct but `P` was misshapen (7-wide with weird right side), `E` was 3-wide, `N` was split across gaps.

**Attempt 2 — Fixed 6-wide letters but wrong shapes:**
```
 ██████  ███████ ███    ██ ███████ ██   ██  █████  ██████  ██   ██
```
Result: "OENSKARK" — the second "letter" was `███████ / ██ / █████ / ██ / ███████` which is not any Latin letter. The `P` had no right-side stem on middle rows.

**Root cause:** The `P` shape was:
```
███████   ← 7 wide, full top bar
██        ← left stem only  
█████     ← middle bar (too wide, no right stem)
██        ← left stem only
███████   ← 7 wide, full bottom bar
```
This is not a `P`. A proper `P` is:
```
██████    ← 6 wide
██  ██    ← left + right stem
██████    ← middle bar
██        ← left stem only
██        ← left stem only
```

## The Fix

**Use exactly 6-character-wide letters with exactly 2-space gaps between them.** Every letter must be a proper recognizable block font shape. Verify each letter independently before assembling the word.

Correct `OPENSHARK`:
```
 ████   █████   █████   ██  ██   ████   ██  ██   ███    █████   ██  ██
██  ██  ██  ██  ██      ███ ██  ██      ██  ██  ██ ██   ██  ██  ██ ██
██  ██  █████   ████    ██ ███   ███    ██████  ██████  █████   ████
██  ██  ██      ██      ██  ██      ██  ██  ██  ██  ██  ██ ██   ██ ██
 ████   ██      █████   ██  ██   ████   ██  ██  ██  ██  ██  ██  ██  ██
```

## Verification Script

Before committing ASCII art, verify each letter shape:

```python
letters = {
    'O': [" ████ ", "██  ██", "██  ██", "██  ██", " ████ "],
    'P': ["██████", "██  ██", "██████", "██    ", "██    "],
    'E': ["██████", "██    ", "████  ", "██    ", "██████"],
    'N': ["██  ██", "███ ██", "██ ███", "██  ██", "██  ██"],
    'S': [" ████ ", "██    ", " ███  ", "    ██", " ████ "],
    'H': ["██  ██", "██  ██", "██████", "██  ██", "██  ██"],
    'A': [" ███  ", "██ ██ ", "██████", "██  ██", "██  ██"],
    'R': ["██████", "██  ██", "██████", "██ ██ ", "██  ██"],
    'K': ["██  ██", "██ ██ ", "████  ", "██ ██ ", "██  ██"],
}
```

Run the Python script from the skill to render and eyeball each letter before assembling the full word.

## Negative-Space vs Positive-Space Rendering

**CRITICAL PITFALL:** There are two fundamentally different approaches to block-character ASCII art, and choosing the wrong one produces garbage.

### Negative-Space (Background = █, Letters = spaces)
```
 ██████  ██████  ██████  ███   ██ ██████  ██████  ██████  ██   ██ ██████ 
██    ██ ██   ██ ██   ██ ████  ██ ██      ██   ██ ██   ██ ██  ██  ██   ██
```
**Result:** Letters are formed by the GAPS between █ blocks. **This fails in terminals** because:
- Terminals render dense █ blocks as cursor icons or geometric shapes
- The "negative space" letters become invisible
- "OPENSHARK" renders as "CURSOR" or "OPPNSRRKR" — complete garbage

**When this happens:** The terminal font maps U+2588 (FULL BLOCK) to a cursor/block glyph instead of a solid fill. The spaces (which form the actual letters) are invisible against the background.

### Positive-Space (Letters = █, Background = spaces)
```
 ████   █████   █████   ██  ██   ████   ██  ██   ███    █████   ██  ██
██  ██  ██  ██  ██      ███ ██  ██      ██  ██  ██ ██   ██  ██  ██ ██
```
**Result:** Letters are formed by the █ blocks themselves. **This works reliably** because:
- Even if █ renders oddly, the letter SHAPE is still visible
- The positive space carries the information
- Terminal fonts handle sparse █ better than dense █ fields

**RULE:** Always use positive-space rendering for TUI ASCII art. Never use negative-space.

## The "CURSOR" Bug (OpenShark Case Study)

When negative-space rendering was used for the OpenShark splash screen:
- Wordmark: ` ██  ██  ███  ████ ██ ████  ████ ██  ██ ████` (spaces = letters)
- Terminal rendered dense █ as cursor icons
- Result: "CURSOR" appeared in pink + a mouse pointer icon
- The actual letters (formed by spaces) were completely invisible

**Fix:** Rewrite with positive-space █ blocks forming actual letter shapes. The wordmark became readable immediately.

## Splash Screen Architecture — Don't Use Chat Messages

**PITFALL:** Injecting ASCII art as a "system message" into the chat history causes:
- Truncation at chat frame width (~60 chars vs 80+ needed)
- Wrapping that breaks letter shapes
- Special styling logic (`msg.content.contains('█')`) that conflicts with normal messages
- Scroll position issues — user sees bottom of banner first

**Correct approach:** Dedicated full-screen splash overlay:
1. Add `AppMode::Splash` to the app state machine
2. Set initial mode to `Splash` on app startup
3. Render splash with `draw_splash_screen()` that uses FULL terminal width
4. Any keypress transitions `Splash → Normal`
5. Only after transition does the chat TUI appear

**Implementation pattern (ratatui):**
```rust
fn draw_ui(f: &mut Frame, app: &App) {
    if app.mode == AppMode::Splash {
        draw_splash_screen(f);
        return;
    }
    // ... normal chat UI
}

async fn handle_input(app: &mut App, key: KeyEvent) -> Result<bool> {
    if app.mode == AppMode::Splash {
        app.mode = AppMode::Normal;
        return Ok(false);
    }
    // ... normal input handling
}
```

## Updated Verification Script

Before committing ASCII art, verify:
1. **Positive space:** Letters are formed by █ blocks, not gaps
2. **Terminal test:** Render in actual terminal (not just text editor)
3. **Width check:** Ensure it fits in target frame width (typically 50-80 chars)
4. **Splash vs inline:** Use full-screen splash for large art, sidebar header for compact

## Cargo Install Path Problem

**Symptom:** `cargo build --release` produces a binary in `target/release/`, but the system runs an older binary from `~/.local/bin/`. Changes appear to have no effect.

**Root cause:** `cargo build` does not copy to the install location. The user has `~/.cargo/config.toml` with `root = "/home/synth/.local"`, but `cargo build` ignores this — only `cargo install` respects it.

**Fix:** Always use `cargo install --path .` from the project root:
```bash
cd ~/projects/openshark && cargo install --path .
```

This builds release and copies to `~/.local/bin/` in one step, honoring the config.toml root setting.

**Never do:**
- `cargo build --release && cp target/release/foo ~/.local/bin/foo` — manual, error-prone, forgettable
- `cargo build --release` alone — binary sits in target/, system runs stale copy

## Ratatui-Specific Notes

- `ratatui::widgets::Paragraph` renders text with the terminal's font. If the font has non-monospace block characters, ASCII art will fail regardless of source correctness.
- Test with the actual terminal font (e.g., the user's configured kitty font) before declaring the art "done."
- Consider using `tui-big-text` crate or similar for guaranteed block-letter rendering instead of hand-rolled ASCII art.

## General Rules

1. **Verify in the actual terminal** — not just in the text editor or `cat` output.
2. **Use fixed-width letters** — every letter same width, consistent gaps.
3. **Use `cargo install --path .`** — never `cargo build --release` alone for user-facing binaries.
4. **Consider alternatives** — for production TUI apps, use a proper big-text crate rather than maintaining hand-rolled ASCII art.
