# Multi-Platform API Client Pattern

When a single backend serves multiple frontend platforms (desktop Tauri, mobile Flutter, web Rails), each client needs a consistent API wrapper that handles auth, error normalization, and fallback behavior.

## Pattern: Shared Backend, Three Clients

```
Janus API Server (Node.js + Express @ localhost:3001)
    │
    ├── Desktop: Tauri 2 (Rust + static HTML/JS)
    │   └── invoke() → Rust → reqwest → backend
    │   └── fallback: fetch() in browser dev mode
    │
    ├── Mobile: Flutter (Dart + http package)
    │   └── http.get/post → backend
    │
    └── Web: Rails 8 (Ruby + Net::HTTP)
        └── JanusApi service → backend
```

## Key Design Decisions

### 1. Auth Token Storage Per Platform

| Platform | Storage | Persistence |
|----------|---------|-------------|
| Tauri (static JS) | `localStorage` | Survives restarts |
| Tauri (Rust) | `AppState` struct in memory | Lost on restart — use localStorage |
| Flutter | `JanusApiService` private field | Lost on restart — use `shared_preferences` |
| Rails | Session cookie + `JanusApi.auth_token` class variable | Session-scoped |

**Lesson:** Don't store tokens in Rust `AppState` alone — it's lost on app restart. The static JS frontend should cache the token in `localStorage` and pass it to Rust commands, or have Rust read from localStorage via a Tauri command.

### 2. Error Normalization

Every client should return the same shape on error:
```json
{ "success": false, "error": "human-readable message" }
```

**Tauri Rust:**
```rust
pub async fn get_health(api_base: &str) -> Result<String, String> {
    client().get(&format!("{}/api/health", api_base))
        .send().await
        .map_err(|e| format!("{{\"success\":false,\"error\":\"{}\"}}", e))? // JSON error string
        .text().await
        .map_err(|e| format!("{{\"success\":false,\"error\":\"{}\"}}", e))
}
```

**Flutter:**
```dart
Future<Map<String, dynamic>> _get(String path) async {
  final res = await http.get(Uri.parse('$_baseUrl$path'), headers: _headers);
  return jsonDecode(res.body) as Map<String, dynamic>;
}
// Backend already returns {success, data|error} — no client-side wrapping needed
```

**Rails:**
```ruby
def self.handle(uri, req)
  response = Net::HTTP.start(...) { |http| http.request(req) }
  parsed = JSON.parse(response.body) rescue { "success" => false, "error" => "Invalid JSON" }
  case response
  when Net::HTTPOK, Net::HTTPCreated then parsed
  else raise BackendError, parsed["error"] || "HTTP #{response.code}"
  end
rescue Errno::ECONNREFUSED
  raise BackendError, "Janus API not running at #{uri.host}:#{uri.port}"
end
```

### 3. Base URL Configuration

| Platform | Default | Override |
|----------|---------|----------|
| Tauri | `http://localhost:3001` | `JANUS_API_URL` env var |
| Flutter | `http://10.0.2.2:3001` (Android emulator) | Build config or settings |
| Rails | `http://localhost:3001` | `ENV["JANUS_API_URL"]` |

**Android emulator note:** `localhost` on the emulator refers to the emulator itself, not the host machine. Use `10.0.2.2` which is the host loopback alias. For iOS simulator, `localhost` works because it shares the host network stack.

### 4. Runtime Detection Bridge (Tauri-specific)

When a Tauri app uses static HTML/JS (no bundler), the frontend can't import `@tauri-apps/api`. Detect Tauri at runtime:

```javascript
const isTauri = typeof window !== 'undefined' && window.__TAURI__ !== undefined;
const invoke = isTauri ? window.__TAURI__.core.invoke : null;

async function apiCall(method, path, body) {
  if (isTauri && invoke) {
    const cmd = mapRestToCommand(method, path);
    const result = await invoke(cmd, buildArgs(body));
    return typeof result === 'string' ? JSON.parse(result) : result;
  }
  // Browser fallback
  return fetchApi(method, path, body);
}
```

**Command map:** Maintain a lookup table mapping REST paths to Tauri command names. This keeps the frontend code REST-agnostic — the same `apiCall('GET', '/api/health')` works in both Tauri and browser.

### 5. Feature Parity Matrix

Track which features work on which platform:

| Feature | Desktop | Mobile | Web |
|---------|---------|--------|-----|
| REST API | ✅ | ✅ | ✅ |
| Auth (register) | ✅ | ✅ | ✅ |
| Real-time (WebSocket) | ❌ | ❌ | ❌ |
| Push notifications | N/A | ❌ | ❌ |
| System tray | ❌ | N/A | N/A |
| Offline cache | ❌ | ❌ | ❌ |
| Biometric auth | N/A | ❌ | ❌ |

Use this to prioritize cross-platform work. WebSocket is usually the highest-impact missing piece.

## Verification Checklist

- [ ] `cargo check` passes (Tauri)
- [ ] `flutter build apk --debug` succeeds (Mobile)
- [ ] `bundle exec ruby -c` on all controllers/services (Rails)
- [ ] Health endpoint returns JSON from all three clients
- [ ] Auth flow completes end-to-end on all three
- [ ] Theme switching works on all three (if applicable)
- [ ] Error states show user-friendly messages on all three
