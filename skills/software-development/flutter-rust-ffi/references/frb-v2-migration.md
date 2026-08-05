# flutter_rust_bridge v2 Integration Issues (GridOS Session)

## Error: E0753 expected outer doc comment

**Root cause:** `flutter_rust_bridge_codegen` injects `mod frb_generated;` at the absolute top of `lib.rs`, before any crate-level `//!` documentation.

**Files affected:** `rust/core/src/lib.rs`

**Fix applied:**
Moved the injected module declaration below all `//!` doc comments.

**Before:**
```rust
mod frb_generated; /* AUTO INJECTED... */
//! GridOS Core — The synthesis engine...
```

**After:**
```rust
//! GridOS Core — The synthesis engine...
//! ...

mod frb_generated;
```

## Error: float type ambiguity in synthwave_score

**Location:** `rust/core/src/synthesis/mod.rs:96`

**Cause:** Unannotated float literals (`0.08`, `0.0`) being added to an `f32` (`base`).

**Fix:** Explicitly type the bonus variable:

```rust
let retro_bonus: f32 = if ... { 0.08 } else { 0.0 };
```

## Wayland Crash on Hyprland

**Symptom:**
```
wl_display#1: error 0: invalid object 5
Io error: Invalid argument (os error 22)
Error: WinitEventLoop(ExitFailure(1))
```

**Workaround used:**
```bash
WINIT_UNIX_BACKEND=x11 cargo run
```

Also added `features = ["wayland"]` to the eframe dependency.

## Config File Migration

The `flutter_rust_bridge.yaml` had to be narrowed from broad glob patterns to a specific module (`crate::bridge`) to avoid FRB trying to analyze unit structs and other non-FRB-friendly types in the rest of the crate.
