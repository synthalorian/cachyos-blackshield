# In-App Provider Auth: OAuth + API Key Login Pattern

**When building a GUI that manages external AI/API provider credentials, do ALL auth within the app — zero terminal commands for the user.**

## Architecture Overview

```
Flutter UI                    Rust Backend (Axum)            Hermes CLI
    │                              │                            │
    │  POST /auth/login/nous ─────►│                            │
    │                              │  hermes auth add           │
    │                              │  --type oauth              │
    │                              │  --no-browser nous ───────►│
    │                              │◄── stdout (auth URL) ──── │
    │◄── { url: "https://..." } ───│                            │
    │                              │                            │
    │  url_launcher → browser ──────────────────────────────────►
    │  (user authenticates)        │                            │
    │                              │  (callback arrives)        │
    │                              │◄── auth.json updated ──── │
    │  GET /auth/status ──────────►│                            │
    │◄── { providers: [...] } ─────│                            │
    │  (polls until "logged_in")   │                            │
```

## Key Insight

The Hermes CLI manages OAuth token exchange natively — the backend should NOT try to handle the callback itself. Instead:
1. Spawn `hermes auth add --type oauth --no-browser {provider}` as a subprocess
2. Capture the auth URL from its stdout (the first line starting with `https://`)
3. Return the URL to the GUI — it opens the browser
4. Let the hermes subprocess handle the loopback callback + token exchange
5. Poll until `auth.json` shows the provider as logged in

## Rust Backend Endpoints

### POST /auth/login/{provider} (OAuth)

```rust
async fn auth_start_oauth(
    Path(provider): Path<String>,
    State(state): State<Arc<AppState>>,
) -> Json<serde_json::Value> {
    // 1. Check if already logged in (read ~/.hermes/auth.json)
    let auth_path = state.hermes_home.join("auth.json");
    let already_logged_in = read_file(&auth_path)
        .ok()
        .and_then(|c| serde_json::from_str::<serde_json::Value>(&c).ok())
        .and_then(|j| j["providers"].as_object()
            .map(|p| p.contains_key(&provider)))
        .unwrap_or(false);

    if already_logged_in {
        return Json(json!({
            "success": true, "status": "already_logged_in"
        }));
    }

    // 2. Spawn `hermes auth add --type oauth --no-browser {provider}`
    let binary = hermes_binary_path();
    match tokio::process::Command::new(&binary)
        .args(["auth", "add", "--type", "oauth", "--no-browser", &provider])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .env("PAGER", "cat")
        .spawn()
    {
        Ok(mut child) => {
            // 3. Pipe "n\n" to stdin (decline re-import prompt if creds exist)
            if let Some(mut stdin) = child.stdin.take() {
                use tokio::io::AsyncWriteExt;
                let _ = stdin.write_all(b"n\n").await;
                drop(stdin);
            }

            let output = child.wait_with_output().await;
            match output {
                Ok(out) => {
                    let combined = format!("{}\n{}",
                        String::from_utf8_lossy(&out.stdout),
                        String::from_utf8_lossy(&out.stderr));

                    // 4. Find the auth URL in stdout
                    let mut auth_url: Option<String> = None;
                    for line in combined.lines() {
                        let t = line.trim();
                        if t.starts_with("https://") || t.starts_with("http://localhost") {
                            auth_url = Some(t.to_string());
                            break;
                        }
                    }

                    // 5. Check if auth already completed
                    let now_logged_in = /* same check as above */;
                    if now_logged_in {
                        Json(json!({"success": true, "status": "logged_in"}))
                    } else if let Some(url) = auth_url {
                        Json(json!({"success": true, "url": url, "status": "awaiting_auth"}))
                    } else {
                        Json(json!({"success": false, "status": "no_url",
                            "error": "Could not extract auth URL"}))
                    }
                }
                Err(e) => Json(json!({"success": false, "error": e.to_string()})),
            }
        }
        Err(e) => Json(json!({"success": false, "error": e.to_string()})),
    }
}
```

### POST /auth/api-key (API Key)

```rust
async fn auth_add_api_key(
    Json(body): Json<serde_json::Value>,
) -> Json<serde_json::Value> {
    let provider = body["provider"].as_str().unwrap_or("").to_string();
    let api_key = body["api_key"].as_str().unwrap_or("").to_string();

    let binary = hermes_binary_path();
    match tokio::process::Command::new(&binary)
        .args(["auth", "add", "--type", "api-key", "--api-key", &api_key, &provider])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
    {
        Ok(out) => Json(json!({
            "success": out.status.success(),
            "stdout": String::from_utf8_lossy(&out.stdout).to_string().trim(),
            "stderr": String::from_utf8_lossy(&out.stderr).to_string().trim(),
        })),
        Err(e) => Json(json!({"success": false, "error": e.to_string()})),
    }
}
```

### GET /auth/status

Reads `~/.hermes/auth.json` and returns the login state for every known provider.

**IMPORTANT:** Use the CORRECT Hermes provider IDs below. Not all common provider names work — `hermes auth add` only accepts specific IDs (tested empirically):

```rust
async fn auth_get_status(State(state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    let auth_path = state.hermes_home.join("auth.json");
    let logged_in = read_file(&auth_path)
        .ok()
        .and_then(|c| serde_json::from_str::<serde_json::Value>(&c).ok())
        .and_then(|j| j["providers"].as_object().map(|p| {
            p.iter().map(|(k, v)| {
                (k.clone(), v["type"].as_str().unwrap_or("unknown").to_string())
            }).collect::<Vec<_>>()
        }))
        .unwrap_or_default();

    // ONLY use provider IDs that actually work with `hermes auth add`
    // Tested working: nous, anthropic, xai, xai-oauth, gemini,
    //                 openai-codex, openrouter, deepseek, zai
    // DO NOT use: openai, google, groq, together (these are NOT valid auth IDs)
    let known_providers = ["nous", "anthropic", "xai", "xai-oauth",
        "gemini", "openai-codex", "openrouter", "deepseek", "zai"];

    let providers: Vec<_> = known_providers.iter().map(|p| {
        let is_logged_in = logged_in.iter().any(|(name, _)| name == p);
        json!({"name": p, "status": if is_logged_in { "logged_in" } else { "not_logged_in" }})
    }).collect();

    Json(json!({"success": true, "providers": providers}))
}
```

### POST /auth/logout/{provider}

```rust
async fn auth_logout(Path(provider): Path<String>) -> Json<serde_json::Value> {
    let binary = hermes_binary_path();
    match tokio::process::Command::new(&binary)
        .args(["auth", "logout", &provider])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
    {
        Ok(out) => Json(json!({"success": out.status.success()})),
        Err(e) => Json(json!({"success": false, "error": e.to_string()})),
    }
}
```

### Route Registration

```rust
.route("/auth/status", get(auth_get_status))
.route("/auth/login/{provider}", post(auth_start_oauth))
.route("/auth/api-key", post(auth_add_api_key))
.route("/auth/logout/{provider}", post(auth_logout))
```

## Flutter UI Pattern

### Provider Definition List

**CRITICAL: Use the EXACT Hermes provider ID for `name`.** These are the IDs that `hermes auth add` accepts — not all common names work:

```dart
class _ProviderDef {
  final String name;        // MUST match hermes auth add provider ID
  final String shortName;   // "Nous", "Anthropic", etc.
  final IconData icon;
  final String description;
  final bool isOAuth;       // true = OAuth flow, false = API key
  final String defaultModel; // only for API-key providers
}

const _allProviders = <_ProviderDef>[
  // OAuth providers
  _ProviderDef(name: 'nous', shortName: 'Nous', isOAuth: true,
    description: 'Nous Research — OAuth login, recommended for Hermes'),
  _ProviderDef(name: 'xai-oauth', shortName: 'xAI', isOAuth: true,
    description: 'xAI — OAuth login for Grok models'),
  _ProviderDef(name: 'openai-codex', shortName: 'OpenAI Codex', isOAuth: true,
    description: 'OpenAI Codex — OAuth login for code generation'),

  // API key providers (these IDs work with --type api-key)
  _ProviderDef(name: 'anthropic', shortName: 'Anthropic', isOAuth: false,
    description: 'Anthropic API key — Claude models',
    defaultModel: 'claude-sonnet-4'),
  _ProviderDef(name: 'xai', shortName: 'xAI (API)', isOAuth: false,
    description: 'xAI API key — Grok models via API key',
    defaultModel: 'grok-3'),
  _ProviderDef(name: 'gemini', shortName: 'Google Gemini', isOAuth: false,
    description: 'Google Gemini API key',
    defaultModel: 'gemini-2.0-flash'),
  _ProviderDef(name: 'openrouter', shortName: 'OpenRouter', isOAuth: false,
    description: 'OpenRouter API key — multi-model access',
    defaultModel: 'openrouter/auto'),
  _ProviderDef(name: 'deepseek', shortName: 'DeepSeek', isOAuth: false,
    description: 'DeepSeek API key',
    defaultModel: 'deepseek-chat'),
  _ProviderDef(name: 'zai', shortName: 'ZAI', isOAuth: false,
    description: 'ZAI API key',
    defaultModel: 'zai/auto'),
];
```

**BROWSER NAMES THAT DO NOT WORK with `hermes auth add`:** 
- `openai` — NOT a valid auth ID (use `openai-codex` for OAuth instead)
- `google` — NOT a valid auth ID (use `gemini` for API key)
- `groq` — NOT a valid auth ID
- `together` — NOT a valid auth ID

### Provider Card

Each provider renders as a glass card with:
- **Left**: Icon (colored by login state — success green when logged in)
- **Center**: Name, description, status badge (`✓ Active` or `—`)
- **Right**: Action button — `OAuth Login` / `Add Key` / `Logout`

### OAuth Login Flow

```dart
Future<void> _startOAuthLogin(_ProviderDef provider) async {
  final result = await backend.loginOAuth(provider.name);

  if (result['status'] == 'already_logged_in' || result['status'] == 'logged_in') {
    // Already authenticated
    await _loadStatus();
    return;
  }

  final url = result['url'] as String?;
  if (url != null && url.isNotEmpty) {
    // Open browser
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    // Show waiting dialog that polls /auth/status every 2s
    _showAuthWaitingDialog(provider, backend);
  }
}
```

### API Key Dialog

Standard AlertDialog with:
- Obscured `TextField` for API key
- Model name field (pre-filled with default)
- POST to `/auth/api-key` on submit

### Auth Waiting Dialog

```dart
// Shows spinner + "Authenticating with {name}"
// Polls /auth/status every 2 seconds via Timer.periodic
// Auto-dismisses when provider status becomes "logged_in"
// Times out after 120 seconds
// User can press "Cancel" to dismiss
```

## Pitfalls

- **`hermes login` is REMOVED** — the old command no longer exists. All auth goes through `hermes auth add`.
- **Provider IDs are NOT intuitive** — `google` → `gemini`, `openai` → `openai-codex` (OAuth) or simply doesn't support API key auth via `auth add`. Always test via CLI before hardcoding.
- **OAuth providers need `--no-browser`** when spawning from a backend — the backend captures the URL and the GUI handles browser opening.
- **Piped stdin for re-import prompt**: `hermes auth add` may prompt "Import existing credentials? [Y/n]" when credentials already exist. Pipe `"n\n"` to stdin to decline.
- **auth.json path**: `~/.hermes/auth.json` — providers key is an object where keys are provider names and values have a `type` field (`"oauth"`, `"api_key"`).
- **Tokio + std::process::Stdio**: Use `tokio::process::Command` (not `std::process::Command`) when the handler is async. The tokio version integrates with the async runtime properly.
- **`url_launcher` on Android 11+**: Do NOT use `canLaunchUrl()` — it returns false even when the browser exists. Use `try { await launchUrl(...) } catch (_) {}` directly.
- **Polling timeout**: Cap OAuth waiting to 120 seconds. Beyond that, assume the user abandoned the flow.
- **`zai` is a valid provider** — don't miss it when listing known providers.
