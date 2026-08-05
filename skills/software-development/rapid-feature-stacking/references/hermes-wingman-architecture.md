# Hermes Wingman Architecture — Three-Layer GUI over CLI Pattern

## Architecture
```
Flutter (Desktop/Mobile) -> Rust Axum Backend (port 9120) -> Hermes CLI + Python helpers
```

## Layer 1: Flutter GUI
- 18 sidebar screens covering all Hermes CLI features
- Schema-based dynamic forms for config-heavy UIs (16 gateway platforms from one Flutter widget)
- Provider pattern (ChangeNotifier/Provider) for state management
- url_launcher for OAuth browser flows

## Layer 2: Rust Axum Backend
- Single binary, zero deps, cross-platform (Linux/macOS/Windows)
- Proxies CLI calls, parses output to structured JSON
- Generic POST /hermes/command endpoint for arbitrary CLI calls
- Dedicated endpoints for frequently-used commands (models, auth, gateway)
- In-memory state for model overrides, auth flow tracking

## Layer 3: Python Helpers + Hermes CLI
- Small Python scripts for tasks awkward in Rust (.env file manipulation)
- Create-if-not-exists pattern: check for script, write it if missing, then call
- CLI called via std::process::Command with piped stdin for interactive confirmation

## CLI Audit Methodology
1. `hermes --help` -> enumerate all 40+ subcommands
2. For each: `hermes <subcommand> --help` -> enumerate sub-subcommands
3. Classify: interactive (needs custom endpoint) vs batch (use generic proxy)
4. Build generic proxy FIRST, then custom endpoints for top-used commands

## Schema-Based Dynamic Forms Pattern
Used for gateway platform config (16 platforms), provider UIs:
- Backend returns `{label, emoji, instructions: [], vars: [{name, prompt, password, help, is_allowlist, current}]}`
- Flutter renders fields dynamically from schema
- Single Flutter widget handles ALL platforms with zero per-platform code
- Password fields get show/hide toggle + redacted current value display

## OAuth Login Flow
1. User clicks "Login with Nous" in Flutter
2. Flutter calls POST /auth/login/nous
3. Backend spawns `hermes auth add --type oauth --no-browser nous`
4. Sends "n\n" to stdin (decline re-importing existing creds)
5. Captures auth URL from stdout, returns URL to Flutter
6. Flutter opens URL via url_launcher
7. Hermes CLI handles callback natively (loopback server)
8. Flutter polls GET /auth/status until provider shows "logged_in"
9. Timeout after 2 minutes