# OpenShark Filesystem Tool Expansion Pattern

Session: 2026-06-01 — Expanding `fs` tool from 3 commands (read/write/list) to 8 commands with user-configurable directory scope, security sandbox integration, and system prompt injection.

## Problem

OpenShark's `fs` tool was too limited (read/write/list only). When users asked questions like "why aren't my local models showing up?", the model couldn't browse configs, inspect directories, or search for files — it would claim it had "no window into the user's machine."

## Solution Overview

1. **Add `FilesystemConfig`** to `Config` with `allowed_paths`, `max_file_size_mb`, `max_list_entries`
2. **Expand `FsTool`** with `tree`, `stat`, `glob`, `find`, `cat` commands
3. **Update security sandbox** to use `allowed_paths` as a whitelist
4. **Inject filesystem capabilities** into the system prompt so the model knows it can browse
5. **Update setup wizard** to ask for allowed directories

## Files Modified

| File | What Changed |
|------|-------------|
| `src/config/mod.rs` | Added `FilesystemConfig` struct, added `filesystem` field to `Config` |
| `src/tools/fs.rs` | Rewrote with 8 commands + tests |
| `src/security/sandbox.rs` | Added `allowed_paths` to `Sandbox`, `is_in_allowed_paths()`, `set_allowed_paths()` |
| `src/security/mod.rs` | Added `allowed_paths` to `SecurityConfig`, sync from `config.toml` at load time |
| `src/tui/mod.rs` | Injected filesystem capabilities into system prompt |
| `src/config/setup.rs` | Added "Filesystem Access" step to setup wizard |
| `src/agent/mod.rs` | Added `filesystem` field to `infer_config()` |
| `src/router/mod.rs` | Added `filesystem` field to test `Config` constructors |
| `src/self_improve/mod.rs` | Added `filesystem` field to test `Config` constructor |

## FilesystemConfig

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilesystemConfig {
    #[serde(default)]
    pub allowed_paths: Vec<String>,
    #[serde(default = "default_max_file_size_mb")]
    pub max_file_size_mb: usize,
    #[serde(default = "default_max_list_entries")]
    pub max_list_entries: usize,
}
```

TOML:
```toml
[filesystem]
allowed_paths = ["/home/synth"]
max_file_size_mb = 10
max_list_entries = 500
```

## FsTool Commands

| Command | Description |
|---------|-------------|
| `fs read <path>` | Read entire file |
| `fs cat <path> [offset] [limit]` | Read with line numbers + pagination |
| `fs write <path> <content>` | Write content |
| `fs list <path>` | Directory listing with sizes + timestamps |
| `fs tree <path> [depth]` | Recursive tree (default depth 3) |
| `fs stat <path>` | File metadata (size, dates, permissions) |
| `fs glob <pattern>` | Pattern matching (e.g., `**/*.toml`) |
| `fs find <path> <name>` | Find files by name under path |

## Security Sandbox Integration

The sandbox now checks `allowed_paths` **before** `working_dir`:

```rust
if !self.allowed_paths.is_empty() {
    // Check each extracted path against allowed_paths
    // Return Err if any path is outside all allowed directories
    return Ok(()); // All paths valid
}
// Fall through to working_dir check (legacy behavior)
```

**Critical:** `SecurityConfig::load()` syncs `allowed_paths` from the main `config.toml`:

```rust
// In SecurityConfig::load()
let main_config_path = config_dir.join("config.toml");
if main_config_path.exists() {
    if let Ok(content) = std::fs::read_to_string(&main_config_path) {
        if let Ok(main_config) = toml::from_str::<crate::config::Config>(&content) {
            if !main_config.filesystem.allowed_paths.is_empty() {
                config.allowed_paths = main_config.filesystem.allowed_paths.clone();
            }
        }
    }
}
```

This is necessary because `SecurityConfig` loads from `security.toml` separately from `Config`.

## System Prompt Injection

The TUI constructs a filesystem capabilities description and injects it into the system prompt:

```rust
let fs_capabilities = if config.filesystem.allowed_paths.is_empty() {
    "You have FULL filesystem access to the entire system. \
     You can read, write, list, and search any directory.".to_string()
} else {
    let paths = config.filesystem.allowed_paths.join(", ");
    format!(
        "You have filesystem access to the following directories: {}. \
         You can read files, list directories, search for files, and inspect configs. \
         Use the fs tool to explore: fs read <path>, fs list <path>, \
         fs tree <path>, fs find <path> <name>, fs glob <pattern>, \
         fs stat <path>, fs cat <path> [offset] [limit].",
        paths
    )
};
```

This tells the model explicitly that it has filesystem access and HOW to use it.

## Setup Wizard Integration

Added after the gateway configuration step:

```
📁 Filesystem Access
─────────────────────
Allowed directories (comma-separated, or 'all' for no restriction): [/home/synth]
```

- Default: user's home directory
- `all` → empty `allowed_paths` → no restriction
- Comma-separated paths → restricted to those directories

## Test Helpers — The Config Field Propagation Problem

Adding a new field to `Config` requires updating **every** test helper that constructs `Config`. In this session, these needed `filesystem: FilesystemConfig::default()`:

- `src/config/mod.rs::create_test_config()`
- `src/router/mod.rs::create_test_config()`
- `src/router/mod.rs::create_test_config_with_small_context()`
- `src/self_improve/mod.rs::create_test_config()`
- `src/agent/mod.rs::infer_config()`

**Rule:** When adding a field to `Config`, search for all `Config { ... }` literals and add the new field with its default.

## Pitfall: `~` Path Expansion in Tests

The sandbox's `extract_paths_from_args()` extracts `~/.config/test` as a path string, but `is_in_allowed_paths()` does `canonicalize()` on both the path and allowed path. If the allowed path is literally `"~"`, canonicalize fails because `~` is not a real path — it's a shell expansion.

**Fix:** Expand `~` with `shellexpand::tilde()` before storing in `allowed_paths`, or use `dirs::home_dir()` in tests.

## Pitfall: Empty String Split Behavior

`"".splitn(2, ' ')` returns `[""]` (len=1), not `[]`. The `FsTool::execute()` checks `parts.len() < 2` to return USAGE. Tests must check for `"Filesystem"` or `"filesystem"` in the output, not `"Usage"`.
