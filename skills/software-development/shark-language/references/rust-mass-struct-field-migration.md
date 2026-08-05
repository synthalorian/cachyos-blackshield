# Rust Mass Struct Field Migration

## Problem

Adding a new field to a widely-used struct (e.g., `Message`, `Config`, `ChatMessage`) requires updating dozens of initializers across a codebase. Automated migration scripts often botch insertions — placing `field: value` inside `format!()` macros, struct definitions, wrong struct types, or dangling outside braces.

## Session Example: Adding `images: Option<Vec<String>>` to `Message`

A migration script inserted `images: None,` in 50+ locations across 8 files. Many were syntactically invalid:
- Inside `format!("...", images: None, "...")` — breaks the macro
- Inside `struct Message { images: None, ... }` — `None` is not a type
- Inside `impl Message { pub fn text() { images: None; Self { ... } }` — statement before `Self`
- In `memory::store::Message` which has NO `images` field — wrong struct type
- Dangling after a `vec![]` literal — orphan syntax

## Categorization System

When cleaning up botched insertions, categorize every occurrence before touching code:

### Category A: Inside `format!()` or other macro calls
**Action:** DELETE the line entirely. It's inside a macro argument list.
**Example:**
```rust
content: format!(
    images: None,  // ← DELETE
    "Hello {}", name
),
```

### Category B: Inside a struct *definition* (not initializer)
**Action:** DELETE. This is a type definition, not a value.
**Example:**
```rust
pub struct Message {
    pub role: String,
    images: None,  // ← DELETE — None is not a type
    pub content: String,
}
```

### Category C: Inside an `impl` function body before `Self {`
**Action:** DELETE. It's a stray statement.
**Example:**
```rust
pub fn text(role: &str, content: &str) -> Self {
    images: None,  // ← DELETE
    Self { role: role.into(), content: content.into() }
}
```

### Category D: Correct initializer for the target struct
**Action:** KEEP. The field belongs here.
**Example:**
```rust
Message {
    role: "user".to_string(),
    content: "hi".to_string(),
    images: None,  // ← KEEP
}
```

### Category E: Wrong struct type (different module, no such field)
**Action:** DELETE. This struct doesn't have the field.
**Example:**
```rust
memory::store::Message {
    id: "...".to_string(),
    session_id: "...".to_string(),
    images: None,  // ← DELETE — store::Message has no images field
}
```

### Category F: Needs field added to a different struct first
**Action:** ADD the field to the struct definition, then KEEP the initializer.
**Example:** `ChatMessage` needs `images: Option<Vec<String>>` added to its definition.

### Category G: Type alias — same as target struct
**Action:** KEEP (same as Category D). Verify by checking the `use` statement.
**Example:** `use crate::providers::Message as ProviderMessage;` — same type, keep `images: None`.

### Category H: Dangling/orphan — not inside any struct
**Action:** DELETE. Usually appears after a `vec![]` literal or similar.
**Example:**
```rust
vec![
    Message { role: "user".to_string(), content: "hi".to_string() },
    images: None,  // ← DELETE — outside any struct
]
```

## Workflow

1. **Find all occurrences:** `grep -rn "images: None" src/`
2. **Catalog by file and line number**
3. **Categorize each occurrence** (A-H) by reading surrounding context
4. **Delete categories A, B, C, E, H** first
5. **Add missing fields to struct definitions** (Category F)
6. **Verify remaining errors with `cargo check`**
7. **Fix missing field errors** — these are structs that need the field but don't have it in their initializers
8. **Repeat `cargo check`** until clean

## Verification

After cleanup, run:
```bash
cargo check 2>&1 | grep "^error\[E" | head -20
```

Expected: zero new errors. Pre-existing warnings (edition, dead_code) are fine.

## Prevention

When writing migration scripts:
- Use AST-aware tools (`cargo expand`, `syn` crate) instead of regex
- Test on a small subset first
- Always verify with `cargo check` before declaring done
- For simple field additions, consider using `#[derive(Default)]` + `..Default::default()` pattern to avoid touching every initializer
