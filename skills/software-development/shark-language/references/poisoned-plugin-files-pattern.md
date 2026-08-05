# Poisoned Plugin/Config Files Pattern

## Problem

External files on disk can contain garbage data (HTTP error responses, truncated downloads, corrupted writes) that causes cryptic failures in seemingly unrelated parts of the system.

**Real case:** The `agentmemory` plugin at `~/.hermes/plugins/agentmemory/package.json` contained:
```
404: Not Found
```

This was written by a failed curl/download that saved the HTTP error response instead of the actual file. When Jest (invoked by OpenShark's `test` tool) scanned the directory tree, it tried to parse this as JSON and exploded with:
```
Error: Cannot parse /home/synth/.hermes/plugins/agentMemory/package.json as JSON:
Unexpected non-whitespace character after JSON at position 3 (line 1 column 4)
```

The error appeared to come from OpenShark's test tool, but the root cause was a poisoned external file.

## Detection Pattern

When you see parse errors on files that should be machine-generated:

1. **Check the raw bytes** — don't trust `cat`:
   ```bash
   od -c /path/to/suspicious/file
   # or
   cat -A /path/to/suspicious/file
   ```

2. **Look for HTTP status codes** in file contents:
   - `404: Not Found`
   - `403: Forbidden`
   - `500: Internal Server Error`
   - `301: Moved Permanently`
   - HTML tags (`<html>`, `<!DOCTYPE`)

3. **Check file size** — poisoned files are often very small:
   ```bash
   ls -la /path/to/file
   # A real package.json is usually 200+ bytes
   # A 404 response is ~14 bytes
   ```

4. **Verify with hex dump**:
   ```bash
   od -c /home/synth/.hermes/plugins/agentmemory/package.json
   # 0000000   4   0   4   :       N   o   t       F   o   u   n   d
   # 0000016
   ```

## Common Causes

| Cause | Signature | Fix |
|-------|-----------|-----|
| Failed curl with `-o` | HTTP status line in file | Re-download, verify with `file` command |
| Failed wget | HTML error page in file | Re-download, check exit code |
| npm/pip install failure | Partial package, missing files | Clear cache, reinstall |
| Disk full during write | Truncated file, missing closing braces | Free space, regenerate |
| Concurrent write collision | Mixed content from two sources | Use atomic writes (write temp, rename) |
| Masked output written to file | Literal `***` instead of actual value | Restore from backup, never write secrets via tools |

## Prevention

- **Verify downloads:** Check HTTP status code before writing to disk
- **Atomic writes:** Write to temp file, then `mv` to final location
- **Checksum verification:** Compare SHA256 after download
- **Health checks:** Validate JSON/TOML/YAML after writing
- **Cleanup on failure:** Remove partial files if download fails

## Quick Fix

```bash
# Remove poisoned files
rm -rf ~/.hermes/plugins/agentmemory

# Or if you need the plugin, re-install from a known-good source
# (don't just re-run the same curl command that failed)
```

## Related

- `references/env-file-corruption-detection.md` — Similar pattern for `.env` files corrupted by masked output
