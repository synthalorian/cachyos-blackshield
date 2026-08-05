# Terminal Keybinding Conflicts — Ctrl+M and Other Hijacked Shortcuts

## Problem

`Ctrl+M` was bound to "model selector" in the TUI, but it never worked. The terminal intercepts `Ctrl+M` as ASCII carriage return (`\r`, same byte as Enter) before it reaches the application.

## Root Cause

In Unix terminals, control characters map to ASCII control codes:
| Key | ASCII Code | Standard Meaning |
|-----|-----------|-----------------|
| `Ctrl+M` | `\r` (0x0D) | Carriage Return (same as Enter) |
| `Ctrl+I` | `\t` (0x09) | Tab |
| `Ctrl+H` | `\b` (0x08) | Backspace |
| `Ctrl+J` | `\n` (0x0A) | Line Feed |
| `Ctrl+[` | `\e` (0x1B) | Escape |

Crossterm cannot distinguish `Ctrl+M` from `Enter` because the terminal sends the same byte. The application never sees a `KeyEvent` with `KeyCode::Char('m')` and `KeyModifiers::CONTROL`.

## Fix

Changed model selector to `Ctrl+P` (for "pick model"):

```rust
// BEFORE (broken — never fires)
KeyCode::Char('m') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    app.show_model_selector();
}

// AFTER (works)
KeyCode::Char('p') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    app.show_model_selector();
}
```

Also updated all references:
- Help text (`help` command output)
- Sidebar shortcuts display
- README documentation

## Safe vs Unsafe Ctrl+Key Bindings

| Shortcut | Safe? | Reason |
|----------|-------|--------|
| `Ctrl+C` | ⚠️ Use `==` | Terminal copy (Ctrl+Shift+C) must not trigger quit |
| `Ctrl+V` | ⚠️ Use `==` | Terminal paste (Ctrl+Shift+V) must not trigger app paste |
| `Ctrl+D` | ✅ | EOF — no standard conflict in TUI context |
| `Ctrl+L` | ✅ | Clear screen — no standard conflict |
| `Ctrl+B` | ✅ | No standard terminal meaning |
| `Ctrl+M` | ❌ | Carriage return — same as Enter |
| `Ctrl+I` | ❌ | Tab — same as Tab key |
| `Ctrl+H` | ❌ | Backspace — same as Backspace |
| `Ctrl+J` | ❌ | Line feed — same as Enter |
| `Ctrl+[` | ❌ | Escape — same as Esc |
| `Ctrl+P` | ✅ | No standard terminal meaning |
| `Ctrl+A` | ✅ | No standard terminal meaning |
| `Ctrl+T` | ✅ | No standard terminal meaning |
| `Ctrl+S` | ⚠️ | XON (software flow control) — may freeze terminal on some systems |
| `Ctrl+Q` | ⚠️ | XOFF (software flow control) — may unfreeze terminal |
| `Ctrl+Z` | ❌ | Suspend process (SIGTSTP) |

## Modifier Check Best Practice

For shortcuts that have standard terminal conflicts, use **exact match** (`==`) not subset (`contains`):

```rust
// WRONG — matches Ctrl+Shift+C, Ctrl+Alt+C, etc.
KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => { }

// RIGHT — only matches bare Ctrl+C
KeyCode::Char('c') if key.modifiers == KeyModifiers::CONTROL => { }
```

Use `==` for: `Ctrl+C`, `Ctrl+V`
Use `contains()` for: `Ctrl+D`, `Ctrl+L`, `Ctrl+B`, `Ctrl+P`, `Ctrl+A`, `Ctrl+T`, `Ctrl+S`

## Related

- `references/tui-keybinding-modifier-exact-match.md` — Modifier exact-match pitfall
- `references/tui-clipboard-integration.md` — Ctrl+V paste implementation
