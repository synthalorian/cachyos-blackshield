---
name: rust-workspace-troubleshooting
description: >
  Troubleshoot Rust workspace compilation errors — edition 2024 const changes,
  rusqlite API incompatibilities, orphan rule violations, type inference gaps,
  and Send/Sync bounds. Covers patterns discovered while fixing the open_habit
  workspace but applies to any Rust project.
version: 1.0.0
category: devops
tags: [rust, cargo, workspace, compilation, troubleshooting]
---

# Rust Workspace Troubleshooting

Load when `cargo build` or `cargo test` fails with compilation errors across workspace crates. Covers edition-specific issues, library API changes, and cross-crate trait impl constraints.

## Common Failure Patterns

### 1. Edition 2024 Const Fn Limits

**Symptoms:** `cannot call conditionally-const method ... in constant functions`, `Ord is not yet stable as a const trait`

Edition 2024 (and stable Rust pre-2024) doesn't allow `.min()`, `.max()`, or `.powi()` in `const fn` because `Ord` and float methods aren't stable in const contexts.

**Fix:** Drop `const` and extract the operations:

```rust
// ❌ BROKEN:
pub const fn xp_for_level(level: u32) -> u32 {
    100 * (1u32 << (level.saturating_sub(1) as usize).min(25)) / (1 << 0).max(1)
}

// ✅ FIXED:
pub fn xp_for_level(level: u32) -> u32 {
    let shift = level.saturating_sub(1) as usize;
    let shift = shift.min(25);
    let divisor = 1u32.max(1);
    100 * (1u32 << shift) / divisor
}
```

### 2. Borrow-After-Move in Struct Initialization

**Symptoms:** `borrow of moved value: X ... value moved here ... value borrowed here after move`

When a struct field takes ownership of a value (`challenge_type` at position 348) but a later field tries to reference it (`match &challenge_type` at position 351), the value was already moved.

**Fix:** Clone the value where it's stored, or compute the derived field before the struct literal:

```rust
// ❌ BROKEN:
Self {
    challenge_type,
    target: match &challenge_type { ... },  // borrowed after move
}

// ✅ FIXED:
Self {
    challenge_type: challenge_type.clone(),
    target: match &challenge_type { ... },
}
```

### 3. Rusqlite 0.32 Breaking Changes

**Symptoms:** `this method takes 2 arguments but 1 argument was supplied` on `query_row`

**The API changed:** `query_row` now takes `(params, |row| { Ok(...) })` instead of returning a `Row` that you call `.get()` on.

```rust
// ❌ OLD (pre-0.32):
let row = stmt.query_row([])?;
let value = row.get::<_, u32>(0)?;

// ✅ NEW (0.32+):
self.conn.query_row(
    "SELECT total_xp FROM progression WHERE id = 1",
    [],
    |row| {
        Ok(PlayerProgression {
            total_xp: row.get(0)?,
            // ...
        })
    },
).map_err(|e| DBError::SQL(e))?
```

Also, `row.get(N)?` without a type annotation now infers `&str` from SQLite text columns instead of `String`. Explicit type annotation is required:

```rust
// ❌ Returns &str, not FromSql-compatible:
row.get(0)?

// ✅ Explicit String:
row.get::<_, String>(0)?
```

### 4. Orphan Rule Violations

**Symptoms:** `cannot define inherent impl for type outside of crate where type is defined`

You cannot `impl` a trait or inherent methods on a type defined in another crate (even in the same workspace).

```rust
// ❌ In db crate — XPSource is defined in shared crate:
impl XPSource {
    fn from_db(...) -> Self { ... }
}
```

**Fix:** Move the logic into a free function or inline it in the row parser:

```rust
// ✅ In db crate row parser:
let source = match source_type.as_str() {
    "HabitCompletion" => XPSource::HabitCompletion { habit_id: parse_uuid(&source_id).unwrap_or(Uuid::new_v4()) },
    // ...
};
```

### 5. Error Type Mismatch with ?

**Symptoms:** `'?': couldn't convert the error to DBError`, `the trait bound &str: FromSql is not satisfied`

The `?` operator requires `From<OtherError>` on your error type. `uuid::Error` and `chrono::ParseError` aren't covered.

**Fix A — Add From impl to your error enum:**
```rust
#[derive(Debug, thiserror::Error)]
pub enum DBError {
    #[error("database error: {0}")]
    SQL(#[from] rusqlite::Error),
    #[error("parse error: {0}")]
    Parse(String),
}
```

**Fix B — Use .map_err():**
```rust
Uuid::parse_str(&s).map_err(|e| DBError::Parse(e.to_string()))?
```

### 6. rusqlite::Connection Is Not Send/Sync

**Symptoms:** `the trait bound Connection: Send is not satisfied`, `cannot be shared between threads safely`, `required for Router<S>::new`

rusqlite's `Connection` holds internal SQLite state and is `!Send`. This means `Arc<RwLock<Database>>` cannot be used in axum's `Router<S>` which requires `S: Clone + Send + Sync + 'static`.

**Fix 1 — Channel-based client pattern (recommended for single-connection setups):**
Spawn a dedicated thread that owns the `Database` exclusively. Communicate via `mpsc` channels with command enums carrying response senders. See the pattern in the open_habit session — it creates a `DatabaseClient` struct with methods like `list_habits()`, `create_habit()`, etc., each of which sends a command and blocks on the response channel.

**Fix 2 — For web APIs: spawn_blocking with Mutex:**
Use `Arc<tokio::sync::Mutex<Database>>` on a single-threaded tokio runtime. Wrap each DB call in `tokio::task::spawn_blocking(move || { ... })`.

**Fix 3 — Connection pooling:** Use `r2d2` or `deadpool-rusqlite`. Best for production, overkill for local-first apps.

**Fix 4 — For TUI apps: move memory ops to main thread, spawn only the HTTP call:**
When a ratatui TUI needs to call an API but the `App` struct holds a `MemoryStore` (which contains `rusqlite::Connection`), you can't pass the whole `App` to a `tokio::spawn` task. Instead:

1. Clone only `Send`-able fields (`Provider`, `String` configs, `Vec<Message>`) into the spawned task
2. Have the task send results back via `tokio::sync::mpsc::UnboundedSender<StreamEvent>`
3. Apply memory operations (saves, metrics, tool calls) in the main thread's event loop when draining the channel

```rust
// In process_user_input — returns immediately after adding user message:
let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
app.stream_rx = Some(rx);

let provider = app.provider.clone();  // Provider is Clone
let model = app.model.clone();
let model_messages = app.model_messages.clone();
// DO NOT clone app.memory — MemoryStore is !Send

tokio::spawn(async move {
    let _ = stream_model_response_task(tx, provider, model, ...).await;
});

// In run_app event loop — drain channel, apply to app:
if let Some(mut rx) = app.stream_rx.take() {
    while let Ok(event) = rx.try_recv() {
        app.apply_stream_event(event);  // memory ops happen here
    }
    app.stream_rx = Some(rx);
}
```

This pattern also solves the "user message doesn't appear until model finishes" problem — the event loop keeps running while the API call happens in the background.

## CLI Scope Bug

The CLI had `cmd_add` referencing `cli.database` out of scope. Fix: restructure handlers to take `&PathBuf` parameters and use a shared `open_db(path: &PathBuf) -> Database` helper. Each handler opens its own DB (fine for single-shot CLI commands).
4. **Then gamification** — Add missing dependencies (uuid, log) to Cargo.toml
5. **Then db** — This is where most errors cluster. Rewrite row parsers with explicit types.
6. **Server last** — Send/Sync issues are architectural, not simple fixes.
7. **Run `cargo test --workspace --exclude <broken-crate>`** — Verify what compiles works.

## CLI Compilation Quirk

The CLI crate (`open_habit_cli`) references `cli.database` out of scope in `cmd_add`. This is a pre-existing bug in the original scaffold that needs `cli.database` to be passed into the function or restructured to use a shared `open_db()` helper.

See `references/cli-scope-bug.md` for the exact line and fix.

### 7. Status String Case Mismatch in DB Queries

**Symptoms:** `list_habits` returns empty when `status` field is `"Active"` but query filters for `"active"`.

Rust's `format!("{:?}", enum_variant)` produces PascalCase (`"Active"`), not lowercase. SQL queries must match exactly:

```rust
// ✅ Must match the stored format:
let query = match status {
    Some(s) => format!("WHERE status = '{}'", s),
    None => String::from("WHERE status = 'Active'"),
};
```

### Diagnostic Commands

```bash
# Check which crates compile
cargo build --workspace 2>&1 | grep "^   Compiling\|^error:"

# Test only compiling crates
cargo test --workspace --exclude open_habit_server

# Find all FromSql-related errors
cargo build 2>&1 | grep "FromSql"

# Check Send/Sync trait requirements
cargo build 2>&1 | grep "Send\|Sync"

# Quick clippy scan (after build succeeds)
cargo clippy --workspace --exclude open_habit_server -- -D warnings
```

## Pre-Ship Clippy Hygiene

Before shipping any Rust project, `cargo clippy --all-targets --all-features -- -D warnings` must pass clean. These are the most common pre-ship clippy issues and their fixes:

### 1. `non_snake_case` Field Names

**Symptom:** `structure field 'hrv_rMSSD' should have a snake case name`

**Fix:** Rename to snake_case. Acronyms at the end of a name stay lowercase:
```rust
// ❌ BROKEN:
pub hrv_rMSSD: Option<f64>,
pub value_mg_dL: f64,

// ✅ FIXED:
pub hrv_rmssd: Option<f64>,
pub value_mg_dl: f64,
```

### 2. `needless_borrows_for_generic_args`

**Symptom:** `the borrowed expression implements the required traits` on `hex::encode(&nonce)`

**Fix:** Remove the borrow — the function takes `impl AsRef<[u8]>`:
```rust
// ❌ BROKEN:
hex::encode(&nonce)

// ✅ FIXED:
hex::encode(nonce)
```

### 3. `result_unit_err`

**Symptom:** `this returns a Result<_, ()>` — use a custom Error type instead

**Fix:** Define a small error enum:
```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CryptoError {
    DecryptionFailed,
}

impl std::fmt::Display for CryptoError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CryptoError::DecryptionFailed => write!(f, "decryption failed"),
        }
    }
}

impl std::error::Error for CryptoError {}

// Usage:
pub fn decrypt(&self, ...) -> Result<Vec<u8>, CryptoError> {
    // ...
    .map_err(|_| CryptoError::DecryptionFailed)?;
}
```

### 4. `unused_imports` in Test Modules

**Symptom:** `unused import: std::sync::Arc` in `#[cfg(test)] mod tests`

**Fix:** Remove the import. If the test module doesn't use `Arc` directly (the production code does), it doesn't need to be imported in tests.

### 5. `unused_imports` at Crate Root

**Symptom:** `unused import: std::sync::Arc` at the top of `main.rs`

**Fix:** Check if the import is actually used in non-test code. If only tests used it but tests were removed/refactored, delete the import.

### Quick Pre-Ship Clippy Fix Sequence

```bash
# 1. Auto-fix what clippy can handle
cargo clippy --fix --all-targets --all-features -- -D warnings

# 2. Check remaining issues
cargo clippy --all-targets --all-features -- -D warnings 2>&1 | grep "error\["

# 3. Manual fixes for the remaining (usually non_snake_case, result_unit_err)
# 4. Verify clean
cargo clippy --all-targets --all-features -- -D warnings
# Should output: Finished dev profile
```

## Cargo Fingerprint Cache False Positives

**Symptoms:** You edit source files, run `cargo build`, and it says `Finished` instantly with no recompilation. The binary doesn't reflect your changes.

**Root cause:** Cargo's fingerprint cache (`target/release/.fingerprint/`) can get out of sync with the actual source, especially after:
- Force-stopping builds (Ctrl+C during compilation)
- Switching git branches with different file contents
- Editing files while a build is in progress
- Using `cargo install --path .` after manual edits

**Fix:** Delete fingerprints and rebuild:

```bash
rm -rf target/release/.fingerprint/openshark* \
       target/release/deps/openshark* \
       target/release/openshark
cargo build --release
```

For workspace builds, use the crate name pattern:
```bash
rm -rf target/release/.fingerprint/<crate-name>* \
       target/release/deps/<crate-name>*
```

**Verification:** After the fix, `cargo build --release` should show `Compiling openshark v0.1.0` not `Fresh`.

## Install Path Mismatch

**Symptoms:** `cargo install --path . --force` succeeds but `which openshark` still shows an old binary. Or the binary behaves like the pre-edit version.

**Root cause:** `cargo install` puts binaries in `~/.cargo/bin/` by default, but the user's PATH may prioritize `~/.local/bin/` (or vice versa). The shell resolves the old binary first.

**Fix:** Check where the binary actually lives and copy to the right location:

```bash
# See which binary the shell finds
which openshark
# → /home/synth/.local/bin/openshark

# See where cargo installed it
ls ~/.cargo/bin/openshark

# Copy to the location the shell expects
cp target/release/openshark ~/.local/bin/openshark
```

**Best practice:** Don't rely on `cargo install` for local development. Build with `cargo build --release` and `cp` the binary to wherever your PATH expects it.

## Module-Level `#[allow(dead_code)]` Strategy

When cleaning up warnings in a Rust project, `cargo fix` handles ~30% automatically. For the rest, use a tiered approach:

1. **`cargo fix --bin <name> -p <pkg> --allow-dirty`** — auto-removes unused imports, unused mut
2. **Module-level `#![allow(dead_code)]`** — for entire modules with future-utility APIs (theme system, LSP client, security stubs)
3. **Targeted `#[allow(dead_code)]`** — on individual functions/structs/fields with planned consumers
4. **Remove truly dead code** — enums with no variants used, structs never constructed, functions with no callers and no future path
5. **Run `cargo test`** — some "dead" code is only used in tests

**Pitfall:** `#[allow(dead_code)]` on enums must be placed BEFORE `pub`, not after:
```rust
// WRONG — breaks compilation
pub #[allow(dead_code)] enum Foo { ... }

// RIGHT
#[allow(dead_code)]
pub enum Foo { ... }
```

**Pitfall:** When adding a field to a struct, ALL test helper constructors need updating. Search for all `Config { ... }` blocks and add the new field.

## Verification After Cleanup

```bash
# Check warnings
cargo check 2>&1 | grep "warning:" | wc -l

# Run tests after cleanup
cargo test

# Verify release build still works
cargo build --release
```

## Absorbed Skill: rust-database-thread-safety-migration (Consolidated 2026-05-27)

Narrow skill about migrating Rust servers from `Mutex<Database>` to thread-safe `DatabaseClient` with channel-based messaging. The core lesson — avoid wrapping entire database types in a single Mutex, use message-passing or interior mutability instead — is a pattern that applies broadly to Rust workspace troubleshooting.

## References

- `references/libgallium-freeze-diagnosis.md` — crash analysis from session 2026-05-13
- **`references/rusqlite-send-pattern.md`** — Channel-based `DatabaseClient` pattern for handling `!Send` rusqlite connections in async web frameworks
- **`references/tokio-block-in-place-deadlock-pattern.md`** — `tokio::task::block_in_place` in async contexts can deadlock the runtime. Safe pattern: dedicated OS thread + single-threaded tokio runtime for sync→async bridges.
