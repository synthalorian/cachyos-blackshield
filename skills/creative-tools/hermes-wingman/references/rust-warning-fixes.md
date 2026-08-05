# Rust Backend Warning Fixes — Session Recipe

Concrete fixes applied to get `cargo check` from 5 warnings → 0 warnings.

## 1. Unreachable Pattern in Match Arm

**File:** `backend/src/handlers/gateway.rs`
**Problem:** `"curl" | "auto" =>` already matches `"auto"`, making `"pip" | "auto" =>` unreachable.
**Fix:** Remove `"auto"` from the later arm.

```rust
// BEFORE (warning: unreachable pattern)
match method {
    "curl" | "auto" => { ... }
    "brew" => { ... }
    "pip" | "auto" => { ... }  // "auto" already matched above
}

// AFTER
match method {
    "curl" | "auto" => { ... }
    "brew" => { ... }
    "pip" => { ... }  // only "pip" here
}
```

## 2. Dead Code Structs (Never Constructed)

**Files:** `config.rs`, `memory.rs`, `skills.rs`
**Problem:** Structs defined with `#[derive(Deserialize)]` but never used as Axum extractors.

| Struct | File | Action |
|--------|------|--------|
| `SessionsQuery` | `config.rs` | Removed entirely |
| `MemorySearchQuery` | `memory.rs` | Removed entirely |
| `SkillToggleParams` | `skills.rs` | Removed entirely |

These were leftover from refactorings where the handlers switched to `Json<serde_json::Value>` instead of typed extractors.

## 3. Unused Serde Imports

**Files:** `memory.rs`, `skills.rs`
**Problem:** `use serde::{Deserialize};` left behind after removing structs.
**Fix:** Remove the import entirely. If `Serialize` is still needed, use `use serde::Serialize;`.

```rust
// BEFORE
use serde::{Deserialize};

// AFTER — if nothing from serde is used in this file, delete the line entirely
// (serde_json::Value comes from axum::extract::Json, not this import)
```

## 4. Reserved Fields with #[allow(dead_code)]

**File:** `backend/src/state.rs`
**Problem:** `auth_urls` field is intentionally reserved for future OAuth flows but currently unused.
**Fix:** Add `#[allow(dead_code)]` instead of deleting scaffolding.

```rust
pub struct AppState {
    pub hermes_home: PathBuf,
    pub override_model: Arc<Mutex<Option<String>>>,
    #[allow(dead_code)]
    auth_urls: Arc<tokio::sync::Mutex<HashMap<String, oneshot::Sender<String>>>>,
}
```

## Verification Commands

```bash
cd backend
cargo check          # should show 0 warnings
cargo build --release
cargo test
```

## Quick Fix Script

```bash
#!/bin/bash
# Run this after any backend refactor to auto-fix trivial warnings
cd backend
cargo fix --bin hermes-wingman-backend --allow-dirty
cargo check
```
