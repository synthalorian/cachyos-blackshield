# Auto-Configure & Setup Wizard Architecture

Pattern: A Rust HTTP backend endpoint that scans the local environment (running services, env vars, existing config) and writes a complete working config, paired with a Flutter step-by-step setup wizard.

## Backend: Auto-Configure Endpoint

**Route:** `POST /setup/auto-configure`

**Algorithm (in order):**

1. **Check local services via TCP port probe**
   - llama-swap at 127.0.0.1:8080
   - Ollama at 127.0.0.1:11434
   - For llama-swap, also discover available models via `GET /v1/models`

2. **Scan environment variables for API keys**
   ```
   OPENAI_API_KEY      → openai      → https://api.openai.com/v1
   ANTHROPIC_API_KEY   → anthropic   → https://api.anthropic.com/v1
   GEMINI_API_KEY      → gemini      → https://generativelanguage.googleapis.com/v1beta
   GROK_API_KEY        → xai         → https://api.x.ai/v1
   XAI_API_KEY         → xai         → https://api.x.ai/v1
   MISTRAL_API_KEY     → mistral     → https://api.mistral.ai/v1
   DEEPSEEK_API_KEY    → nous        → https://api.nousresearch.com/v1
   OPENROUTER_API_KEY  → openrouter  → https://openrouter.ai/api/v1
   TOGETHER_API_KEY    → together    → https://api.together.xyz/v1
   ```

3. **Determine default model**
   - First priority: First model from llama-swap (local)
   - Second priority: First cloud provider with matching env var
   - Third priority: Keep existing model from config (if present)

4. **Merge with existing config** — Parse the existing config via `serde_yaml`, merge discovered providers, then serialize back to YAML. This preserves ALL existing config sections (`agent`, `delegation`, `display`, `terminal`, `model.provider`, etc.) unlike naive string building which drops everything outside `model`, `fallback_providers`, and `providers`.

5. **Write config.yaml** — Serialize the merged `serde_yaml::Value` back to a YAML string. The full approach:

```rust
// Parse existing config
let existing: serde_yaml::Value = serde_yaml::from_str(&existing_raw).unwrap_or(serde_yaml::Value::Null);
let mut config_value = existing.clone();

// Update model, fallback_providers, providers via mapping mutation
if let Some(mapping) = config_value.as_mapping_mut() {
    mapping.insert(
        serde_yaml::Value::String("model".into()),
        serde_yaml::Value::String(default_model),
    );
    // ... update other fields ...
}

// Serialize back — preserves ALL sections
let config_yaml = serde_yaml::to_string(&config_value).unwrap();
std::fs::write(&config_path, &config_yaml);
```

**PITFALL:** Old string-building approach (`config_yaml.push_str(...) + std::fs::write`) loses all config sections not explicitly reconstructed. Always parse → mutate → serialize when merging config. This is essential for tools that wrap Hermes Agent, since users may have custom `agent`, `delegation`, `checkpoints`, `display`, or `memory` sections that must survive auto-configure.

**TCP port check utility (Rust):**
```rust
fn check_port(port: u16) -> bool {
    use std::net::TcpStream;
    TcpStream::connect_timeout(
        &format!("127.0.0.1:{}", port).parse().unwrap(),
        std::time::Duration::from_millis(500),
    ).is_ok()
}
```

**Response format:**
```json
{
  "success": true,
  "config_written": true,
  "default_model": "deepseek/deepseek-v4-flash",
  "discovered": [
    {"name": "llama-swap", "type": "local", "status": "running"},
    {"name": "openai", "type": "cloud", "source": "env:OPENAI_API_KEY", "status": "key_found"}
  ],
  "providers_count": 3,
  "fallback_count": 24
}
```

## Backend: Probe Provider Endpoint

**Route:** `POST /setup/probe-provider`

Sends a real test request to a configured provider to verify it works.

**Request:** `{"provider": "openai", "model": "gpt-4o-mini"}` (model is optional — auto-selected per provider)

**Provider → default model mapping:**
- openai → gpt-4o-mini
- anthropic → claude-sonnet-4
- gemini → gemini-2.5-flash
- xai / xai-oauth → grok-4-mini
- mistral → mistral-small
- nous / deepseek → deepseek-v4-flash
- llama-swap / ollama → (requires explicit model name)

**Key implementation detail:** Resolve `api_key_env` to actual value at runtime:
```rust
let api_key = provider_cfg["api_key"].as_str()
    .or_else(|| {
        provider_cfg["api_key_env"].as_str()
            .and_then(|env| std::env::var(env).ok())
            .map(|s| Box::leak(s.into_boxed_str()) as &str)
    })
    .unwrap_or("");
```

## Flutter: Setup Wizard (5-Step Guided Flow)

### Step 1: Detect
- Calls `GET /setup/detect`
- Shows 5 checkmarks: Hermes installed, config exists, API keys, model configured, gateway connected
- If Hermes not installed → Step 2
- If Hermes installed → Step 3 (skip install)

### Step 2: Install
- Calls `POST /setup/install` with method "pip" (falls back to pip → pip3 → brew)
- Shows real-time install output in a monospace scrollable container
- Green border on success, red on failure with error details
- Re-detects after install to update status
- Handles: pip3 not found, externally-managed-environment, brew missing

### Step 3: Configure
- Calls `POST /setup/auto-configure`
- Shows discovered providers with type and source icons
- Displays: default model, provider count, fallback count
- Each discovered item: name • type → status

### Step 4: Test
- Calls `POST /setup/probe-provider` with the first cloud provider
- Shows green checkmark on success, yellow warning on failure
- Auto-selects the best provider to test (cloud with key > local)

### Step 5: Done
- Summary: all 5 steps with green/red indicators
- Quick links to other tabs (Chat, Models, Config, Gateways)
- "You're All Set!" if all critical steps passed

### Progress Bar
Visual 5-dot progress bar at the top showing: Detect ○———○ Install ○———○ Configure ○———○ Test ○———○ Ready
Completed steps show green check, current step shows glowing circle.

## Flutter: Provider Wiring

The BackendService is provided TWICE to the widget tree:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider<BackendService>.value(value: backend),  // for status dots/listeners
    Provider<HermesService>.value(value: backend),                 // for API calls via abstract interface
  ],
)
```

Screens that need raw API access (setup wizard, models, gateway) check the type:
```dart
if (service is BackendService) {
  final data = await service.httpGet('/setup/auto-configure');
} else {
  // CLI fallback path
}
```

The import pattern for this is:
```dart
import '../../services/hermes_api_client.dart' show BackendService;
```

## Backend: Binary Detection (Cross-Platform)

The `detect_setup` endpoint must find `hermes` binary on any system:

1. **Try `which hermes`** — works on Linux, macOS, Windows (git bash/WSL)
2. **Fallback paths** (in order):
   - `$HOME/.local/bin/hermes` — pip --user installs
   - `/usr/bin/hermes` — system package managers
   - `/usr/local/bin/hermes` — Homebrew (Intel), manual installs
   - `/opt/homebrew/bin/hermes` — Homebrew (Apple Silicon macOS)
   - `/Users/{user}/.local/bin/hermes` — macOS pip installs (alternative $HOME format)

The Flutter-side BackendService `_findBinary()` mirrors this pattern for the backend binary itself, adding:
- `backend/target/release/hermes-wingman-backend` — development
- `../MacOS/hermes-wingman-backend` — macOS .app bundle
- `$HOME/.cargo/bin/hermes-wingman-backend` — cargo install

## Installation Pathways Priority

When the setup wizard installs Hermes:

| System | Method 1 | Method 2 | Method 3 |
|--------|----------|----------|----------|
| Linux | `pip3 install hermes-agent` | `pip install --break-system-packages hermes-agent` | venv |
| macOS | `brew install hermes-agent` | `pip3 install hermes-agent` | venv |
| Windows | `pip install hermes-agent` | venv | — |
