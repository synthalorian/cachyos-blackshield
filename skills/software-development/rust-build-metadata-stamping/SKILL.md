---
name: rust-build-metadata-stamping
description: Fix stale version/commit/model strings in Rust CLI/TUIs.
triggers:
  - outdated version string in Rust app
  - wrong commit hash or build date displayed
  - stale model name in TUI splash/status
  - hardcoded UI text that should reflect live state
---

# Rust Build Metadata Stamping & Live UI State

Two faces of the same bug: **string literals that describe runtime reality**. Version dates, commit hashes, model names, provider endpoints, session info — if it can change, it must not be a literal.

## Signal

User reports a UI surface showing outdated info ("it says X but we're on Y"). **Grep the literal string FIRST** — it is almost always a baked-in constant, not a data-flow bug. The telltale code smell: a render function that receives the app/state struct but ignores it (`fn draw_splash(_app: &App, ...)`).

## Fix 1: Compile-time stamps via build.rs (no dependencies)

Version, build date, commit hash belong in `build.rs`, not source literals. Build scripts can't use the crate's deps — use std-only code:

```rust
// build.rs
use std::time::{SystemTime, UNIX_EPOCH};

fn main() {
    let hash = std::process::Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "unknown".to_string());

    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let (y, m, d) = civil_from_days(secs / 86_400);

    println!("cargo:rustc-env=OS_GIT_HASH={hash}");
    println!("cargo:rustc-env=OS_BUILD_DATE={y}.{m}.{d}");
    println!("cargo:rerun-if-changed=.git/HEAD"); // rebuild when commit changes
}

/// Days since Unix epoch -> (year, month, day). Howard Hinnant's algorithm.
fn civil_from_days(z: u64) -> (i64, u32, u32) {
    let z = z as i64 + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}
```

Consume with `env!("CARGO_PKG_VERSION")`, `env!("OS_BUILD_DATE")`, `env!("OS_GIT_HASH")`.

**Verify the stamp landed:** `strings target/debug/<bin> | grep -oE "20[0-9]{2}\.[0-9]+\.[0-9]+"`. Adjacent string literals pack together in the string table — a date immediately followed by the hash in `strings` output is normal, not corruption.

## Fix 2: Thread live state into renderers

Replace literal parameters with an info struct built from live app state at the call site:

```rust
pub struct SplashInfo {
    pub model: String,      // app.model — NOT a literal like "kimi-k2.7-code"
    pub provider: String,   // app.provider.name
    pub permissions: String,// app.profile_registry.active()
    pub branch: String,     // git rev-parse --abbrev-ref HEAD, fallback "n/a"
    pub directory: String,  // app.project_path, fallback current_dir
    pub session: String,    // app.session_id
}
```

Rename the ignored param (`_app` → `app`) and populate the struct there. Check `Config::default()` and setup wizards for fossil endpoints/models at the same time — same disease, same cure.

## Pitfalls

- **Duplicate rendering hides in plain sight.** When a banner function already includes a version line but the caller draws it again below, removing the caller's copy is part of the fix — check for double-draw before shipping.
- **Patch-tool lint noise is not a compile error.** The patch tool runs rustc without the crate edition, so it flags false "async fn is not permitted in Rust 2015" / "let chains" errors on modern-edition files. `cargo check` / `cargo build` is the only real gate.
- **Binary-only crates:** `cargo test --lib` fails with "no library targets found" — use `cargo test --bin <name>`.
- **Don't forget the sweep.** One stale literal usually means more: grep for sibling fossils (old model names in tests, help text, doc comments, default configs) and replace them all in one pass, including test fixtures that assert the old value.

## References

- `references/openshark-splash-sweep-2026-07.md` — worked example: OpenShark TUI splash showing a two-generations-old model name; full file map of the fix, plus provider-default fossil (dead local proxy) found during the same sweep.
