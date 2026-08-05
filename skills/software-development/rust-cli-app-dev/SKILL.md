---
name: rust-cli-app-dev
description: |
  Rust CLI application development — clap derive, cargo dependency management,
  GitHub Actions CI/release, common compile-time pitfalls, and test
  infrastructure for terminal-focused Rust projects like Forge.
trigger_phrases:
  - forge
  - rust cli
  - clap command
  - cargo clippy
  - rust release workflow
  - github actions rust
  - rust compile error
  - rust clippy fix
  - raw string rust
  - gitignore test assets
---

# Rust CLI Application Development

## Project Structure

Typical Rust CLI monorepo:

```
project/
├── src/
│   ├── main.rs          # CLI dispatch
│   ├── cli.rs           # clap derive definitions
│   ├── module_x.rs      # Feature modules (each a command handler)
│   └── module_x_cmd.rs  # CLI-specific output formatting for module
├── tests/               # Integration tests
├── Cargo.toml
├── .github/workflows/
│   ├── ci.yml           # cargo check → fmt → clippy → test
│   └── release.yml      # Tag-triggered binary release
└── assets/              # App icon, branding
```

## Adding CLI Commands with clap

Pattern: define in `cli.rs`, dispatch in `main.rs`, implement in module file.

1. Add enum variant to `Commands` in `cli.rs` with `#[command(about = "...")]`
2. Create args struct if needed (`#[derive(Args)]`)
3. For sub-subcommands, nest `#[derive(Subcommand)]`
4. Wire dispatch in `main.rs` match block
5. Implement the handler in the module file

Aliases: add `alias = "x"` to the `#[command()]` attribute. Multiple aliases:
```rust
#[command(about = "...", alias = "quench", alias = "q")]
```

## Adding Dependencies to Cargo.toml

- `walkdir` is used for filesystem traversal — do NOT remove it
- For image processing: `image = { version = "0.25", default-features = false, features = ["jpeg", "png"] }`
- Requires `use image::GenericImageView;` for `dimensions()` and `pixels()` methods
- `Pixels` iterator does NOT have `.len()` — use `.count()` instead
- The `Pixels` iterator is consumed on first iteration — cache the count before iterating if you need it for both data extraction and display

### Custom Terminal Markdown Renderer

Forge-style `forge melt markdown` implements a full custom markdown renderer using the project's theme system (no external crate). Architecture:

**Block-level handlers** (checked in order, per-line state machine):
1. Fenced code blocks (```) — toggle `in_code_block`, draw `┌─`/`│`/`└─` borders with language tag
2. Blank lines — reset blockquote/list state
3. Thematic breaks (`---`, `***`, `___`) — `style_border`
4. Blockquotes (`> `) — `style_muted` with `▍` margin marker
5. Headers (H1-H6) — route to theme styles by level: H1→`style_bold_header`, H2→`style_header`, H3→`style_accent`, H4-H6→`style_muted`
6. Lists — `•` for unordered, numbered bullets for ordered
7. Paragraphs — `style_value` with inline formatting applied

**Inline formatting** (`inline_format` helper function):
- `**bold**` → ANSI bold (`\x1b[1m`) + theme accent color
- `*italic*` → ANSI italic (`\x1b[3m`) + theme muted color
- `` `code` `` → theme value color
- `[text](url)` → theme accent text + theme muted URL in parentheses
- `\` escape — next character literal

**Input modes:** file path, `-` for explicit stdin, no arg (reads stdin). First `# H1` becomes the doc title banner.

### Patch Tool: Cross-Function Collision

When using `patch` on a file where two functions have similar patterns (e.g., both print a `style_bold_header`), the patch tool may match the wrong function. Use enough unique context lines (5+) to guarantee a single match — include the function signature and at least one distinct line below the pattern.

## Rust Module Naming Pitfalls

### NEVER name a module `test.rs`

**Problem:** Rust's built-in `test` attribute system (`#[test]`, `#[cfg(test)]`) conflicts with a module named `test.rs`. The compiler gives a misleading error:

```
error[E0599]: no method named `execute` found for struct `TestTool` in the current scope
```

Even though `cargo expand` shows the impl is correct, the compiler silently fails to resolve the trait implementation. This happens because `test` is a reserved name in Rust's module system.

**Fix:** Rename the module to anything else — `test_runner.rs`, `testing.rs`, `tests.rs`:

```bash
mv src/tools/test.rs src/tools/test_runner.rs
```

Then update `mod.rs`:
```rust
// WRONG:
pub mod test;

// CORRECT:
pub mod test_runner;
```

**Other reserved module names to avoid:** `main.rs`, `lib.rs`, `mod.rs` (these are special entry points, not regular modules), `bench.rs` (conflicts with benchmark harness).

### NEVER name a module `main.rs` inside `src/`

A file at `src/some_module/main.rs` creates a binary target named `some_module` in Cargo's target auto-discovery. This causes `cargo build` to try compiling it as a separate binary, which usually fails because it expects a `fn main()`.

**Fix:** Use `src/some_module/mod.rs` or `src/some_module/core.rs` instead.

## Common Rust Compile Fixes

### Raw String (`r#"..."#`) with `"#` inside

**Problem:** `format!(r#"red = "#{er:02x}"#, ...)` — the `"#` in the string content closes the raw string prematurely.

**Fix:** Use `r##"..."##` (double hash) as the raw string delimiter when the content contains `"#`:
```rust
format!(r##"red = "#{er:02x}"##, er = theme.error.r)
```

### `style_border` / `style_*` expects `&str`

**Problem:** `style_border("─".repeat(48), theme)` — these functions take `&str`, not `String`.

**Fix:** Borrow: `style_border(&"─".repeat(48), theme)`

### Result::ok() → match on Some

**Problem:** `if let Some(x) = val.parse::<f64>().ok()` — clippy `match_result_ok`.

**Fix:** Use `if let Ok(x) = val.parse::<f64>()` directly.

### sort_by → sort_by_key

**Problem:** `sorted.sort_by(|a, b| b.1.cmp(&a.1))` — clippy flags this.

**Fix:** `sorted.sort_by_key(|(_, count)| Reverse(*count))` with `use std::cmp::Reverse;`

## Embedded HTTP API (Axum) in CLI Binaries

When a Rust CLI needs a local HTTP API (for web dashboard, health endpoint, etc.), embed Axum directly:

### Cargo.toml additions
```toml
axum = "0.8"
tower-http = { version = "0.6", features = ["cors"] }
tokio = { version = "1", features = ["full"] }  # already needed for async main
```

### Thread-safe shared state with rusqlite

**CRITICAL GOTCHA:** `rusqlite::Connection` uses `RefCell` internally and is NOT `Sync`. You cannot wrap it in `Arc<Connection>` and share across Axum handlers.

```rust
// WRONG — Connection is not Sync:
pub struct AppState {
    pub db: Arc<Connection>,  // compile error!
}

// CORRECT — wrap in Mutex:
pub struct AssetDb {
    conn: Mutex<Connection>,
}
```

Every database method acquires the lock:
```rust
pub fn upsert_asset(&self, path: &str, sha256: &str) -> Result<()> {
    let conn = self.conn.lock().unwrap();
    conn.execute("INSERT INTO ...", params![path, sha256])?;
    Ok(())
}
```

Then `Arc<AssetDb>` works because `Mutex<T>` is `Sync` when `T` is `Send`, and `Connection` is `Send`.

### Server lifecycle

The API server runs in a `tokio::spawn` task alongside the CLI's main loop:

```rust
#[tokio::main]
async fn main() -> Result<()> {
    // Start API in background
    let api_db = db.clone();  // AssetDb is Clone if you impl it
    tokio::spawn(async move {
        rift::api::serve(api_db, port).await
    });

    // Main CLI logic continues here
    let runner = Runner::new(db);
    watcher.watch(&config)?;
    Ok(())
}
```

### CORS for local development

```rust
let cors = CorsLayer::new()
    .allow_methods([Method::GET, Method::POST])
    .allow_origin(Any)
    .allow_headers(Any);
```

### Axum handler signatures (v0.8)

In axum 0.8, handlers take `State(state): State<ApiState>` directly:

```rust
async fn handle_status(
    State(state): State<ApiState>,
) -> Json<StatusResponse> {
    let counts = state.db.get_asset_counts().unwrap_or_default();
    Json(StatusResponse { asset_counts: counts })
}
```

### Axum 0.8 Path Parameters: Use `{name}` Not `:name`

**CRITICAL PITFALL:** Axum 0.8 changed path parameter syntax from `:param` to `{param}`. Using the old `:param` syntax causes a **runtime panic** at server startup, not a compile error:

```rust
// WRONG — panics at startup with "Path segments must not start with `:`":
let app = Router::new()
    .route("/skills/:name/toggle", post(handler))  // runtime panic!

// CORRECT — uses `{name}` syntax:
let app = Router::new()
    .route("/skills/{name}/toggle", post(handler))
```

**The panic message:** `thread 'main' panicked at src/main.rs:N:10:\nPath segments must not start with ':'. For capture groups, use '{capture}'. If you meant to literally match a segment starting with a colon, call 'without_v07_checks' on the router.`

**Axum 0.7 vs 0.8 path syntax:**

| Axum version | Path parameter | Wildcard |
|-------------|----------------|----------|
| 0.7 | `:id` | `/*path` |
| 0.8 | `{id}` | `{*path}` |

**Why it's insidious:** The `:param` syntax doesn't fail at compile time — it only fails at runtime when `main()` calls `axum::serve(listener, app)`. The binary compiles fine, starts fine, and crashes the moment `serve()` checks the route table.

**Audit pattern:** Search all route definitions for `:param` patterns:

```bash
grep -n 'route.*:"/' backend/src/*.rs | grep -E '":[a-z]'  # Finds stale :param routes
```

## Dynamic SQL Parameter Numbering with rusqlite

When building SQL queries with optional WHERE filters, numbered params (`?1`, `?2`, `?3`) must match actual parameter count. If you write `LIMIT ?2 OFFSET ?3` but only pass 2 params (no filter), rusqlite will error with `InvalidParameterCount`.

**BEST APPROACH:** Use separate SQL strings per filter variant instead of dynamic concatenation:

```rust
fn get_assets(&self, status_filter: Option<&str>, limit: u32, offset: u32) -> Result<Vec<AssetRecord>> {
    let (sql, params) = match status_filter {
        Some(s) => (
            "SELECT ... FROM assets WHERE status = ?1 ORDER BY ... LIMIT ?2 OFFSET ?3",
            vec![Box::new(s.to_string()), Box::new(limit as i64), Box::new(offset as i64)],
        ),
        None => (
            "SELECT ... FROM assets ORDER BY ... LIMIT ?1 OFFSET ?2",
            vec![Box::new(limit as i64), Box::new(offset as i64)],
        ),
    };
    // Use params_from_iter with the Vec<Box<dyn ToSql>>
    let rows = stmt.query_map(
        rusqlite::params_from_iter(params.iter().map(|p| p.as_ref())),
        |row| { Ok(AssetRecord { ... }) },
    )?;
}
```

**Do NOT use** dynamic `format!()` to insert `WHERE status = ?N` into a template — the numbered params shift and you'll get `InvalidParameterCount` on the unfiltered variant.

## `notify` Crate (v7) File Watcher

File watcher uses channel-based architecture:

```rust
use notify::{Config, Event, RecommendedWatcher, RecursiveMode, Watcher};
use std::sync::mpsc;

let (tx, rx) = mpsc::channel::<notify::Result<Event>>();
let mut watcher = RecommendedWatcher::new(tx, Config::default())?;
watcher.watch(&path, RecursiveMode::Recursive)?;

for event in rx {
    match event {
        Ok(event) => { /* handle */ }
        Err(e) => { /* warn */ }
    }
}
```

**Debounce pattern:** Collect events and batch-trigger after a short delay:
```rust
let debounce = Duration::from_millis(500);
let mut last_trigger = Instant::now();
for event in rx {
    match event {
        Ok(_) if last_trigger.elapsed() >= debounce => {
            run_pipeline();
            last_trigger = Instant::now();
        }
        _ => {}
    }
}
```

## image Crate Feature Flags

| Format | Feature flag | Available in 0.25 |
|--------|-------------|-------------------|
| JPEG | `jpeg` | ✅ |
| PNG | `png` | ✅ |
| WebP | `webp` | ✅ |
| TIFF | `tiff` | ✅ |
| BMP | `bmp` | ✅ |
| PSD | `psd` | ❌ (not in 0.25) |

PSD support is **NOT** available in `image` 0.25. If you need to handle PSD files, either:
- Fall back to copying the PSD as-is (with original extension in the target directory)
- Use a separate library or imagemagick conversion

```rust
// Graceful fallback for unsupported formats:
match image::open(source) {
    Ok(img) => { /* process and convert */ }
    Err(_) => {
        // Format not supported — copy as-is
        let fallback = target.project.join(&format!("{}.psd", stem));
        std::fs::copy(source, &fallback)?;
    }
}
```

## Rust CLI + Rails Hub Sidecar Pattern

When a Rust CLI needs a web dashboard companion, structure the project with a `hub/` directory containing a Rails 8 app that reads the same SQLite database:

```
project/
├── src/                # Rust CLI (binary)
├── hub/                # Rails 8 web app (dashboard)
│   ├── app/
│   │   ├── controllers/
│   │   ├── views/
│   │   └── services/   # RiftDb service reads the SQLite DB
│   ├── config/
│   └── .rift/          # Symlink or copy of the shared state.db
├── Cargo.toml
├── Gemfile             # Only needed if hub/ has standalone gem dependencies
└── rift.yml            # Pipeline config (shared config)
```

### Database Sharing Strategy

The Rails app reads the Rust CLI's SQLite database directly. No API server needed — the Rails app uses a service object to query the same `.rift/state.db` file:

- **Rust side**: creates the DB in `.rift/state.db` with schema managed by `rusqlite::Connection::execute_batch`
- **Rails side**: a `RiftDb` service class reads the same file using raw `SQLite3::Database` queries
- **No ActiveRecord**: Rails doesn't manage the schema — it's read-only from the Rails perspective
- **Sync**: simply `cp .rift/state.db hub/.rift/state.db` when you want the dashboard to reflect current state

```ruby
# hub/app/services/rift_db.rb (SQLite3 v2.x — returns arrays, not hashes)
class RiftDb
  class << self
    def connection
      @connection ||= SQLite3::Database.new(db_path)
    end

    def recent_runs(limit: 10)
      query("SELECT id, timestamp, status, converted, errors FROM pipeline_runs ORDER BY timestamp DESC LIMIT ?", limit)
        .map { |row| { "id" => row[0], "timestamp" => row[1], ... } }
    end

    private

    def query(sql, *params)
      connection.execute(sql, params)
    end

    def find_db_path
      dir = Rails.root
      5.times do
        candidate = dir.join(".rift", "state.db")
        return candidate.to_s if File.exist?(candidate)
        dir = dir.parent
      end
      ENV["RIFT_DB_PATH"] || File.join(Rails.root, ".rift", "state.db")
    end
  end
end
```

### SQLite3 Ruby Gem v2.x API Differences

**CRITICAL GOTCHA:** SQLite3 v2.x (2.9.x) returns arrays from `execute()`, NOT hashes:

| Version | `execute()` returns | Access pattern |
|---------|-------------------|----------------|
| v1.x | `[{"col" => val}, ...]` | `row["col"]` |
| v2.x | `[["val"], ...]` | `row[0]`, `row[1]` |

To get hash-like access, map manually:
```ruby
query("SELECT id, name FROM assets").map { |row|
  { "id" => row[0], "name" => row[1] }
}
```

### Project-Level .gitignore for Rust + Rails

```gitignore
/target/
hub/log/*
hub/tmp/*
hub/storage/*
hub/db/*.sqlite3
hub/vendor/bundle/
*.db
.ruff_cache/
.omo/
```

### When to Use the Rust-Embedded API vs Rails Direct DB

- **Rust embedded API** (Axum on :8910): Use when the Rails app runs on a different machine, or when you need real-time data from a running process (watcher daemon)
- **Rails direct DB** (SQLite file read): Use for simple dashboards that just need to display historical/state data — no server coupling, simpler deployment

For Rift, we use the direct DB approach: the Rust CLI writes to `.rift/state.db`, the Rails Hub reads it. The Axum API is available for external tooling.

## Pipeline Engine Pattern (Graceful Error Recovery)

When building a data pipeline (asset processing, batch conversion, ETL), use this Rust pattern for per-item error handling that prevents one bad file from crashing the whole run:

```rust
// Core pattern: wrap each item in a Result, catch errors, continue
let mut results = Vec::new();
for item in item_list {
    let result = match process_item(item) {
        Ok(r) => r,
        Err(e) => {
            warn!("  ✗ Failed {}: {}", item_name, e);
            error_log.record_failure(item, &e);
            ProcessResult { success: false, error: Some(e.to_string()), ..default() }
        }
    };
    results.push(result);
}
```

### Content-Hash Caching

Skip already-processed items using SHA256 content hashing:

```rust
// Database tracks (path, sha256, status)
fn needs_conversion(path: &str, current_hash: &str, db: &Db) -> bool {
    match db.get_status(path) {
        Ok(status) if status.sha256 == current_hash => false,  // unchanged
        _ => true,  // new or changed
    }
}
```

This prevents re-processing files that haven't changed between runs.

### YAML-Driven Rules Engine

Parse rules from YAML config rather than hardcoding:

```rust
// Config defines: what to do with each file type
rules:
  - pattern: "**/*.{png,jpg}"
    convert: textures
  - pattern: "**/*.{wav,mp3}"
    convert: audio
  - pattern: "**/*.{fbx,gltf}"
    convert: models
    validate: true

// Rust matches files to rules using glob patterns
let matched_rule = config.rules.iter().find(|rule| {
    Pattern::new(&rule.pattern)
        .ok()
        .map_or(false, |p| p.matches(&relative_path))
});
```

## CI/CD
- Runs on push to main + PRs to main
- Steps: `cargo check` → `cargo fmt --all -- --check` → `cargo clippy --all-targets -- -D warnings` → `cargo test`
- Needs `dtolnay/rust-toolchain@stable` and `Swatinem/rust-cache@v2`

### Release workflow (release.yml)
- Triggered by `v*` tag push
- **Must have** `permissions: contents: write` at the workflow level or the release step will 403:
  ```yaml
  permissions:
    contents: write
  ```
- Uses `softprops/action-gh-release@v2` with `generate_release_notes: true`

### Managing releases
- Tag management: `git tag -d v0.x.0 && git push origin :refs/tags/v0.x.0 && git tag v0.x.0 && git push origin v0.x.0`
- The tag always points to the latest commit — if you push a fix after tagging, delete and recreate the tag

## Test Assets

- If a `.gitignore` has `*.db`, test assets like `src/spirit/bible.db` are ignored
- Force-track with: `git add -f src/spirit/bible.db`
- This is necessary for CI where the file must exist but the pattern blocks it

## Security & Safety Pitfalls

### Shell Injection via `format!` + `sh -c`

**NEVER** interpolate user-controlled strings into shell commands:
```rust
// VULNERABLE — path with "; rm -rf /" executes arbitrary code:
Command::new("sh").arg("-c").arg(format!("du -sh {}", path)).output()

// SAFE — arguments bypass shell entirely:
Command::new("du").args(["-sh", &path]).output()
```

Rule: If you see `Command::new("sh").arg("-c")`, it's almost certainly a bug. Use the target binary directly with `.args()`.

## Progress Bars with indicatif + rayon

When running parallel workloads with rayon, a shared `AtomicUsize` counter bridges the gap between parallel processing and linear progress display:

```rust
use indicatif::{ProgressBar, ProgressStyle};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

let pb = ProgressBar::new(jobs.len() as u64);
pb.set_style(
    ProgressStyle::default_bar()
        .template("{spinner:.cyan} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len}  {msg}")
        .unwrap()
        .progress_chars("=> "),
);
pb.set_message("processing...");

let completed = Arc::new(AtomicUsize::new(0));
let pb_arc = Arc::new(pb);

let results: Vec<Result> = jobs.par_iter().map(|job| {
    pb_arc.set_message(format!("{} — {}", job.name, job.kind));
    let result = process(job);
    let done = completed.fetch_add(1, Ordering::SeqCst) + 1;
    pb_arc.set_position(done as u64);
    result
}).collect();

pb_arc.finish_and_clear();
```

**Why this works:** `Arc<AtomicUsize>` is `Send + Sync` — multiple rayon threads can atomically increment it. `Arc<ProgressBar>` is cloned cheaply and each thread sets position from the atomic counter. The `set_message` shows the current asset being processed (last writer wins on each tick — good enough for visual feedback).

## ffmpeg Subprocess for Media Conversion

For reliable audio/video format conversion without heavy Rust deps, shell out to ffmpeg via `std::process::Command`:

```rust
use std::process::{Command, Stdio};

fn encode_audio(source: &Path, output: &Path, quality: f64) -> Result<(), Error> {
    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent)?;
    }

    let status = Command::new("ffmpeg")
        .args([
            "-i", &source.to_string_lossy(),
            "-codec:a", "libvorbis",
            "-q:a", &quality.to_string(),
            "-y",  // overwrite output
            &output.to_string_lossy(),
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .status();

    match status {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("ffmpeg exited with code {}", s).into()),
        Err(e) => Err(format!("ffmpeg not found: {}", e).into()),
    }
}
```

**Key points:**
- Use `.args()` with individual string slices — NO shell interpolation, no `sh -c`
- `.stdout(Stdio::null())` suppresses ffmpeg's verbose output
- `.stderr(Stdio::piped())` captures errors (read with `.stderr` on the child)
- `-y` flag overwrites output files without prompting
- Check return status instead of parsing stderr for success detection
- Test with real file output and check magic bytes: `&header[0..4] == b"OggS"`

### `Box::leak` + `OnceLock` for "Reloadable" State

`Box::leak` allocates memory that can never be reclaimed. Combined with `OnceLock`, it creates state that is both leaked AND immutable — calling "reload" does nothing because `OnceLock` only sets once:
```rust
// WRONG — leaked, can never reload:
static THEMES: OnceLock<Vec<Theme>> = OnceLock::new();
THEMES.set(Theme::load_all()); // leaked, and set() fails on second call

// CORRECT — proper mutable static with reload support:
static THEMES: Mutex<HashMap<String, Theme>> = Mutex::new(HashMap::new());
// lock, clear, re-insert on reload
```

### Async Trait Dyn Compatibility

Rust async traits are not dyn-compatible. Three patterns to handle this:
1. **Enum wrapper** (recommended for closed sets) — zero-cost, no deps
2. **`async-trait` crate** — open plugin systems, adds heap alloc per call
3. **Manual future boxing** — no external deps, verbose

OpenShark uses enum wrapper for MCP transports. See `references/rust-async-trait-dyn-compatibility.md` for full comparison.

### UTF-8 Byte Slicing Panics

`&string[..10]` slices bytes, not characters. On any multibyte UTF-8 (emoji, CJK, accented chars), this panics at runtime:
```rust
// WRONG — panics on "héllo":
let first = &output[..10];

// CORRECT — chars() iterator respects character boundaries:
let first: String = output.chars().take(10).collect();
```

### `.unwrap()` on Runtime Operations

`.unwrap()` is fine for invariant assertions in tests. On runtime operations (file I/O, command output, parsing), it turns recoverable errors into panics:
```rust
// WRONG — panics if file doesn't exist:
let config = fs::read_to_string(&path).unwrap();

// CORRECT — graceful degradation:
if let Ok(config) = fs::read_to_string(&path) { ... }
// or:
let config = fs::read_to_string(&path).unwrap_or_default();
```

Audit targets: `Command::new().output().unwrap()`, `str::parse().unwrap()`, `fs::read().unwrap()`, `Path::exists().unwrap()` (doesn't even exist — but you get the idea).

## Cargo Build Cache Invalidation

When you edit source files but the compiled binary doesn't reflect changes, Cargo's fingerprint cache may be stale. Symptoms:
- `cargo build --release` finishes in <1 second ("Fresh" instead of compiling)
- `strings target/release/<bin>` shows old string literals
- Binary size/timestamp unchanged after source edits
- Running the binary shows old behavior

**Root causes:**
1. Cargo fingerprint cache thinks the file is unchanged (mtime issues, or edits outside cargo's watch)
2. The binary in `PATH` (`~/.local/bin/`, `~/.cargo/bin/`) is a **different copy** than the one cargo built

**Fix — force rebuild:**
```bash
cd /path/to/project
rm -rf target/release/.fingerprint/<crate>* target/release/deps/<crate>* target/release/<bin>
cargo build --release
```

**Fix — stale binary in PATH (most common):**
```bash
# Check which binary is actually running
which <bin>              # e.g., ~/.local/bin/chronos-editor
ls -la $(which <bin>)   # check timestamp — is it from the recent build?

# If timestamp is old, the PATH binary is stale
cp target/debug/<bin> ~/.local/bin/<bin>
# Or use cargo install --path . (preferred, see below)
```

**Verification:** After rebuild, check the binary contains new strings:
```bash
strings target/release/<bin> | grep "your_new_string"
```

Note: `strip = true` in `[profile.release]` removes debug symbols — `strings` may not find your literals. Use `strip = false` temporarily for verification, or check behavior instead.

## Cargo Install Root Configuration

To make `cargo install` place binaries in `~/.local/bin/` (matching XDG spec and most Linux PATH setups):

```bash
mkdir -p ~/.cargo
cat > ~/.cargo/config.toml << 'EOF'
[install]
root = "/home/synth/.local"
EOF
```

Then `cargo install --path .` from any project will install to `~/.local/bin/<bin>`.

**Why this matters:** Without this config, `cargo install` defaults to `~/.cargo/bin/`. If your PATH has `~/.local/bin` before `~/.cargo/bin`, you end up running stale binaries from `~/.local/bin` while cargo installs fresh ones to `~/.cargo/bin`.

**Preferred workflow for development:**
```bash
cd ~/projects/openshark
cargo install --path .  # Builds release + installs to ~/.local/bin
```

This is superior to `cargo build --release && cp target/release/openshark ~/.local/bin/` because:
1. It's one command, not two
2. It respects the install root config
3. It handles binary stripping and permissions automatically
4. It updates the cargo install registry (for `cargo install --list`)

**When the user says the binary hasn't changed after building:**
1. Check `which openshark` — is it the binary you think it is?
2. Check `ls -la $(which openshark)` — timestamp should match recent build
3. If timestamp is old, the binary in PATH is stale
4. Fix: `cargo install --path .` (preferred) or `cp target/release/openshark ~/.local/bin/`
5. **NEVER assume `cp target/release/<bin> ~/.local/share/<app>/<bin>` is sufficient** — check `which <bin>` first to find the actual PATH location

## Clippy Discipline

Run before each commit:
```bash
cargo fmt --all
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
```
