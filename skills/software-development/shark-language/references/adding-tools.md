# Adding a New Tool to OpenShark

Quick reference for the exact steps to add a tool.

## Step 1: Create the tool module

File: `src/tools/<name>.rs`

```rust
use anyhow::{Context, Result};
use super::Tool;

pub struct MyTool;

impl Tool for MyTool {
    fn name(&self) -> &str {
        "mytool"
    }

    fn description(&self) -> &str {
        "What this tool does"
    }

    fn execute(&self, args: &str) -> Result<String> {
        // Parse args, do work, return result
        Ok("done".to_string())
    }
}
```

## Step 2: Register the module

In `src/tools/mod.rs`:

```rust
pub mod mytool;  // Add this line
```

## Step 3: Register in the tool registry

In `src/tools/mod.rs`, in `get_tools()`:

```rust
pub fn get_tools() -> Vec<Box<dyn Tool>> {
    vec![
        Box::new(mytool::MyTool),  // Add this line
        // ... existing tools
    ]
}
```

## Step 4: Verify

```bash
cd /home/synth/projects/openshark
cargo build
```

## Pitfalls

- **Lint false positives**: The write_file lint tool shows style diffs (import ordering, formatting) as "errors". These are NOT actual compilation errors. Always run `cargo build` to verify.
- **Args parsing**: Use `splitn(2, ' ')` for command + rest patterns. Use delimiters like ` ||| ` for multi-part args (replace old ||| new).
- **Path handling**: Use `std::path::Path` for cross-platform paths. Create parent dirs with `fs::create_dir_all` before writing.
