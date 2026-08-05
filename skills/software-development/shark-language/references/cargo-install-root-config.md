# Cargo Install Root Configuration

Pattern for redirecting `cargo install` output to `~/.local/bin` instead of `~/.cargo/bin`.

## Problem

By default, `cargo install --path .` installs binaries to `~/.cargo/bin/`. If the user's PATH prioritizes `~/.local/bin` (common on Linux), the old binary in `~/.local/bin` takes precedence and the newly installed cargo binary is ignored.

## Solution

Create `~/.cargo/config.toml` with an install root override:

```toml
[install]
root = "/home/synth/.local"
```

Now `cargo install --path .` installs to `~/.local/bin/` directly.

## Verification

```bash
# Check which binary launches
which openshark

# Check install path
cargo install --path . --force
# Should print: "Installing /home/synth/.local/bin/openshark"
```

## When to Use

- User's PATH has `~/.local/bin` before `~/.cargo/bin`
- User wants all Rust binaries in `~/.local/bin` alongside other tools
- Building a Rust CLI that the user launches by name from terminal

## Alternative: Manual Copy

If you can't change cargo config, copy the release binary directly:

```bash
cp target/release/openshark ~/.local/bin/openshark
chmod +x ~/.local/bin/openshark
```

**Note:** If the binary is running, `cp` may fail with "Text file busy". Use the swap-then-move pattern:

```bash
cp target/release/openshark ~/.local/bin/openshark.new
mv ~/.local/bin/openshark.new ~/.local/bin/openshark
chmod +x ~/.local/bin/openshark
```
