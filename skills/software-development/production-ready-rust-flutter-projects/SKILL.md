---
name: production-ready-rust-flutter-projects
category: software-development
description: Building ambitious, visually distinctive, local-first creative tools with shared Rust core + Flutter.
---

# Production-Ready Rust + Flutter Projects

**Class**: Building ambitious, visually distinctive, local-first creative tools with shared Rust core + Flutter frontend.

## Core Principles
- **Production before testing**: Code must be feature-packed, compilable, and release-ready before any manual testing begins.
- **Aesthetic consistency**: Synthwave/retro-futurist visuals (CRT, neon, chrome) are first-class and must be implemented early.
- **Shared core discipline**: Heavy logic lives in the Rust core; platform layers are thin.
- **Release engineering from day one**: GitHub releases, APK embedding, icon integration, build scripts, and **auto-deployment to ~/.local/bin/** are part of the initial scaffolding. After every build, copy the Flutter binary + shared libs + **runtime data (data/flutter_assets, data/icudtl.dat)** + Rust backend to `~/.local/bin/` so launcher shortcuts always pick up the latest version. The `data/` directory is required — Flutter loads assets and ICU data from it relative to the binary. Without it, the app may crash or show stale/blank content. Use `cp -r src/data/. dst/data/` (trailing slash-dot) to avoid the nested-directory trap. Handle the "Text file busy" edge case by stopping systemd, copying, then restarting. See `scripts/deploy-local-bin.sh`.
- **Universal by default**: Tooling, wizards, detection paths, and binary discovery MUST work on ALL supported platforms (Linux + macOS; Windows when available) without hardcoded paths. Never assume the user's OS, filesystem layout, or package manager.
- **Adaptive, not hardcoded**: The app must detect and adapt to the user's environment (running services, env vars, installed tools) rather than requiring manual config file editing. This is a first-class design constraint for any tool that wraps another system.

## Architecture Patterns

### Pattern A: flutter_rust_bridge (FFI)
Rust compiled as shared library, loaded via FFI into Flutter/Dart. Best for low-latency calls, shared state, no serialization overhead. Use when: call frequency is high (hundreds per second), data is complex structs that would be expensive to serialize, or the Rust core must respond synchronously from Dart.

### Pattern B: Rust HTTP Backend (Subprocess)
Rust binary runs as a local HTTP server (axum + tokio). Flutter spawns it as a subprocess on launch and communicates via localhost HTTP. Best for: tooling/agent UIs that wrap existing CLIs, apps where the backend does file I/O or subprocess management, cross-platform apps where FFI complexity isn't justified.

**Key differences from Pattern A:**
- Zero FFI complexity — no bridge codegen, no shared library compilation, no native build integration
- Backend is a standalone binary — can be tested, debugged, and packaged independently
- Communication is async HTTP — natural fit for request/response patterns, polling, streaming
- Backend can shell out to system commands (hermes CLI, curl) without blocking the UI
- Simpler cross-compilation — the Rust binary is a standard cargo build, not a shared library
- Backend lifecycle: Flutter spawns on startup (`Process.start`), health-checks via `/health`, kills on exit

**Backend server pattern (Rust + axum):**
```rust
#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/health", get(health))
        .route("/models", get(get_models))
        .route("/chat", post(chat_handler))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("127.0.0.1:9120").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

**Flutter backend lifecycle (ChangeNotifier pattern):**

The BackendService should be a `ChangeNotifier` that:
- Exposes `BackendConnectionState` (initializing/connected/failed/notFound)
- Checks if the backend is already running via port probe before trying to start
- Discovers the binary across release/debug/dist paths
- Starts the subprocess, polls `/health` until ready
- Implements the abstract service interface for API calls
- Is provided to the widget tree as BOTH `ChangeNotifier` (for status widgets) AND the service interface (for API calls)

```dart
enum BackendConnectionState { initializing, connected, failed, notFound }

class BackendService extends ChangeNotifier implements HermesService {
  Process? _process;
  BackendConnectionState _state = BackendConnectionState.initializing;
  String? _lastError;
  final HttpClient _client = HttpClient();
  final String _baseUrl = 'http://127.0.0.1:9120';
  bool _started = false;

  BackendConnectionState get state => _state;
  bool get isRunning => _state == BackendConnectionState.connected;

  Future<bool> start({Duration timeout = const Duration(seconds: 8)}) async {
    if (_started) return _state == BackendConnectionState.connected;
    _started = true;

    // 1. Check if already running (external process or stale session)
    if (await _checkPort(9120)) {
      _state = BackendConnectionState.connected;
      notifyListeners();
      return true;
    }

    // 2. Find the binary across common paths
    final binary = await _findBinary();
    if (binary == null) {
      _state = BackendConnectionState.notFound;
      _lastError = 'Backend binary not found';
      notifyListeners();
      return false;
    }

    // 3. Start the subprocess
    // PITFALL: Without PATH, any Command::new("hermes") inside the Rust
    // backend will fail silently. Pass PATH explicitly or use the
    // Rust-side hermes_binary_path() approach (see flutter-backend-integration
    // skill's references/rust-spawn-cli-path-resolution.md).
    _process = await Process.start(binary, [],
        environment: {
          'HOME': Platform.environment['HOME'] ?? '/tmp',
          'PATH': Platform.environment['PATH'] ?? '/usr/local/bin:/usr/bin:/bin',
        },
    );

    // 4. Poll /health until ready
    while (DateTime.now().isBefore(deadline)) {
      if (await _checkHealth()) {
        _state = BackendConnectionState.connected;
        notifyListeners();
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _state = BackendConnectionState.failed;
    notifyListeners();
    return false;
  }

  Future<String?> _findBinary() async {
    // Try relative paths first (development, bundled, macOS .app bundle)
    final candidates = [
      'backend/target/release/hermes-wingman-backend',
      'backend/target/debug/hermes-wingman-backend',
      'hermes-wingman-backend',
      '../MacOS/hermes-wingman-backend',   // macOS .app bundle
      '../hermes-wingman-backend',         // alternative .app layout
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return File(path).absolute.path;
    }
    // Search from known locations (cross-platform)
    final home = Platform.environment['HOME'] ?? '/tmp';
    final alt = [
      '$home/projects/hermes_wingman/backend/target/release/hermes-wingman-backend',
      '$home/projects/hermes_wingman/backend/target/debug/hermes-wingman-backend',
      '$home/.local/bin/hermes-wingman-backend',
      '$home/.cargo/bin/hermes-wingman-backend',
      '/opt/homebrew/bin/hermes-wingman-backend',   // macOS Apple Silicon
      '/usr/local/bin/hermes-wingman-backend',       // macOS Intel / Linux
    ];
    for (final path in alt) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  Future<bool> _checkPort(int port) async { /* Socket probe */ }
  Future<bool> _checkHealth() async { /* HTTP GET /health */ }
}
```

**Provider wiring (both ChangeNotifier + service interface):**
```dart
void main() async {
  final backend = BackendService();
  final started = await backend.start();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<BackendService>.value(value: backend),  // for UI status
      Provider<HermesService>.value(value: backend),                 // for API calls
    ],
  ));
}
```

**Sidebar status indicator (glowing dot):**
```dart
Container(
  width: 8, height: 8,
  decoration: BoxDecoration(
    color: isRunning ? scheme.success : scheme.error,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1),
    ],
  ),
)
```

**Recommended when:** The backend primarily orchestrates external tools (CLI subprocesses, file I/O, HTTP probes), the API surface is request/response shaped, or you want to avoid FFI build complexity. Not recommended for: high-frequency real-time calls, shared complex state, or when the Rust core must be called synchronously from Dart.

## SSE Streaming (Real-Time Chat)

When you need real-time streaming from an LLM through a Rust HTTP backend, use `axum::response::Sse` with `tokio::sync::mpsc` channels. This lets the backend make a streaming API call to the provider and forward each chunk as an SSE event to the Flutter client.

**Architecture:**
1. Flutter sends `GET /chat/stream?message=...`
2. Backend spawns a tokio task that calls the LLM provider with `"stream": true`
3. Backend parses the streaming response, extracts `delta.content`, forwards as SSE events
4. Flutter reads the SSE stream line-by-line, appending to a buffer
5. Stream ends with `data: [DONE]`

**Backend handler:**
```rust
use axum::response::sse::Event;
use axum::response::Sse;
use futures::stream::Stream;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;

async fn chat_stream_handler(
    Query(query): Query<ChatStreamQuery>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let (tx, rx) = mpsc::channel::<Result<Event, Infallible>>(32);

    tokio::spawn(async move {
        // Determine provider + base_url from config (same as chat_handler)
        let client = reqwest::Client::new();
        let mut req = client.post(&chat_url)
            .header("Content-Type", "application/json");
        if !api_key.is_empty() && api_key != "local-fake-key" {
            req = req.header("Authorization", format!("Bearer {}", api_key));
        }

        match req.json(&payload).send().await {
            Ok(response) => {
                let mut byte_stream = response.bytes_stream();
                use futures::StreamExt;
                let mut buffer = String::new();
                while let Some(chunk_result) = byte_stream.next().await {
                    if let Ok(chunk) = chunk_result {
                        buffer.push_str(&String::from_utf8_lossy(&chunk));
                        while let Some(line_end) = buffer.find('\n') {
                            let line = buffer[..line_end].trim().to_string();
                            buffer = buffer[line_end + 1..].to_string();
                            if line == "data: [DONE]" {
                                let _ = tx.send(Ok(Event::default().data("[DONE]"))).await;
                                return;
                            }
                            if let Some(data) = line.strip_prefix("data: ") {
                                if let Ok(json) = serde_json::from_str::<Value>(data) {
                                    let delta = json["choices"][0]["delta"]["content"]
                                        .as_str().unwrap_or("");
                                    if !delta.is_empty() {
                                        tx.send(Ok(Event::default()
                                            .data(json!({\"content\": delta}).to_string()))).await;
                                    }
                                }
                            }
                        }
                    }
                }
                let _ = tx.send(Ok(Event::default().data("[DONE]"))).await;
            }
            Err(e) => { /* send error event */ }
        }
    });

    Sse::new(ReceiverStream::new(rx)).keep_alive(
        KeepAlive::new().interval(Duration::from_secs(15)).text("keep-alive"),
    )
}
```

**CRITICAL PITFALLS:**
- Use `reqwest` (async), NOT `curl` subprocess and NOT `reqwest::blocking`. Streaming requires async byte-level parsing.
- SSE response type requires `Result<Event, _>`, not raw strings. Wrap data in `Event::default().data(...)`.
- Add `KeepAlive` with text pings — proxies and load balancers drop idle SSE connections after 30-60s.
- Use `max_tokens: 4096` for streaming to avoid truncation (non-streaming defaults are lower).

**Flutter SSE client (with auto-scroll):**
```dart
Future<void> _streamChat(String message, ChatMessage placeholder) async {
  final uri = Uri.parse('http://127.0.0.1:9120/chat/stream')
      .replace(queryParameters: {'message': message});
  final client = HttpClient();
  final request = await client.getUrl(uri);
  final response = await request.close();

  final buffer = StringBuffer();
  String line = '';

  await for (final chunk in response.transform(utf8.decoder)) {
    for (var i = 0; i < chunk.length; i++) {
      if (chunk[i] == '\n') {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') {
            setState(() => _sending = false);
            _scrollToBottom();  // scroll on finalize
            return;
          }
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final content = json['content'] as String? ?? '';
            if (content.isNotEmpty) {
              buffer.write(content);
              setState(() {
                final idx = _messages.indexOf(placeholder);
                if (idx >= 0) _messages[idx] = ChatMessage(text: buffer.toString().trim(), isUser: false);
              });
              _scrollToBottom();  // auto-scroll on every chunk
            }
          } catch (_) {}
        }
        line = '';
      } else {
        line += chunk[i];
      }
    }
  }
}
```

The mpsc channel bridges async work to SSE. Keep-alive prevents idle-drop. Flutter parses SSE events char-by-char and updates the placeholder message on each chunk.

## Mandatory Pre-Testing Checklist
1. Core compiles cleanly (`cargo check` passes with minimal warnings).
2. Tests pass (`cargo test` — all tests green).
3. Desktop builds and runs with full theme system.
4. **Bridge codegen is wired**: `flutter_rust_bridge_codegen generate` has been run, Dart bindings exist in `lib/src/rust/`, and the mobile app initializes `RustLib.init()` at startup (not mocked strings).
5. Mobile builds with proper app icon embedded in mipmap folders.
6. Git repository is clean and pushable (handle nested git / submodule issues early).
7. README and release notes are written with actual features, not placeholders.

## Ship-Ready Signal Assessment
When asked "is this project ship-ready?", verify in order:
- **Compile**: `cargo check` on core + desktop + any workspace members
- **Test**: `cargo test` passes
- **Bridge**: Flutter app calls real Rust functions (not hardcoded mock strings)
- **CI**: Workflow references correct paths (workspace vs. subdirectory), targets the right Flutter/Dart SDK version range
- **Scripts**: Build scripts exist and are executable (`chmod +x`)
- **Docs**: README describes actual features, version is bumped

## Visual & Branding Standards
- Aggressive CRT/scanline effects using custom painters (egui `CustomPainter` or Flutter `CustomPaint`).
- Theme system with at least 8 options (Synthwave '84 as default aggressive variant). Aim for 20+ themes covering multiple aesthetic families.
- App icon must be placed in Android `mipmap-*` folders as `ic_launcher.png` for release APKs.
- Custom Flutter `CustomPainter` icons beat text-based logos. Design a vector monogram (e.g., "HW") with wings, orbital rings, and neon glow effects using `MaskFilter.blur()`.

## Theme System: Compact Palette Pattern

When building a Flutter app with many themes, use a compact one-line-per-field const constructor pattern. This keeps 20+ theme definitions readable in a single file:

```dart
class AppColorScheme {
  final Color background, surface, surfaceAlt, primary, secondary, accent;
  final Color text, textDim, textMuted, border, borderDim;
  final Color success, warning, error;
  final Color cardBackground, selectedBackground, scaffoldBackground, appBarBackground, bottomNavBackground;

  const AppColorScheme({
    required this.background, required this.surface, required this.surfaceAlt,
    required this.primary, required this.secondary, required this.accent,
    required this.text, required this.textDim, required this.textMuted,
    required this.border, required this.borderDim,
    this.success = const Color(0xFF00FF87), this.warning = const Color(0xFFFFB800), this.error = const Color(0xFFFF3355),
    required this.cardBackground, required this.selectedBackground,
    required this.scaffoldBackground, required this.appBarBackground, required this.bottomNavBackground,
  });
}
```

**Compact theme definition style** (one-line per property, minimal repetition):

```dart
const zeus = AppColorScheme(
  background: Color(0xFF0D0A1A), surface: Color(0xFF1A1530), surfaceAlt: Color(0xFF282045),
  primary: Color(0xFFC9A84C), secondary: Color(0xFF4A7CFF), accent: Color(0xFF00D4FF),
  text: Color(0xFFFFF8F0), textDim: Color(0xFFB0A8C0), textMuted: Color(0xFF706880),
  border: Color(0xFFC9A84C), borderDim: Color(0xFF1A153080),
  cardBackground: Color(0xFF1A1530), selectedBackground: Color(0xFF282045),
  scaffoldBackground: Color(0xFF0D0A1A), appBarBackground: Color(0xFF0D0A1A80), bottomNavBackground: Color(0xFF0D0A1A80),
);
```

**Dark/light detection via luminance** — never list every theme in a fragile `isDark` check:

```dart
ThemeData themeDataFromScheme(AppColorScheme scheme) {
  final isDark = scheme.background.computeLuminance() < 0.3;
  // ... build theme with automatic brightness
}
```

This works for ALL themes regardless of how many you add — no manual whitelist required.

### Theme Families to Cover

Aim for breadth across aesthetic families:
- **Retro/cyber**: Synthwave '84, Synthwave Light, Outrun, Vaporwave, Cyberpunk
- **Brand**: Hermes (company identity)
- **Greek pantheon** (21 themes): Zeus, Hera, Poseidon, Hades, Ares, Apollo, Artemis, Athena, Aphrodite, Dionysus, Demeter, Hephaestus, Hestia, Nyx, Eos, Hypnos, Iris, Tyche, Thanatos, Nemesis, Hecate
- **Professional**: Light, Dark

Each Greek god theme uses deep backgrounds (< 0.3 luminance) with a primary color that reflects their domain, and secondary/accent colors that complement.

## CustomPainter Icon Widget Pattern

Create a Flutter `CustomPainter` for the app icon rather than embedding a PNG or SVG image. This gives you resolution-independent rendering, eliminates asset management, and lets the icon adapt to theme changes:

```dart
class WingmanIcon extends StatelessWidget {
  final double size;
  const WingmanIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _WingmanIconPainter(
          primary: const Color(0xFF8F00FF),
          accent: const Color(0xFF00FFFF),
        ),
        size: Size(size, size),
      ),
    );
  }
}

class _WingmanIconPainter extends CustomPainter {
  // Use MaskFilter.blur for neon glow effects
  final glowPaint = Paint()
    ..color = primary.withValues(alpha: 0.6)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid background, wings, letterforms, orbital rings, accent dots
  }
}
```

**Key techniques:**
- `MaskFilter.blur(BlurStyle.normal, radius)` for neon glow (works as blur filter on filled paths)
- `canvas.drawCircle()` with blur for glowing dots
- `LinearGradient.createShader()` for gradient fills across letterforms
- Draw abstract shape first, then inner detail for depth
- Keep it simple — a stylized monogram with 2-3 elements reads better than a detailed illustration at 40px


## Common Pitfalls
- **Nested git directories**: `desktop/<binary>/` often creates a nested repo. Add to `.gitignore` early.
- **Icon embedding**: Placing icons only in `assets/` does **not** make them the launcher icon. Must copy to `res/mipmap-*`.
- **Release attachment**: Use `gh release upload <tag> <path> --clobber` when updating binaries.
- **Bridge readiness**: Expose synthesis functions via `#[frb]` early so mobile can call the core.

## Recommended Tooling
- `flutter_rust_bridge` for deep integration
- `gh` CLI for release automation
- Custom egui painters for CRT/neon effects
- `scripts/deploy-local-bin.sh` — Deploy Flutter builds to `~/.local/bin/` with automated backend restart handling (systemd service stop/copy/start cycle)

## Cross-Platform Terminal Detection

When launching external terminals (for CLI tools like `hermes`), use a detection utility that adapts to the user's OS:

| OS | Detection order |
|----|----------------|
| **Linux** | `$TERMINAL` env var → alacritty → kitty → foot → gnome-terminal → konsole → xfce4-terminal → xterm → x-terminal-emulator |
| **macOS** | iTerm2 → Warp → Terminal.app |
| **Windows** | Windows Terminal (wt.exe) → PowerShell (pwsh.exe) → cmd.exe |

Implementation: check each terminal via `which`/`where`, then use the correct launch flag (`-e` for most, no flag for kitty/foot, `--` for gnome-terminal). See `services/terminal_detector.dart` for reference.

-## Critical Pitfall: Rust format!() Auth Header Interpolation
+## Critical Pitfall: OAuth Providers Must Be CLI-Routed
+
+**DO NOT make direct HTTP calls to providers that have OAuth tokens in `auth.json`.** The Hermes CLI manages token refresh, agent key minting, and proper base URL resolution. The backend can't do any of this.
+
+**Detection:** Call `oauth_providers()` which reads `~/.hermes/auth.json` and returns the set of provider names that have OAuth tokens. Any provider in this set MUST be routed through the Hermes CLI.
+
+**The fix (applied to EVERY handler that makes direct API calls):**
+
+```rust
+if oauth_providers().contains(provider_name) {
+    // Route through Hermes CLI — handles token refresh natively
+    let args = vec!["-z", &message];
+    // ... CLI fallback code
+    return;
+}
+```
+
+**Why env var fallback doesn't work:** The `DEEPSEEK_API_KEY` env var may be set to the old-style (pre-OAuth) API key. Using it directly sends stale credentials to the wrong base URL (`api.nousresearch.com/v1` vs `inference-api.nousresearch.com/v1`). The real auth lives in `auth.json` and is CLI-managed.
+
+See `references/hermes-oauth-provider-handling.md` for full implementation with auth.json structure, detection code, and all handler entry points.
+
+## Critical Pitfall: Rust format!() Auth Header Interpolation

When building a Rust backend that proxies API calls via `curl` subprocess, the `Authorization` header is constructed with `format!()`. **A single wrong character in the format string silently breaks all API auth** — no compiler error, no runtime crash, just `401 Unauthorized` from the cloud provider.

**The bug (literal asterisks in format string):**
```rust
// WRONG — sends "Authorization: Bearer *** key" as the raw header
curl.arg("-H");
curl.arg(format!("Authorization: Bearer *** key));
```

**The fix (proper interpolation):**
```rust
// RIGHT — sends "Authorization: Bearer sk-xxx..." 
curl.arg("-H");
curl.arg(format!("Authorization: Bearer {}", key));
```

**PITFALL:** This is insidious because:
- The API call doesn't crash — `curl -s` hides HTTP error responses
- The response body may contain `401` or `Unauthorized` text, but `output.status.success()` returns false so the error path is taken, not the success path
- The error message shown to the user is a generic "HTTP 401" or curl error, making it look like a provider config issue rather than a code bug
- All three occurrences of the same pattern must be fixed — if you fix one but miss another, that endpoint still silently fails

**Audit pattern for this bug class:** Search the entire Rust source for all occurrences of `format!(.*Bearer` to ensure every auth header construction uses `{}` interpolation, not literal text after `Bearer `.

## Critical Pitfall: reqwest::blocking in axum/tokio Handlers

**NEVER use `reqwest::blocking::get()` or `reqwest::blocking::Client` inside an axum handler.** The blocking call hangs the tokio async runtime, causing the handler to hang indefinitely and subsequent requests to queue up.

**Root cause:** reqwest's blocking API uses its own internal thread pool. When called from within a tokio task, the blocking call occupies the tokio worker thread. If the target server is slow or unreachable, the worker thread blocks until reqwest's internal timeout (which can be 60s+ by default). All other requests on that worker thread stall.

**Fix: Use `std::process::Command::new("curl")` instead.**

```rust
// DON'T:
if let Ok(resp) = reqwest::blocking::get("http://127.0.0.1:8080/v1/models") {

// DO:
if let Ok(output) = std::process::Command::new("curl")
    .args(["-s", "--max-time", "3", "http://127.0.0.1:8080/v1/models"])
    .output()
{
    if let Ok(body) = serde_json::from_slice::<serde_json::Value>(&output.stdout) {
        // process body["data"]
    }
}
```

The `--max-time` flag on curl ensures the call doesn't hang longer than the specified seconds. The subprocess approach doesn't interfere with tokio's task scheduling at all — the OS handles the process lifecycle independently.

**For HTTP POST probes (model testing):**
```rust
let payload = serde_json::json!({ "model": model_name, "messages": [...], "max_tokens": 1 });
let payload_str = serde_json::to_string(&payload).unwrap_or_default();

match std::process::Command::new("curl")
    .args(["-s", "--max-time", "10", "-X", "POST", &chat_url,
           "-H", "Content-Type: application/json",
           "-d", &payload_str])
    .output()
{
    Ok(output) if output.status.success() => /* success */,
    Ok(output) => /* HTTP error */,
    Err(e) => /* connection error */,
}
```

**PITFALL:** This creates a subprocess per request. For low-frequency probes (model health checks) this is fine. For high-frequency calls (hundreds/sec), switch to `reqwest` with the `json` feature in async mode instead.

## Model Probing Pattern

When building a model/LLM management UI, **probe each model with a real request** instead of just changing a config string. This tells the user definitively whether a model works:

1. Determine the provider from the model name prefix (`deepseek/` → nous, `x-ai/` → xai, `llama-swap/` → local)
2. Read the provider's `base_url` from config
3. Send a tiny test request: `{"model": "<name>", "messages": [{"role": "user", "content": "say hi"}], "max_tokens": 20}`
4. Parse the JSON response — check BOTH `content` and `reasoning_content` fields
5. Return `"ok"` if EITHER field is non-empty
6. On HTTP error, read the response body for the actual error message (not just the status code)

**REASONING MODEL PITFALL:** Reasoning models (DeepSeek R1, synthclaw-*) output their chain-of-thought to `reasoning_content` and leave `content` empty until final answer. A probe with `max_tokens: 1` will always get empty content. Use `max_tokens: 20` and check both fields:

```rust
let content = msg["content"].as_str().unwrap_or("");
let reasoning = msg["reasoning_content"].as_str().unwrap_or("");
if !content.is_empty() || !reasoning.is_empty() {
    ("ok".into(), "".into())
} else {
    ("error".into(), "empty response".into())
}
```

**ERROR SURFACE PITFALL:** Llama-swap returns HTTP 500 with the actual error in the response BODY (not JSON). The old probe only checked `output.status.success()` — a 500 status returned fake "ok". Always parse the body:

```rust
match curl.output() {
    Ok(output) => {
        if !output.status.success() {
            let body = String::from_utf8_lossy(&output.stdout);
            // Show the actual error from the body, not just "HTTP 500"
            let err = body.lines().next().unwrap_or(&body).chars().take(150).collect();
            return ("error".into(), err);
        }
        // Parse JSON body for content...
    }
}
```

Use `curl` from a subprocess (not reqwest blocking) to avoid hanging the async runtime. Set `--max-time 30` for cold models that need to load into VRAM (some take 20s+ to respond).

### Auto-Probe on Load

When the Models screen loads, automatically probe the currently-active model. This gives the user immediate feedback about whether their default model is actually working:

```dart
// After loading model list:
if (_currentModel.isNotEmpty) {
  _probeModel(_currentModel);
}
```

For the full probe-all-models flow, probe progressively and update the UI after each model so the user sees progress.

### CLI Usage Hints in UI

At the bottom of the models screen, show the correct CLI command for the currently-selected model. This prevents users from running `hermes 35b` (which Hermes interprets as a subcommand) instead of `hermes -m model-name`:

```dart
Text('hermes -m ${_currentModel} "your prompt"',
  style: TextStyle(fontFamily: 'monospace'))
Text('hermes chat --model ${_currentModel}',
  style: TextStyle(fontFamily: 'monospace'))
```

## Setup Wizard: Auto-Install Robustness

When building a setup wizard that auto-installs dependencies via pip, handle these failure modes:

### Failure Mode: brew install (macOS)
On macOS, Homebrew may have the package. Try brew as an alternative to pip:
```rust
"brew" => {
    match Command::new("brew").args(["install", "hermes-agent"]).output() {
        Ok(output) if output.status.success() => { /* success */ },
        Ok(output) => { /* brew error */ },
        Err(_) => { /* brew not installed, fall through to pip */ },
    }
}
```

### Failure Mode: pip3 not found
```rust
// Try pip3 first, then pip
for pip_cmd in &["pip3", "pip"] {
    if let Ok(output) = Command::new(pip_cmd).args(["install", "hermes-agent"]).output() {
        // ...
    }
}
// Neither found — detect OS and show instructions
```

### Failure Mode: externally-managed-environment (Arch Linux)
Python on Arch Linux ships with `externally-managed-environment` protection that blocks `pip install` at the system level. Automatically retry with `--break-system-packages`:

```rust
if err_lower.contains("externally-managed-environment") {
    if let Ok(retry) = Command::new(pip_cmd)
        .args(["install", "--break-system-packages", "hermes-agent"])
        .output()
    {
        if retry.status.success() { return success; }
    }
    // Show multiple workarounds:
    return Json(json!({
        "error": "Options:\n1. pip install --break-system-packages hermes-agent\n2. python3 -m venv ~/.hermes-venv && .../pip install hermes-agent\n3. pipx install hermes-agent"
    }));
}
```

### Failure Mode: pip not installed at all
Detect the OS package manager and show platform-specific instructions:

```rust
fn detect_os_install_instructions() -> &'static str {
    let checks = [
        ("pacman --version", "Arch:  sudo pacman -S python-pip"),
        ("apt --version", "Debian/Ubuntu:  sudo apt install python3-pip"),
        ("dnf --version", "Fedora:  sudo dnf install python3-pip"),
        ("brew --version", "macOS:  brew install python"),
    ];
    for (cmd, instruction) in &checks {
        if Command::new("sh").args(["-c", cmd]).output().is_ok() {
            return instruction;
        }
    }
    "Install pip via your package manager, then run: pip3 install hermes-agent"
}
```

This makes the setup wizard work out of the box for any Linux distro and macOS.

### Failure Mode: setup detection misses binary on non-standard PATH

**PITFALL:** Hardcoding only /usr/bin/hermes and /usr/local/bin/hermes in detect_setup misses installations in ~/.local/bin/ or custom locations. Also misses macOS Homebrew (/opt/homebrew/bin/). Always add a `which` fallback:

```rust
let hermes_bin = {
    let which_result = Command::new("which").arg("hermes").output().ok().and_then(|o| {
        if o.status.success() {
            String::from_utf8(o.stdout).ok().map(|s| s.trim().to_string())
        } else { None }
    });
    if which_result.is_some() { which_result }
    else {
        let home = std::env::var("HOME").unwrap_or_default();
        [format!("{}/.local/bin/hermes", home),
         "/usr/bin/hermes".into(),
         "/usr/local/bin/hermes".into(),
         "/opt/homebrew/bin/hermes".into(),     // macOS Apple Silicon
         format!("/Users/{}/.local/bin/hermes", home.split('/').last().unwrap_or("")),
        ].iter().find(|p| Path::new(p).exists()).cloned()
    }
};
```

## Adaptive Configuration (Out-of-Box Experience)

**User preference**: The app should ADAPT to any user's environment, not require manual file editing. When building a tool that wraps another system:

- **Detect** the dependency (is it installed? is it configured? are there API keys?)
- **Guide** the user through setup with a wizard, never assume manual terminal commands
- **Probe** all available models/providers on startup and report which ones actually work
- **Fail gracefully** with clear error messages that explain what's missing and how to fix it

Do NOT edit config files on the user's machine without explicit UI interaction. The app should present changes visually and let the user confirm.

## First-Run Auto-Redirect Pattern

When building a GUI that wraps an external system (Hermes, Docker, CLI tool), auto-redirect new users to the setup wizard on first launch. This prevents the "app is broken" impression when the dashboard shows errors because the underlying tool isn't installed yet:

```dart
// In root widget initState:
Future<void> _checkFirstRun() async {
  try {
    await Future.delayed(const Duration(seconds: 2));  // wait for backend ready
    final status = await backend.httpGet('/setup/detect');
    final installed = status['hermes_installed'] == true;
    final hasConfig = status['config_exists'] == true;
    if (!installed || !hasConfig) {
      setState(() => _selectedIndex = setupTabIndex);
    }
  } catch (_) {}  // backend not ready — manual navigation
}
```

Also add a "Setup Wizard" button on the dashboard error screen so users can navigate directly:

```dart
Row(
  children: [
    MaterialButton(onPressed: _retry, child: Text('Retry')),
    MaterialButton(
      onPressed: () => widget.onNavigate?.call(setupTabIndex),
      child: Row(children: [Icon(Icons.rocket_launch), Text('Setup Wizard')]),
    ),
  ],
)

## Subprocess Confirmation: Piping stdin for CLI Prompts

**PITFALL:** Some Hermes CLI commands prompt for confirmation (e.g., `hermes gateway stop`). When spawned from a Rust subprocess without a TTY, `Command::new().output()` hangs forever waiting for stdin.

## Axum State: Unused Handler Parameters

When an Axum handler takes `State(state): State<Arc<AppState>>` but many handler functions only call helpers like `read_config()` (which uses `hermes_home_dir()` directly), the `state` parameter is unused. This generates a compiler warning.

There are two fixes — prefer the simpler one:

**1. Prefix with underscore when it's still needed for one call (preferred):**
```rust
// When the function still uses state once
async fn health(State(_state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    // Use _state.config_path() somewhere — the underscore prefix suppresses the unused warning
}
```

**2. Remove the parameter entirely when no state access is needed:**
```rust
// When the function doesn't need state at all (calls read_config(), not state.config_path())
async fn discover_models() -> ModelsResponse {
    let config = read_config();  // hermes_home_dir() internally
    // ...
}
```

**When to remove vs underscore:** If the handler needs `state` for exactly one call (health check, config path), use `_state`. If the handler never touches `state` and only calls free functions (like `read_config()` or `run_hermes()`), remove the parameter entirely. This keeps the route registration unchanged while the handler signature stays clean.

## Flutter Desktop Right-Click Context Menu Pattern

On desktop platforms, right-click should trigger a context menu with file/folder actions. Flutter provides `onSecondaryTapDown` on `GestureDetector` to detect right-click and get the cursor position:

```dart
GestureDetector(
  onTap: onTap,
  onSecondaryTapDown: (details) => _showContextMenu(details.globalPosition),
  child: Container(/* ... */),
)
```

Use `showMenu()` with `RelativeRect.fromLTRB(position.dx, position.dy, ...)` to position the popup at the cursor:

```dart
Future<void> _showContextMenu(Offset pos) async {
  final result = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
    color: scheme.surface.withAlpha(235),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: scheme.borderDim.withAlpha(40)),
    ),
    items: [
      PopupMenuItem(value: 'open', child: _menuItem(scheme, Icons.folder_open, 'Open')),
      PopupMenuItem(value: 'copy_path', child: _menuItem(scheme, Icons.link, 'Copy Path')),
      const PopupMenuDivider(),
      PopupMenuItem(value: 'rename', child: _menuItem(scheme, Icons.edit, 'Rename', scheme.accent)),
      PopupMenuItem(value: 'delete', child: _menuItem(scheme, Icons.delete_outline, 'Delete…', scheme.error)),
    ],
  );

  if (result == null) return;
  switch (result) {
    case 'open': /* ... */
    case 'copy_path': Clipboard.setData(ClipboardData(text: path));
    case 'rename': _showRenameDialog(name);
    case 'delete': _showDeleteConfirm(name);
  }
}
```

Also add a **⋮ (more_vert)** button on each item so users who don't know about right-click can still access the menu:

```dart
GestureDetector(
  onTap: () => onSecondaryTap?.call(
    (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero) + const Offset(40, 0),
  ),
  child: Container(
    padding: const EdgeInsets.all(4),
    child: Icon(Icons.more_vert, size: 12, color: scheme.textMuted),
  ),
)
```

**Common right-click actions for file explorers:** View/Open, Open w/ Default App (xdg-open), Copy Path (clipboard), Rename (dialog), Duplicate (read+write with _copy suffix), Delete (confirmation dialog).

## Rust Raw String Pitfall: Embedding Python in r#" Literals

When embedding Python (or any language containing `"#`) in a Rust raw string, the `r#"` delimiter will terminate prematurely when the inner code contains `"#` (e.g., Python's `"# " + key + "="` pattern for env var detection).

**The bug:** `r#"` ends at the FIRST `"#` sequence, not the closing `"#;`.
```rust
// WRONG — Python's "# " + key + "=" terminates the raw string early!
let s = r#"if s.startswith("# " + key + "="):
    print("found")
"#;  // <- Rust sees THIS as the end of the raw string!
```

**The fix:** Use `r##"..."##` (double hash) as the raw string delimiter:
```rust
// RIGHT — double hash delimiter avoids conflict with "# in Python
let s = r##"if s.startswith("# " + key + "="):
    print("found")
"##;
```

This is the correct approach because:
- `# "` is a common Python idiom for checking commented-out env vars
- `r##"` requires exact `"##` to terminate, so `"#` inside has no special meaning
- You can go up to `r###"..."###` if needed, though `r##` covers nearly all real cases

## Gateway Platform Setup: Dynamic Form Pattern

When building a UI that configures 16+ messaging platforms (Telegram, Discord, Slack, etc.), each with different env var requirements, use a data-driven approach:

1. **Define platform metadata** in the backend (emoji, label, instructions, vars array with name/prompt/password/help fields)
2. **Return metadata + status** from a single endpoint (`GET /gateway/platforms`)
3. **Flutter renders forms dynamically** from the vars array — no per-platform hardcoded widgets

**Backend platform definition shape:**
```rust
serde_json::json!({
    "key": "telegram",
    "label": "Telegram",
    "emoji": "📱",
    "token_var": "TELEGRAM_BOT_TOKEN",
    "instructions": ["1. Open Telegram and message @BotFather", "2. Send /newbot..."],
    "vars": [
        {"name": "TELEGRAM_BOT_TOKEN", "prompt": "Bot token", "password": true,
         "help": "Paste the token from @BotFather."},
        {"name": "TELEGRAM_ALLOWED_USERS", "prompt": "Allowed user IDs", "password": false,
         "is_allowlist": true},
    ],
})
```

**Status detection logic:**
```rust
let status = if has_token {
    if runtime_status == "connected" { "connected" }
    else if runtime_status == "retrying" || runtime_status == "error" { "error" }
    else { "configured" }
} else {
    "not_configured"
};
```

**Flutter dynamic form rendering:**
```dart
for (final v in platform['vars'] as List) {
  _EnvVarField(
    scheme: scheme,
    spec: v as Map<String, dynamic>,
    controller: controllers[v['name'] as String]!,
  );
}
```

This pattern handles 16+ platforms with zero per-platform hardcoded Flutter code. The backend stores config by writing to `~/.hermes/.env` via a Python helper script.

## Cross-Platform Paths: Never Hardcode $HOME

**PITFALL:** It's easy to write `let config_path = PathBuf::from(format!("{}/.hermes/config.yaml", "/home/synth"))` when debugging, but this breaks on any other machine or platform.

**PITFALL (Dart):** On Windows, `Platform.environment['HOME']` does NOT exist — Windows uses `USERPROFILE` instead. Always fall back to `USERPROFILE` for cross-platform Dart apps:

```dart
final home = Platform.environment['HOME']
    ?? Platform.environment['USERPROFILE']
    ?? '/tmp';
```

Without the `USERPROFILE` fallback, `.hermes/` paths resolve to `/tmp/.hermes/` on Windows because `HOME` returns null. This also affects the `wingman_settings.json` path.

**PITFALL (Dart Process.start):** On Windows, setting `environment: { 'HOME': ... }` when starting a subprocess may interfere with Windows-native path resolution. Only set the HOME env on POSIX systems:

```dart
Process.start(binary, [],
  environment: Platform.isWindows
    ? null  // Windows doesn't use HOME
    : { 'HOME': Platform.environment['HOME'] ?? '/tmp' },
);
```

### Hardcoded Path Audit: Batch-Find-and-Fix Recipe

After fixing one hardcoded path, do a batch search across the entire codebase to catch ALL occurrences — they're rarely isolated:

```bash
# Rust + Dart
grep -rn "/home/YOUR_USER" --include="*.rs" --include="*.dart" .

# Shell scripts (often have fallback paths)
grep -rn "/home/YOUR_USER" --include="*.sh" .

# Also search for the pattern without the username:
# Some files use PathBuf::from(format!("{}/.hermes/...", "/home/synth"))
# instead of hermes_home_dir(). Search for format strings with home dirs.
grep -rn 'format!(".*/home' --include="*.rs" .

# Dart Platform.environment fallbacks (will have /home/synth as fallback)
grep -rn "Platform.environment" --include="*.dart" .
```

**Common places hardcoded paths hide:**
- `Platform.environment['HOME'] ?? '/home/username'` — Dart fallback values
- `std::env::var("HOME").unwrap_or("/home/username")` — Rust fallback values  
- Probe cache paths like `wingman_probed.json` that used `$HOME` construction instead of `hermes_home_dir()`
- Commented-out debug code with hardcoded paths
- Binary discovery fallback lists that reference a specific user's development directories

**Always use a shared helper function that detects the platform:**

```rust
fn hermes_home_dir() -> PathBuf {
    #[cfg(target_os = "windows")]
    {
        let local = std::env::var("LOCALAPPDATA")
            .or_else(|_| std::env::var("APPDATA"))
            .unwrap_or_else(|_| {
                let profile = std::env::var("USERPROFILE").unwrap_or_else(|_| "C:\\Users\\Default".into());
                format!("{}\\\\AppData\\Local", profile)
            });
        PathBuf::from(format!("{}\\\\hermes", local))
    }
    #[cfg(not(target_os = "windows"))]
    {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
        PathBuf::from(format!("{}/.hermes", home))
    }
}
```

**Batch-fix recipe:** After fixing one hardcoded path, search the entire codebase for the hardcoded username (`/home/synth`, `/Users/synth`) and the hardcoded path pattern (`/home/synth/.hermes/`, `format!("{}/.hermes/", home)` should use `hermes_home_dir()` instead).

## Subprocess Confirmation: Piping stdin for CLI Prompts

**PITFALL:** Some Hermes CLI commands prompt for confirmation (e.g., `hermes gateway stop`). When spawned from a Rust subprocess without a TTY, `Command::new().output()` hangs forever waiting for stdin.

**Fix:** Use `spawn()` with piped stdin, write "y\n" to the child's stdin handle, then close it:

```rust
match std::process::Command::new("hermes")
    .args(["gateway", "stop"])
    .stdin(std::process::Stdio::piped())
    .stdout(std::process::Stdio::piped())
    .stderr(std::process::Stdio::piped())
    .spawn()
{
    Ok(mut child) => {
        if let Some(stdin) = child.stdin.take() {
            use std::io::Write;
            let _ = write!(&stdin, "y\n");
            drop(stdin);  // close stdin so child can proceed
        }
        match child.wait_with_output() {
            Ok(output) if output.status.success() => { /* success */ },
            Ok(output) => { /* error: check stderr */ },
            Err(e) => { /* spawn error */ },
        }
    }
}
```

Without this, the subprocess blocks on stdin forever and the tokio runtime hangs too (since it's a blocking `wait()` on the child).

## Config Model Format: Handle Both Simple and Nested

Hermes config.yaml can represent the model field in two ways:

```yaml
# Simple (string directly)
model: llama-swap/synthclaw-qwen-128k

# Nested (with additional fields)
model:
  default: deepseek/deepseek-v4-flash
  provider: nous
  base_url: https://inference-api.nousresearch.com/v1
```

When reading the current model in Rust, handle both:

```rust
let current = config["model"].as_str()
    .map(|s| s.to_string())
    .or_else(|| config["model"]["default"].as_str().map(|s| s.to_string()))
    .unwrap_or_default();
```

When **writing** (e.g., model switch), write as a simple string:

```rust
for line in lines.iter_mut() {
    if trimmed.starts_with("model:") || trimmed == "model:" {
        *line = format!("{indent}model: {model_name}");
        break;
    }
}
```

## Universal Model Catalog Pattern

When building a model/LLM management UI, maintain a **universal catalog** of all major providers and their models. Tag each model as `"configured"` (user's config has a matching provider) or `"available"` (not yet configured but in the catalog):

```rust
fn universal_cloud_catalog() -> Vec<(&'static str, &'static str, &'static str)> {
    vec![
        ("x-ai", "grok-4", "xai"),
        ("google", "gemini-2.5-flash", "gemini"),
        ("anthropic", "claude-sonnet-4", "anthropic"),
        ("openai", "gpt-4o", "openai"),
        ("deepseek", "deepseek-v4-flash", "nous"),
        ("meta-llama", "llama-4-scout", "meta-llama"),
        ("mistral", "mistral-large", "mistral"),
        ("qwen", "qwen-3-235b-a22b", "qwen"),
        // ...
    ]
}

// Determine if configured by matching provider name patterns
let is_configured = configured_providers.iter().any(|p| {
    p == prefix
    || (prefix == "google" && (p == "gemini" || p == "gemini-oauth"))
    || (prefix == "x-ai" && p.contains("xai"))
    // ...
});
```

In the Flutter UI, show configured models in a "CONFIGURED PROVIDERS" section (green dots) and available models in an "AVAILABLE (add provider)" section (orange dots). This lets users see what's possible without being overwhelming.

## Gateway Detection: Use `running` Field, Not Platform Count

The gateway state JSON has a `gateway_state` field that can be `"running"` or `"stopped"`. When a gateway was previously running, the `platforms` object still contains entries even after it stops (they retain their last state). **NEVER use `platforms.isNotEmpty` to determine if the gateway is running** — the platforms list is non-empty even when stopped.

```rust
// CORRECT:
let is_running = json["gateway_state"].as_str() == Some("running");

// WRONG:
let is_running = !json["platforms"].as_object().unwrap_or_default().is_empty();
// This returns true even when gateway is stopped!
```

In Flutter, pass the `running` boolean from the API response directly to the UI widget:

```dart
// In gateway_screen.dart
final data = await client.httpGet('/gateway');
_serviceRunning = data['running'] == true;  // NOT platforms.isNotEmpty
```

## Flutter API Client: Expose Raw HTTP for Screens

When screens need to call new backend endpoints that aren't in the abstract `HermesService` interface, expose public `httpGet`/`httpPost` methods on `HermesApiClient`:

```dart
class HermesApiClient implements HermesService {
  // Private methods stay private
  Future<Map<String, dynamic>> _get(String path) async { ... }
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async { ... }

  // Public wrappers for screens that need raw access
  Future<Map<String, dynamic>> httpGet(String path) async => _get(path);
  Future<Map<String, dynamic>> httpPost(String path, Map<String, dynamic> body) async => _post(path, body);
}
```

Screens check the type at runtime:
```dart
if (client is HermesApiClient) {
  final data = await client.httpGet('/some/new/endpoint');
  // ... use data
}
```

This avoids modifying the abstract interface for every experimental endpoint while keeping the CLI fallback path working.

## Config Screen: Editable YAML Pattern

Never ship a config screen as read-only. Implement a toggle between view mode (syntax-highlighted YAML) and edit mode (plain text field):

1. **View mode**: Parse and render YAML with key:value color coding, line numbers
2. **Edit mode**: Full `TextField` with `maxLines: null, expands: true` for free editing
3. **Save**: POST the entire content to `/config/write` — simpler than partial updates
4. **Cancel**: Restore original text from state, revert to view mode

```dart
if (_editing)
  TextField(
    controller: _controller,
    maxLines: null,
    expands: true,
    style: TextStyle(fontFamily: 'monospace', fontSize: 11),
    decoration: InputDecoration(border: InputBorder.none),
    keyboardType: TextInputType.multiline,
  )
else
  // Syntax-highlighted YAML viewer with line numbers
  _buildYamlLines(scheme);
```

## Visual Feedback: Snackbars on Dark Themes

On dark/synthwave themes, snackbars with `backgroundColor: surface` blend into the UI and look like rendering artifacts. Always use:

```dart
SnackBar(
  backgroundColor: scheme.surface,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: scheme.primary.withValues(alpha: 0.4), width: 0.5),
  ),
  behavior: SnackBarBehavior.floating,
  margin: const EdgeInsets.all(12),
)
```

Floating snackbar with a neon border reads as intentional UI, not a visual glitch.

## System Tray Integration (Close-to-Tray)

For Flutter desktop apps that should **minimize to system tray instead of quitting**, use the `system_tray` package. The tray icon doubles as a background agent indicator — green when backend is healthy, shows tooltip with current model.

### Dependencies

```yaml
dependencies:
  system_tray: ^2.0.3
```

### Architecture

1. **`TrayService`** singleton manages `SystemTray` icon + `AppWindow` lifecycle
2. **Initialize** in `main()` after backend starts
3. **`PopScope`** widget wraps the root Scaffold to intercept window close
4. **Close → `AppWindow.hide()`** (minimizes to tray, does NOT quit)
5. **Double-click tray → `AppWindow.show()`** (restores window)
6. **Quit** from tray menu calls `_tray.destroy()` + kills backend + exits

### TrayService

```dart
class TrayService {
  final SystemTray _tray = SystemTray();
  final AppWindow _appWindow = AppWindow();

  VoidCallback? onShow;       // restore window
  VoidCallback? onQuit;       // kill backend + exit
  VoidCallback? onSetupWizard; // navigate to setup tab

  Future<void> init() async {
    // Icon path: for development it's assets/icons/; for AppImage it's usr/bin/
    await _tray.initSystemTray(
      iconPath: 'assets/icons/hermes-wingman.png',
      toolTip: 'Hermes Wingman',
    );

    // Register for tray events (left-click = show)
    _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == 'leftClick' || eventName == 'doubleClick') {
        onShow?.call();
        _appWindow.show();
      }
    });

    _buildMenu();
  }

  void _buildMenu() {
    final menu = Menu();
    menu.buildFrom([
      MenuItemLabel(label: 'Show', onClicked: (_) { onShow?.call(); _appWindow.show(); }),
      MenuItemLabel(label: 'Setup Wizard', onClicked: (_) {
        onShow?.call(); _appWindow.show(); onSetupWizard?.call();
      }),
      MenuSeparator(),
      MenuItemLabel(label: 'Quit', onClicked: (_) { _tray.destroy(); onQuit?.call(); }),
    ]);
    _tray.setContextMenu(menu);
  }

  Future<void> hideWindow() async => _appWindow.hide();
  Future<void> showWindow() async => _appWindow.show();
}
```

### Wire in main()

```dart
final trayService = TrayService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... start backend ...

  trayService.onShow = () {};
  trayService.onQuit = () { backend.stop(); };
  trayService.init();
}
```

### Window Close Interception with PopScope

```dart
return PopScope(
  canPop: false,  // never allow normal back-navigation to close
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop) {
      trayService.hideWindow();  // minimize to tray
    }
  },
  child: Scaffold(
    // ... normal app body ...
  ),
);
```

**PITFALL:** The icon must be a PNG file that exists relative to the process working directory. In development (`flutter run`), the working directory is the project root so `assets/icons/...` works. In an AppImage, the AppRun sets `cd "$HERE/usr/bin"` so icons must be bundled there. For system installer setups (`~/.local/bin/`), the icon path must be absolute. Handle this with a path search at runtime:

```dart
/// Find the tray icon from known locations — try each and return the first hit.
Future<String> _findIcon() async {
  // 1. Relative to project root (dev mode)
  if (await File('assets/icons/hermes-wingman.png').exists()) return 'assets/icons/hermes-wingman.png';
  // 2. Same directory as the running binary (installed mode)
  final exeDir = Platform.resolvedExecutable.substring(0, Platform.resolvedExecutable.lastIndexOf('/'));
  final beside = '$exeDir/hermes-wingman.png';
  if (await File(beside).exists()) return beside;
  // 3. XDG icon paths (themed or fallback)
  final home = Platform.environment['HOME'] ?? '/tmp';
  for (final path in [
    '$home/.local/share/icons/candy-icons/256x256/apps/hermes-wingman.png',
    '$home/.local/share/icons/hicolor/256x256/apps/hermes-wingman.png',
    '$home/.local/share/icons/hermes-wingman.png',
  ]) { if (await File(path).exists()) return path; }
  // 4. Last resort
  return '$home/.local/share/icons/hermes-wingman.png';
}
```

**PITFALL:** `system_tray` on Linux uses `Gtk.StatusIcon` internally, which does NOT work on Wayland compositors like Hyprland, Sway, or KDE. Wayland uses the `StatusNotifierItem` protocol (SNI) for tray icons. The `system_tray` plugin does not implement SNI — it relies on XWayland compatibility layers. The tray icon will show as a **white placeholder with a "no" symbol** on Wayland. This is cosmetic only — the app works fine, closing the window still minimizes, and double-clicking the placeholder still restores the window. For proper Wayland tray support, need a plugin that uses `libappindicator`/`libayatana-appindicator` (`StatusNotifierItem` protocol) instead of `Gtk.StatusIcon`.

**PITFALL:** When the app is re-shown after hiding (`AppWindow.show()`), Flutter may not trigger a rebuild automatically. Use `notifyListeners()` on your backend state or call `setState()` explicitly in the show callback.

## XDG Icon Installation & Cache Management

When installing a desktop application that should appear in application launchers (Spotlight, Walker, Rofi, dmenu), the icon must be:

1. A valid PNG or SVG file placed in the XDG icon theme directory
2. Referenced by name (not path) in the `.desktop` file's `Icon=` field
3. Discoverable through the icon theme cache

### Installation Steps

```bash
# 1. Copy icon to the right theme directories
ICON_NAME="my-app"
cp icon.png ~/.local/share/icons/hicolor/256x256/apps/${ICON_NAME}.png
cp icon.svg ~/.local/share/icons/hicolor/scalable/apps/${ICON_NAME}.svg

# 2. If the user's active icon theme (e.g., candy-icons) is not hicolor,
#    install into that theme too
ACTIVE_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
if [ -n "$ACTIVE_THEME" ] && [ "$ACTIVE_THEME" != "hicolor" ]; then
  mkdir -p ~/.local/share/icons/$ACTIVE_THEME/256x256/apps
  cp icon.png ~/.local/share/icons/$ACTIVE_THEME/256x256/apps/${ICON_NAME}.png
  mkdir -p ~/.local/share/icons/$ACTIVE_THEME/scalable/apps
  cp icon.svg ~/.local/share/icons/$ACTIVE_THEME/scalable/apps/${ICON_NAME}.svg
  gtk-update-icon-cache ~/.local/share/icons/$ACTIVE_THEME/ 2>/dev/null || true
fi

# 3. Ensure hicolor fallback has an index.theme (required for cache)
mkdir -p ~/.local/share/icons/hicolor
cat > ~/.local/share/icons/hicolor/index.theme << 'EOF'
[Icon Theme]
Name=Hicolor
Comment=Fallback icon theme
Hidden=true
EOF

# 4. Rebuild the icon cache
gtk-update-icon-cache ~/.local/share/icons/hicolor/ 2>/dev/null || true

# 5. Desktop entry references by name (NOT path)
cat > ~/.local/share/applications/my-app.desktop << 'DESKTOP'
Icon=my-app
DESKTOP
```

### Desktop File Icon Resolution

The XDG desktop entry spec resolves `Icon=my-app` by looking up `my-app` in:
1. The user's active icon theme (e.g., candy-icons)
2. The hicolor fallback theme
3. Absolute paths (not recommended — breaks on other machines)

**PITFALL:** `gtk-update-icon-cache` requires an `index.theme` file in the theme directory. If it doesn't exist, the cache won't be built and icons won't be found by name. Check with:
```bash
cat ~/.local/share/icons/hicolor/index.theme 2>/dev/null || echo "missing"
```

**PITFALL:** The user's active icon theme might not be `hicolor`. Check with:
```bash
gsettings get org.gnome.desktop.interface icon-theme
```
Install the icon into the active theme AND hicolor. The active theme inherits from hicolor, but not all icon lookup libraries follow XDG inheritance correctly.

**PITFALL:** After installing icons, the application launcher (Walker, Rofi, etc.) may not see the new icon until the desktop environment is restarted or the icon cache is rebuilt. Always run `gtk-update-icon-cache` after adding icons.

## Systemd User Service for Backend

For Rust HTTP backends that should run persistently (always available when the app launches), create a systemd user service. This keeps the backend alive across app restarts and reboots:

```bash
# Create the service file
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/my-backend.service << 'SERVICE'
[Unit]
Description=My App Backend
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/my-backend-binary
Restart=on-failure
RestartSec=3
Environment=PAGER=cat

[Install]
WantedBy=default.target
SERVICE

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now my-backend.service

# Check status
systemctl --user status my-backend.service
```

**How this interacts with the Flutter app:** The Flutter `BackendService` checks port availability FIRST (before trying to start the binary). If the systemd service is already running on the expected port, `_checkPort(9120)` returns true and the app connects to the existing process. No conflict.

**Key details:**
- `%h` expands to `$HOME` in systemd — no hardcoded paths
- `Restart=on-failure` with `RestartSec=3` auto-recovers from crashes
- `Type=simple` is correct for long-lived server processes
- `systemctl --user` runs in user space — no root/sudo needed
- The service file should be installed alongside the binary by the installer script

## Binary Discovery: Platform.resolvedExecutable Fallback

When a Flutter app needs to find its companion backend binary across multiple install modes (development, AppImage, system install), add a candidate path derived from `Platform.resolvedExecutable`:

```dart
Future<String?> _findBinary() async {
  final candidates = [
    'backend/target/release/my-backend',     // development
    'backend/target/debug/my-backend',
    'my-backend',                             // same CWD
    '../MacOS/my-backend',                    // macOS .app bundle
    // Same directory as the running Flutter binary (installed mode)
    '${Platform.resolvedExecutable.substring(
      0, Platform.resolvedExecutable.lastIndexOf('/'))}/my-backend',
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) return File(path).absolute.path;
  }

  // Fallback to known installation paths
  final home = Platform.environment['HOME'] ?? '/tmp';
  final alt = [
    '$home/.local/bin/my-backend',
    '$home/.cargo/bin/my-backend',
    '/opt/homebrew/bin/my-backend',    // macOS Apple Silicon
    '/usr/local/bin/my-backend',
  ];
  for (final path in alt) {
    if (File(path).existsSync()) return path;
  }
  return null;
}
```

This handles:
- **Development**: relative paths from project root
- **AppImage/AppDir**: backend in same `usr/bin/` directory
- **System install**: both binaries in `~/.local/bin/`
- **macOS .app bundle**: backend in `Contents/MacOS/`

## YAML Config Deep-Merge for Auto-Configure

When auto-detecting providers and writing config, **never rebuild the config from scratch using string formatting**. This silently drops all user-configured sections (agent, delegation, display, cron settings, profiles).

**WRONG approach** (string building — loses sections):
```rust
let mut config_yaml = String::new();
config_yaml.push_str(&format!("model: {}\n", default_model));
config_yaml.push_str("\nproviders:\n");
// ... loses 'agent', 'delegation', 'display', etc.
```

**RIGHT approach** (parse → merge → serialize):
```rust
// Parse existing config
let existing_raw = read_file(&config_path).unwrap_or_default();
let mut config_value: serde_yaml::Value = serde_yaml::from_str(&existing_raw)
    .unwrap_or(serde_yaml::Value::Null);

// Update specific fields via mapping
if let Some(mapping) = config_value.as_mapping_mut() {
    mapping.insert(
        serde_yaml::Value::String("model".into()),
        serde_yaml::Value::String(new_model.into()),
    );
    
    // Merge providers: new discoveries added, existing ones preserved
    let mut providers_map = serde_yaml::Mapping::new();
    for (name, cfg) in &discovered_providers {
        // Build provider entry...
        providers_map.insert(name_key, provider_value);
    }
    // Existing providers take precedence over discovered ones
    if let Some(existing_provs) = mapping.get(&"providers".into()) {
        if let Some(existing_map) = existing_provs.as_mapping() {
            for (k, v) in existing_map {
                providers_map.insert(k.clone(), v.clone());
            }
        }
    }
    mapping.insert("providers".into(), providers_map.into());
}

// Serialize to YAML
let config_yaml = serde_yaml::to_string(&config_value)
    .unwrap_or_else(|_| format!("model: {}", new_model));
std::fs::write(&config_path, &config_yaml)?;
```

This preserves ALL existing config sections — only `model` and `providers` are updated.

## XDG Icon Installation & Cache Management

When installing a desktop application that should appear in application launchers (Spotlight, Walker, Rofi, dmenu), the icon must be:
1. A valid PNG or SVG file placed in the XDG icon theme directory
2. Referenced by name (not path) in the `.desktop` file's `Icon=` field
3. Discoverable through the icon theme cache

### Installation Recipe

```bash
ICON_NAME="my-app"
# Copy to hicolor fallback AND the active theme
cp icon.png ~/.local/share/icons/hicolor/256x256/apps/${ICON_NAME}.png
cp icon.svg ~/.local/share/icons/hicolor/scalable/apps/${ICON_NAME}.svg

ACTIVE_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
if [ -n "$ACTIVE_THEME" ] && [ "$ACTIVE_THEME" != "hicolor" ]; then
  mkdir -p ~/.local/share/icons/$ACTIVE_THEME/256x256/apps
  cp icon.png ~/.local/share/icons/$ACTIVE_THEME/256x256/apps/${ICON_NAME}.png
  gtk-update-icon-cache ~/.local/share/icons/$ACTIVE_THEME/ 2>/dev/null || true
fi

# hicolor needs an index.theme file for the cache to work
cat > ~/.local/share/icons/hicolor/index.theme << 'EOF'
[Icon Theme]
Name=Hicolor
Comment=Fallback icon theme
Hidden=true
EOF
gtk-update-icon-cache ~/.local/share/icons/hicolor/ 2>/dev/null || true
```

**PITFALL:** `gtk-update-icon-cache` requires an `index.theme` file. Without it, the cache isn't built and icon name lookups fail silently — the launcher shows a white paper with a "no" symbol.

**PITFALL:** Installing the icon in `hicolor/256x256/apps/` is necessary but not sufficient if the user's ACTIVE theme (check `gsettings get org.gnome.desktop.interface icon-theme`) isn't hicolor. Install into the active theme too, or at minimum ensure hicolor has an `index.theme` so the cache builds.

**PITFALL:** The `.desktop` file `Exec=` line must use an absolute path or a command found in `$PATH` at launch time. Walker and other launchers may not inherit the user's shell PATH (which includes `~/.local/bin/`). Use an absolute path to a wrapper script:

```ini
[Desktop Entry]
Exec=/home/user/.local/bin/my-app-wrapper
Icon=my-app
```

### Desktop File Launch Pattern: Direct Binary, No Wrapper

Flutter Linux desktop binaries have `$ORIGIN/lib` RUNPATH baked into the ELF by the build system. This means the dynamic linker automatically finds shared libraries in `lib/` relative to the binary's own directory — no `LD_LIBRARY_PATH` needed.

**PREFERRED: Point desktop entries directly at the binary:**

```ini
[Desktop Entry]
Exec=/home/user/.local/bin/hermes_wingman
Icon=hermes-wingman
```

**Do NOT use a wrapper script for `LD_LIBRARY_PATH`.** The wrapper:

- Introduces a failure point: if `$HOME` is unset in the launcher's environment, `LD_LIBRARY_PATH` resolves incorrectly
- Prevents the launcher from tracking the binary directly (causes stale/wrong version issues after rebuilds)
- Is redundant — the binary's own RUNPATH handles library resolution

**The `Exec` line MUST be an absolute path.** Application launchers (Walker, Rofi, dmenu) may not inherit the user's shell `$PATH`, so `Exec=hermes_wingman` (bare name without path) will fail. Use the full path.

**After updating the desktop entry, always refresh the launcher cache:**
```bash
update-desktop-database ~/.local/share/applications/ 2>/dev/null
pkill walker      # Walker auto-restarts on Hyprland
# Or log out/in to refresh all launcher caches
```

**PITFALL:** The old recommendation of using a wrapper script with `LD_LIBRARY_PATH` was inherited from AppImage patterns. For system-installed Flutter binaries (`~/.local/bin/`), the built-in RUNPATH handles everything. Only use a wrapper if you need to set additional environment variables (not library paths).

## Desktop Launch Environment: Wayland vs X11

**CRITICAL PITFALL: Flutter GTK apps behave differently when launched via a desktop entry (Walker, Rofi, dmenu) vs the terminal.** This is because application launchers inherit the compositor's full Wayland environment, while terminal launches may only have `DISPLAY=:0` (X11):

**Environment when launched via desktop entry (Walker):**
```
WAYLAND_DISPLAY=wayland-1
GDK_BACKEND=wayland,x11,*
XDG_SESSION_TYPE=wayland
HYPRLAND_INSTANCE_SIGNATURE=...
```

**Environment when launched from terminal with DISPLAY=:0:**
```
DISPLAY=:0
# No WAYLAND_DISPLAY, GDK_BACKEND, or HYPRLAND vars set
```

**The app produces different window layout results in these two environments.** This is because:
- On Wayland, GTK receives window constraints from the compositor (server-side decorations, minimum/maximum sizes, tiling rules)
- On X11 (via XWayland), GTK has full control over window positioning and sizing
- Flutter's GTK embedder may receive different parent widget sizes depending on the backend

### How to Diagnose

Create a diagnostic wrapper that captures the environment:

```bash
#!/bin/bash
exec 2>/tmp/app-debug.log
set -x
echo "PWD: $(pwd)" >&2
env | sort >&2
exec /path/to/your/desired/binary "$@"
```

Point the `.desktop` file's `Exec` to this wrapper, launch from launcher, then read `/tmp/app-debug.log`.

### Fix Options (in order of preference)

**Option 1: Fix the Flutter/GTK window sizing on Wayland**

The root cause is that `Container` with only `color` set doesn't demand full space from its parent, and this interacts differently with Wayland's window constraints. **Always force Flutter desktop root layouts to fill:**

```dart
return PopScope(
  canPop: false,
  child: Container(
    color: scheme.scaffoldBackground,
    width: double.infinity,   // EXPLICITLY DEMAND FULL SPACE
    height: double.infinity,  // EXPLICITLY DEMAND FULL SPACE
    child: Row(
      children: [
        // sidebar, content...
      ],
    ),
  ),
);
```

Without `width: double.infinity, height: double.infinity` on the root `Container`, the Flutter widget tree sizes to the minimum needed by its children. On Wayland, the compositor may then size the window frame to match this smaller content area, rather than expanding it to fill the screen. The `double.infinity` tells Flutter to grab all available space from the parent's layout constraints, which forces the GTK window to request maximum size from the compositor.

**Option 2: Add the fix to the Flutter runner's GTK code (`my_application.cc`)**

In the Linux Flutter runner, after default size is set, maximize the window:

```c
gtk_window_set_default_size(window, 1280, 720);
gtk_window_maximize(window);
```

**Option 3: Force the desktop entry to use X11 (workaround, not recommended)**

```ini
[Desktop Entry]
Exec=env GDK_BACKEND=x11 /home/user/.local/bin/my-app
```
This works but loses Wayland-native performance and breaks if XWayland is disabled.

### Prevention

Always test Flutter desktop apps under BOTH launch conditions before shipping:
1. `DISPLAY=:0 /path/to/binary` (terminal, X11)
2. Via desktop entry through the system launcher (Wayland)

If the window sizes differently, apply `width: double.infinity`/`height: double.infinity` at the root layout level. This is generally good practice anyway — a `Container` with only `color` and no explicit size constraint is a layout time bomb.

## Systemd User Service for Backend

For Rust HTTP backends that should run persistently (always available when the app launches), create a systemd user service. This keeps the backend alive across app restarts and reboots:

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/my-backend.service << 'SERVICE'
[Unit]
Description=My App Backend
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/my-backend-binary
Restart=on-failure
RestartSec=3
Environment=PAGER=cat

[Install]
WantedBy=default.target
SERVICE

systemctl --user daemon-reload
systemctl --user enable --now my-backend.service
```

**How this interacts with the Flutter app:** The Flutter `BackendService` checks port availability FIRST (before trying to start the binary). If the systemd service is already running on the expected port, the port probe succeeds and the app connects to the existing process. No conflict.

**Key details:**
- `%h` expands to `$HOME` in systemd — no hardcoded paths
- `Restart=on-failure` with `RestartSec=3` auto-recovers from crashes
- `systemctl --user` runs in user space — no root/sudo needed
- The service file should be installed alongside the binary by the installer script

**PITFALL:** Don't create a systemd service that launches the Flutter GUI app — systemd user services are for daemons, not GUI applications. The service should only manage the Rust backend. The Flutter app is launched independently (from launcher, terminal, or desktop entry).

## Flutter Desktop Window Layout: The `double.infinity` Fix

**PROBLEM:** Flutter desktop apps on Linux sometimes render with a window that doesn't fill the available application area. The content appears "shrink-wrapped" — only as big as the widget tree naturally demands, rather than filling the window frame.

**ROOT CAUSE:** A `Container` with only `color` set (no explicit `width`/`height`/`constraints`) sizes itself to its child's natural dimensions. The child chains down to `Row`/`Column`/`Scaffold` which only demand the space their rendered children need. On tiling window managers (Hyprland, sway), the WM allocates the full screen but the Flutter content doesn't claim it — the GTK window frame is full-size but the Flutter scene is smaller, resulting in a dead zone or misaligned layout.

**FIX:** Add `width: double.infinity, height: double.infinity` to the root `Container` that wraps the main layout:

```dart
// BEFORE (broken — content shrink-wraps):
Container(
  color: scheme.scaffoldBackground,
  child: Row(children: [...]),
)

// AFTER (fixed — fills all available space):
Container(
  color: scheme.scaffoldBackground,
  width: double.infinity,
  height: double.infinity,
  child: Row(children: [...]),
)
```

**WHY IT WORKS:** In Flutter's layout algorithm:
- `double.infinity` means "be as big as possible given the parent's constraints"
- The parent (`PopScope` or direct widget) passes down the full window frame constraints
- The `Container` resolves to the full window size and passes tight constraints to the `Row`
- The `Row` then distributes the full width to its children (sidebar at 68px, content via `Expanded`)
- The `Expanded` widget fills all remaining space, making each screen fill edge-to-edge

**This fix is applicable whenever a Flutter desktop root layout doesn't fill the window.** Add `width: double.infinity, height: double.infinity` to any root-level `Container`, or use `SizedBox.expand()` as the parent widget.

**Architecture note:** The root widget should NOT be a `Scaffold` — each screen/section manages its own `Scaffold` for per-screen `AppBar` handling. The root only needs a `Container` or `ColoredBox` with full-size constraints.

**PITFALL:** The `chat_handler` wraps a synchronous `handle_chat()` function. Call `get_active_model()` in the async handler before calling the sync function — not inside it.

## In-Memory Model State (Frontend-Isolated Selection)

When a Flutter frontend lets users switch models, the model selection must NOT write to the global config file. Writing to config.yaml on every model switch poisons the CLI/gateway/other sessions and creates race conditions.

**Pattern:** Store the override in an `Arc<Mutex<Option<String>>>` on the shared AppState. The backend checks override first, falls back to config.

```rust
#[derive(Clone)]
struct AppState {
    override_model: Arc<Mutex<Option<String>>>,
}

fn get_active_model(state: &AppState) -> String {
    if let Ok(lock) = state.override_model.lock() {
        if let Some(ref model) = *lock { return model.clone(); }
    }
    let config = read_config();
    config["model"].as_str()
        .or_else(|| config["model"]["default"].as_str())
        .unwrap_or_default()
        .to_string()
}
```

**Switch handler:** Store in memory, return success.

```rust
async fn switch_model(
    State(state): State<Arc<AppState>>,
    Json(body): Json<SwitchModelRequest>,
) -> Json<serde_json::Value> {
    match state.override_model.lock() {
        Ok(mut override_model) => {
            let model = body.model.clone();
            if model.is_empty() { *override_model = None; }
            else { *override_model = Some(model.clone()); }
            Json(serde_json::json!({"success": true, "model": model}))
        }
        Err(e) => Json(serde_json::json!({"success": false, "error": format!("Lock poisoned: {e}")})),
    }
}
```

**Chat/stream handlers:** Capture `get_active_model` BEFORE the tokio::spawn or sync call — the Mutex borrow doesn't cross the async boundary.

**Flutter UI:** After switching, verify response and refresh model list via `GET /models` (also uses `get_active_model`).

**Benefits:**
- Config.yaml is NEVER touched by model switching
- Hermes CLI, Discord, etc. see their own config unchanged
- No file I/O on every switch — instant response
- Send empty string to reset to config default

## SOUL.md Identity Injection (Critical for Backend Proxies)

When a Rust backend proxies API calls directly to an LLM provider (llama-swap, OpenAI, Anthropic, etc.), it loses the identity/system prompt injection that the CLI tool normally handles. Without a system message containing SOUL.md, the model responds as a generic assistant.

**Fix:** Read `~/.hermes/SOUL.md` and inject it as the first `{"role": "system"}` message. Create a helper:

```rust
fn load_soul_md() -> String {
    let soul_path = hermes_home_dir().join("SOUL.md");
    match std::fs::read_to_string(&soul_path) {
        Ok(c) => c.trim().to_string(),
        Err(_) => String::new(),
    }
}
fn build_chat_messages(msg: &str) -> Vec<serde_json::Value> {
    let soul = load_soul_md();
    let mut msgs = Vec::new();
    if !soul.is_empty() { msgs.push(json!({"role":"system","content":soul})); }
    msgs.push(json!({"role":"user","content":msg}));
    msgs
}
```

**Audit:** `grep -n '"messages":' backend/src/*.rs` — every messages array should include SOUL.md, be in a CLI fallback path, or be a probe endpoint.

**Pitfall:** ~/.hermes/SOUL.md may be a symlink. Use cross-platform `hermes_home_dir()` to resolve it. Missing SOUL.md is OK — just omit the system message.

## Flutter Time Label Formatting

Relative time labels must be self-contained with proper pluralization. Never return bare units ("1m") and never append " ago" at the display site.

```dart
String get label {
    if (lastActivity == null) return '—';
    final diff = DateTime.now().difference(lastActivity!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes == 1) return '1 min ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours == 1) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return '1 day ago';
    return '${diff.inDays} days ago';
}
```

Use the label directly at display: `'latest ${session.label}'`, never `'latest ${session.label} ago'`.

## Emoji Font Bundling + Per-Codepoint Detection (Flutter Linux)

`fontFamilyFallback` only works when the primary font is **missing** the glyph. On Linux desktops with Nerd Fonts, the system font covers emoji codepoints with monochrome outlines — the fallback NEVER triggers because no codepoint is missing, the renderer just uses a monochrome glyph.

**CRITICAL:** You MUST bundle the font in pubspec.yaml AND use `fontFamily` (not `fontFamilyFallback`) on emoji-only TextSpans. A per-codepoint detection helper is required.

### Step 1: Bundle the font

```bash
cp /usr/share/fonts/noto/NotoColorEmoji.ttf assets/fonts/
```

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Noto Color Emoji
      fonts:
        - asset: assets/fonts/NotoColorEmoji.ttf
```

### Step 2: Add a detection + rendering helper

```dart
/// Detect if a code point is in an emoji range.
bool _isEmoji(int codePoint) {
  return (codePoint >= 0x2600 && codePoint <= 0x27BF) ||   // Misc symbols, dingbats
         (codePoint >= 0x1F000 && codePoint <= 0x1FFFF) ||  // Supplemental symbols, emoticons, etc.
         codePoint == 0x200D ||                             // ZWJ
         codePoint == 0xFE0F ||                             // Variation selector-16
         (codePoint >= 0x2300 && codePoint <= 0x23FF) ||   // Misc technical
         (codePoint >= 0x2B00 && codePoint <= 0x2BFF) ||   // Misc arrows
         (codePoint >= 0x3000 && codePoint <= 0x303F) ||   // CJK symbols
         (codePoint >= 0xA9 || codePoint == 0xAE) ||       // © and ®
         (codePoint >= 0x203C && codePoint <= 0x3299);      // Other common emoji ranges
}

/// Build a Text widget that renders emoji in the color emoji font
/// while using the default font for regular text.
Widget buildEmojiText(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  final runes = text.runes.toList();
  int i = 0;

  while (i < runes.length) {
    if (_isEmoji(runes[i])) {
      final start = i;
      while (i < runes.length && (_isEmoji(runes[i]) || runes[i] == 0xFE0F || runes[i] == 0x200D)) {
        i++;
      }
      spans.add(TextSpan(
        text: String.fromCharCodes(runes.sublist(start, i)),
        style: baseStyle.copyWith(fontFamily: 'Noto Color Emoji'),
      ));
    } else {
      final start = i;
      while (i < runes.length && !_isEmoji(runes[i])) { i++; }
      spans.add(TextSpan(
        text: String.fromCharCodes(runes.sublist(start, i)),
        style: baseStyle,
      ));
    }
  }
  return Text.rich(TextSpan(children: spans));
}
```

### Step 3: Use instead of bare `Text` widgets

```dart
// Instead of: Text(message.text, style: TextStyle(...))
buildEmojiText(message.text, TextStyle(color: scheme.text, fontSize: 13))
```

**PITFALL:** `fontFamilyFallback` in the text theme or on TextStyle is useless for emoji on Linux because system fonts (especially Nerd Fonts) claim to have emoji codepoints. Only `fontFamily` on an emoji-only `TextSpan` works. Do NOT rely on `fontFamilyFallback` for color emoji — it will silently do nothing.

**PITFALL:** Noto Color Emoji is an 11MB font. Bundling it increases the app's data/flutter_assets/ size by 11MB. This is the price of proper color emoji in Flutter on Linux. There is no lighter alternative that renders in color.

**PITFALL:** Always deploy `data/` along with the binary: `cp -r build/.../bundle/data/. ~/.local/bin/data/`. Without the flutter_assets/ directory (including the font), the app may crash or show stale content. The trailing slash-dot pattern `data/.` copies contents, not the directory itself.

## Absorbed Skills (Consolidated 2026-05-27)

- **flutter-backend-integration** — Flutter + Rust Axum backend integration: REST API patterns, headless browser auth (chromiumoxide), offline-first with bundled assets, FleetYards API, reference database pattern. Unique content moved to references: `references/headless-browser-auth.md`, `references/fleetyards-api.md`, `references/reference-database-pattern.md`, `references/rust-spawn-cli-path-resolution.md`, `references/api_endpoints.md`, `references/model_mapping.md`, `references/riverpod_pattern.md`

## References
- `references/icon-embedding.md` — How to properly embed custom icons in Android release APKs
- `references/release-automation.md` — Patterns for attaching builds to GitHub releases
- `references/rust-http-backend.md` — Full example: Rust HTTP backend spawned by Flutter, Hermes Wingman architecture
- `references/hermes-cli-wrapper-architecture.md` — Architecture for wrapping CLI-based Python tools with Rust backend + Flutter frontend: backend lifecycle, common interface pattern, config writing strategy, endpoint design, model discovery, gateway state parsing
- `references/hermes-wingman-backend-architecture.md` — Full 16-route backend architecture: provider classification, model discovery, model probing (curl subprocess, reasoning model fallback), chat handler (direct API + CLI fallback), gateway toggle (stdin piping), gateway state parsing, setup detection with `which` fallback. All routes documented with curl test commands.
- `references/theme-system-pattern.md` — Flutter theme system pattern: AppColorScheme class, compact const syntax, luminance-based dark detection, all 28 themes documented with hex codes
- `references/chat-direct-api.md` — Chat handler that calls model API directly (not via CLI shim): reasoning model handling, provider resolution, curl POST pattern
- `references/user-settings.md` — User-customizable title/settings persistence pattern: WingmanSettings ChangeNotifier, JSON file storage, edit dialog
- `references/auto-configure-setup-wizard.md` — Full auto-configure + setup wizard architecture: environment scanning, provider probing, 5-step wizard flow, cross-platform binary detection, installation pathways, YAML deep-merge
- `references/sse-streaming-pattern.md` — SSE streaming with Axum + reqwest + Flutter: mpsc channel architecture, provider SSE parsing, Flutter client with auto-scroll, Sse response type, keep-alive config
- `references/flutter-chat-session-persistence.md` — Multi-session chat persistence with ChangeNotifier, JSON file storage, tabbed chat UI, SSE streaming integration with session management, and session resume pattern (bottom sheet picker + `--resume <id>` CLI integration)\n- `references/in-app-provider-and-gateway-setup.md` — In-app OAuth+API key provider login and 16-platform gateway config with dynamic forms\n- `references/system-wide-file-explorer.md` — System-wide file browsing with right-click context menus (delete/rename/duplicate/copy-path)\n- `references/cli-proxy-endpoints-and-memory.md` — 17 CLI proxy endpoints, generic command runner, memory from MEMORY.md, curl installer
- `references/packaging-distribution.md` — AppDir/AppRun packaging, systemd service, install.sh, build.sh, CI workflow, .tar.gz distribution
- `references/flutter-linux-runner-wayland.md` — Flutter Linux runner GTK header bar fix for non-GNOME Wayland compositors (Hyprland, Sway, KDE), WM class matching, window property configuration
- `references/llm-jinja-template-formats.md` — Jinja chat template format compatibility by model architecture (Qwen ChatML, DeepSeek plain text, Gemma Llama-3 style), custom identity injection, tool calling, reasoning handling, debugging guide
- `references/hermes-oauth-provider-handling.md` — Full reference for detecting OAuth providers in `auth.json`, routing them through CLI, auth.json structure, auto-configure skip logic, CLI fallback for probes, and token expiry verification
- `references/in-app-provider-auth.md` — Complete pattern for building in-app provider login management: OAuth flow (spawn subprocess, capture URL, open browser, poll status), API key flow, provider status polling, logout, Flutter UI with status badges, known provider catalog
- `templates/synthclaw-qwen-chatml.jinja` — Working ChatML template for Qwen models with synthclaw identity injection, tool calling, reasoning support
- `templates/synthclaw-qwen.jinja` — Working Llama-3-style template for Gemma 4 with system prompt merged into first user turn, tool calling, reasoning support
- `scripts/strip-think-tags.rs` — Rust function to strip `<think>...</think>` reasoning blocks from streaming LLM output, usable in Axum SSE handlers
- `references/llm-reasoning-budget.md` — `--reasoning-budget` flag behavior on Qwen models, `<think>` tag stripping guidance, verbosity control

This skill governs how ambitious synthwave-themed creative tools should be built and shipped.
