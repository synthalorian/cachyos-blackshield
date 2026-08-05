# OpenShark Forensics Recipes (sessions 2026-07-24, 2026-07-25)

Concrete queries and file locations for debugging OpenShark sessions. Class-level patterns live in ../SKILL.md; this is the OpenShark-specific detail.

## Files

- `~/.local/share/openshark/memory.db` — sessions/messages/tool_calls (ground truth for "what did the agent do")
- `~/.local/share/openshark/openshark.log` — panic hook + stream-death log (READ FIRST on silent death)
- Repo: `/home/synth/Projects/active/openshark` — live binary `~/.cargo/bin/openshark` (install: `cargo install --path . --force`; tests: `cargo test --quiet --bin openshark`, no lib target)

## memory.db schema (relevant tables)

- `sessions(id, started_at, model, project_path)` — one row per launch, may be empty
- `messages(id, session_id, role, content, created_at)` — tool results stored as role='system', "Result: ..." content
- `tool_calls(id, session_id, tool_name, args, result, success, created_at)` — success flag HONEST since 2026-07-24 (tool_output_indicates_failure heuristic)

## Queries

```bash
# Latest sessions
sqlite3 ~/.local/share/openshark/memory.db \
  "SELECT id, started_at, model FROM sessions ORDER BY started_at DESC LIMIT 5;"

# Tool timeline for a session
sqlite3 ~/.local/share/openshark/memory.db \
  "SELECT tool_name, success, substr(replace(result,char(10),' | '),1,100)
   FROM tool_calls WHERE session_id='<id>' ORDER BY created_at;"

# Last messages (where did the turn die?)
sqlite3 ~/.local/share/openshark/memory.db \
  "SELECT role, substr(replace(content,char(10),' '),1,150)
   FROM messages WHERE session_id='<id>' ORDER BY created_at DESC LIMIT 4;"
```

## Death modes logged to openshark.log

- `PANIC: ...` (panic hook in main.rs)
- `stream_model_response_task harness error: ...`
- `stream_model_response_task PANIC: ...`
- `stream channel closed while is_streaming=true (background task died without sending Done)`

NOTE: if openshark.log does NOT exist at all, no panic/harness error ever fired — the turn "completed cleanly" from the code's perspective. That's the signature of death mode 5 below, not a crash.

## Diagnostic signature: empty follow-up ends turn (2026-07-25)

Symptom: streaming indicator turns off mid-task, no error, app still running. DB shows:
- tool_calls all succeed through time T
- final row in messages is role='assistant' with `length(content)=0`, timestamped ~10s after T (the follow-up request round-trip)

Root cause located: `src/harness/engine.rs run_turn_streaming` — the tool loop breaks when a follow-up has no tool calls, without checking whether `follow_content` is empty. Empty string flows through `HarnessEvent::FollowUp("")` → forwarder sends `StreamEvent::ResponseComplete{content:""}` → `src/tui/stream.rs` ResponseComplete handler saves the empty assistant message unconditionally. The LEGACY path (`src/tui/mod.rs stream_model_response_task_legacy`, ~line 4226) has an empty-follow-up re-prompt guard; the harness engine path that replaced it does not.

Forensic discriminators:
- Provider-layer failures surface as INLINE content chunks: `[API error N: ...]`, `[stream error: ...]`, `[⏱ Stream timed out...]`. A genuinely EMPTY saved message means the HTTP request succeeded and the stream ended "normally" with zero content chunks — none of the error paths fired.
- The `messages` table has NO reasoning column, so reasoning-only model responses (reasoning model emits reasoning, then stops with no content) are indistinguishable from truly empty responses in the DB. To tell them apart you'd need provider-side logging; the finish_reason is not persisted either.
- Fix proposed (not yet applied as of 2026-07-25): port the legacy empty-follow-up re-prompt into the engine.rs tool loop + skip persisting empty assistant messages in stream.rs.

## Fixed-in-this-session catalog (2026-07-24)

1. Splash banner hardcoded model "kimi-k2.7-code" → SplashInfo from live App state; version via build.rs stamp
2. edit normalizer: {"operation":"write|patch|replace"} JSON → CLI with ` ||| ` delimiter
3. Ok(String) success lie → tool_output_indicates_failure heuristic in harness + chat.rs
4. Mouse selection dead (Down→ChatClick) → Down→DragStart, copy-on-release via arboard
5. Chat wedge: 120s tool timeout, busy submit guard, 4-min stall watchdog
6. Dead K2-era defaults: kimi-k2.6→k3, local proxy 127.0.0.1:8699→direct api.kimi.com/coding/v1
