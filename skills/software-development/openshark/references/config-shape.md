# OpenShark config shape

Fields seen in practice on `~/.config/openshark/config.toml`.

## Top-level

| Field | Type | Notes |
|-------|------|-------|
| `version` | string | schema version, currently `1.1.0` |
| `default_model` | string | exact `providers.X.models[].name` |
| `weak_model` | optional string | fallback when context is tight |
| `architect_model` | optional string | architecture task routing |
| `editor_model` | optional string | editor task routing |
| `memory_db_path` | path | SQLite memory DB |
| `tools_enabled` | array | `fs`, `terminal`, `git`, `search`, `edit` |
| `auto_route` | bool | capability routing on/off |
| `cost_limit_usd` | float | remote provider safety rail |
| `user_name` | string | identity |
| `effort_level` | string | `low` / `medium` / `high` |

## Provider block

```toml
[providers.<name>]
base_url = "..."
api_key = "..."
kind = "open_ai_compatible"
headers = { }            # optional
env_file = "<name>.env"  # preferred over inline key

[[providers.<name>.models]]
name = "<model-id>"
context_length = 131072
cost_per_1k_input = 0.0
cost_per_1k_output = 0.0
capabilities = ["code", "chat", "vision"]
```

Routing key is `providers.<name>.models[].name` — exact string match.

## Agent identity

```toml
[agent]
name = "..."
display_name = "..."
role = "..."
origin = "..."
purpose = "..."
tagline = "..."
tone = "..."
style = "..."
greeting = "..."
farewell = "..."
emoji = "🎹🦞"
catchphrases = [ "...", "..." ]
behavioral_rules = [ "...", "..." ]
```

## Autonomy

```toml
[autonomy]
enabled = true
tool_timeout_secs = 0
stream_stall_timeout_secs = 900
approval_timeout_secs = 60
```
