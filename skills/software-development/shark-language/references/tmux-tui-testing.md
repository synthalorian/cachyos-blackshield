# Testing TUIs with tmux in Non-TTY Environments

**Session:** 2026-05-29

## The Problem

ratatui TUI apps require a terminal (TTY). Running them directly in a non-TTY environment (like a script or CI) fails with:
```
failed to initialize terminal: Os { code: 6, kind: Uncategorized, message: "No such device or address" }
```

## Solution: tmux as Pseudo-Terminal

Use tmux to create a detached session with a PTY, then interact with it programmatically.

### Basic Pattern

```bash
# Start TUI in detached tmux session
tmux new-session -d -s openshark-test -c /project/dir "./target/release/openshark"

# Wait for startup
sleep 1

# Send keyboard input
tmux send-keys -t openshark-test "test" Enter

# Wait for response
sleep 5

# Capture visible output
tmux capture-pane -t openshark-test -p | head -50

# Double Ctrl+C to quit (if app supports it)
tmux send-keys -t openshark-test "C-c" && sleep 1 && tmux send-keys -t openshark-test "C-c"

# Verify session died
sleep 1
tmux has-session -t openshark-test 2>/dev/null && echo "Still running" || echo "Killed"

# Clean up
tmux kill-session -t openshark-test 2>/dev/null
```

### Key Send Syntax

| Key | tmux send-keys syntax |
|-----|----------------------|
| Ctrl+C | `C-c` |
| Ctrl+L | `C-l` |
| Ctrl+B | `C-b` |
| Enter | `Enter` |
| Arrow Up | `Up` |
| Arrow Down | `Down` |
| Page Up | `PPage` |
| Page Down | `NPage` |

### Checking Session Status

```bash
# List all sessions
tmux list-sessions

# Check if specific session exists
tmux has-session -t openshark-test 2>/dev/null && echo "Running" || echo "Dead"
```

### Capturing Output with ANSI

The raw capture includes ANSI escape sequences. For human-readable output:
```bash
tmux capture-pane -t openshark-test -p | cat -v | head -40
```

Or strip ANSI:
```bash
tmux capture-pane -t openshark-test -p | sed 's/\x1b\[[0-9;]*m//g' | head -40
```

### Timing Considerations

- **Startup:** `sleep 1` after `new-session` before sending input
- **Model responses:** `sleep 5-8` for streaming LLM responses
- **Key delays:** `sleep 0.5-1` between Ctrl+C presses for double-tap quit
- **Too fast:** `sleep 0.3` between keypresses may be too quick for crossterm event polling

### Common Pitfalls

1. **Session name collision:** Kill existing session before creating new one:
   ```bash
   tmux has-session -t openshark-test 2>/dev/null && tmux kill-session -t openshark-test
   ```

2. **Binary not found:** Use absolute path or ensure binary is in PATH within tmux session:
   ```bash
   tmux new-session -d -s test -c /project/dir "./target/release/openshark"
   ```

3. **Output truncated:** `capture-pane` only gets visible content. For scrollback, use `-S` flag:
   ```bash
   tmux capture-pane -t test -S -100 -p  # last 100 lines
   ```

### Full Test Script Template

```bash
#!/bin/bash
set -e

SESSION="openshark-test"
PROJECT="/home/synth/projects/openshark"
BINARY="$PROJECT/target/release/openshark"

# Clean up any existing session
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Start TUI
tmux new-session -d -s "$SESSION" -c "$PROJECT" "$BINARY"
sleep 1

# Send test message
tmux send-keys -t "$SESSION" "test" Enter
sleep 6

# Capture output
tmux capture-pane -t "$SESSION" -p > /tmp/tui-test.log

# Verify response appeared
if grep -q "assistant" /tmp/tui-test.log; then
    echo "✅ TUI responded"
else
    echo "❌ No response found"
fi

# Quit
tmux send-keys -t "$SESSION" "C-c" && sleep 1
tmux send-keys -t "$SESSION" "C-c" && sleep 1

# Clean up
tmux kill-session -t "$SESSION" 2>/dev/null || true
```
