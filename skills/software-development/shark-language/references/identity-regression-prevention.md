# Identity Regression Prevention

**Critical pitfall:** The `[agent]` section in `~/.config/openshark/config.toml` can be overwritten by setup wizard re-runs, config patches, or manual edits that accidentally revert to defaults. This causes the agent name to regress from `synthclaw` back to `openshark`.

## Prevention

1. **Always read current config before patching** — preserve existing `[agent]` values
2. **Use `#[serde(default)]`** on new fields so missing fields don't fail deserialization
3. **Setup wizard should detect existing identity** and offer to keep it
4. **`AgentIdentity::default()` returns blank slate values** — user's config overrides these
5. **Never overwrite the entire config file** — patch specific sections only

## Recovery

```bash
# Check current identity
grep -A5 '\[agent\]' ~/.config/openshark/config.toml

# Fix if reverted
sed -i 's/name = "openshark"/name = "synthclaw"/' ~/.config/openshark/config.toml
sed -i 's/display_name = "OpenShark"/display_name = "synthclaw"/' ~/.config/openshark/config.toml
```

## When It Happens

- Running `openshark setup` after initial config is set
- Manual `write_file` to config.toml that replaces entire file
- Config migration from Hermes/OpenShark that doesn't preserve existing agent section
- Git checkout or config restore that overwrites local changes
