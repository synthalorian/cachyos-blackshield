# Common Compilation Fixes for Rust + Flutter Bridge

## E0432 - Unresolved Import

**Cause:** Module re-exports before the items are defined, or missing `pub use`.

**Fix:**
```rust
// In synthesis/mod.rs
pub use local_engine::{LocalSynthesisEngine, SynthesisEngine};
```

Always define the implementation struct and trait before re-exporting.

## E0716 - Temporary Value Dropped

**Cause:** Chained method calls creating temporary values that are freed too early.

**Fix:**
```rust
let hash = password_hash.hash.unwrap();
let key_bytes = hash.as_bytes();
```

Never chain `.unwrap().as_bytes()` directly when the result needs to live.

## Module Organization

Recommended structure:
```
src/
├── lib.rs
├── bridge.rs          # All #[frb] functions
├── synthesis/
│   ├── mod.rs
│   └── local_engine.rs
└── storage/
```

This prevents circular dependency issues during codegen.