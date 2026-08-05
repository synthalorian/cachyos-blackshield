# Dead Code Cleanup Pattern for Rust Projects

## The Tiered Approach (128 → 0 warnings)

### Step 1: `cargo fix` for easy wins
```bash
cargo fix --bin "openshark" -p openshark --allow-dirty
```
Auto-removes unused imports, unused mut. Typically fixes ~20-30% of warnings.

### Step 2: Module-level `#![allow(dead_code)]`
For modules with many unused items that are part of a public API or will be used soon:
```rust
#![allow(dead_code)]
```

Good candidates:
- `theme.rs` — theme functions not yet wired to all consumers
- `lsp/mod.rs` — LSP client modules with future features
- `security/identity.rs` — identity system stubbed for future zero-trust

### Step 3: Targeted `#[allow(dead_code)]` on specific items
For individual functions/structs/fields with future utility:
```rust
#[allow(dead_code)]
pub fn list_models(&self) -> Result<Vec<String>> { ... }
```

### Step 4: Remove truly dead code
For code that's genuinely obsolete and has no future path.

### Step 5: Fix test-only breakage
After cleanup, run `cargo test` — some "dead" code is actually used in tests.

## Common Pitfalls

**Pitfall 1: Removing a field that's used in struct initialization**
```rust
// DON'T just delete the field — check all constructors
let metrics = ToolExecutionMetrics {
    tool_name: "...".to_string(),
    args: args.clone(),  // This field IS used in tests!
    duration_ms: 0,
    success: true,
};
```

**Pitfall 2: `#[allow(dead_code)]` on enums breaks syntax**
```rust
// WRONG — breaks compilation
pub #[allow(dead_code)] enum InjectionCheck { ... }

// RIGHT
#[allow(dead_code)]
pub enum InjectionCheck { ... }
```

**Pitfall 3: Unused variable that's actually read in a closure**
```rust
// The `body` variable is assigned but the read happens in a different scope
let mut body = String::new();
{
    body = String::from_utf8_lossy(&buf).to_string();
}
let response = serde_json::from_str(&body);  // Used here!
// Fix: Don't rename to _body unless you update ALL references
```

**Pitfall 4: Test Config constructors missing new fields**
When adding a field to a struct, ALL test helper constructors need updating:
```rust
// Every test that constructs Config needs the new field
Config {
    // ... existing fields ...
    theme: "synthwave84".to_string(),  // Don't forget this!
}
```

## Verification

```bash
cargo check 2>&1 | grep "warning:" | wc -l
cargo test
cargo build --release
```

## When to Stop

Zero warnings is the goal, but don't sacrifice API completeness. If a function is part of a planned feature, `#[allow(dead_code)]` is correct. Remove only code with no plausible future consumer.
