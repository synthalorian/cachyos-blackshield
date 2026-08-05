# OpenShark Splash Sweep — 2026-07-24

Worked example of the rust-build-metadata-stamping fixes, applied to OpenShark
(`~/Projects/active/openshark`, binary-only crate — test with `cargo test --bin openshark`).

## Symptom

TUI splash banner displayed `kimi-k2.7-code` while the live config ran `k3`.
Version line showed hardcoded `2026.6.16` / commit `c9523d0`.

## Root causes found

1. `src/tui/ascii_art.rs` — `banner(term_width)` had every value as a string literal:
   model, permissions (`danger-full-access`), branch, directory, session id, provider.
2. `src/tui/components/splash.rs` — `draw_splash_screen(_app: &App, ...)` received the
   live `App` but ignored it (the `_app` telltale). Also drew the version line a second
   time below the banner (double-draw bug).
3. Version date/commit hardcoded in BOTH files.
4. Fossil provider default: `Config::default()` in `src/config/mod.rs` pointed kimi at
   `http://127.0.0.1:8699/v1` — a K2-era local translation proxy. Obsolete: the Kimi
   coding endpoint (`https://api.kimi.com/coding/v1`) is natively OpenAI-compatible
   AND Anthropic-bilingual. No shim needed. Setup wizard (`src/config/setup.rs`) also
   offered the proxy.
5. `kimi-k2.6` stale default across 8 files (~20 sites): `config/mod.rs`,
   `config/setup.rs`, `agent/mod.rs`, `harness/engine.rs`, `memory/compression.rs`,
   `router/mod.rs` (tests), `evolution/mod.rs` (tests), `main.rs` (help text).

## Fix map

- New `build.rs` (std-only): `OS_GIT_HASH` from `git rev-parse --short HEAD`,
  `OS_BUILD_DATE` from SystemTime via Howard Hinnant civil-from-days,
  `cargo:rerun-if-changed=.git/HEAD`.
- `ascii_art.rs`: `banner()` now takes `&SplashInfo` (model/provider/permissions/
  branch/directory/session); version line uses the env! stamps.
- `splash.rs`: builds `SplashInfo` from `app.model`, `app.provider.name`,
  `app.profile_registry.active()`, `app.session_id`, `app.project_path`; new
  `detect_git_branch()` helper (fallback "n/a"); duplicate version draw removed.
- `kimi-k2.6` → `k3` everywhere; default kimi provider → direct endpoint,
  1M context (1048576), capabilities + reasoning/vision; wizard text updated.

## Verification

- `cargo build` clean; all 470 tests pass (`cargo test --bin openshark`).
- Stamps confirmed in binary: `strings target/debug/openshark` shows the build date
  and short hash (adjacent in the string table — reads merged, that's normal).

## OpenShark provider facts (durable)

- Kimi for Coding: DIRECT `https://api.kimi.com/coding/v1`. Never reintroduce the
  8699 proxy — it only existed to translate protocols and alias `kimi-k2.7-code` →
  `kimi-for-coding` for the old endpoint.
- Current model name in user's live config (`~/.config/openshark/config.toml`): `k3`.
- Repo path: `~/Projects/active/openshark` (NOT `~/projects/openshark` — older notes
  and the shark-language skill still say the lowercase path; it's stale).
