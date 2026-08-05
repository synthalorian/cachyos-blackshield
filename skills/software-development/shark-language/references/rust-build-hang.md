# Rust Build Hang on Final Linking Step

Session: 2026-05-29. `cargo build --release` stuck at "building 256/257" for extended period.

## Symptom

Cargo progress shows `Building [=====================> ] 256/257` and hangs. No CPU activity. No error output. The process appears frozen.

## Context

This happens on large Rust binaries with many dependencies (tokio + ratatui + crossterm + SQLite + reqwest + etc.). The final step is linking the binary, which can be slow or hang under certain conditions.

## Resolution

**First, wait.** Large binaries with debug symbols can take 30-60s on the final link step. The user reported it eventually completed in 46s.

**If it truly hangs (no progress after 2+ minutes):**

```bash
cd /home/synth/projects/openshark
cargo clean
cargo build --release
```

`cargo clean` removes all incremental compilation artifacts and forces a full rebuild. This resolves most hang scenarios caused by corrupted incremental state.

## Prevention

- Use `lld` linker for faster linking: `RUSTFLAGS="-C link-arg=-fuse-ld=lld" cargo build --release`
- Ensure sufficient disk space (linking needs temporary space for the binary + symbols)
- Ensure sufficient RAM (linking large binaries can use several GB)

## Verification

After build completes, verify the binary is fresh:
```bash
ls -la target/release/openshark
# Should show current timestamp
```

Then copy to PATH location:
```bash
cp target/release/openshark ~/.local/bin/openshark
```
