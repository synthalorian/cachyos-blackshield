# write_file Lint False Positive — Rust Edition Detection

Session: 2026-05-30, building OpenShark Discord gateway with serenity 0.12.

## The Symptom

When writing `.rs` files with `write_file`, the lint checker incorrectly reports:

```
error[E0670]: `async fn` is not permitted in Rust 2015
  --> src/gateway/discord.rs:52:9
   |
52 |     pub async fn start(&self) -> Result<()> {
   |         ^^^^^ to use `async fn`, switch to Rust 2018 or later
```

Even though `Cargo.toml` clearly specifies:
```toml
edition = "2024"
```

## The Reality

This is a **false positive from the write_file lint checker**, not a real compile error. The actual `cargo check` passes fine:

```bash
cd /home/synth/projects/openshark && cargo check
# Finished `dev` profile [unoptimized + debuginfo] target(s) in 12.38s
```

## Why It Happens

The `write_file` tool runs a syntax checker that may not have access to the project's `Cargo.toml` or may use a default Rust edition (2015) for standalone file checking. Since `async fn` requires edition 2018+, the checker flags it as an error.

## The Workaround

**Ignore the lint error.** Trust `cargo check` instead:

1. Write the file with `write_file` (lint will show errors)
2. Run `cargo check` to verify actual compilation
3. If `cargo check` passes, the code is correct

## When to Worry

Only worry if `cargo check` ALSO fails. In that case, the error is real and needs fixing. Common real errors after write_file:
- Missing imports
- Type mismatches
- API changes (e.g., serenity 0.12 vs 0.11)
- Borrow checker issues

## Verification Pattern

```bash
# After writing any .rs file:
cd /home/synth/projects/openshark && cargo check 2>&1 | grep -E "^error" | head -20

# If output is empty or only shows real errors (not E0670), you're good
```

## Related

- `references/serenity-0.12-api-migration.md` — Real serenity API changes that DO cause compile errors
