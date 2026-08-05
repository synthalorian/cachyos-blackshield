# TUI Clipboard Integration Pattern

## Problem

Terminal emulators like Kitty and Alacritty use `Ctrl+Shift+C` for copy and `Ctrl+Shift+V` for paste. In a crossterm TUI running in raw mode, these shortcuts are intercepted by the TUI's key handler instead of the terminal emulator.

Even after fixing the modifier exact-match issue (`== KeyModifiers::CONTROL` instead of `.contains()`), `Ctrl+Shift+V` still doesn't paste because:

1. Crossterm reports `Ctrl+Shift+V` as `KeyCode::Char('V')` (uppercase) with `CONTROL | SHIFT` modifiers
2. The key falls through to the generic `KeyCode::Char(c)` arm which inserts a literal `'V'`
3. There is no clipboard access — raw mode TUIs don't get terminal paste events

## Solution: Native Clipboard via `arboard`

Add the `arboard` crate for cross-platform clipboard access and wire `Ctrl+V` to paste:

### 1. Add dependency

```bash
cargo add arboard
```

Or in `Cargo.toml`:
```toml
arboard = "3.6"
```

### 2. Import in TUI module

```rust
use arboard::Clipboard;
```

### 3. Replace the Ctrl+V handler

```rust
// BEFORE — toggles comparison mode (useless, conflicts with paste expectation)
KeyCode::Char('v') if key.modifiers == KeyModifiers::CONTROL => {
    app.show_comparison = !app.show_comparison;
    app.comparison_selected = 0;
}

// AFTER — pastes from system clipboard
KeyCode::Char('v') if key.modifiers == KeyModifiers::CONTROL => {
    match Clipboard::new().and_then(|mut cb| cb.get_text()) {
        Ok(text) => {
            for ch in text.chars() {
                app.input.insert(app.cursor_position, ch);
                app.cursor_position += 1;
            }
        }
        Err(e) => {
            app.add_system_message(format!("⚠️ Paste failed: {}", e));
        }
    }
}
```

## Why Not Just Let Terminal Handle It?

In raw mode (`crossterm::terminal::enable_raw_mode()`), the terminal emulator does NOT process `Ctrl+Shift+V` as paste. Raw mode gives the application exclusive control over all key events. The terminal only gets them back after `disable_raw_mode()`.

This is different from:
- **Bracketed paste** — terminals send escape sequences for paste, but crossterm doesn't expose them as clipboard content
- **Terminal-native copy** — `Ctrl+Shift+C` in Kitty copies the terminal's scrollback buffer, not the TUI's internal selection

## Crossterm Character Case with Shift

| Key Press | Crossterm Reports |
|-----------|------------------|
| `Ctrl+V` | `KeyCode::Char('v')` + `CONTROL` |
| `Ctrl+Shift+V` | `KeyCode::Char('V')` + `CONTROL \| SHIFT` |
| `Ctrl+C` | `KeyCode::Char('c')` + `CONTROL` |
| `Ctrl+Shift+C` | `KeyCode::Char('C')` + `CONTROL \| SHIFT` |

The shift key changes the character to uppercase in the `KeyCode::Char` value. This is why `== KeyModifiers::CONTROL` correctly excludes `Ctrl+Shift+V` — the modifiers don't match, AND the character is `'V'` not `'v'`.

## OpenShark Implementation (2026-06-01)

**File:** `src/tui/mod.rs`

```rust
use arboard::Clipboard;

// In handle_input():
KeyCode::Char('v') if key.modifiers == KeyModifiers::CONTROL => {
    match Clipboard::new().and_then(|mut cb| cb.get_text()) {
        Ok(text) => {
            for ch in text.chars() {
                app.input.insert(app.cursor_position, ch);
                app.cursor_position += 1;
            }
        }
        Err(e) => {
            app.add_system_message(format!("⚠️ Paste failed: {}", e));
        }
    }
}
```

**Dependency:** `arboard = "3.6.1"` in `Cargo.toml`

## Testing

1. Copy some text to clipboard (from browser, editor, etc.)
2. Run OpenShark TUI
3. Press `Ctrl+V` — text should appear in input line
4. Press `Ctrl+Shift+V` — same result (both paste)
5. `Ctrl+Shift+C` should NOT close the app (passes through, does nothing in TUI)

## Related

- `references/tui-keybinding-modifier-exact-match.md` — Modifier exact-match pattern
- `shark-language` skill — TUI keybinding section
