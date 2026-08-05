# Security Config Override Pitfall

## Problem

OpenShark's `SecurityConfig` has defaults in code (`src/security/mod.rs`), but these are **overridden** by `~/.config/openshark/security.toml` if it exists. Changing code defaults has no effect if a saved config file already exists.

## Symptom

Code says `auto_approve_risk_level = RiskLevel::High`, but the user still gets permission prompts for `fs` write operations. The security message shows:

```
🔒 Security: Tool 'fs' requires approval
Reason: Risk level 'High' exceeds auto-approve threshold (autonomous=false)
Risk: High
```

## Root Cause

The `security.toml` was created earlier with `auto_approve_risk_level = "Medium"` and persists across sessions:

```toml
# ~/.config/openshark/security.toml
auto_approve_risk_level = "Medium"  # ← overrides code default
```

## Fix

Edit the saved config, not the code:

```bash
# Check current value
cat ~/.config/openshark/security.toml | grep auto_approve

# Fix it
sed -i 's/auto_approve_risk_level = "Medium"/auto_approve_risk_level = "High"/' \
    ~/.config/openshark/security.toml
```

## Risk Level Behavior

| Level | Auto-approves | Requires approval |
|-------|---------------|-------------------|
| `Low` | Low only | Medium, High, Critical |
| `Medium` | Low, Medium | High, Critical |
| `High` | Low, Medium, High | Critical only |

**Recommended for coding:** `High` — only `rm -rf`, `mkfs`, `dd`, `fdisk` (Critical) will prompt.

## How It Works

```rust
// src/security/mod.rs
impl SecurityConfig {
    pub fn load() -> Result<Self> {
        let path = config_dir().join("openshark").join("security.toml");
        if path.exists() {
            // ← SAVED CONFIG TAKES PRECEDENCE
            let content = std::fs::read_to_string(&path)?;
            let config: SecurityConfig = toml::from_str(&content)?;
            config
        } else {
            // ← CODE DEFAULT ONLY IF NO FILE EXISTS
            let config = SecurityConfig::default();
            config.save()?;  // Creates the file!
            config
        }
    }
}
```

**Critical:** The first time OpenShark runs, it creates `security.toml` from code defaults. After that, code changes to defaults are **ignored** unless the file is deleted or edited.

## Prevention

When debugging permission issues:

1. **Always check the saved config first:**
   ```bash
   cat ~/.config/openshark/security.toml
   ```

2. **Compare against code defaults:**
   ```bash
   grep -A2 "auto_approve_risk_level" src/security/mod.rs
   ```

3. **If they differ, the saved config is the source of truth.**

## Related

- `auto_approve_risk_level` is serialized as a string enum: `"None"`, `"Low"`, `"Medium"`, `"High"`, `"Critical"`
- Tool permissions are also in `security.toml` under `[tool_permissions]`
- The `autonomous_mode` runtime toggle (Ctrl+A) temporarily elevates threshold to `High` regardless of config
