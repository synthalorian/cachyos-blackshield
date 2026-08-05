---
name: project-ship-readiness
description: End-to-end v1.0.0 launch checklist — version audit, build verification, metadata, CHANGELOG, release artifacts, tag, push, make public.
tags: [release, launch, ship, public, v1.0.0, audit, checklist]
version: 1.0.0
---

# Project Ship-Readiness

Taking a project from "works on my machine" to "public v1.0.0 on GitHub with release artifacts." Used for Hermes Wingman, Chronos Engine, Open Psalm, and similar launches.

## Triggers

- User says "ship it", "get it ready", "polish and release", "make public"
- User mentions version number inconsistency (README says X, Cargo.toml says Y)
- User wants first public release of a repo

## Checklist (in order)

### 0. Security Audit (Before ANY Push)

Run this BEFORE committing. One leaked API key in a public repo is permanent.

```bash
# Search for API keys, tokens, passwords that aren't placeholder patterns
grep -riE '(api_key|token|password|secret|private_key)' src/ --include='*.rs' | \
  grep -v 'env_or_placeholder\|api_key = "\${\|api_key = "llama-swap\|api_key = "hermes-proxy\|api_key = "test-\|api_key = ""\|api_key = "local"\|// \|/\*\|password_hash\|persist_password\|test_redact'

# Search for hardcoded URLs with auth
grep -riE 'https?://[^\s]+@[^\s]+' src/ --include='*.rs'

# Check for .env files accidentally staged
git diff --cached --name-only | grep -E '\.env$|secret|key'
```

**Rule:** All secrets must use `${ENV_VAR}` placeholder syntax or be test-only values (`"test-key"`, `"local"`). If grep finds anything that looks like a real key (long hex string, `sk-...`, `ghp_...`, `xoxb-...`), ABORT the push and rotate the credential immediately.

### 1. Audit Version Consistency

Every version string must agree. Check ALL of these:

- `Cargo.toml` / `pubspec.yaml` / `CMakeLists.txt` / `package.json` — the build config
- `README.md` badges — version badge must match
- Source code — grep for hardcoded version strings (e.g., `const VERSION = "0.2.0"`)
- `CHANGELOG.md` — heading must match release version
- Git tags — don't conflict with existing tags

**Also audit license consistency:** The `LICENSE` file, `Cargo.toml` / `package.json` license field, and README badge must all agree. A mismatch (e.g., `GPL-3.0-or-later` in Cargo.toml but `MIT` in LICENSE) is a legal contradiction that blocks shipping.

**Pitfall:** CMake `project()` version and the C++ `constexpr VERSION` string are independent. Bump both.

**Pitfall:** CMake `project()` version and the C++ `constexpr VERSION` string are independent. Bump both.

**Rust-specific version drift pattern:**
Hardcoded version strings often drift across the codebase. Search comprehensively:
```bash
grep -rn '"0\.[0-9]\.[0-9]"' src/ | grep -v test | grep -v "//"
```
Common drift locations in Rust projects:
- TUI sidebar/header hardcoded display string (e.g., `" v0.2.0"` in `src/tui/mod.rs`)
- Config default values for module version fields
- Agent/router/self-improve module version strings (often `"0.1.0"` from initial scaffold)
- Protocol version strings (e.g., MCP `initialize` request)

**Fix:** Use `env!("CARGO_PKG_VERSION")` for CLI `--version`. For module version fields that need runtime access, consider a single `const VERSION: &str = env!("CARGO_PKG_VERSION")` in a central location.

### 1b. Functional Verification (Before Mechanical Checks)

Before running version audits and formatting checks, verify the product **actually works** for its intended purpose. A repo that passes CI but can't perform its core function is not ship-ready.

**Ask the user:**
- "Does this actually work for your use case?"
- "Have you tested the main workflow end-to-end?"

**Example from Kicks Guitar Workstation:**
The app passed all mechanical checks (version consistency, clippy, tests, CI) but the JACK audio backend was a stub — it registered ports but never ran a process callback. The app couldn't route audio in qpwgraph. The user had to push back: *"there's no way to select input and output, it needs to display as kicks in my qpwgraph."*

**Functional checks for audio/DSP apps:**
- Can the app register as a JACK/AudioUnit/VST client?
- Are input/output ports visible in the system audio router?
- Does audio flow end-to-end (input → DSP → output)?
- Can the user select devices/ports from the UI?

**Functional checks for web apps:**
- Does the main user journey work (login → action → result)?
- Are API endpoints responding with correct data?
- Does the frontend talk to the backend successfully?

**Functional checks for Rust + Flutter local-first apps:**
- Does the Flutter frontend communicate with the Rust backend via real IPC/HTTP (not mocked responses)?
- Can the app import at least one real data format (CSV, JSON, XML)?
- Do charts/dashboards display data queried from the database (not hardcoded placeholder values)?
- Does the encryption layer actually encrypt (dump the SQLite file, verify it's unreadable)?

If functional verification fails, **stop the ship-readiness process** and fix the core functionality first. Do not tag a release of a broken product.

### 2. Fix Compilation

- `cargo check` / `flutter analyze` / `cmake --build` / `mix compile` must pass with zero errors
- Fix all warnings if auto-fixable (`cargo fix`, `mix format`, etc.)
- **Rust:** `cargo clippy --all-targets --all-features -- -D warnings` must pass clean. Common pre-ship clippy issues:
  - `non_snake_case` field names (e.g., `value_mg_dL` → `value_mg_dl`)
  - `needless_borrows_for_generic_args` (e.g., `hex::encode(&nonce)` → `hex::encode(nonce)`)
  - `result_unit_err` — use a custom `Error` type instead of `Result<T, ()>`
  - `unused_imports` in test modules
- **Pitfall (Rust/Axum):** After modularization refactors, structs used as Axum extractors become private. Any type in a route handler (`post(handlers::files::file_mkdir)`) must be `pub`. Symptom: "type `XxxRequest` is private" errors.

**Elixir-specific version tracking:**
When a project has multiple shipped versions (e.g., v0.1.0, v0.2.0, v0.3.0), the CHANGELOG must document ALL of them, not just the latest. The `mix.exs` version must also match the latest release.

```bash
# Check what changed between tags for accurate CHANGELOG entries
git log --oneline v0.2.0..v0.3.0
```

Common version drift in Elixir:
- `mix.exs` `@version` attribute lags behind git tags
- CHANGELOG only has the first version entry
- Git tags exist but CHANGELOG doesn't mention them

**Fix:** After tagging a release, immediately update CHANGELOG with the new section and bump `mix.exs` version to the NEXT planned version (or match the tag).

**Elixir-specific quality gates:**
```bash
# Run ALL gates in sequence — any failure blocks ship
mix compile        # zero warnings
mix test           # all pass
mix format --check-formatted
mix credo          # zero issues
mix dialyzer       # zero errors
```
- **Pitfall:** `mix format --check-formatted` fails if `.formatter.exs` is missing. Create one: `[import_deps: [:phoenix], inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]]`
- **Pitfall:** Credo flags "function body nested too deep" for `init/1` with nested `case` blocks. Extract private functions to flatten nesting.
- **Pitfall:** Dialyzer infers `with` blocks always succeed unless `else` clause is explicit. If a function returns `{:error, _}` but Dialyzer says "pattern can never match", add `else error -> error` to the `with` block.
- **Pitfall:** ExUnit does NOT provide a `tmp_dir` fixture. Use `System.tmp_dir!()` + `System.unique_integer([:positive])` + `on_exit(fn -> File.rm_rf!(tmp_dir) end)` instead.
- **Pitfall:** Named GenServer processes (`name: __MODULE__`) collide in async tests. Add a `:name` option to `start_link/1` and use unique names in tests.
- **Pitfall:** ETS match specs with `%{field: :"$1", :_ => :_}` are invalid. Use `%{field: :"$1"}` instead — match only the fields you need.
- **Pitfall:** `:named_table` on ETS tables causes "table name already exists" crashes in async ExUnit tests. Use unnamed tables (table ref in GenServer state) and route all lookups through GenServer calls.
- **Pitfall:** Plug.Conn test state leaks between async tests when `Application.get_env/3` returns a default that gets modified by a prior test. Use `Application.delete_env/2` in `setup` + `on_exit` restore for env vars that affect plug behavior.
- **Pitfall:** Phoenix controller tests that call `Router.call/2` directly (not through the endpoint) bypass the endpoint's `render_errors` config and socket mounting. The router still runs plugs, so auth plugs and content-type plugs still fire. But the endpoint's `render_errors` config and socket mounting are not exercised.

**Elixir CHANGELOG version tracking:**
When a project has multiple shipped versions (e.g., v0.1.0, v0.2.0, v0.3.0), the CHANGELOG must document ALL of them, not just the latest. The `mix.exs` version must also match the latest release.

```bash
# Check what changed between tags for accurate CHANGELOG entries
git log --oneline v0.2.0..v0.3.0
```

Common version drift in Elixir:
- `mix.exs` `@version` attribute lags behind git tags
- CHANGELOG only has the first version entry
- Git tags exist but CHANGELOG doesn't mention them

**Fix:** After tagging a release, immediately update CHANGELOG with the new section and bump `mix.exs` version to the NEXT planned version (or match the tag).

**Rust dead code assessment:**
**Flutter-specific compilation check:**
```bash
flutter analyze
```
- Must report "No issues found!" — zero infos, zero warnings, zero errors
- Common pre-ship issues:
  - `deprecated_member_use` — Flutter evolves fast; replace deprecated APIs (e.g., `DropdownButtonFormField.value` → `initialValue` after v3.33.0)
  - `unused_import` — `dart fix --apply` handles these automatically
  - `must_be_immutable` / `prefer_const_constructors` — style lints, auto-fixable
- Run `flutter pub outdated` to see available upgrades, but DO NOT upgrade major versions right before shipping — risk of breaking changes

**Rust dead code assessment:**
Not all warnings are debt. Distinguish:

1. **Genuinely dead code** — obsolete, no future consumer → remove
2. **Scaffolded but unimplemented** — MCP protocol types, gateway platform abstractions, tool adapters that will be wired in next phase → leave, `#[allow(dead_code)]` if noisy
3. **Import-only warnings** — `cargo fix` handles these automatically

Quick audit:
```bash
cargo check 2>&1 | grep "warning:" | sed 's/.*--> //; s/:[0-9]*:[0-9]*//' | sort | uniq -c | sort -rn
```
This shows which files have the most warnings. Focus cleanup on files with >3 warnings.

### 3. Fix Metadata

- **pubspec.yaml:** `description` must not be "A new Flutter project." Add `repository` and `homepage` fields.
- **Cargo.toml:** Add `repository` and `homepage`. `description` should be descriptive, not placeholder.
- **package.json:** `repository`, `description`, `author`.

### 4. Fix README

- Version badge must match release version
- Architecture/structure diagrams must reflect current code (not pre-refactor state)
- File counts and module counts must be accurate
- All outdated paths fixed (e.g., old repo names pre-monorepo migration)
- Authorship line: "Made by synth with synthclaw" — NEVER "heavy lifting by" or "assistance from"

### 4a. Verify ASCII Art / Logo Spelling

**Critical for pinned repos.** The ASCII art at the top of the README is the first thing visitors see. If it spells gibberish, the project looks amateur.

**Verify before shipping:**
```bash
# Generate correct ASCII art with pyfiglet
python3 -c "import pyfiglet; print(pyfiglet.figlet_format('YourProjectName', font='standard'))"

# Or use an online figlet generator and paste the result
```

**Common failure mode:** The ASCII art was hand-edited or copied from a different project name. Each big letter must be verified:
- First letter starts at column 0 or 1
- Each subsequent letter has clear vertical strokes (`|`) or curves
- The word is readable at a glance from 3+ feet away

**If the project name doesn't figlet well** (too long, weird letters), use a shorter variant or skip ASCII art and use a banner image instead.

**OpenShark example — what NOT to ship:**
```
     _                      _    _
    / \   ___ _ __ __ _ ___| | _| |__   _____  __
   / _ \ / __| '__/ _` / __| |/ / '_ \ / _ \ \/ /
  / ___ \ (__| | | (_| \__ \   <| | | | (_) >  <
 /_/   \_\___|_|  \__,_|___/_|\_\_| |_|\___/_/\_\
```
This spells **"Acraskhox"** or similar gibberish — the letters are completely wrong. The correct art:
```
  ___                   ____  _                _    
 / _ \ _ __   ___ _ __ / ___|| |__   __ _ _ __| | __
| | | | '_ \ / _ \ '_ \\___ \| '_ \ / _` | '__| |/ /
| |_| | |_) |  __/ | | |___) | | | | (_| | |  |   < 
 \___/| .__/ \___|_| |_|____/|_| |_|\__,_|_|  |_|\_\
      |_|
```

**Always have a second pair of eyes (or the user) verify the logo before shipping.**

**Banner image alternative:** If ASCII art is error-prone, use a banner image (`openshark.png`) instead. Less error-prone and more visually striking. The image should be committed to the repo and referenced in the README:
```markdown
![OpenShark Banner](openshark.png)
```

### 5. Fix CONTRIBUTING.md (if exists)

- Project structure must match current state
- Build instructions must reference correct paths
- Monorepo migrations: update all `cd` paths

### 6. CHANGELOG.md

Must exist for v1.0.0+. Cover:
- All features per edition/platform
- Architecture highlights (file count, module count, lines of code)
- Technical details (refactors, build fixes, migrations)
- Authorship footer

**Writing the CHANGELOG:**
If a prior tag exists (e.g., moving from v0.1.0 to v1.0.0), check what changed:
```bash
git log --oneline --stat v0.1.0..HEAD
```
This shows commits and files changed — use it to write accurate technical details. Don't guess what changed; let git tell you.

### 6a. Mock vs Real Detection

A common trap is UI that looks complete but is entirely mocked. Check for these red flags:
- Flutter `FutureProvider` returns hardcoded data instead of querying the backend
- Chart widgets generate random data (`List.generate(7, (i) => FlSpot(i.toDouble(), 55 + ...))`)
- Import screens show "coming soon" placeholders with no actual file parsing
- IPC/HTTP clients have `_mockResponse()` methods that bypass real network/socket calls
- Database screens show "Connected" status badges without actually pinging the DB

**Verification:** Search the codebase for mock patterns:
```bash
# Dart/Flutter
grep -rn "mock\|coming soon\|placeholder\|TODO" lib/ --include="*.dart"
grep -rn "List.generate\|FlSpot\|random" lib/ --include="*.dart" | head -20

# Rust
grep -rn "TODO\|FIXME\|unimplemented!" src/ --include="*.rs"
```

If mock data is found in user-facing features, the project is NOT ship-ready regardless of how polished the UI looks.

### 7. Build Release Artifacts

- **Flutter Android:** `flutter build apk --release` (may need `JAVA_HOME=/usr/lib/jvm/java-21-openjdk` — see pitfalls)
  - Also run `flutter analyze` — zero issues required
  - Check for deprecated API warnings; fix before shipping (`DropdownButtonFormField.value` → `initialValue` after v3.33.0)
  - Verify `flutter build linux --release` (or target platform) succeeds
- **Flutter Linux desktop:** `flutter build linux --release` — binary lands in `build/linux/x64/release/bundle/<name>`
- **Rust:** `cargo build --release`
- **C++:** `cmake --build build` (or Release mode)
- Commit the build BEFORE tagging — uncommitted changes don't make it into the release APK

**Flutter project scaffolding check:** If `flutter build apk` fails with "unsupported Gradle project" and the `android/` directory is missing or incomplete, the Flutter project was created without Android platform support. Fix by re-scaffolding:
```bash
mv flutter flutter_bak
flutter create --project-name <name> --org <domain> --platforms android flutter
cp -r flutter_bak/lib/* flutter/lib/
cp flutter_bak/pubspec.yaml flutter/
cp -r flutter_bak/test flutter/  # if tests exist
rm -rf flutter_bak
```
This preserves all Dart code while generating proper Android Gradle files.

**Rust release build timeout:** `cargo build --release` on large workspaces (especially with Tauri's webkit2gtk compilation) can exceed default 60s timeouts. Use `timeout=300` or run in background if the toolchain is cold.

**CI workflow correctness:** Before shipping, verify the release workflow builds the correct binary name:
```bash
# Check what binaries the workspace produces
cargo build --release && ls target/release/ | grep -v "^lib" | grep -v "^\."
```
Common mistake: workflow references `--bin open-health` but the actual binary is `open_health_server` (underscore vs hyphen, missing `_server` suffix).

### 8. Git Housekeeping

- `git add -A` — include ALL uncommitted work (check `git status --short` first)
- Run `cargo fmt` / `mix format` / `flutter format` BEFORE committing — CI will fail on formatting checks
- **Pitfall:** Do NOT `git commit --amend` after pushing to remote — it changes the commit hash and causes non-fast-forward rejections on subsequent pushes. If you need to fix formatting after push, make a new commit instead.
- Meaningful commit message documenting what the release includes
- Delete old conflicting tags: `git push origin :refs/tags/v1.0.0 && git tag -d v1.0.0`
- Create annotated tag: `git tag -a v1.0.0 -m "v1.0.0: ..."`
- Push with tags: `git push origin main --tags` (check branch name — may be `master` not `main`)
- **If a GitHub Release already exists** (e.g., from a previous failed tag), delete it before recreating: `gh release delete v1.0.0 --yes`

### 9. Create GitHub Release

```bash
gh release create v1.0.0 \
  --title "v1.0.0 — Project Name: Tagline 🎹🦞" \
  --notes-file CHANGELOG.md \
  build/app/outputs/flutter-apk/app-release.apk  # if applicable
```

### 10. Make Public (if private)

```bash
gh repo edit owner/repo --visibility public --accept-visibility-change-consequences
```

### 11. Update GitHub Repo "About" Description

The GitHub repo has an "About" field (right sidebar, gear icon) that appears on your profile when the repo is pinned. This is **separate from the README**.

- Must be ≤ 350 characters
- Include the project emoji (e.g., 🦞) for brand recognition on profile pins
- Should complement the README tagline, not duplicate it
- Example: `🦞 The harness that learns. The agent that decides. Open-source AI coding harness in Rust.`

**This cannot be set via git push.** Edit it manually on the GitHub repo page, or use `gh repo edit`:
```bash
gh repo edit synthalorian/openshark --description "🦞 The harness that learns. The agent that decides. Open-source AI coding harness in Rust."
```

**Emoji in README tagline:** The README tagline (the blockquote under the ASCII art) should ALSO include the emoji:
```markdown
> 🦞 *The harness that learns. The agent that decides. The tool that doesn't argue.*
```
This ensures the emoji appears in both the README rendering AND the GitHub "About" description.

### 12. Deprecate Old Repos (if monorepo migration)

- Old standalone repo README → archive notice pointing to monorepo
- Push deprecation commit
- Delete old repo from GitHub (needs `delete_repo` scope on `gh auth`)

### 13. Update Skill Library

- Create or update the project's skill in `~/.hermes/skills/`

## Rails-Specific Ship Checklist

When shipping a Rails 8 app (not just a Rust/Flutter project), additional checks:

### R.1. Database Migrations
- All migrations run cleanly on a fresh database: `rails db:drop db:create db:migrate`
- Seed data loads: `rails db:seed` (create `db/seeds.rb` if missing)
- Schema.rb is committed and up to date

### R.2. Asset Pipeline
- CSS compiles: `rails assets:precompile` (or `bin/rails tailwindcss:build` for Tailwind)
- JavaScript imports resolve: check browser console for 404s on importmap
- `app/assets/builds/` is in `.gitignore` (generated files)

### R.3. Background Jobs
- Solid Queue schema is migrated: `rails db:migrate` (includes queue tables)
- Worker starts: `bin/jobs work` (verify it doesn't crash immediately)
- Recurring jobs config is valid YAML: `config/recurring.yml`

### R.4. Action Cable / WebSockets
- `config/cable.yml` uses correct adapter (solid_cable for SQLite/PostgreSQL, redis for Redis)
- Channel classes load without errors
- JavaScript `createConsumer()` connects (check browser console)

### R.5. Test Suite
- RSpec (or Minitest) passes: `bundle exec rspec` or `bin/rails test`
- Factory Bot factories are valid: `FactoryBot.lint` in `spec/support/factory_bot.rb`
- Request specs use correct route helpers (not literal paths like `/articles/index`)
- Factory data respects model validations (no `status: "MyString"` or `link_quality: 1.5`)
- System specs run if using Cuprite/Selenium

### R.6. Production Config
- `config/environments/production.rb` has:
  - `config.force_ssl = true` (if serving over HTTPS)
  - `config.active_record.dump_schema_after_migration = false`
  - `config.solid_queue.connects_to` configured if using separate DB for queue
- `config/recurring.yml` has scheduled jobs if using Solid Queue recurring tasks
- `RAILS_MASTER_KEY` is set and `config/credentials.yml.enc` is committed
- `config/database.yml` production section uses ENV vars, not hardcoded passwords

### R.7. Health Check Endpoint
- `GET /up` returns 200 (built into Rails 7+)
- Custom health checks if needed (database connectivity, external service reachability)

### R.8. bin/setup Script
- `bin/setup` runs end-to-end without errors on a fresh clone
- Installs dependencies, creates database, runs migrations, seeds data
- Documents any required ENV vars

### R.9. Web App Smoke Test (Monorepo `web/`)
When the Rails app lives inside a monorepo at `web/`, run these before shipping:

```bash
cd web

# 1. Dependencies
bundle check || bundle install

# 2. Database
bin/rails db:migrate:status  # all migrations must be 'up'

# 3. Server boots
bin/rails server -b 127.0.0.1 -p 3000 &
sleep 4
curl -s http://127.0.0.1:3000/up | head -1  # should return JSON with status:ok

# 4. API endpoints respond
curl -s http://127.0.0.1:3000/api/status
curl -s http://127.0.0.1:3000/api/models
curl -s http://127.0.0.1:3000/api/sessions

# 5. Kill server
kill %1
```

**Common monorepo web issues:**
- Missing gems not in Gemfile.lock yet: `bundle install` resolves
- Migrations not run: `bin/rails db:migrate`
- Tailwind build task missing: Rails 8 with `propshaft` + `tailwindcss-rails` gem uses `bin/rails tailwindcss:build`; without the gem, CSS is static in `app/assets/builds/tailwind.css`
- `HERMES_BACKEND_URL` env var not set: defaults to `http://127.0.0.1:9120`, but verify the Rust backend is actually running on that port

## Linux Audio / JACK Backend Implementation

For pro-audio Linux apps (guitar amps, DAWs, synthesizers), CPAL alone is insufficient — users need JACK/PipeWire visibility for routing. See `references/jack-backend-rust.md` for a complete implementation pattern.

**Quick checklist:**
- [ ] JACK client registers with a recognizable name (e.g., "Kicks")
- [ ] Stereo input/output ports with clear names (`in_l`, `in_r`, `out_l`, `out_r`)
- [ ] Real `ProcessHandler` with audio buffer read/write
- [ ] Proper `activate_async` / `deactivate` lifecycle
- [ ] CPU load tracking in the process callback
- [ ] Backend selectable in settings (CPAL vs JACK)
- [ ] Separate input/output device selection for CPAL path

**The `jack` crate (0.9) pattern:**
```rust
// 1. Define a custom ProcessHandler that holds ports + engine
pub struct MyProcessHandler {
    engine: Arc<Mutex<MyEngine>>,
    in_l: jack::Port<jack::AudioIn>,
    in_r: jack::Port<jack::AudioIn>,
    out_l: jack::Port<jack::AudioOut>,
    out_r: jack::Port<jack::AudioOut>,
}

impl jack::ProcessHandler for MyProcessHandler {
    fn process(&mut self, _client: &jack::Client, ps: &jack::ProcessScope,
    ) -> jack::Control {
        let in_l_buf = self.in_l.as_slice(ps);
        let out_l_buf = self.out_l.as_mut_slice(ps);
        // ... run DSP ...
        jack::Control::Continue
    }
}

// 2. Register ports, create handler, activate
let in_l = client.register_port("in_l", jack::AudioIn)?;
let out_l = client.register_port("out_l", jack::AudioOut)?;
let handler = MyProcessHandler { engine, in_l, in_r, out_l, out_r };
let active = client.activate_async((), handler)?;

// 3. Deactivate on shutdown
active.deactivate()?;
```

**Port buffer access:**
- `port.as_slice(&process_scope)` for input (immutable)
- `port.as_mut_slice(&process_scope)` for output (mutable)
- Both methods assert the port belongs to the same client as the process scope

**Feature-gating:**
```toml
# Cargo.toml
[features]
default = ["jack-backend"]
jack-backend = ["dep:jack"]
```

```rust
// Code
#[cfg(feature = "jack-backend")]
pub struct JackAudioIO { ... }

#[cfg(not(feature = "jack-backend"))]
pub struct JackAudioIO { /* no-op stub */ }
```

## Pitfalls

See also:
- `references/cargo-deny-tauri-config.md` — copy-paste `deny.toml` template for Tauri projects
- `references/tauri-ci-frontend-dist.md` — fixing `cargo clippy` failures when `frontend/dist` is missing in CI
- `references/license-consistency-audit.md` — checking for license mismatches across LICENSE file, build config, and README badges
- `references/jack-backend-rust.md` — complete JACK audio client implementation pattern for Linux pro-audio apps
- `references/rust-flutter-local-first-ship-checklist.md` — Rust+Flutter local-first app ship checklist (IPC bridge, CSV import, clippy hygiene, widget tests)

### Java 25 Breaks Android Gradle
Flutter Android builds fail on Java 25 with `IllegalArgumentException: 25.0.3` from `JavaVersion.parse`. Fix:
```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk flutter build apk --release
```
Java 21 is the maximum supported version for current Gradle/Android toolchains.

### Flutter `deprecated_member_use` Pre-Ship
Flutter's rapid release cycle means APIs deprecate between releases. A project that analyzed clean last month may now show `deprecated_member_use` on the next `flutter analyze`.

**Common recent deprecations:**
- `DropdownButtonFormField.value` → `initialValue` (v3.33.0+)
- `RadioListTile.groupValue` / `RadioListTile.onChanged` → Use `ListTile` with checkmarks or `RadioGroup` ancestor (v3.32.0+)
- `TextField.controller` with `initialValue` pattern changes

**Fix:** Update to the replacement API. The deprecation message includes the version it was deprecated after and the recommended replacement. Do not ignore these — they become errors in future Flutter releases.

**Alternative for `RadioListTile` deprecation:** Instead of `RadioListTile` with `groupValue`/`onChanged`, use `ListTile` with a trailing checkmark icon:
```dart
ListTile(
  leading: const Icon(Icons.dark_mode),
  title: const Text('Dark Mode'),
  trailing: currentMode == ThemeMode.dark
      ? const Icon(Icons.check_circle, color: Colors.green)
      : null,
  onTap: () => ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
)
```
This avoids the deprecated API entirely while maintaining the same UX.

### Kotlin Gradle Plugin Deprecation (Flutter Android)
Flutter warns when the Kotlin Gradle plugin version is below 2.1.0. The warning appears during `flutter build apk`:
```
Flutter support for your project's Kotlin version (1.9.22) will soon be dropped.
Please upgrade your Kotlin version to a version of at least 2.1.0 soon.
```

**Fix:** Update `android/settings.gradle`:
```gradle
id "org.jetbrains.kotlin.android" version "2.1.0" apply false
```

**Verify:** Re-run `flutter build apk --release` — the warning should disappear and the build should still succeed.

### Version Drift
CMake project version, C++ constexpr string, README badge, and git tag can all disagree. Audit all four independently.

### Branch Name Mismatch
Some older repos use `master` instead of `main`. Check before pushing tags: `git branch --show-current`.

### Tag Conflicts
If a tag already exists on remote or local, delete it first on BOTH:
```bash
git push origin :refs/tags/v1.0.0  # delete remote
git tag -d v1.0.0                   # delete local
```

### Moving an Existing Tag to Current HEAD
If a tag was created on an older commit (e.g., an early "v0.1.0" from initial scaffolding) and the actual release is now on a later commit, you MUST move the tag. Git does not update tags automatically.

**Symptom:** `git show v0.1.0` points to an old commit, not the ship-readiness commit.

**Fix:**
```bash
# 1. Delete the old tag everywhere
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0

# 2. Recreate on current HEAD
git tag -a v0.1.0 -m "v0.1.0: actual release notes"

# 3. Push
git push origin main --tags
```

**Critical:** Do this BEFORE creating the GitHub Release. If you create a release while the tag points to the wrong commit, the release will bundle stale code. Always verify with `git show vX.Y.Z --stat` before running `gh release create`.

**Also critical:** After committing the ship-readiness changes, verify the tag points to the NEW HEAD (the commit with the ship message), not the pre-commit HEAD. If you tagged before committing, the tag is stale. Move it:
```bash
git log --oneline -3   # verify the ship commit is at the top
git show v1.0.0 --stat # verify the tag points to the ship commit
```
If the tag points to the wrong commit, delete and recreate it on the correct HEAD.

### Monorepo .gitignore
When merging a separate repo into a monorepo, add the sub-project's build artifacts to the ROOT `.gitignore` with the subdirectory prefix (e.g., `web/tmp/*`, `web/log/*`).

### Rust Test Compilation After Config Changes
When adding a new field to a widely-used config struct (e.g., `Config` in `src/config/mod.rs`), EVERY test initializer across the codebase breaks with `error[E0063]: missing field`. The compiler does NOT auto-fill `Default` — each struct literal must be updated.

**Detection:**
```bash
cargo test 2>&1 | grep "error\[E0063\]"
```

**Fix pattern:**
1. Find all `Config {` initializers in test modules: `grep -rn "Config {" src/`
2. Add the new field with its default to each one
3. If the field type is from another module, use fully-qualified path: `crate::memory::compression::ContextCompressionConfig::default()`

**Prevention:** Consider deriving `Default` for config structs and using `..Default::default()` in test initializers, or use a `create_test_config()` helper function that centralizes defaults.

### Git Push "Fetch First" Rejection
After committing and tagging locally, `git push origin main --tags` may fail with:
```
! [rejected]  main -> main (fetch first)
```

This happens when the remote has commits you don't have locally (e.g., a GitHub Actions commit, or someone else pushed).

**Fix:**
```bash
git pull origin main --rebase   # replay your commits on top of remote
git push origin main --tags     # now pushes cleanly
```

**Never** force-push (`--force`) to main on a public repo — it destroys others' work. Rebase is always the right answer for fast-forwardable divergence.

**If rebase hits a `.gitignore` conflict:** The remote likely added `tmp/` while your branch added `/tmp/` + `*.tmp`. Resolve by keeping both patterns (`tmp/` and `*.tmp`), then `git add .gitignore && git rebase --continue`.

### Stale Binary Masking Fresh Build (Rust/CLI)
After `cargo build --release`, the new binary lives in `target/release/<name>`. But the binary in `~/.local/bin/`, `~/.cargo/bin/`, or system PATH may be an **older version** that `cargo install` or manual `cp` placed there earlier.

**Always verify which binary executes:**
```bash
which openshark          # shows PATH location
openshark --version      # shows ACTUAL running version
ls -la $(which openshark) # shows timestamp — is it BEFORE the build?
```

If stale: `cp target/release/openshark ~/.local/bin/openshark`

**Pitfall:** User launches the app and sees old TUI, old behavior, missing features — not because the build failed, but because the shell resolves to a stale binary. This is devastating when the user thinks their work didn't land.

### Uncommitted Changes Before Build
`git status --short` before `flutter build` / `cargo build`. Uncommitted changes won't be in the release binary — the user will install and see old behavior.

### Rust `cargo-deny` License/Advisory Triage

Tauri-based Rust projects (and anything depending on gtk3, webkit2gtk, or large C FFI bindings) will hit ~10-20 `cargo deny check` failures that are **transitive and unactionable**. Do not waste time trying to upgrade these — they are deep in the dependency tree.

**Common failures:**
- **License rejections:** `GPL-3.0-or-later`, `Unicode-3.0`, `Apache-2.0 WITH LLVM-exception`, `CDLA-Permissive-2.0` — these are valid OSI/FSF licenses that `deny.toml` simply doesn't allow by default
- **Unmaintained advisories:** gtk-rs GTK3 bindings (`RUSTSEC-2024-0411` through `0419`, `0420`), `proc-macro-error` (`RUSTSEC-2024-0370`), `dlopen_derive` (`RUSTSEC-2023-0051`), `unic-*` crates (`RUSTSEC-2025-0080`/`0081`/`0098`)
- **`license-not-encountered` warnings:** These are harmless — they mean you allowed a license in `deny.toml` that no dependency actually uses. No action needed.

**Fix — update `deny.toml`:**
```toml
[advisories]
version = 2
yanked = "warn"
ignore = [
    # gtk-rs GTK3 bindings — unmaintained but still used by Tauri on Linux
    "RUSTSEC-2024-0411", "RUSTSEC-2024-0412", "RUSTSEC-2024-0413",
    "RUSTSEC-2024-0414", "RUSTSEC-2024-0415", "RUSTSEC-2024-0416",
    "RUSTSEC-2024-0417", "RUSTSEC-2024-0418", "RUSTSEC-2024-0419",
    "RUSTSEC-2024-0420",
    # proc-macro-error — pulled in by gtk3-macros
    "RUSTSEC-2024-0370",
    # dlopen_derive — pulled in by midir (MIDI)
    "RUSTSEC-2023-0051",
    # unic-* — pulled in by urlpattern (Tauri)
    "RUSTSEC-2025-0080", "RUSTSEC-2025-0081", "RUSTSEC-2025-0098",
]

[licenses]
version = 2
allow = [
    "MIT", "Apache-2.0", "Apache-2.0 WITH LLVM-exception",
    "BSD-3-Clause", "ISC", "Unicode-DFS-2016", "Unicode-3.0",
    "MPL-2.0", "OpenSSL", "Zlib", "BSL-1.0",
    "GPL-3.0", "GPL-3.0-or-later", "CDLA-Permissive-2.0",
]
```

**Workflow:**
1. Run `cargo deny check` and note the IDs
2. Run `cargo audit | grep "^ID:" | sort | uniq` to get the full RUSTSEC list
3. Add them to `deny.toml` ignore list with comments explaining which top-level dep pulls them in
4. Re-run `cargo deny check` until it passes
5. Commit `deny.toml` changes as part of the ship commit

**Do NOT** add ignore entries for advisories that don't match any crate — `cargo-deny` will error with "no crate matched advisory criteria". Remove stale entries.

See `references/cargo-deny-tauri-config.md` for a full copy-paste `deny.toml` template.
Large Rust projects often have modules that are structurally complete but not yet wired into the main app (MCP tool adapter, gateway platform abstractions, protocol types). These produce `dead_code` warnings that are NOT debt — they're the foundation for the next feature phase.

**Assessment rule:**
- If the item has a clear planned consumer in the next 1-2 development phases → `#[allow(dead_code)]` or leave
- If the item has been unused for 3+ phases with no planned consumer → remove
- If `cargo fix` can auto-remove it → let it (imports, unused mut, etc.)

**Never** remove protocol structs, transport traits, or adapter patterns just because they're not yet wired. Removing them creates rework when the feature is implemented.
