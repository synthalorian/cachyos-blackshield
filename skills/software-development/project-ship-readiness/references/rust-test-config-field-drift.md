# Rust Test Config Field Drift — Session Reference

## Problem

Adding a new field to a central config struct (e.g., `Config` in `src/config/mod.rs`) breaks test compilation across multiple modules. Each test module that constructs the struct literal needs the new field.

## Error Pattern

```
error[E0063]: missing field `context_compression` in initializer of `config::Config`
   --> src/config/mod.rs:633:9
   --> src/router/mod.rs:708:9
   --> src/router/mod.rs:745:9
   --> src/self_improve/mod.rs:707:9
```

Note: the error points to the *test module* inside each file, not the struct definition.

## Root Cause

Rust struct literals require ALL fields unless `..Default::default()` is used. When a new field is added to a struct, every literal construction site breaks — including test helpers, mock configs, and inline test data.

## Fix (from OpenShark v1.0.0 session)

Files affected and their fixes:

| File | Field Added | Location |
|------|-------------|----------|
| `src/config/mod.rs` | `context_compression: crate::memory::compression::ContextCompressionConfig::default()` | `create_test_config()` helper |
| `src/router/mod.rs` | same | `create_test_config()` and `create_test_config_with_small_context()` |
| `src/self_improve/mod.rs` | same | `create_test_config()` helper |
| `src/agent/mod.rs` | `swarm` + `context_compression` | `infer_config()` method |

## Prevention Strategies

1. **Centralized test config helper** — One `create_test_config()` function that all tests call. Only one place to update.
2. **`..Default::default()`** — Use struct update syntax in tests so new fields auto-fill:
   ```rust
   Config {
       version: "1.0.0".to_string(),
       ..Default::default()
   }
   ```
3. **Derive Default** — Ensure the struct and all nested types implement `Default`.

## Quick Detection

```bash
cargo test 2>&1 | grep -E "error\[E0063\]|missing field"
```

## Related

- `project-ship-readiness` skill: "Rust Test Compilation After Config Changes" pitfall
