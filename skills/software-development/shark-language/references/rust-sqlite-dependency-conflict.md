# Rust SQLite Dependency Conflict Resolution

## Problem

Adding `matrix-sdk` 0.17 to a project that already uses `rusqlite` 0.34 causes a `libsqlite3-sys` linking conflict:

```
error: failed to select a version for `libsqlite3-sys`.
    ... required by package `rusqlite v0.37.0`
    ... which satisfies dependency `rusqlite = "^0.37.0"` of package `matrix-sdk-sqlite v0.17.0`
    ... which satisfies dependency `matrix-sdk-sqlite = "^0.17.0"` of package `matrix-sdk v0.17.0`

package `libsqlite3-sys` links to the native library `sqlite3`, but it conflicts with a previous package:
package `libsqlite3-sys v0.32.0`
    ... which satisfies dependency `libsqlite3-sys = "^0.32.0"` of package `rusqlite v0.34.0`
```

Only one package in the dependency graph may specify the same `links = "sqlite3"` value.

## Root Cause

`rusqlite` bundles `libsqlite3-sys` which links to the native SQLite library. Different `rusqlite` versions bundle different `libsqlite3-sys` versions. Cargo cannot link two different versions of the same native library.

## Solution

Upgrade the project's `rusqlite` to match the version required by the new dependency:

```bash
cargo remove rusqlite
cargo add rusqlite@0.37 --features=bundled,chrono
```

**Verify:** `cargo tree -i libsqlite3-sys` should show a single version.

## Prevention

When adding a new crate that depends on SQLite:
1. Check `cargo tree -i libsqlite3-sys` before adding
2. If conflict, upgrade existing `rusqlite` to match
3. Run `cargo test` after upgrade — rusqlite API may have minor changes

## Alternative: System SQLite

If both crates support it, use system SQLite instead of bundled:

```toml
rusqlite = { version = "0.37", features = ["chrono"] }  # no "bundled"
```

This requires `libsqlite3-dev` (or equivalent) installed system-wide. Both crates will link against the same system library.
