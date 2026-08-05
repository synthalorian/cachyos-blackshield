---
name: openshark-tui
description: Use when OpenShark splash/TUI shows stale display values.
triggers:
  - OpenShark splash screen shows wrong/stale model, version, or session info
  - OpenShark banner, ASCII art, or theme changes
  - TUI display values that should reflect live config but don't
---

# OpenShark TUI

Repo: `/home/synth/Projects/active/openshark` (note: older docs say `~/projects/openshark` — wrong casing/path).

## Key Files

| File | Role |
|------|------|
| `src/tui/ascii_art.rs` | Splash banner generator: logo, `SplashInfo` panel, connection status, version line, help bar |
| `src/tui/components/splash.rs` | Draws splash via direct ANSI (crossterm queue!), anti-flicker `SPLASH_DRAWN` AtomicBool, builds `SplashInfo` from `App` |
| `src/tui/theme.rs` | `Theme`, `ansi_fg`/`ansi_reset`, `Color::Rgb` |
| `src/tui/mod.rs` | `App` struct (pub(crate)); splash can read its fields |

## Live State Available From `App`

The splash banner must be fed from `App`, never literals. Available fields:
`app.model`, `app.provider.name`, `app.config` (incl. `find_provider_for_model`), `app.session_id`, `app.project_path`, `app.profile_registry.active()`.

Private `App` fields ARE accessible from `crate::tui::components::*` — child modules see parent-module-private items. No need to make fields `pub`.

## Pitfalls

- **Chat feed scroll model (fixed 2026-07-27):** `App.scroll` is a LINE offset into the rendered feed (all_lines in components/chat.rs), NOT a message index. The feed auto-follows the tail via `App.follow_tail` (true by default); scroll_up unpins, scroll_down to bottom re-pins, submitting a message re-pins. Geometry comes from `feed_total_lines`/`feed_viewport`, refreshed EVERY frame by draw_unified_feed — never recompute line counts in input handlers. History: scroll_down used to clamp to messages.len() (message count vs line offset → bottom unreachable), nothing auto-followed (new responses rendered below the viewport → "clipped"), and wheel scroll never called request_redraw (invisible until some other event repainted).
- **Never scroll on mouse click.** ChatClick/plain-click used to set scroll = y-5 — every click teleported the viewport. Clicks are no-ops now; drag = select+copy, wheel/PgUp/PgDn = scroll. mouse::build_rendered_lines (selection extraction) must return app.effective_scroll(), not app.scroll, or copy grabs the wrong rows.

- **Hardcoded display literals go silently stale.** The banner shipped with baked-in `kimi-k2.7-code`, permission profile, branch, cwd, a fake session ID, and a hardcoded version date/commit — it kept displaying them long after the config moved on. `draw_splash_screen` even received `App` and ignored it (`_app`). Before trusting any TUI display string: `rg 'kimi|gpt|20\d\d\.|session-' src/tui/`.
- **Version line is still hardcoded** (`"2026.6.16"` / `"c9523d0"` in both `ascii_art.rs` `banner()` and `splash.rs`) — same staleness class; wire to build-time git info (e.g. vergen) if touched again.
- **Fallback defaults age too.** `src/config/mod.rs`, `src/agent/mod.rs`, `src/harness/engine.rs`, `src/memory/compression.rs` default to `kimi-k2.6` — fresh-install defaults; bump when the flagship model changes.
- **Pixel-art glyphs: use ▪ (U+25AA), not █ (U+2588).** █ blobs adjacent cells into unreadable blocks in terminal fonts; ▪ renders with natural gaps. Test spacing before shipping.
- **Anti-flicker pattern:** splash draws once behind `SPLASH_DRAWN: AtomicBool` and never clears again; `reset_splash()` re-arms it. Don't add per-frame clear/redraw — 60fps full-screen clears are seizure-inducing.

## Fix Recipe

Threading live session info into the splash banner (the `SplashInfo` refactor):
`references/splash-live-state.md`

## Verify

```bash
cd /home/synth/Projects/active/openshark
cargo check && cargo build
```
