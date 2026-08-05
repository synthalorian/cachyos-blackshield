# Session 2026-05-30: Security Gate Wiring + Autonomous Mode + Personalization

Complete implementation session making OpenShark bulletproof for coding tasks.

## What Was Done

### 1. PII Test Fix
- `test_detect_api_key` was failing — test key was 47 chars, regex requires `sk-[a-zA-Z0-9]{48}` (51 total)
- Fixed with proper 51-char key
- **Result:** 306 tests passing (was 305)

### 2. Security Gate Wired Into All 5 Paths

| Path | File | Function | Change |
|------|------|----------|--------|
| 1 | `tui/mod.rs` | `handle_user_tool_invocation()` | Check before `find_tool()`, sanitize output, audit |
| 2 | `tui/mod.rs` | `stream_model_response_task()` | Create `SecurityEngine` in bg task from `SecurityConfig::load()` |
| 3 | `tui/mod.rs` | `execute_tool_suggestion()` | Check before executor, sanitize, audit |
| 4 | `agent/mod.rs` | `execute_single_step()` | Added `security_engine: &SecurityEngine` param |
| 5 | `tui/mod.rs` | `stream_model_response_task()` | Fresh `SecurityEngine` in spawned task |

**Key pattern:** `App` can't be moved to background tasks (non-Send `MemoryStore`). Solution: reconstruct `SecurityEngine` from config in the background task. `SecurityEngine` itself is `Send` via `Arc<Mutex<...>>`.

### 3. CODING MODE Defaults

Changed `SecurityConfig::default()` to `Allow` for all coding tools:
```rust
tool_permissions.insert("fs".to_string(), PermissionLevel::Allow);
tool_permissions.insert("terminal".to_string(), PermissionLevel::Allow);
tool_permissions.insert("edit".to_string(), PermissionLevel::Allow);
tool_permissions.insert("refactor".to_string(), PermissionLevel::Allow);
// git, search, test, lsp already Allow
```

Only risk assessment (based on command content) and hard blocks (sudo, sensitive paths, PII) gate execution.

### 4. Autonomous Mode Toggle

- Added `autonomous_mode: bool` to `App` struct
- `Ctrl+A` toggles in `handle_input()`
- Added `check_tool_call_with_mode(tool, args, autonomous_mode)` to `SecurityEngine`
- When enabled: risk threshold elevates `Medium` → `High`
- **Never** bypasses sudo, sensitive paths, or PII
- Status message confirms mode change

### 5. Personalized Chat Names

- Added `user_name: String` to `Config` struct with `#[serde(default)]`
- Setup wizard asks: "Your name/username:"
- TUI shows `user_name` instead of "user", `agent.display_name` instead of "assistant"
- Streaming indicator uses agent display name
- **Cascading fix:** Added `user_name` to ALL test helper `Config` constructors across router, self_improve, agent modules

### 6. MAX_ITERATIONS = 50

Changed from 888 (liability for runaway loops) to 50 (~5 plan steps + retries + recovery).
- Updated const in `agent/mod.rs`
- Updated test assertion

### 7. Test Isolation Bug Fix

`test_blank_soul` was flaky in parallel execution — `std::env::set_var("SOUL_NAME", "blank")` polluted other tests.
- Fixed by clearing env var at test start: `std::env::remove_var("SOUL_NAME")`

## Files Modified

| File | Lines Changed | What |
|------|--------------|------|
| `src/security/pii.rs` | ~2 | Fixed test key length |
| `src/security/mod.rs` | ~30 | CODING MODE defaults; `check_tool_call_with_mode()` |
| `src/tui/mod.rs` | ~60 | `security_engine` + `autonomous_mode` fields; wiring in 3 paths; Ctrl+A; personalized names |
| `src/agent/mod.rs` | ~25 | `security_engine` field; `MAX_ITERATIONS` 888→50; param in `execute_single_step()` |
| `src/agent/soul.rs` | ~3 | Test isolation fix |
| `src/config/mod.rs` | ~15 | `user_name` field; default; test config |
| `src/config/setup.rs` | ~10 | User name prompt |
| `src/router/mod.rs` | ~5 | `user_name` in test configs |
| `src/self_improve/mod.rs` | ~3 | `user_name` in test config |

## Test Status

- **306/306 passing** after all changes
- `cargo check` clean
- `cargo test` clean

## Key Decisions

1. **SecurityEngine in background tasks:** Reconstruct from config, don't pass from App
2. **CODING MODE:** All tools Allow by default. Only content-based risk assessment blocks.
3. **Autonomous mode:** Runtime toggle, not config change. Elevates threshold only.
4. **MAX_ITERATIONS 50:** Realistic cap. User accepted after discussion.
5. **Personalized names in Config:** Persisted to config file, survives restarts.

## User Frustration Signal

User asked "are you actually doing anything?" during planning phase — immediate pivot to execution. Captured in `concise-implementation` skill as anti-pattern.

## Next Session Priority

1. Native Discord/Platform Gateway (serenity crate) — replace Hermes bridge
2. Native MCP Client — stdio + SSE transport, tool discovery
3. Multi-model chats — polish `/multi` toggle (last priority)
