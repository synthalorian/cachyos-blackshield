# Splash Live-State Refactor (2026-07-24)

Symptom: OpenShark splash showed `kimi-k2.7-code` while the live config ran
`default_model = "k3"`. Root cause: every splash value was a hardcoded literal.

## Before

`src/tui/ascii_art.rs` — `banner(term_width)` contained:

```rust
let info_lines = system_info_panel(
    "kimi-k2.7-code",
    "danger-full-access",
    "main",
    "/home/synth",
    "session-1781637801812-0",
);
// ...
connection_status("kimi-k2.7-code", "openai")
```

`src/tui/components/splash.rs` — `draw_splash_screen(_app: &App, ...)` ignored
the live `App` it was handed.

## After

1. `ascii_art.rs`: added a public struct and changed the signature:

```rust
pub struct SplashInfo {
    pub model: String,
    pub provider: String,
    pub permissions: String,
    pub branch: String,
    pub directory: String,
    pub session: String,
}

pub fn banner(term_width: usize, info: &SplashInfo) -> String
```

`system_info_panel` / `connection_status` now receive `&info.*` fields.

2. `splash.rs`: renamed `_app` → `app`, built the struct from live state:

```rust
let directory = if app.project_path.is_empty() {
    std::env::current_dir()
        .map(|p| p.display().to_string())
        .unwrap_or_else(|_| ".".to_string())
} else {
    app.project_path.clone()
};
let info = ascii_art::SplashInfo {
    model: app.model.clone(),
    provider: app.provider.name.clone(),
    permissions: app.profile_registry.active().to_string(),
    branch: detect_git_branch(&directory),
    session: app.session_id.clone(),
    directory,
};
let banner_text = ascii_art::banner(term_width as usize, &info);
```

3. Added helper in `splash.rs`:

```rust
fn detect_git_branch(dir: &str) -> String {
    std::process::Command::new("git")
        .args(["rev-parse", "--abbrev-ref", "HEAD"])
        .current_dir(dir)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "n/a".to_string())
}
```

## Why It Works

- `App` (defined in `crate::tui`, `pub(crate)`) fields are visible from
  `crate::tui::components::splash` — child modules access parent-private items.
- `app.model` mirrors `config.default_model` at launch (`k3` in the live
  `~/.config/openshark/config.toml`), so the banner tracks model changes with
  zero future edits.
- Verified: `cargo check` + `cargo build` clean.

## Known Remaining Stale Literals (as of 2026-07-24)

- Version line `"2026.6.16"` / commit `"c9523d0"` — hardcoded in BOTH
  `ascii_art.rs` `banner()` and `splash.rs` `draw_splash_screen` (drawn twice,
  by the way — banner includes it and splash re-draws it below).
- Fallback default `kimi-k2.6` in `src/config/mod.rs`, `src/agent/mod.rs`,
  `src/harness/engine.rs`, `src/memory/compression.rs`, `src/config/setup.rs`.
