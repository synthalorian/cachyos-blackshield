# Cargo Install Path Discipline

## Problem

Running `cargo build` or `cargo build --release` compiles the binary into `target/debug/` or `target/release/` but does NOT install it to the user's PATH. The user continues running the old binary from `~/.local/bin/` or `~/.cargo/bin/` and sees no changes.

Common user complaint: "I don't see the changes" or "it hasn't changed" after edits.

## Solution

### For Development Testing

```bash
# Build release binary
cargo build --release

# Copy to user's local bin (immediate, no cargo metadata update)
cp target/release/openshark ~/.local/bin/openshark

# Verify timestamp
ls -la ~/.local/bin/openshark
```

### For Proper Installation

```bash
# Build + install in one command (respects ~/.cargo/config.toml install.root)
cargo install --path . --force

# This copies to ~/.cargo/bin/ (default) or ~/.local/bin/ (if configured)
# AND updates cargo's install tracking metadata
```

### Configuring Install Location

Create `~/.cargo/config.toml`:
```toml
[install]
root = "/home/synth/.local"
```

Then `cargo install --path . --force` installs to `~/.local/bin/`.

## Verification Checklist

When user says "it hasn't changed":

1. **Check binary timestamp**: `ls -la ~/.local/bin/openshark` — should be recent
2. **Check version string**: `openshark --version` — only changes if `Cargo.toml` was bumped
3. **Check file size**: `ls -la ~/.local/bin/openshark` — size should differ if code changed
4. **Search for new strings**: `strings ~/.local/bin/openshark | grep "new_feature_name"`
5. **Verify PATH priority**: `which openshark` — ensure it's `~/.local/bin/openshark` not another copy

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Only ran `cargo build` | Old binary still runs | Run `cargo install --path . --force` or `cp target/release/openshark ~/.local/bin/` |
| Multiple binary copies | Inconsistent behavior | `which openshark` to find which one runs; remove duplicates |
| Cargo install root not configured | Binary goes to `~/.cargo/bin/` not `~/.local/bin/` | Set `install.root` in `~/.cargo/config.toml` |
| Version not bumped | `openshark --version` shows same version | Bump `version` in `Cargo.toml` before release build |

## Rule

**Always `cargo install --path . --force` after making changes the user needs to test.** `cargo build` alone is insufficient.
