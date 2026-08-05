# TUI Keybinding Modifier Exact-Match Pattern

## Problem

Crossterm's `KeyModifiers` uses bitflags. `key.modifiers.contains(KeyModifiers::CONTROL)` returns `true` when **any** of the pressed modifiers includes `CONTROL` — including `Ctrl+Shift`, `Ctrl+Alt`, `Ctrl+Shift+Alt`, etc.

This causes TUI keybindings to intercept terminal emulator shortcuts:
- `Ctrl+Shift+C` → intercepted as `Ctrl+C` → triggers quit countdown
- `Ctrl+Shift+V` → intercepted as `Ctrl+V` → triggers comparison toggle

## Root Cause

```rust
// Crossterm KeyModifiers is bitflags:
// Ctrl+C     = CONTROL
// Ctrl+Shift+C = CONTROL | SHIFT
// Ctrl+Alt+C   = CONTROL | ALT

key.modifiers.contains(KeyModifiers::CONTROL)
// Returns true for ALL of the above — subset match
```

## Solution

Use exact equality `==` instead of subset `contains()`:

```rust
// BEFORE — wrong, matches Ctrl+Shift+C
KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    // quit logic
}

// AFTER — correct, only matches bare Ctrl+C
KeyCode::Char('c') if key.modifiers == KeyModifiers::CONTROL => {
    // quit logic
}
```

## When to Use Which

| Check Type | Use For | Example |
|-----------|---------|---------|
| `== KeyModifiers::CONTROL` | Shortcuts with terminal conflicts | `Ctrl+C`, `Ctrl+V`, `Ctrl+D`, `Ctrl+L` |
| `.contains(KeyModifiers::CONTROL)` | Custom shortcuts with no conflicts | `Ctrl+B`, `Ctrl+M`, `Ctrl+A`, `Ctrl+T` |

## OpenShark Fix (2026-05-30)

**File:** `src/tui/mod.rs`, lines 908 and 962

```rust
// Line 908 — quit on double-tap Ctrl+C
KeyCode::Char('c') if key.modifiers == KeyModifiers::CONTROL => {
    let now = Instant::now();
    let within_window = app.last_ctrl_c.map(|t| now.duration_since(t).as_secs() < 2).unwrap_or(false);
    // ... double-tap logic
}

// Line 962 — toggle comparison mode
KeyCode::Char('v') if key.modifiers == KeyModifiers::CONTROL => {
    app.show_comparison = !app.show_comparison;
    app.comparison_selected = 0;
}
```

## Testing

1. Run OpenShark TUI
2. Press `Ctrl+Shift+C` — should NOT trigger quit message, should copy to clipboard (via Kitty)
3. Press `Ctrl+Shift+V` — should NOT toggle comparison, should paste from clipboard
4. Press `Ctrl+C` twice within 2 seconds — should quit OpenShark
5. Press `Ctrl+V` — should toggle comparison mode

## Related

- `shark-language` skill — TUI keybinding section
- Crossterm docs: `crossterm::event::KeyModifiers`
