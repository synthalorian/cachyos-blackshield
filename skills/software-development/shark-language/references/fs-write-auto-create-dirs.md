# Filesystem Tool — Auto-Create Parent Directories

## Problem

`fs write` failed when writing to a path with non-existent parent directories.
The model would then fall back to using `terminal` tool with `mkdir -p`, which
triggers security approval (High risk) and interrupts the flow.

Meanwhile, `edit write` already auto-created parent directories — the two tools
had inconsistent behavior.

## Fix

Add `fs::create_dir_all()` to `fs write` before `fs::write()`:

```rust
fn cmd_write(args: &str) -> Result<String> {
    let write_parts: Vec<&str> = args.splitn(2, ' ').collect();
    if write_parts.len() < 2 {
        return Ok("Usage: fs write <path> <content>".to_string());
    }
    let path = expand_path(write_parts[0]);
    
    // Auto-create parent directories if needed
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("Failed to create directory for {}", path.display()))?;
    }
    
    fs::write(&path, write_parts[1])
        .with_context(|| format!("Failed to write {}", path.display()))?;
    Ok(format!("Written successfully to {}", path.display()))
}
```

## Lesson

All write-path tools (`fs write`, `edit write`, any future tool that creates files)
must auto-create parent directories. The model assumes this behavior and gets
confused (or triggers unnecessary security prompts) when it doesn't work.

## Test

```rust
#[test]
fn test_fs_write_creates_dirs() {
    let dir = temp_dir();
    let path = format!("{}/deeply/nested/path/test.txt", dir);
    
    let tool = FsTool;
    let result = tool.execute(&format!("write {} Hello World", path)).unwrap();
    
    assert!(result.contains("Written successfully"));
    assert!(std::fs::read_to_string(&path).unwrap().contains("Hello World"));
}
```
