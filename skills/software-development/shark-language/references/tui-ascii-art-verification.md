# TUI ASCII Art Verification Checklist

Session: 2026-05-30. Fixing "DPEKFARK" → "OPENSHARK" in OpenShark TUI.

## The Problem

ASCII art that looks correct in a text editor can render as completely wrong letters in a terminal due to:
1. **Variable-width letters** — letters of different widths create misalignment
2. **Ambiguous shapes** — P vs B, E vs F, N vs H, S vs 5
3. **Font rendering differences** — some terminals compress horizontal spacing
4. **Block character width** — `█` (U+2588) may render at different widths than spaces

## The Fix: Fixed-Width Letters with Consistent Gaps

Each letter MUST be exactly the same width. Use 6-char wide letters with 2-space gaps:

```
O:  ████   P: █████   E: █████   N: ██  ██  S:  ████
   ██  ██     ██  ██     ██        ███ ██     ██
   ██  ██     █████      ████      ██ ███      ███
   ██  ██     ██          ██        ██  ██        ██
    ████      ██          █████     ██  ██     ████

H: ██  ██   A:  ███    R: █████   K: ██  ██
   ██  ██     ██ ██      ██  ██     ██ ██
   ██████     ██████     █████      ████
   ██  ██     ██  ██     ██ ██      ██ ██
   ██  ██     ██  ██     ██  ██     ██  ██
```

## Verification Steps

1. **Design each letter individually** — verify it reads correctly in isolation
2. **Assemble with consistent gaps** — 2 spaces between every letter
3. **Test in terminal** — `cat` the art and verify from a distance (squint test)
4. **Check in actual TUI** — build and run to see how ratatui renders it
5. **Verify both locations** — if art appears in multiple files, update ALL of them

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Variable letter widths | Letters merge or drift | Use fixed-width (6 chars) for all letters |
| Missing gap between letters | "OP" reads as "O" or "D" | Always 2+ spaces between letters |
| Ambiguous P shape | P reads as B or D | P must have open lower-right (only top half closed) |
| Ambiguous E shape | E reads as F | E needs 3 horizontal bars (top, middle, bottom) |
| Ambiguous N shape | N reads as H or M | N needs clear diagonal connecting top-left to bottom-right |
| Ambiguous S shape | S reads as 5 | S needs curves (top-right bulge, bottom-left bulge) |
| Ambiguous R shape | R reads as P | R needs diagonal leg going down-right from loop |
| Ambiguous K shape | K reads as N or X | K needs two diagonals meeting at center |

## File Locations for OpenShark Branding

| Element | File | Function ~ |
|---------|------|-----------|
| ASCII art welcome (TUI startup) | `src/tui/mod.rs` | `run()` ~675 |
| ASCII art (agent soul) | `src/agent/soul.rs` | `welcome_message()` ~130 |
| Sidebar header (name, version) | `src/tui/mod.rs` | `draw_sidebar()` ~1595 |
| Color detection for art | `src/tui/mod.rs` | `draw_chat_area()` ~1780 |
| Default greeting | `src/config/setup.rs` | `run()` ~58 |
| Default identity values | `src/config/mod.rs` | `AgentIdentity::default()` ~52 |

## Build Verification

After updating ASCII art:
```bash
cd /home/synth/projects/openshark
cargo install --path .  # Builds release + installs to ~/.local/bin
```

**Never use `cargo build --release` alone** — it drops the binary in `target/release/` which may not be the same as the binary in `PATH`. Always use `cargo install --path .` to ensure the installed binary matches the source.

## Session-Specific Notes

- Original broken art: `DPEKFARK` (P was wrong shape, E was misaligned, all subsequent letters drifted)
- Fixed art: `OPENSHARK` (all letters 6-wide, 2-space gaps, verified in terminal)
- Greeting also fixed: "Ready to build. What are we shipping today?" → "The grid is endless. What are we building?"
- Both files updated: `src/tui/mod.rs` AND `src/agent/soul.rs`
- Build command: `cargo install --path .` (not `cargo build --release`)
