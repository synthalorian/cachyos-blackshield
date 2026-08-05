# Rust Ship-Readiness Checklist

Extension of the generic ship-readiness checklist for Rust CLI/TUI projects like OpenShark.

## Pre-Flight Audit

### 1. Compiler Health
```bash
cd /path/to/project

# Check errors
cargo check 2>&1 | grep "error" | head -5

# Count warnings by file
cargo check 2>&1 | grep "warning:" | sed 's/.*--> //; s/:[0-9]*:[0-9]*//' | sort | uniq -c | sort -rn

# Auto-fix easy wins
cargo fix --bin "project-name" -p project-name --allow-dirty
```

### 2. Test Health
```bash
cargo test 2>&1 | tail -10
# Look for: "test result: ok. N passed; 0 failed"
```

### 3. Release Build
```bash
cargo build --release 2>&1 | tail -5
ls -lh target/release/project-name
```

### 4. Version String Audit
```bash
# Find ALL hardcoded version strings
grep -rn '"0\.[0-9]\.[0-9]"' src/ | grep -v test | grep -v "//"

# Check TUI display strings
grep -rn "v0\." src/ | grep -v test

# Verify CLI version matches Cargo.toml
./target/release/project-name --version
```

### 5. Stub/TODO Audit
```bash
# Find unimplemented stubs
grep -rn "unimplemented!\|todo!\|TODO\|FIXME" src/ | grep -v test

# Check for placeholder values
grep -rn "placeholder\|stub\|dummy" src/ | grep -v test
```

### 6. Binary Verification
```bash
# Check binary size
ls -lh target/release/project-name

# Verify it runs
./target/release/project-name --help
./target/release/project-name --version
```

## Warning Classification

| Warning Type | Action | Example |
|-------------|--------|---------|
| Unused import | `cargo fix` | `use std::sync::Arc` |
| Unused mut | `cargo fix` | `let mut x = ...` never mutated |
| Dead code — scaffolded | Leave / `#[allow(dead_code)]` | MCP protocol types not yet wired |
| Dead code — obsolete | Remove | Old bridge module after native replacement |
| Unused variable | Check if test-only | `session_id` used only in debug logging |

## Ship-Readiness Grades

| Grade | Criteria |
|-------|----------|
| **A** — Ship now | 0 errors, ≤10 warnings (all scaffolded), tests pass, release builds, version consistent |
| **B** — Ship after cleanup | 0 errors, 10-30 warnings (mix of scaffolded + fixable), tests pass |
| **C** — Needs work | Any errors, or >30 warnings, or test failures, or version drift |
| **D** — Not ready | Compilation broken, or major features are stubs, or no tests |

## Common Rust-Specific Issues

1. **Edition linter false positives** — `write_file`/`patch` lint checker runs without `--edition` context. Trust `cargo check`, not the standalone linter.
2. **Async fn flagged as "Rust 2015"** — Ignore. The project is on edition 2024.
3. **HashMap borrow scoping** — Temporary borrows in closures need explicit drop or scope boundaries.
4. **Test isolation** — `std::env::set_var` in tests pollutes parallel runs. Use `std::env::remove_var` in cleanup or serial test execution.
