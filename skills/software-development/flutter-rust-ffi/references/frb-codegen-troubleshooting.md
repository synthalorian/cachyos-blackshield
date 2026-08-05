# flutter_rust_bridge Codegen Troubleshooting

## Unit Struct Rejection

**Error:**
```
struct with unit fields are not supported yet... no entry found for key=MirStructIdent(...)
```

**Cause:** `LocalSynthesisEngine;` (unit struct) is rejected by FRB's MIR parser.

**Fix:**
```rust
pub struct LocalSynthesisEngine {
    _private: (),
}

impl LocalSynthesisEngine {
    pub fn new() -> Self {
        Self { _private: () }
    }
}
```

Never use bare unit structs (`struct Foo;`) when they will be referenced from bridge functions.

## Bridge Function Design for Fragile Codegen

When codegen panics on complex types:

- Keep `#[frb(sync)]` functions accepting only primitives: `String`, `i32`, `f32`, `bool`.
- Construct internal domain types (`Project`, `AgentTask`, etc.) *inside* the function body.
- Return formatted `String` or simple scalars instead of rich structs until the bridge is stable.

Example pattern used successfully:
```rust
#[frb(sync)]
pub fn run_project_synthesis(project_name: String) -> String {
    // build dummy project internally
    let score = ...;
    format!("Score: {:.0}%", score * 100.0)
}
```

## Numeric Type Ambiguity with `.min()`

**Error:** `can't call method `min` on ambiguous numeric type`

**Fix:** Explicitly type the intermediate value:
```rust
let retro_bonus: f32 = if ... { 0.08 } else { 0.0 };
(base + retro_bonus).min(1.0)
```

Or use a fully qualified literal: `1.0_f32`.

## v2 Configuration Narrowing

When full-crate codegen fails, restrict input:

```yaml
rust_input: crate::bridge
rust_root: rust/core/
```

This prevents FRB from walking modules that contain unsupported types.

## Pre-Codegen Hygiene

Always run `cargo check` in the Rust crate before `flutter_rust_bridge_codegen generate`. Clean MIR is required for reliable codegen.

## After Successful Codegen

1. `flutter pub get` in the Flutter project
2. Verify `lib/src/rust/frb_generated.dart` and `bridge.dart` exist (note: **not** under `api/`)
3. Add `await RustLib.init();` before `runApp()`
4. Import generated bridge: `import 'package:<app>/src/rust/bridge.dart';` (top-level in the rust generated folder)
5. For functions marked `#[frb(sync)]`, call them **without** `await` — they return the value directly, not a Future.
