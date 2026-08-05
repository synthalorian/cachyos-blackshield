# Rust Binary Path Discovery Pattern

When an editor/IDE needs to launch a companion binary (e.g., editor launches game binary), resolve the binary relative to the editor's own executable location rather than relying on `$PATH`.

## Problem

The editor binary (`chronos-editor`) tries to spawn `chronos-game` by bare name. This only works if `chronos-game` is in `$PATH`. After a fresh build, the game binary sits in `target/debug/` or `target/release/` — not in PATH.

## Solution

Resolve the companion binary relative to the editor's own executable path:

```rust
fn launch_engine(&mut self) {
    let game_binary = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.join("chronos-game")))
        .filter(|p| p.exists())
        .or_else(|| {
            // Fallback: try debug/ then release/ relative to exe dir
            std::env::current_exe().ok().and_then(|p| {
                let d = p.parent()?;
                let debug = d.join("chronos-game");
                if debug.exists() { Some(debug) } else {
                    let release = d.parent()?.join("release").join("chronos-game");
                    if release.exists() { Some(release) } else { None }
                }
            })
        });

    let mut cmd = match game_binary {
        Some(path) => std::process::Command::new(&path),
        None => {
            // Final fallback: try PATH
            std::process::Command::new("chronos-game")
        }
    };

    match cmd.spawn() { /* ... */ }
}
```

## Resolution Order

1. Same directory as editor executable
2. `debug/` subdirectory (for dev builds)
3. `release/` subdirectory (for release builds)
4. `$PATH` fallback with warning

## Why This Works

- `cargo build --bin chronos-editor` and `cargo build --bin chronos-game` place both binaries in the same `target/debug/` directory
- `std::env::current_exe()` returns the path to the running editor binary
- `.parent()` gives us the directory containing both binaries
- No need to install to `~/.local/bin/` or modify PATH for development

## Related Patterns

- `cargo-install-root-config.md` — for production installs where binaries DO need to be in PATH
- `install-script-pattern.md` — for end-user install scripts that copy binaries to `~/.local/bin/`
