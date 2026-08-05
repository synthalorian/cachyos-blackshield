# Build Verification Pitfall

## Problem

User reports "the binary hasn't changed" after `cargo build --release` + `cp target/release/openshark ~/.local/bin/openshark`. The version string is still `1.0.0` because `Cargo.toml` wasn't bumped. The user can't visually verify the update.

## Root Cause

- `openshark --version` reads from `env!("CARGO_PKG_VERSION")` which comes from `Cargo.toml`
- If you don't bump the version, the user sees the same output as before
- The binary IS updated (new code, new strings, new size) but the user has no way to know

## Verification Methods (in order of reliability)

### 1. Check file timestamp
```bash
ls -la ~/.local/bin/openshark
```
Should show a recent modification time.

### 2. Check file size
```bash
ls -la ~/.local/bin/openshark
```
Size should differ from the old binary (even by a few bytes).

### 3. Check SHA256
```bash
sha256sum ~/.local/bin/openshark /home/synth/projects/openshark/target/release/openshark
```
Both should match, proving the copy succeeded.

### 4. Search for new strings
```bash
strings ~/.local/bin/openshark | grep "Context compressed"
strings ~/.local/bin/openshark | grep "context_compression"
strings ~/.local/bin/openshark | grep "threshold"
```
These prove the new code is actually in the binary.

### 5. Bump version in Cargo.toml (BEST PRACTICE)
```bash
# Before building, bump the version
sed -i 's/^version = "1.0.0"/version = "1.0.1"/' /home/synth/projects/openshark/Cargo.toml
```
Then build and install. The user can verify with `openshark --version`.

## Prevention

**Always bump version before release builds.** Even a patch bump (`1.0.0` → `1.0.1`) gives the user immediate visual confirmation.

## What NOT to do

- Don't rely solely on `openshark --version` if you didn't bump the version
- Don't tell the user "it's built" without giving them a way to verify
- Don't assume the binary is stale just because the version string is the same — check timestamps and strings first
