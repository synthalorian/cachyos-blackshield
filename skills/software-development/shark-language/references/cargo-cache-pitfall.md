# Cargo Cache Pitfall — Stale Fingerprints

**Session:** 2026-05-29

## The Problem

After editing `src/tui/mod.rs` and running `cargo build --release`, Cargo finishes in 0.06 seconds with "Finished" — no actual recompilation happens. The binary at `target/release/openshark` retains the old timestamp and old behavior. User sees "it's the exact same" after every build.

Root cause: Cargo's fingerprint cache (`target/release/.fingerprint/openshark-*`) thinks the source is **Fresh** even though the file was edited. This can happen when:
- The file mtime didn't change (NFS, container mounts, some editors)
- The fingerprint got corrupted
- A previous build was interrupted mid-write

## Detection

```bash
cd /home/synth/projects/openshark
cargo build --release 2>&1 | grep -i "finished\|compiling"
# "Finished `release` profile [optimized] target(s) in 0.06s" = BAD (cached)
# "Compiling openshark v0.1.0" = GOOD (actual rebuild)
```

Also check binary timestamp:
```bash
ls -la target/release/openshark
# Should be within seconds of the build command
```

## Fix

Force a full rebuild by deleting fingerprints and deps:
```bash
cd /home/synth/projects/openshark
rm -rf target/release/.fingerprint/openshark* \
       target/release/deps/openshark* \
       target/release/openshark
cargo build --release
```

Or use `cargo clean` for a nuclear option (slower, rebuilds everything including deps):
```bash
cargo clean && cargo build --release
```

## Prevention

Always check build output. If you see "Finished in <1s" after editing source, the cache is stale. Never tell the user "it's built" without verifying the binary timestamp changed.

## Related

- `references/install-path-pitfall.md` — Even after a real build, `~/.local/bin/openshark` may be stale
