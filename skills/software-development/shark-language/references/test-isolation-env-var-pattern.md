# Test Isolation: Env Var Pollution in Rust Tests

## Problem

Tests that use `std::env::set_var()` / `remove_var()` can pollute each other when running in parallel (default `cargo test` behavior).

## Example from OpenShark

```rust
#[test]
fn test_default_soul() {
    unsafe { std::env::remove_var("SOUL_NAME"); }
    let soul = load_soul();
    assert_eq!(soul.name(), "synthclaw");  // Expects default
}

#[test]
fn test_blank_soul() {
    unsafe { std::env::set_var("SOUL_NAME", "blank"); }
    let soul = load_soul();
    assert_eq!(soul.name(), "agent");  // Expects blank
    unsafe { std::env::remove_var("SOUL_NAME"); }
}
```

**Failure:** `test_default_soul` fails with `left: "synthclaw", right: "agent"` because `test_blank_soul` sets `SOUL_NAME=blank` before `test_default_soul` reads it.

## Solutions

### 1. Order Tests Sequentially (Simplest)

Rename tests so they run in desired order (Rust runs tests in lexicographic order by default):

```rust
#[test]
fn test_1_blank_soul() {   // Runs first
    unsafe { std::env::set_var("SOUL_NAME", "blank"); }
    let soul = load_soul();
    assert_eq!(soul.name(), "agent");
    unsafe { std::env::remove_var("SOUL_NAME"); }  // Clean up
}

#[test]
fn test_2_default_soul() {  // Runs second, env is clean
    unsafe { std::env::remove_var("SOUL_NAME"); }
    let soul = load_soul();
    assert_eq!(soul.name(), "synthclaw");
}
```

### 2. Use `std::sync::Mutex` (Robust)

```rust
use std::sync::Mutex;

static ENV_LOCK: Mutex<()> = Mutex::new(());

#[test]
fn test_with_env() {
    let _guard = ENV_LOCK.lock().unwrap();
    unsafe { std::env::set_var("SOUL_NAME", "blank"); }
    // ... test ...
    unsafe { std::env::remove_var("SOUL_NAME"); }
}
```

### 3. Use `serial_test` Crate (Cleanest)

```toml
[dev-dependencies]
serial_test = "3.0"
```

```rust
use serial_test::serial;

#[test]
#[serial(env)]
fn test_blank_soul() {
    unsafe { std::env::set_var("SOUL_NAME", "blank"); }
    // ... test ...
}
```

## Verification

```bash
# Should pass (single-threaded)
cargo test test_blank_soul -- --test-threads=1

# Should also pass (parallel, after fix)
cargo test
```

## General Rule

Any test that mutates global state (env vars, statics, filesystem outside temp dirs) needs isolation. Prefer:
1. Thread-local state instead of global
2. Dependency injection (pass config as param instead of reading env)
3. `serial_test` crate for unavoidable global mutations
