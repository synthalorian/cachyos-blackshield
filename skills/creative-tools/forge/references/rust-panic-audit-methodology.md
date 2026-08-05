# Rust Panic-Safety Audit Methodology

Used for v0.10.0 remaining hardening of Forge. Reusable for any Rust codebase audit.

## Search Queries (run via search_files)

### 1. Find all unwrap/expect calls
```
pattern: \.unwrap\(\)|\.expect\(
output_mode: count
```
Then switch to `content` mode for files with hits to get line numbers.

### 2. Find byte slicing on strings
```
pattern: \[\.+\d+\]
```
Flags: `&hash[..2]`, `&output[..10]`, etc. Safe on hex strings, but inconsistent — prefer `.chars().take(N)`.

### 3. Find hardcoded paths
```
pattern: /home/synth/
```
Replace with `env::var()` or `dirs::home_dir()`.

### 4. Find shell format injection
```
pattern: format!\(.*sh|Command::new\("sh"\)
```
Any `format!` inside `sh -c` is injection-vulnerable.

### 5. Find to_str().expect() on paths
```
pattern: to_str\(\)\.expect
```
Non-UTF8 paths panic. Use `.ok_or_else(|| anyhow!(...))?` in production code.

## Severity Classification

| Pattern | Severity | Fix |
|---------|----------|-----|
| `chars.next().unwrap()` in parser | HIGH | `match chars.next() { Some(c) => ..., None => break }` |
| `to_str().expect()` in prod code | MEDIUM | `.ok_or_else(\|\| anyhow!(...))?` |
| `expect("entry should exist")` on DB lookup | MEDIUM | `.ok_or_else(\|\| anyhow!(...))?` |
| `unwrap()` on test fs operations | LOW | `.expect("descriptive message")` |
| `&hash[..2]` on known hex strings | LOW | `.chars().take(2).collect()` for consistency |
| `expect()` with terse message in tests | LOW | Improve message for debugging |

## Files Remaining in Forge v0.10.0

| File | Issues | Severity |
|------|--------|----------|
| `src/crucible.rs` | 5x `chars.next().unwrap()` | HIGH |
| `src/spirit.rs` | 2x test `unwrap()` on fs | LOW |
| `src/spirit.rs` | 5x test `unwrap()` on parse | LOW |
| `src/archive.rs` | 3x `to_str().expect()` prod code | MEDIUM |
| `src/archive.rs` | 6x test `expect()` terse | LOW |
| `src/reflect.rs` | 3x `expect()` on DB lookup | MEDIUM |
| `src/db.rs` | 3x test `expect()` terse | LOW |
| `src/anvil.rs` | 1x `&hash[..2]` byte slice | LOW |

## Audit Workflow

1. Run all 5 search queries across `src/`
2. Exclude already-fixed files from results
3. For each hit, read surrounding context (±10 lines) to confirm it's a real issue
4. Classify severity using the table above
5. Group into tasks by file, order by severity
6. Write plan with exact line numbers, before/after code, and verification steps
