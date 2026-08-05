# OpenShark Security Architecture Reference

Session: 2026-05-30 — Built 4-layer security system for OpenShark

## Layer Overview

```
┌─────────────────────────────────────────┐
│ L4: Application Guardrails              │
│    - Prompt injection detection         │
│    - Tool permissions                   │
│    - Risk assessment                    │
│    - Output validation                  │
├─────────────────────────────────────────┤
│ L3: Data Protection                     │
│    - PII detection & redaction          │
│    - Secret redaction                   │
│    - Output truncation                  │
├─────────────────────────────────────────┤
│ L2: Identity & Access Control           │
│    - Zero-trust credentials             │
│    - Scoped permissions                 │
│    - Session limits                     │
├─────────────────────────────────────────┤
│ L1: Infrastructure Isolation            │
│    - Working directory sandbox          │
│    - Path validation                    │
│    - Sudo approval gates                │
└─────────────────────────────────────────┘
```

## Module Structure

```
src/security/
├── mod.rs           # SecurityEngine, SecurityConfig, SecurityDecision
├── guardrails.rs    # Guardrails, RiskAssessor, InjectionCheck
├── identity.rs      # IdentityManager, ScopedCredential, CredentialScope
├── pii.rs           # PiiDetector, PiiFinding, quick_redact
└── sandbox.rs       # Sandbox, path extraction
```

## Key Types

### SecurityDecision
```rust
pub enum SecurityDecision {
    Allow,
    RequireApproval { reason: String, risk_level: RiskLevel },
    Deny { reason: String },
}
```

### RiskLevel (ordered)
```rust
pub enum RiskLevel {
    None, Low, Medium, High, Critical
}
```

### PermissionLevel
```rust
pub enum PermissionLevel {
    Allow,   // No approval needed
    Ask,     // Requires human approval
    Deny,    // Completely disabled
}
```

### CredentialScope
```rust
pub enum CredentialScope {
    ReadOnly,   // fs, search, lsp
    ReadWrite,  // + edit
    Git,        // git, search
    Terminal,   // terminal, fs, search
    Full,       // All tools
}
```

## SecurityConfig Default Permissions

| Tool | Default Permission |
|------|-------------------|
| fs | Ask |
| terminal | Ask |
| git | Allow |
| search | Allow |
| edit | Ask |
| lsp | Allow |
| refactor | Ask |
| test | Allow |

## Prompt Injection Patterns Detected

- `ignore all previous instructions`
- `disregard all previous instructions`
- `system: you are now`
- `you are now a developer/admin/root`
- `act as a developer/admin/root`
- `execute this command`
- `bypass security`
- `send/transmit/exfiltrate data`
- `base64/hex/rot13 encode`
- `` ```system `` blocks
- Excessive repetition (obfuscation)
- Mixed scripts (homograph attacks)

## Sudo Handling

- Sudo commands require approval by default
- `always_approve_commands` list: rm, dd, mkfs, fdisk (always require explicit approval)
- `approve_sudo(command, duration_secs)` grants temporary session
- `revoke_sudo()` clears all approvals
- Password persistence optional (masked as `****` in saved config)

## PII Categories

| Category | Pattern |
|----------|---------|
| EMAIL | `\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b` |
| CREDIT_CARD | `\b(?:\d{4}[\s-]?){3}\d{4}\b` |
| SSN | `\b\d{3}-\d{2}-\d{4}\b` |
| PHONE | `\b\d{3}-\d{3}-\d{4}\b` |
| API_KEY | `sk-[a-zA-Z0-9]{48}` |
| GITHUB_TOKEN | `ghp_[a-zA-Z0-9]{36}` |
| AWS_KEY | `AKIA[0-9A-Z]{16}` |
| UUID | `[0-9a-f]{8}-...-[0-9a-f]{12}` |
| IP_ADDRESS | `\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b` |

## Integration Points (Still To Wire)

1. **TUI tool execution** — call `security_engine.check_tool_call()` before executing any tool in `src/tui/mod.rs`
2. **Output sanitization** — call `security_engine.sanitize_output()` before sending tool results to model
3. **Prompt injection check** — call `security_engine.check_prompt_injection()` on user input before processing
4. **Audit logging** — call `security_engine.audit()` after every tool execution

## Testing

```bash
# Run security tests
cargo test security::

# Test specific modules
cargo test security::pii::
cargo test security::guardrails::
cargo test security::identity::
cargo test security::sandbox::
```
