# TOML Config Placement Pitfall

When patching OpenShark's `config.toml`, it's easy to accidentally place a field inside the wrong TOML section due to context drift in `patch` operations.

## The Bug

A `patch` operation intended to add `user_name = "synth"` at root level instead placed it inside `[providers.zai.headers]`:

```toml
[providers.zai.headers]

user_name = "synth"  # WRONG — inside providers.zai.headers section!

[agent]
```

This caused TOML parsing to silently misinterpret `user_name` as a field of `providers.zai.headers` (which expects an empty table or key-value pairs), or the field was simply ignored. The result: the app fell back to the default `user_name = "user"` despite the config appearing to have `user_name = "synth"`.

## Root Cause

The `patch` tool matched on a string that crossed a section boundary. The `old_string` included content from the end of the providers section and the start of the `[agent]` section, causing the replacement to splice the new content in the wrong place.

## Prevention

1. **Always verify config after patching** — `read_file` the result to confirm field placement
2. **Use more unique context** in `old_string` — include surrounding lines that clearly identify the correct section
3. **For root-level fields**, ensure they appear BEFORE any `[section]` headers
4. **For section fields**, include the section header in the `old_string`

## Correct Pattern

```toml
# Root-level fields — BEFORE any [section] headers
version = "1.0.0"
default_model = "kimi-k2.6"
user_name = "synth"  # ✅ Correct — at root level
theme = "synthwave84"

[providers.kimi]
# ...

[agent]
name = "synthclaw"
# ...
```

## Verification

After patching config.toml, always verify:
```bash
# Quick syntax check
toml-test ~/.config/openshark/config.toml 2>/dev/null || echo "TOML invalid"

# Or just read the relevant lines
head -20 ~/.config/openshark/config.toml
```

## Related

- `references/harness-vs-agent-identity-separation.md` — The user_name field's purpose
