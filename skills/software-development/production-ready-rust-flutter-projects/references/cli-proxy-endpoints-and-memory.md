# CLI Proxy Endpoints & Batch Backend Infrastructure

Pattern for rapidly adding backend endpoints that wrap CLI subcommands,
allowing Flutter UIs to call any Hermes feature without custom per-command code.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Flutter (CLI Tools screen)                     │
│  - Doctor, Security, Dump, Debug, Backup        │
│  - Proxy, Secrets, Pairing, Insights, Hooks     │
│  - Plugins, Curator, MCP, Webhooks, Fallback    │
└──────────────┬──────────────────────────────────┘
               │ 17 dedicated endpoints
               ▼
┌─────────────────────────────────────────────────┐
│  Rust Axum Backend                              │
│  ┌──────────────────────────────────────────┐   │
│  │ cli_doctor() → run_hermes(&["doctor"])   │   │
│  │ cli_security() → run_hermes(&[...])      │   │
│  │ ...  (17 identical wrappers)             │   │
│  │                                          │   │
│  │ Generic: POST /hermes/command            │   │
│  │   Body: {"args": ["fallback", "list"]}   │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## When to Add a Dedicated Endpoint vs. Use the Generic Runner

| Scenario | Choice |
|---|---|
| Feature user interacts with directly | Dedicated endpoint |
| Feature that needs status/progress | Dedicated endpoint |
| Feature that produces structured output | Dedicated endpoint |
| One-shot CLI command, no UI needed | Generic runner |
| Command the user rarely runs | Generic runner |
| Need to clean/parse the output for UI | Dedicated endpoint |

## The 17 CLI Proxy Endpoints Pattern

Each endpoint follows the same boilerplate:

```rust
async fn cli_<name>() -> Json<serde_json::Value> {
    match run_hermes(&["<subcommand>", ...]) {
        Ok((stdout, _, _)) => Json(serde_json::json!({
            "success": true,
            "<key>": stdout.trim(),
        })),
        Err(e) => Json(serde_json::json!({
            "success": false,
            "error": e,
        })),
    }
}
```

All functions registered in the router:
```rust
.route("/cli/fallback", get(cli_fallback_list))
.route("/cli/fallback/add", post(cli_fallback_add))
.route("/cli/fallback/clear", post(cli_fallback_clear))
.route("/cli/webhooks", get(cli_webhook_list))
.route("/cli/hooks", get(cli_hooks_list))
.route("/cli/plugins", get(cli_plugins_list))
.route("/cli/curator", get(cli_curator_status))
.route("/cli/mcp", get(cli_mcp_list))
.route("/cli/doctor", get(cli_doctor))
.route("/cli/security", get(cli_security_audit))
.route("/cli/dump", get(cli_dump))
.route("/cli/debug", get(cli_debug_share))
.route("/cli/backup", post(cli_backup_create))
.route("/cli/checkpoints", get(cli_checkpoints_status))
.route("/cli/proxy", get(cli_proxy_status))
.route("/cli/secrets", get(cli_secrets_status))
.route("/cli/pairing", get(cli_pairing_list))
.route("/cli/insights", get(cli_insights))
```

## Fallback Add (POST, Takes Body)

For interactive-only CLI commands that use Rich pickers (hermes fallback add),
you need a custom endpoint that passes provider+model as arguments:

```rust
async fn cli_fallback_add(Json(body): Json<serde_json::Value>) -> Json<serde_json::Value> {
    let provider = body["provider"].as_str().unwrap_or("");
    let model = body["model"].as_str().unwrap_or("");
    // ...
    match run_hermes(&["fallback", "add", "--provider", provider, "--model", model]) {
        Ok((stdout, _, code)) => Json(serde_json::json!({ "success": code == 0 })),
        Err(e) => Json(serde_json::json!({ "success": false, "error": e })),
    }
}
```

## Flutter Generic CLI Runner

```dart
/// Run any hermes CLI command through the backend proxy.
Future<Map<String, dynamic>> runCliCommand(List<String> args) async {
  return await _post('/hermes/command', {'args': args});
}
```

## Flutter CLI Tools Screen

A single unified screen with sections + action buttons:

```
Diagnostics:
  [Run Doctor] [Security Audit] [Setup Dump] [Debug Report]

Data Management:
  [Quick Backup] [Checkpoints]

Integrations:
  [Proxy Status] [Secrets Manager] [Pairing Codes] [Shell Hooks]

Analytics:
  [Insights]
```

Each action button calls its dedicated endpoint, shows output in a scrollable
monospace box below. The output box shows/hides per section.

## Memory From Files (Not CLI Commands)

`hermes memory list` does not exist — `hermes memory` is only for configuring
external memory providers. To show agent memory in a GUI, read files directly:

```rust
let mem_path = hermes_home_dir().join("memories").join("MEMORY.md");
let user_path = hermes_home_dir().join("memories").join("USER.md");
```

Parse MEMORY.md into entries by splitting on `§` (section separator).
Each section's first line (after stripping `#` or `**`) is the key/name.
Content is the remaining lines, truncated to 200 chars for preview.

## Hermes Installer: Curl Script (Not Pip)

The official Hermes install script is:
```
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

Replace pip-based install in setup wizard with this. Handle:
- curl not installed → detect OS and show platform-specific install instructions
- Script failure → show stderr output
- Fall back to brew on macOS if curl install fails