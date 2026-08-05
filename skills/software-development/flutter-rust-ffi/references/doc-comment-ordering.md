# Crate Doc Comment Ordering with flutter_rust_bridge_codegen

## The Problem
When `flutter_rust_bridge_codegen generate` runs, it injects this line at the very top of `lib.rs`:

```rust
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge... */
```

If your crate already has `//!` (inner) documentation comments, this injection breaks them.

## Observed Error
```
error[E0753]: expected outer doc comment
```

The errors typically appear at regular intervals (~13 lines apart), e.g.:
- line 2
- line 15
- line 28
- line 41
- line 54
- line 67

## Root Cause
`//!` comments are **inner** doc comments — they document the parent item (the crate). When a `mod` declaration appears before them, Rust no longer considers the following `//!` comments as valid crate documentation.

## Fix
Move the injected `mod frb_generated;` line **below** all crate-level documentation.

**Before (broken):**
```rust
mod frb_generated;
//! GridOS Core — The synthesis engine...
//! ...
```

**After (correct):**
```rust
//! GridOS Core — The synthesis engine that powers every platform.
//!
//! ...

mod frb_generated;
```

## Prevention
After running codegen, always check the top of `lib.rs` and ensure the ordering is correct. Re-running codegen will re-inject the line at the top, so this fix may need to be re-applied.