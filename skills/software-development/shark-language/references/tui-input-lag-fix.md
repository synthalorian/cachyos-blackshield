# ratatui TUI Input Lag Fix

## Problem

User reports typing feels delayed / sluggish in a ratatui-based TUI application.

## Root Cause

The event loop uses `crossterm::event::poll(timeout)` with a long `TICK_RATE`:

```rust
const TICK_RATE: Duration = Duration::from_millis(250);
```

This means the loop only checks for keyboard input every 250ms. Every keystroke sits in the buffer for up to a quarter second before being processed.

## Fix

Reduce `TICK_RATE` to ~16ms (60fps):

```rust
const TICK_RATE: Duration = Duration::from_millis(16); // ~60fps for responsive input
```

Location: typically in `src/tui/mod.rs` or the main event loop file, near the top with other constants.

## Verification

After rebuild, typing should feel instant. The cursor should track keystrokes in real time with no perceptible delay.

## Trade-offs

- **CPU usage**: Higher poll rate means more frequent wakeups. On battery-powered devices, 16ms may drain slightly faster than 250ms. For a coding harness that runs plugged-in, this is negligible.
- **Alternative**: Use `crossterm::event::read()` (blocking) instead of `poll()` for zero-latency without busy-waiting. But this requires restructuring the event loop to handle async tasks (streaming responses, timers) via channels rather than polling.

## Related

- `references/tui-layout-patterns.md` — Other ratatui TUI fixes
