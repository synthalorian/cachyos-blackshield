---
name: openshark-tool-calling
description: >
  Fix and maintain native OpenAI-compatible tool calling in OpenShark.
  Covers tool_call_id threading, empty content handling, and JSON-to-flat-args
  conversion for all built-in tools.
triggers:
  - OpenShark tool calling errors
  - tool_call_id is not found
  - must not be empty assistant message errors
  - Native function calling with fs/git/terminal/search tools
  - Model outputs JSON args but tool expects flat strings
---

# OpenShark Native Tool Calling Fix Guide

## The Three Failure Modes

When OpenShark uses native OpenAI function calling (request.tools = Some(...)), three distinct API errors can occur. All three must be fixed together.

### 1. tool_call_id is not found (400 Bad Request)

**Root cause:** The Message struct is missing tool_call_id and tool_calls fields. When the model makes a tool call and OpenShark sends the result back, the API cannot match the tool result to the original call.

**Fix in src/providers/mod.rs:**
- Add tool_call_id: Option<String> to Message
- Add tool_calls: Option<Vec<ToolCallRequest>> to Message
- Add ToolCallRequest and ToolCallFunction structs
- Update build_chat_body() to serialize these fields into the JSON payload
- Update ALL Message { ... } constructions across the codebase to include the new fields

**Critical:** The assistant message that initiates the tool call MUST include tool_calls array with the id. The tool result message MUST include tool_call_id matching that id.

### 2. must not be empty assistant message (400 Bad Request)

**Root cause:** When the model only outputs a tool call (no text), full_content is "". The API rejects empty string content on assistant messages, even when tool_calls is present.

**Fix in src/providers/mod.rs — build_chat_body():**
```rust
let content = if m.role == "assistant" && m.content.is_empty() && m.tool_calls.is_some() {
    serde_json::Value::Null
} else {
    m.to_openai_content()
};
```

The assistant message MUST have content: null (not "") when it only contains tool_calls.

### 3. Tool receives JSON but expects flat string args

**Root cause:** OpenShark's built-in tools (fs, git, terminal, search, etc.) were designed for flat-string args like "list /home". The model's native function calling sends JSON like {"operation": "list", "path": "/home"}.

**Fix:** Add a universal converter json_args_to_flat() in src/tools/mod.rs that handles all built-in tools, converting their JSON schemas to the flat string format each tool expects. Use it in the TUI where StreamChunk::ToolCall is handled.

## Files Modified

| File | What changed |
|------|-------------|
| src/providers/mod.rs | Added tool_call_id, tool_calls, ToolCallRequest, ToolCallFunction; updated build_chat_body() to serialize them; emit null for empty assistant content |
| src/tui/mod.rs | Capture id from StreamChunk::ToolCall; build assistant message with tool_calls; build tool result with tool_call_id; use json_args_to_flat() |
| src/tools/mod.rs | Added json_args_to_flat() universal converter |
| src/tools/fs.rs | Added JSON parsing fallback in execute() |
| src/gateway/channel_state.rs | Added tool_call_id/tool_calls to Message constructions |
| src/gateway/message_router.rs | Added tool_call_id/tool_calls to Message constructions |
| src/agent/mod.rs | Added tool_call_id/tool_calls to Message constructions |
| src/swarm/agent_runner.rs | Added tool_call_id/tool_calls to Message constructions |

## Verification

After all fixes:
```bash
cd /home/synth/projects/openshark
cargo build --release
cp target/release/openshark ~/.local/bin/openshark
```

Test with a tool call like `fs /home/synth/projects` — it should list the directory without errors.

## Pitfalls

- **Do not forget Message constructors:** Message::text() and Message::with_image() must also set tool_call_id: None and tool_calls: None
- **Tests too:** Unit tests that construct Message { ... } directly need the new fields
- **Kimi vs OpenAI:** Both enforce content: null (not "") for assistant messages with tool_calls
- **Install path:** The live binary is ~/.cargo/bin/openshark — `cargo build` alone does NOT update it. Always finish with `cargo install --path . --force` (in ~/Projects/active/openshark). If install fails with "Text file busy", pkill -f openshark first.

## Pitfalls added 2026-07-24 (edit tool + success flags + chat flow)

- **edit replace needs the ` ||| ` delimiter:** `replace_in_file` splits args on `" ||| "`. Any normalizer emitting `replace <path> <old> <new>` without ` ||| ` ALWAYS lands on the usage error. Correct form: `replace <path> <old> ||| <new>`.
- **K3 sends `{"operation":"write","file":...,"new_string":...}`:** the normalize_tool_args "edit" arm must map operation+file/path+content/new_string to `edit <read|write|replace> ...` CLI syntax, or raw JSON hits the parser → "Unknown edit command". If the model loops on edit failures, check this arm first.
- **Ok(String) ≠ success:** most tools return usage/parse failures as `Ok("Usage: ...")`. Anywhere `success: true` is hardcoded on Ok results (harness/engine.rs, tui/chat.rs) the tool_calls DB table lies. Use `tools::tool_output_indicates_failure(&output)` (prefix heuristic) before setting success.
- **execute_tool_call has no timeout by default:** a stuck tool (terminal waiting on stdin) wedges the turn with is_streaming=true forever. Harness wraps execution in spawn_blocking + tokio::time::timeout; the timeout is `[autonomy] tool_timeout_secs` in config.toml (default 600, 0 = unlimited). The TUI stall watchdog is `[autonomy] stream_stall_timeout_secs` (default 900, 0 = never reset). Approval prompts auto-approve on timeout when `[autonomy] enabled = true` (else they skip after approval_timeout_secs).
- **Mouse selection relies on DragStart:** if click-drag doesn't highlight, check translate_mouse_event — Down(Left) must emit DragStart (not ChatClick), and the event loop's DragEnd handler does copy-on-release via extract_rectangular_text + arboard. Plain click (no drag) falls back to click-to-scroll.
- **git tool is cwd-bound by default:** every command runs in the process cwd unless args start with `--repo <path>`. Model JSON `{"command":...,"repo":"/path"}` normalizes to that prefix. "Not a git repository" in a sandbox folder means the model forgot repo=.
- **Silent deaths need openshark.log:** the TUI alt-screen swallows stderr. Panic hook + harness error paths write to ~/.local/share/openshark/openshark.log — check it FIRST when a turn dies mid-flight. memory.db tool_calls/messages tables are the second source.
- **Empty assistant reply = turn completed but model returned no content** (often after burning max_tool_loops=10 on repeated tool failures). Symptom: chat goes idle with no error, no crash log. Check last assistant message in memory.db — empty string confirms it.

## Pitfalls added 2026-07-27 (normalizer arm coverage — the "protocol test" sweep)

A full-toolcall sweep by K3 exposed that normalize_tool_args (src/tools/mod.rs) silently passes raw JSON through when an arm is missing/mismatched, and the tool then prints usage/errors. Fixed arms — keep these in sync when adding tools:

- **Arm name MUST equal Tool::name(), not the schema key:** `"web_search"` arm/schema existed but the tool is `"web"`; `"home_assistant"` vs tool `"homeassistant"`. Both were dead arms — every call fell to the default `get_str("args")` or leaked raw JSON (web searched DDG for the literal JSON string → "No results found").
- **browser:** tool only accepts `--navigate/--snapshot/--click/--type`. Never emit `{action} {url}` ("visit https://..." → usage error). Map visit/goto/open/extract → --navigate.
- **spotify:** no `search`/`next`/`previous` subcommands — only --play/--pause/--resume/--queue/--now-playing. search maps to --play.
- **memory:** schema used `query` for both add and search; arm must accept content/query/text and map action→--add/--search/--list.
- **session_search:** needs its own arm (`query [--limit n]`) — sharing memory's arm leaked raw JSON as the query.
- **android:** schema is a single `command` string ('<category> <operation> <args>') — passthrough; raw JSON becomes the category → "Unknown category: {\"command\":...".
- **code_execution:** emit BARE code only. The tool runs python3 on the whole arg string; a "python <code>" prefix lands in the temp file. Also fixed in execution.rs: chained `.strip_prefix("python").unwrap_or(code).strip_prefix("Python").unwrap_or(code)` RESURRECTS the original string when the second strip fails (unwrap_or falls back to the pre-strip `code`) — strip once with or_else, and word-boundary guard (`"python "`/`"python\n"`) so `python_version = ...` isn't mangled.
- **Whole-string-query tools (web, x_search):** never append flags like `--limit` in the normalizer — the tool treats the entire arg string as the query, flags become search terms.
- **Failure heuristic:** Ok-result soft failures now also caught: "No FAL_KEY", "No test framework detected", "No Python code provided", "No session database found", "No results found".
- **Regression tests live in normalize_tests** (src/tools/mod.rs) — one test per observed failure, tagged "2026-07-27 protocol-test regressions". Run: `cargo test --bin openshark normalize_tests` (no lib target; use --bin).
- **Live-debug tip:** `sqlite3 ~/.local/share/openshark/memory.db "SELECT tool_name, success, args, result FROM tool_calls ORDER BY created_at DESC LIMIT 15;"` shows exactly what the model sent vs what the tool returned — fastest way to spot normalizer gaps.

## Pitfalls added 2026-07-27 (LSP tool)

- **"Failed to start LSP server: <cmd>" almost always means the binary is not installed**, not a crash. The detect_server tables (THREE copies: src/lsp/manager.rs, src/tools/lsp.rs, src/tools/refactor.rs) name pylsp / typescript-language-server / gopls / rust-analyzer / clangd — check `which <cmd>` before reading any LSP code.
- Both spawn sites (sync `LspClient::start` in src/lsp/mod.rs, async `AsyncTransport::spawn` in src/lsp/transport.rs) now pre-flight via `ensure_lsp_server()` → actionable error "LSP server 'X' is not installed... Install: <cmd-specific hint>". When adding a server to a detect table, also add its hint to `lsp_server_install_hint()` — a test enforces coverage.
- **Install without sudo:** `pip install --user --break-system-packages python-lsp-server` puts pylsp in ~/.local/bin (on PATH). pipx is NOT installed on this machine.
- LSP tool is cwd-rooted (`LspClient::start(cmd, args, ".")` / global manager root ".") — hover/def on files outside the process cwd tree may return empty results even with the server running.
- **THE sync-LSP wedge (fixed 2026-07-27):** `LspClient::read_response` read the body via `stdout.get_mut().read_exact()` — bypassing the BufReader that had already swallowed headers+body into its user-space buffer. read_exact then blocked forever waiting for data already consumed → every sync LSP call wedged until the harness 120s timeout ("Tool 'lsp' timed out after 120s", pylsp idle). NEVER mix BufReader reads with raw-fd reads on the same pipe — always read the body through the same BufReader. Same fix added EOF bail (read_line Ok(0) used to spin the header loop forever) and expected-id matching (pylsp interleaves publishDiagnostics before the real response; the old code returned the notification as the "result" → phantom "No hover information found").
- **Repro pattern for LSP protocol bugs:** hand-drive the server with a small Python probe speaking Content-Length framing (see /tmp/lsp_check/probe_*.py pattern) — if the probe works but Rust hangs, the bug is in Rust I/O, not the server. Live Rust repros: `cargo test --bin openshark lsp_live -- --include-ignored --nocapture` (needs pylsp on PATH).
- **Memory-context injection must sanitize roles (fixed 2026-07-27):** harness/engine.rs `get_relevant_memory` results were pushed into the request with their ORIGINAL role but tool_call_id: None. Any remembered role="tool" message (e.g. an old "Tool 'lsp' timed out" row) in the semantic/keyword search results → 400 "tool_call_id is not found" on the FIRST API call of the turn → headless turn dies instantly and the model never runs tools. Skip tool/function roles; coerce unknown roles to "user". Symptom: fresh headless run re-logs old session messages and dies with a 400 within a second of startup.
- **Headless history confusion:** headless runs inject memory matches that LOOK like replayed history in the messages table (old user/assistant/tool rows get fresh timestamps). Don't mistake them for live traffic — check tool_calls for rows stamped during the run to see what actually executed.
- **rust-analyzer is a rustup PROXY:** `which rust-analyzer` passes even when the component is missing — the shim prints "Unknown binary 'rust-analyzer' in official toolchain" to stderr and exits → sync client EOF. Fix on machine: `rustup component add rust-analyzer`. LspClient now pipes stderr into a 4KB ring buffer and quotes it in the EOF error, so a dying server self-diagnoses.
- **rust-analyzer needs a cargo project for semantics:** bare .rs "detached files" get no hover/definition — scratch-file tests will report "No hover information found" even when everything works. Also -32801 (ContentModified) is transient during startup (r-a reloads the file from disk and bumps its version) — retry, don't fail.
- **Live LSP tests are self-contained:** lsp_live_tests write their own scratch dirs under temp_dir (lsp_check_py, lsp_check_rs with Cargo.toml). Never point them at a shared /tmp path — a cleanup pass WILL delete it and the tests fail with os error 2.