# Fixing Botched Migration Script Insertions

## Problem

A migration script inserted field assignments (`images: None,`) across a codebase but placed them incorrectly — inside `format!()` macro arguments, struct definitions, wrong struct types, and dangling after struct literals.

## Systematic Fix Approach

### Step 1: Catalog All Insertions

Use `search_files` to find every occurrence of the inserted pattern:

```bash
search_files(pattern="images: None", path="src/", output_mode="content")
```

### Step 2: Categorize by Insertion Type

For each occurrence, examine context to classify:

| Category | Description | Fix |
|----------|-------------|-----|
| **A** | Inside `format!()` string argument | Delete line entirely |
| **B** | Inside struct definition (type, not init) | Delete line entirely |
| **C** | Inside `impl` fn body before `Self {` | Delete line entirely |
| **D** | Correct — in `providers::Message` init | Keep as-is |
| **E** | In `memory::store::Message` (no `images` field) | Delete line |
| **F** | In `tui::ChatMessage` (needs field added) | Add field to struct, keep init |
| **G** | Dangling after vec literal | Delete line |

### Step 3: Verify No Overlaps

Before applying fixes, check that delete/keep categories don't overlap:

```python
delete_set = cat_a | cat_b | cat_c | cat_e | cat_g
keep_set = cat_d
assert len(delete_set & keep_set) == 0, "Overlap between delete and keep!"
```

### Step 4: Apply Fixes by Category

Use `patch` (for targeted single-line fixes) or Python script (for bulk deletion):

```python
# Bulk delete by (file, line_number)
for rel_path, line_num in sorted(delete_lines, reverse=True):
    path = os.path.join(base, rel_path)
    with open(path, 'r') as f:
        lines = f.readlines()
    del lines[line_num - 1]  # 0-indexed
    with open(path, 'w') as f:
        f.writelines(lines)
```

**Sort descending** so line numbers don't shift after each deletion.

### Step 5: Add Missing Fields

For structs that SHOULD have the field (like `ChatMessage`), add it properly:

```rust
struct ChatMessage {
    role: String,
    content: String,
    images: Option<Vec<String>>,
    timestamp: DateTime<Utc>,
}
```

### Step 6: Fix Initializers Missing the Field

After cleanup, `cargo check` will report `missing field` errors. Find each with:

```bash
cargo check 2>&1 | grep -A3 "missing field"
```

Add the field to each initializer. For `providers::Message`, add `images: None`.
For other types, verify they actually need it.

### Step 7: Verify Clean Build

```bash
cargo check  # zero errors before proceeding
cargo test   # if tests exist
```

## Key Pitfalls

- **Don't trust the migration script** — it likely botched edge cases
- **Don't fix one file at a time** — catalog ALL occurrences first to understand the pattern
- **Check struct type before adding field** — `memory::store::Message` may have different schema than `providers::Message`
- **Verify with `cargo check` after each batch** — catch shifted line numbers early
- **Beware of format strings** — `images: None,` inside `format!("...")` breaks the macro silently

## Session Reference

OpenShark multimodal migration: 50+ bad insertions across 8 files. Script inserted `images: None,` inside format strings, struct defs, and wrong struct types. Systematic categorization + bulk fix resolved all errors in one pass.
