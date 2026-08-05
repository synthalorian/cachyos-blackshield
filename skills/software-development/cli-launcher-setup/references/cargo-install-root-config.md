# Cargo Install Root Config

Redirect `cargo install` output to `~/.local/bin` instead of `~/.cargo/bin`.

## Problem

User's shell PATH has `~/.local/bin` before `~/.cargo/bin`. `cargo install --path .` puts binaries in `~/.cargo/bin`, but the shell finds the old binary in `~/.local/bin` first.

## Solution

Create `~/.cargo/config.toml`:

```toml
[install]
root = "/home/synth/.local"
```

After this, `cargo install --path .` places binaries directly in `~/.local/bin`.

## Verification

```bash
which openshark          # should show ~/.local/bin/openshark
echo $PATH | tr ':' '\n' # confirm ~/.local/bin comes before ~/.cargo/bin
```

## Related

- `install-path-pitfall.md` — Copying binary after build when cargo root isn't configured
