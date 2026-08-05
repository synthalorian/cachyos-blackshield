# flutter_rust_bridge v2 Gotchas (GridOS Session)

## Error: "no entry found for key=MirStructIdent"
**Cause:** FRB tried to analyze a struct (`LocalSynthesisEngine`) that was defined as a unit struct elsewhere in the crate.

**Fix:** 
- Narrow `rust_input` to only the bridge module, OR
- Give the struct a private field: `struct Foo { _private: () }`

## Error: "struct with unit fields are not supported yet"
Same root cause as above. Unit structs are rejected during MIR traversal.

## Dart: "Uses 'await' on an instance of 'String'"
**Cause:** Called a `#[frb(sync)]` function with `await`.

**Fix:** Remove `await`. Sync functions return values directly.

## Codegen Config Format Change (v2)
Old:
```yaml
rust_input: rust/core/src/**/*.rs
```

New (recommended for existing crates):
```yaml
rust_input: crate::bridge
rust_root: rust/core/
```

## Recommended Minimal Bridge
When in doubt, make the bridge module completely self-contained with only primitives:

```rust
#[frb(sync)]
pub fn run_project_synthesis(project_name: String) -> String {
    // Do work internally, return formatted string
    format!("Score: 87% for {}", project_name)
}
```

This avoids exposing any internal domain types to FRB's analyzer.
