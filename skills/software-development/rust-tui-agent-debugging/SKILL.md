---
name: rust-tui-agent-debugging
description: >
  Debug Rust TUI agent apps that die silently mid-turn.
triggers:
  - TUI agent dies silently mid-turn
  - chat stops responding after a few messages
  - background task panic invisible
  - tool call recorded success but failed
  - stale version/model string in TUI
---

# Rust TUI Agent Debugging

Class-level playbook for debugging Rust terminal agent harnesses (chat loop + streaming + tool execution, crossterm/ratatui + tokio). Distilled from OpenShark sessions; applies to any similar agent app.

## 1. The alt-screen swallows stderr — log panics to a file FIRST

In a crossterm/ratatui alternate-screen app, `panic!` and `tracing` output in background tasks are invisible. Symptom: "it just died, no error anywhere."

Fix at startup, before anything else:
```rust
let default_hook = std::panic::take_hook();
std::panic::set_hook(Box::new(move |info| {
    debug_log(&format!("PANIC: {}", info)); // append to ~/.local/share/<app>/<app>.log
    default_hook(info);
}));
```
Also call the same logger at every async death point: JoinError branches, error paths before sending a Done event, and channel-closed-early detection. **Rule: if a background task can kill the user-facing loop, its failure must reach a file.** Do this before deep debugging — it converts guessing into reading.

## 2. SQLite session forensics — query ground truth, don't speculate

Agent apps persist sessions/messages/tool_calls. When the user says "it died" or "did it finish?", reconstruct from the DB:
- `sessions` — one row per launch (created at startup; an empty row with no messages = launched but unused)
- `messages` — user/assistant/system; tool results often stored as system "Result: ..." rows
- `tool_calls` — name, args, result, success, timestamp: the exact tool timeline

Pattern: find the latest session with actual messages, list its tool_calls ordered by time, then read the last 2-4 messages. The gap between last successful tool and last message is where the turn died.

## 3. Chat-flow death modes (check in this order)

1. **Stuck tool with no timeout** — sync tool execution (e.g. a subprocess waiting on stdin, `git commit` opening an editor) wedges the turn forever with `is_streaming=true`. Fix: wrap tool execution in `tokio::task::spawn_blocking` + `tokio::time::timeout` (120s), return a failure result so the turn continues.
2. **No submit guard** — user presses Enter mid-stream and the new spawn overwrites the stream receiver, orphaning the in-flight turn (events go nowhere, history lost). Fix: one-stream-at-a-time guard that hands the text back to the input box instead of swallowing it.
3. **No stall recovery** — hung HTTP / dead channel leaves `is_streaming=true` permanently. Fix: event-loop watchdog (e.g. 4 min) that resets streaming state and drops the receiver so the chat can never wedge for good.
4. **Provider 400s from malformed history** — assistant messages with `tool_calls` but no matching `tool`-role results (or empty-string content) make the API reject the NEXT turn. Verify message-chain integrity when turns die after tool use.
5. **Empty model follow-up treated as turn end** — after the last tool call, the model can return zero content chunks and zero tool calls with a "successful" stream. A tool loop that only breaks on `tool_calls.is_empty()` accepts the empty response as a completed turn: the UI saves an empty assistant message, `is_streaming` flips off, and from the user's view the agent "stopped mid-task" with no error anywhere (not even the debug log — the failure path never errored). Forensic signature: last DB row is an assistant message with `length(content)=0`, ~seconds after the final tool result. Fix: re-prompt once on empty follow-up (with a SystemMessage so the user sees it), and never persist empty assistant messages (also prevents mode-4 400s on the next turn).
5. **Empty follow-up treated as clean turn end** — after the last tool result, the harness re-queries the model; if that response has zero content chunks and zero tool calls, a naive loop breaks and emits Done with empty content. Symptom: streaming indicator turns OFF, an empty assistant message (length 0) lands in the DB seconds after the last tool result, no panic, no error log, app still alive — user reports "it stopped mid-task and no longer says streaming." Fix: in the tool loop, when a follow-up returns empty content AND no tool calls, re-prompt once with a nudge ("Your previous response was empty; using the tool results above, write a complete response..."); if still empty, surface a system message instead of silent Done. Also skip persisting empty assistant messages at the completion handler. When migrating from a legacy loop to a new engine path, diff the guard clauses — legacy paths often carry guards (empty-retry, stall watchdog) that silently get dropped in the rewrite.

## 4. Ok(String) ≠ success

CLI-style tools commonly return usage/parse failures as `Ok("Usage: ...")`. Hardcoding `success: true` on `Ok` results makes every analytics table lie. Fix: a conservative prefix heuristic (`tool_output_indicates_failure`) checked at result-recording sites — match only the START of output (`Usage:`, `Unknown `, `String not found`, `Failed to`, `fatal:`, `Not a git repository`) to avoid false positives from file contents.

Related: JSON-arg normalizers must emit the tool's exact CLI syntax (delimiters included — e.g. OpenShark's edit replace needs ` ||| `). A normalizer that produces almost-right syntax fails 100% of the time and sends the model into a retry loop. Add unit tests for each JSON shape the model actually emits.

## 5. Version stamps via build.rs (never hardcode date/commit)

Hardcoded `"2026.6.16"` / `"c9523d0"` strings go stale silently. Stamp at compile time, dependency-free:
```rust
// build.rs
fn main() {
    let hash = std::process::Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output().ok().filter(|o| o.status.success())
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string()).filter(|s| !s.is_empty())
        .unwrap_or_else(|| "unknown".into());
    println!("cargo:rustc-env=OS_GIT_HASH={hash}");
    println!("cargo:rerun-if-changed=.git/HEAD");
}
```
Use `env!("OS_GIT_HASH")` in the binary; same pattern for build date via `SystemTime`. Verify: `strings target/debug/<bin> | grep "$(git rev-parse --short HEAD)"`.

Same staleness pattern applies to splash/banner info (model, branch, dir, session id): pass a struct populated from live app state instead of string literals, and cross-check `Config::default()` against the user's live config — when they differ, the default is usually the fossil.

## 6. Verify the install, not just the build

`cargo build` / `cargo test` do NOT update the running binary. The dev loop for an installed CLI ends with `cargo install --path . --force` and a timestamp check on `which <bin>`. Reporting "fixed" from a successful build alone ships the user the same broken binary — a real user correction (2026-07-24); don't repeat it.

## 7. `?` in match arms returning Option

`?` can't be used when the enclosing function returns `String` but an arm builds `Option<String>`. Wrap the arm in an immediately-invoked closure:
```rust
"edit" => (|| {
    let file = get_str("file")?;
    Some(format!("read {}", file))
})(),
```
