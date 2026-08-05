# Forge Security Audit — v0.3.0 (May 2026)

Full surgical audit of AI-generated code (GLM-5.1). 34 issues found, 14 fixed.

## Triage Framework

| Tier | Label | Criteria |
|------|-------|----------|
| C | **Bleeders** | Exploitable security vulnerabilities |
| H | **Landmines** | Correctness bugs (panics, leaks, race conditions) |
| M | **Meh** | Quality issues (style, naming, structure) |

## Fixed Issues

### C1: Rust Command Injection (bridge.rs, tongs.rs)

**Pattern:** `Command::new("sh").arg("-c").arg(format!("du -sh {}", path))`

User-controlled `path` interpolated into shell command. Any path with `; rm -rf /` or `$(malicious)` executes arbitrary code.

**Fix:** Replace with `std::process::Command` using `.args()` — arguments bypass shell interpretation entirely:
```rust
// BEFORE (vulnerable):
Command::new("sh").arg("-c").arg(format!("du -sh {}", archive_dir)).output()

// AFTER (safe):
Command::new("du").args(["-sh", &archive_dir]).output()
```

Applied to: `bridge.rs` (~line 391), `tongs.rs` (~line 514), `tongs.rs` (~line 475).

### C2: Ruby Command Injection (tongs_controller.rb, bridge_controller.rb, flame_controller.rb, bellows_controller.rb)

**Pattern:** Backtick interpolation and `safe_command` helper:
```ruby
`#{safe_forge_command("backup")} --name #{params[:id]}`
```

The `safe_command` / `safe_forge_command` helpers only gsub'd double quotes — backticks, `$()`, `;`, newlines all passed through.

**Fix:** Full rewrite using `Open3.capture3` with argv arrays:
```ruby
# BEFORE (vulnerable):
`#{safe_forge_command("backup")} --name #{params[:id]}`

# AFTER (safe):
require 'open3'
cmd = forge_binary_path
stdout, stderr, status = Open3.capture3(cmd, "backup", "--name", params[:id])
```

`Open3.capture3` with separate argv elements bypasses shell entirely — no interpolation, no injection.

### C3: Rust unwrap Panics (bridge.rs, mind.rs, anvil.rs)

**Pattern:** `.unwrap()` on operations that can fail at runtime (file reads, command output).

**Fix:** Replace with `if let Ok(...)`, `.unwrap_or("")`, or match with continue:
```rust
// BEFORE (panics on failure):
let output = Command::new(...).output().unwrap();

// AFTER (graceful):
if let Ok(output) = Command::new(...).output() { ... }
```

### C4: Hardcoded `/home/synth/` Paths (bridge.rs, mind.rs)

**Pattern:** `PathBuf::from("/home/synth/.config/llama-swap/config.yaml")`

**Fix:** `env::var("LLAMA_SWAP_CONFIG").unwrap_or_else(|_| format!("{}/.config/llama-swap/config.yaml", home_dir()))`

### C5: UTF-8 Byte Slicing (bridge.rs)

**Pattern:** `&output[..10]` — slices bytes, not chars. Panics on multibyte characters.

**Fix:** `output.chars().take(10).collect::<String>()`

### C6: Box::leak Memory Leak (theme.rs)

**Pattern:** `OnceLock` + `Box::leak` for theme storage — themes were leaked and could never be reloaded.

**Fix:** `Mutex<HashMap<String, Theme>>` with proper `reload_custom_themes()` that clears and reloads.

### C7: HTTP Basic Auth (application_controller.rb)

**Added:** Opt-in HTTP basic auth via `FORGE_HUB_USERNAME` / `FORGE_HUB_PASSWORD` env vars.
- Uses `ActiveSupport::SecurityUtils.secure_compare` to prevent timing attacks
- Backwards compatible — no auth unless username env var is set

### C8: SQLite Connection Leaks (database.rb, flame_controller.rb, bellows_controller.rb)

**Pattern:** `db = SQLite3::Database.new(path); db.execute(...)` without `ensure db.close`.

**Fix:** Wrap all DB access in `begin...ensure db.close` blocks.

### C9: Backup Race Condition (anvil/backups_controller.rb)

**Pattern:** Double-enqueue possible if user clicks backup button twice quickly.

**Fix:** Atomic cache write sentinel before `BackupJob.perform_later`, delete on failure.

### M2: SQL N+1 (statistics.rb)

**Pattern:** Loading 10K rows into Ruby memory, then iterating with `Enumerable#group_by`.

**Fix:** SQL `GROUP BY`, `OVER()`, `FILTER()` aggregates — let the database do the work.

### M4: Path Traversal (anvil/backups_controller.rb)

**Pattern:** `params[:id]` passed directly to filesystem operations.

**Fix:** Validate no `..` in path components before use.

## Audit Patterns Reusable for Future Reviews

### Shell Injection Checklist

1. **Rust:** Search for `Command::new("sh")` or `.arg("-c")` — every instance is a red flag
2. **Ruby:** Search for backtick interpolation (`` `#{...}` ``), `%x{}`, `system("...#{...}")`, `exec("...#{...}")`
3. **False security helpers:** Any `safe_*` function that only sanitizes quotes is insufficient. Shell metacharacters include: `` ; | & $ > < ` () {} \n \r ``

### Rust Panic Checklist

1. `.unwrap()` on `Command::new().output()`, `fs::read_to_string()`, `str::parse()` — all can fail at runtime
2. String slicing `[..n]` on potentially non-ASCII input — panics on multibyte
3. `Box::leak` for "persistent" state — memory leak by definition; use proper static storage

### Ruby Leak Checklist

1. `SQLite3::Database.new` without `ensure db.close`
2. `File.open` without block form
3. Backtick / `%x{}` for shell commands — always prefer `Open3.capture3` with argv arrays

## Files Modified

| File | Fixes Applied |
|------|--------------|
| `src/bridge.rs` | C1 (command injection), C3 (unwrap), C4 (hardcoded path), C5 (UTF-8 slice) |
| `src/tongs.rs` | C1 (command injection) |
| `src/mind.rs` | C3 (unwrap), C4 (hardcoded path), unused import removed |
| `src/anvil.rs` | C3 (unwrap) |
| `src/theme.rs` | C6 (Box::leak), Clone derive, working reload |
| `hub/app/controllers/application_controller.rb` | C7 (HTTP basic auth) |
| `hub/app/controllers/tongs_controller.rb` | C2 (full rewrite: Open3) |
| `hub/app/controllers/bridge_controller.rb` | C2 (which injection), M1 (rescue logging) |
| `hub/app/controllers/flame_controller.rb` | C2 (backtick), C8 (SQLite leak), M1 |
| `hub/app/controllers/bellows_controller.rb` | C2 (injection), M4 (session validation), C8 |
| `hub/app/controllers/anvil/backups_controller.rb` | C9 (race condition), M4 (path traversal) |
| `hub/app/services/forge/database.rb` | C8 (connection leak) |
| `hub/app/services/forge/statistics.rb` | M2 (SQL aggregates) |
