# Install Path Pitfall — OpenShark Binary Deployment

**Session:** 2026-05-29

## The Problem

`synth` has `~/.local/bin/` in their PATH and an `openshark` binary there. After `cargo build --release`, the fresh binary is at `target/release/openshark` inside the project directory, but running `openshark` from anywhere executes the **stale** binary in `~/.local/bin/`.

This caused confusion where the user saw no changes after builds — the TUI looked identical because the old binary was running.

## Detection

```bash
which openshark          # Shows ~/.local/bin/openshark
openshark --version      # Shows ACTUAL running version — CRITICAL
ls -la ~/.local/bin/openshark   # Check timestamp
ls -la target/release/openshark # Compare timestamp
```

If `~/.local/bin/openshark` is older than `target/release/openshark`, it's stale.

**Critical:** Always run `openshark --version` BEFORE telling the user to test. If the version doesn't match what you just built, you're running stale code. This is devastating — the user sees old TUI, missing features, and thinks their work didn't land.

## Fix

After every release build, copy the fresh binary:
```bash
cd /home/synth/projects/openshark
cargo build --release
cp target/release/openshark ~/.local/bin/openshark
```

Or add a shell function to `.bashrc`:
```bash
openshark-update() {
    cd /home/synth/projects/openshark
    cargo build --release
    cp target/release/openshark ~/.local/bin/openshark
    echo "openshark updated — $(ls -la ~/.local/bin/openshark | awk '{print $6,$7,$8}')"
}
```

## Prevention

Always verify the binary is current before telling the user to test:
```bash
cp target/release/openshark ~/.local/bin/openshark && echo "Installed"
```
