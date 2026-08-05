# Rust Subprocess CLI Resolution from Flutter-Spawned Backend

## The Problem

When a Flutter app spawns a Rust backend binary via `Process.start()`, the child
process inherits NO shell PATH when `runInShell: false` (the default). If the
Rust backend then calls `Command::new("hermes")` (or any other CLI tool), it
will fail with "command not found" — even though the tool works fine in a
terminal.

The error is SILENT from Flutter's perspective. The Rust code catches the
`io::Error` and typically sends back an SSE error event like
`{"error":"hermes command failed"}` or just logs and continues. The Flutter
SSE parser ignores events without a `"content"` key, so the user sees a chat
bubble with nothing in it.

## Symptom Triage

Silent empty responses during chat in a Flutter↔Rust↔CLI chain:

1. **Check health endpoint** — does the backend report `hermes_installed: true`?
   ```bash
   curl http://127.0.0.1:9120/health
   ```
   If `false` but `hermes` works in your terminal, it's a PATH/env issue.

2. **Check the backend stderr** — the Rust backend logs errors to stderr.
   Read them from the process output or check `~/.hermes/logs/agent.log`.

3. **Test the chat endpoint directly**:
   ```bash
   curl -s --max-time 30 -N "http://127.0.0.1:9120/chat/stream?message=hello"
   ```
   If this returns an error event, the backend can't invoke `hermes`.

## Two Fix Approaches

### Approach A: Pass PATH from Flutter (Quick)

In `main.dart`, add `PATH` to the backend's environment:

```dart
_process = await Process.start(binary, [],
   environment: {
     'HOME': Platform.environment['HOME'] ?? '/tmp',
     'PATH': Platform.environment['PATH'] ?? '/usr/local/bin:/usr/bin:/bin',
   },
);
```

**Pros**: One-line change, works for every CLI tool the backend spawns.
**Cons**: Depends on Flutter's environment being correct. Breaks on mobile
where no PATH exists.

### Approach B: Resolve Binary Path in Rust (Robust)

Write a helper that unconditionally resolves the CLI binary path using
`find_hermes_binary()` (or equivalent), then use the ABSOLUTE PATH in every
`Command::new()` call. The backend works regardless of how it was spawned.

**Add a caching layer** using `std::sync::OnceLock` so the binary is discovered
once and reused across all calls — avoids running subprocess (`which`) on
every request:

```rust
use std::sync::OnceLock;

/// Resolve the absolute path to the `hermes` binary, cached once.
fn hermes_binary_path() -> &'static str {
    static PATH: OnceLock<String> = OnceLock::new();
    PATH.get_or_init(|| {
        find_hermes_binary().unwrap_or_else(|| "hermes".to_string())
    })
}

/// find_hermes_binary() already checks:
/// 1. `which hermes` (PATH lookup)
/// 2. `~/.local/bin/hermes`
/// 3. `/usr/bin/hermes`, `/usr/local/bin/hermes`, `/opt/homebrew/bin/hermes`
fn find_hermes_binary() -> Option<String> {
    // Try `which hermes` first
    let from_path = Command::new("which").arg("hermes")
        .output().ok()
        .and_then(|o| {
            if o.status.success() {
                String::from_utf8(o.stdout).ok()
                    .map(|s| s.lines().next().unwrap_or("").trim().to_string())
            } else { None }
        });
    if from_path.is_some() { return from_path; }

    // Fallback: hardcoded paths
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    let paths = vec![
        format!("{}/.local/bin/hermes", home),
        "/usr/bin/hermes".into(),
        "/usr/local/bin/hermes".into(),
        "/opt/homebrew/bin/hermes".into(),
    ];
    paths.iter().find(|p| std::path::Path::new(p).exists()).cloned()
}
```

Then replace EVERY `Command::new("hermes")` with `Command::new(hermes_binary_path())`:

```rust
// In run_hermes():
fn run_hermes(args: &[&str]) -> Result<(String, String, i32), String> {
    let binary = hermes_binary_path();
    let output = Command::new(binary)
        .args(args)
        .env("PAGER", "cat")
        .output()
        .map_err(|e| format!("Failed to run hermes ({}): {}", binary, e))?;
    // ...
}

// In health endpoint:
let hermes_check = Command::new(hermes_binary_path()).arg("--version").output().ok();

// In gateway toggle:
Command::new(hermes_binary_path()).args(["gateway", "stop"])...
```

**Finding all bare `Command::new("hermes")` sites:**
```bash
grep -n 'Command::new("hermes")' backend/src/main.rs
```
Each one must be replaced with `Command::new(hermes_binary_path())`.

**Pros**: Works everywhere — desktop, mobile, CI, bare-metal spawns.
OnceLock caches the result so `which` only runs once.
**Cons**: Requires modifying every CLI-call site. OnceLock requires
`std::sync::OnceLock` (available since Rust 1.70), or use `once_cell::sync::Lazy`
on older editions.

## Flutter SSE Error Handling

When the backend sends error events (not just content events), the Flutter SSE
parser MUST surface them. The standard SSE event format from the backend uses
either `{"content":"..."}` for data or `{"error":"..."}` for errors.

**Fix**: Check BOTH keys in every SSE data event:

```dart
try {
  final json = jsonDecode(data) as Map<String, dynamic>;
  // Surface backend error events
  final error = json['error'] as String?;
  if (error != null && error.isNotEmpty) {
    buffer.write('\n[Error: $error]\n');
    // Update the UI immediately
  }
  // Normal content
  final content = json['content'] as String? ?? '';
  if (content.isNotEmpty) {
    buffer.write(content);
    // Update the UI immediately
  }
} catch (_) {}
```

Without this, errors are silently dropped (no `content` key → empty buffer →
empty chat bubble that looks like "sent but no reply").
