# Bash CLI Development Pattern

## When to Use

When you need a CLI tool that:
- ANY environment can run (no Python, Node, or SDK dependencies)
- ANY AI harness should be able to call (Hermes, Claude Code, Codex CLI, etc.)
- Auto-registers on first use without pre-shared credentials
- Works with `curl` as the only dependency

## File Structure

```bash
project-root/
├── ai-sdk/
│   └── project-cli.sh      # Single-file CLI, installed to /usr/local/bin/
```

The CLI is a single bash script (no directory, no modules, no package manager). Install it with:
```bash
chmod +x ai-sdk/project-cli.sh
sudo ln -sf $(pwd)/ai-sdk/project-cli.sh /usr/local/bin/project-cli
```

## Core Components

### 1. Configuration via Environment Variables

```bash
HOST="${MYPROJ_HOST:-http://localhost:3001}"
API_KEY="${MYPROJ_API_KEY:-}"
AGENT_NAME="${MYPROJ_AGENT_NAME:-}"
HARNESS_TYPE="${MYPROJ_HARNESS_TYPE:-}"
DEBUG="${MYPROJ_DEBUG:-}"

API_BASE="${HOST}/api"
CACHE_DIR="${HOME}/.cache/myproj-cli"
mkdir -p "${CACHE_DIR}"
```

**Naming convention:** `PROJECTNAME_VARIABLE`. All caps, underscores. Match the project name to avoid collisions with other CLI tools.

### 2. Safe curl Wrapper

```bash
curl_api() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"

  local args=(-sS)
  args+=(-X "$method")
  args+=("${API_BASE}${path}")

  [ -n "$API_KEY" ] && args+=(-H "Authorization: Bearer ${API_KEY}")
  args+=(-H "Content-Type: application/json")

  if [ -n "$data" ]; then
    args+=(-d "$data")
  fi

  [ -n "$DEBUG" ] && echo "[debug] curl ${method} ${path}" >&2

  curl "${args[@]}" 2>/dev/null || error "HTTP request failed: ${path}"
}
```

### 3. JSON Parsing without jq

```bash
json_val() {
  local key="$1"
  local json="${2:-$(cat)}"
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r "$key" 2>/dev/null || echo "null"
  else
    echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | \
      sed "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"//;s/\"//" 2>/dev/null || echo "null"
  fi
}

json_success() {
  local json
  json="$(cat)"
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r '.success' 2>/dev/null || echo "false"
  else
    echo "$json" | grep -o '"success"[[:space:]]*:[[:space:]]*true' >/dev/null && echo "true" || echo "false"
  fi
}

json_raw() {
  # Extract raw value (not quoted string) — for booleans, numbers, null
  local key="$1"
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r "$key" 2>/dev/null || echo "null"
  else
    # For simple cases: just grep the key and value
    echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[^,}]*" | \
      sed "s/.*\"${key}\"[[:space:]]*:[[:space:]]*//" 2>/dev/null || echo "null"
  fi
}
```

### 4. Auto-Registration

```bash
auto_register() {
  local cache_file="${CACHE_DIR}/registration.json"

  [ -n "$API_KEY" ] && return 0
  [ -z "$HARNESS_TYPE" ] && return 0

  # Check cache
  if [ -f "$cache_file" ]; then
    local cached_key
    cached_key=$(json_val '.api_key' < "$cache_file")
    [ -n "$cached_key" ] && { export API_KEY="$cached_key"; return 0; }
  fi

  local agent_name="${AGENT_NAME:-${HARNESS_TYPE}-$(hostname -s)}"

  local result
  result=$(curl_api POST "/api/harnesses/register" \
    "{\"name\":\"${agent_name}\",\"type\":\"${HARNESS_TYPE}\",\"metadata\":{\"auto\":true}}") || return 1

  local api_key
  api_key=$(echo "$result" | json_val '.data.apiKey')
  [ -z "$api_key" ] && { debug "Registration failed"; return 1; }

  export API_KEY="$api_key"
  echo "{\"api_key\":\"${api_key}\",\"agent\":\"${agent_name}\",\"harness\":\"${HARNESS_TYPE}\"}" > "$cache_file"
  echo "✅ Registered as ${agent_name} — API key cached"
}
```

### 5. Command Router

```bash
main() {
  local cmd="${1:-help}"; shift || true

  # Auto-register for non-help commands
  case "$cmd" in help|health|register) ;; *) auto_register ;; esac

  case "$cmd" in
    health)    cmd_health ;;
    send)      cmd_send "$@" ;;
    register)  cmd_register "$@" ;;
    search)    cmd_search "$@" ;;
    plan)      cmd_plan "$@" ;;
    watch)     cmd_watch "$@" ;;
    help|--help|-h) cmd_help ;;
    *) error "Unknown command: ${cmd}. Run 'project-cli help'." ;;
  esac
}

main "$@"
```

### 6. Help System

```bash
cmd_help() {
  cat <<HELP
MyProject CLI v0.1.0

Usage: project-cli <command> [args...]

Commands:
  health                    Check server health
  send <channel> <msg>      Send a message
  register [name] [type]    Register this harness
  search <query> [limit]    Search knowledge graph
  plan <goal>               Submit a goal for swarm execution
  watch <plan-id> [secs]    Poll plan status

Environment:
  MYPROJ_HOST        Server URL (default: http://localhost:3001)
  MYPROJ_API_KEY     API key for authentication
  MYPROJ_AGENT_NAME  Agent display name
  MYPROJ_HARNESS_TYPE Harness type (hermes, claude-code, etc.)
  MYPROJ_DEBUG       Enable debug output

Examples:
  export MYPROJ_HARNESS_TYPE="hermes"
  project-cli register "my-agent"
  project-cli send "general" "Hello!"
  project-cli plan "Research Rust async runtimes"
HELP
}
```

## Error Handling

- All errors exit non-zero with a message to stderr: `error() { echo "[project:error] $*" >&2; exit 1; }`
- Debug output goes to stderr: `debug() { [ -n "$DEBUG" ] && echo "[project:debug] $*" >&2; }`
- Warnings go to stderr: `warn() { echo "[project:warn] $*" >&2; }`
- Normal output (JSON responses) goes to stdout for piping

## Pitfalls

1. **jq is not guaranteed** — Always provide a grep/sed fallback. The grep fallback only handles flat string values. For nested JSON or arrays, pipe to jq if available, otherwise return raw text.

2. **API key shown once** — The registration endpoint returns the key once. Never store the raw key in the cache file for long-term production use. The cache is a convenience for dev sessions. In production, the user should set `MYPROJ_API_KEY` explicitly.

3. **Token expires** — JWT tokens have short lifetimes (15 min by default). The auto-registration returns an API key (long-lived), not a JWT. If the backend uses JWTs internally, the CLI should use the API key as a Bearer token — the backend middleware should handle JWT↔API key mapping.

4. **No interactive login** — This CLI is designed for programmatic use by AI harnesses. It does not support interactive browser-based OAuth flows. If OAuth is needed, implement a `login` command that opens a browser window.

5. **jq escaping** — When building JSON payloads with `jq -Rs .`, ensure the content is properly escaped for the shell. Use `$(echo "$content" | jq -Rs .)` to safely embed arbitrary strings in JSON.