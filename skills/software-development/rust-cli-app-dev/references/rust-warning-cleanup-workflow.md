# Systematic Rust Warning Cleanup Workflow

Session: 2026-05-30. Cleaning 42 compiler warnings down to 0 in OpenShark v1.0 push.

## Three-Tier Approach

### Tier 1: Automated Fixes (`cargo fix`)

```bash
cargo fix --bin "openshark" -p openshark --allow-dirty
```

This handles ~30% of warnings automatically:
- Unused imports
- Unused mut
- Unnecessary borrows
- `match_result_ok` → direct match
- `sort_by` → `sort_by_key`

**Always run first** before manual work. Don't waste time on what the machine can fix.

### Tier 2: Version String Centralization

Hardcoded version strings drift across the codebase. Centralize them:

```rust
// src/main.rs
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
```

Then update all constructors that previously had `"0.1.0".to_string()`:
- `Config::default()`
- `Config::test_config()` helpers
- `Agent::infer_config()`
- `Router::test_config()`
- `McpProtocol::client_info.version`
- TUI sidebar version display

Use `crate::VERSION.to_string()` everywhere. This ensures `--version`, TUI banner, and config all stay in sync.

### Tier 3: Intentional Dead Code Marking

For scaffolded APIs that will have callers in the future, use `#[allow(dead_code)]` with a comment explaining the planned consumer:

```rust
/// Platform abstraction types — will be used when consolidating
/// Discord/Telegram/Slack/Matrix into unified gateway architecture.
#[allow(dead_code)]
pub enum PlatformEvent { ... }

/// Transport method for SSE streaming — will be wired when
/// we add async notification handling to MCP connections.
#[allow(dead_code)]
fn start_message_stream(...) { ... }
```

**Rule of thumb:** If the code has a clear future purpose and removing it would require re-implementing later, mark it. If it's genuinely obsolete, remove it.

## Common Warning Categories and Fixes

| Warning | Fix Strategy |
|---------|-------------|
| `unused import` | `cargo fix` or remove manually |
| `unused variable` | Prefix with `_` or remove |
| `variable does not need to be mutable` | `cargo fix` |
| `dead_code` (scaffold) | `#[allow(dead_code)]` + comment |
| `dead_code` (obsolete) | Delete the code |
| `method never used` | Check if trait method — if so, `#[allow(dead_code)]` on impl |
| `variant never constructed` | If enum is event type, `#[allow(dead_code)]` on enum |
| `trait never used` | If planned for future, `#[allow(dead_code)]` |
| `async fn not permitted in Rust 2015` | **FALSE POSITIVE** — linter bug. Trust `cargo check` |

## The "Rust 2015" Linter False Positive

The standalone linter in `write_file`/`patch` incorrectly flags `async fn` as "not permitted in Rust 2015" even when `edition = "2024"` is set in `Cargo.toml`.

**Rule:** Always verify with `cargo check`. Never trust the standalone linter for edition-related errors. The linter runs without `--edition` context.

## Verification Workflow

```bash
# 1. Automated fixes
cargo fix --allow-dirty

# 2. Check remaining
cargo check 2>&1 | grep "warning:" | wc -l

# 3. Manual cleanup — iterate on remaining warnings
#    - Add #[allow(dead_code)] to intentional scaffolds
#    - Remove genuinely obsolete code
#    - Fix real issues (unused vars, unnecessary mut)

# 4. Verify clean
cargo check 2>&1 | grep "warning:" | wc -l  # should be 0

# 5. Verify tests still pass
cargo test

# 6. Verify release build
cargo build --release
```

## Feature Gating Optional Dependencies

For heavy optional dependencies (e.g., `matrix-sdk`, `slack-morphism`), gate them behind feature flags:

```toml
[features]
default = ["discord", "telegram"]
discord = []
telegram = []
slack = []
matrix = []

[dependencies]
matrix-sdk = { version = "0.17", optional = true }
slack-morphism = { version = "2.22", optional = true }
```

This removes the dependency from default builds, eliminating warnings from unused scaffold code in those modules.
