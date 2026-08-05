# HermesClient — CLI Wrapper Service Pattern

When building a Flutter desktop app that wraps a local CLI tool (like Hermes Agent), use this architecture.

## Service Layer

A single `HermesClient` class owns all CLI communication:

```dart
class HermesClient {
  String? _hermesPath;

  // Auto-discover binary: which/where + common paths
  Future<String> _findHermesBinary() async { ... }

  // Run a CLI command and return stdout
  Future<String> runHermesCommand(List<String> args) async {
    final binary = await _findHermesBinary();
    // Use runInShell for regular subcommands (status, sessions, logs).
    // For --oneshot, call Process.run directly WITHOUT runInShell.
    final result = await Process.run(binary, args, runInShell: true);
    if (result.exitCode != 0) throw HermesClientException(...);
    return (result.stdout as String).trim();
  }

  // Read config files directly
  Future<String> getConfigRaw() async {
    final home = await hermesHome;
    return File('$home/config.yaml').readAsString();
  }

  // Feature methods — each returns typed models
  Future<HermesStatus> getStatus() async { ... }
  Future<List<HermesSession>> listSessions() async { ... }
  Future<List<LogEntry>> readLogs({int lines = 50}) async { ... }
}
```

**Key decisions:**
- Shell commands for dynamic data (status, sessions, logs)
- File reads for static data (config.yaml, state.db, gateway_state.json)
- Fallback from CLI to direct file reads when commands fail
- All methods throw `HermesClientException` with command context for debugging

## Cross-Platform Binary Discovery

```dart
Future<String> _findHermesBinary() async {
  // Try `which hermes` (Linux/macOS)
  // Try `where hermes` (Windows)
  // Fallback: common paths (~/.local/bin, /usr/local/bin, /opt/homebrew/bin)
  // Allow user override via settings
}
```

## Fixed-Width CLI Table Parsing

CLI tools output tables with fixed-width columns. Parse by measuring column positions from the header line, NOT by splitting on spaces:

```
Title                            Preview       Last Active   ID
─────────────────────────────────────────────────────────────────
GridOS Real Answer Revealed      you need to... just now      20260517_231732_60a037
```

Column positions (from header):
- Title: 0-32 (33 chars)
- Preview: 33-73 (41 chars) — typically not parsed
- Last Active: 74-87 (14 chars)
- ID: 88+ (rest of line)

```dart
List<HermesSession> _parseSessionList(String output) {
  // Column positions measured from the header line
  const titleEnd = 32;
  const lastActiveEnd = 87;
  
  for (final line in lines) {
    final trimmed = line.trimRight();
    if (trimmed.startsWith('Title')) continue;                     // header
    if (trimmed.startsWith('─') || trimmed.startsWith('-')) continue; // separator
    if (trimmed.length < 88) continue; // need ID column
    
    final title = trimmed.substring(0, titleEnd + 1).trim();
    final id = trimmed.substring(88).trim();
    sessions.add(HermesSession(id: id, title: title, ...));
  }
}
```

**PITFALL:** Never `.trim()` the full line before extracting columns — it destroys positional alignment. Use `.trimRight()` only.

**PITFALL:** The separator line (dashes/em-dashes) spans the full page width, not individual columns. Use the header line for column positions.

## gateway_state.json — Direct File Read

Instead of parsing `hermes gateway status` output (systemd format), read `~/.hermes/gateway_state.json` directly:

```json
{
  "gateway_state": "running",
  "platforms": {
    "telegram": { "state": "retrying", "error_code": "...", "error_message": "..." },
    "discord": { "state": "connected", "error_code": null, "error_message": null }
  }
}
```

```dart
Future<List<GatewayPlatform>> getGatewayStatus() async {
  final stateFile = File('${await hermesHome}/gateway_state.json');
  if (!await stateFile.exists()) return [];
  
  final json = jsonDecode(await stateFile.readAsString());
  final platformsJson = json['platforms'] as Map<String, dynamic>? ?? {};
  
  for (final entry in platformsJson.entries) {
    final state = entry.value['state'] ?? 'disconnected';
    platforms.add(GatewayPlatform(
      name: entry.key,
      isConnected: state == 'connected',
      icon: _platformIcon(entry.key),
    ));
  }
  return platforms;
}
```

## In-App Chat via --oneshot Subprocess

For embedded chat, use `Process.run` with `--oneshot`:

```dart
final args = ['--oneshot', userMessage];
if (lastSessionId != null) {
  args.insertAll(0, ['--resume', lastSessionId!]);  // continue conversation
}
final result = await Process.run('hermes', args);  // NO runInShell — breaks --oneshot
final response = (result.stdout as String).trim();
```

**PITFALL:** Never use `runInShell: true` with `--oneshot`. The shell re-quotes arguments, and `hermes --oneshot` is sensitive to argument quoting — it returns empty stdout when run through a shell. Use direct `Process.run` without `runInShell`.

- Session IDs extracted from stderr via regex: `RegExp(r'session[=_ ]([a-zA-Z0-9_]+)')`
- No tool access in --oneshot mode on most providers
- Chat bubble UI: user right (primary tint), AI left (surface card), session badge

## Cross-Platform Terminal Detection

```dart
class TerminalDetector {
  static Future<List<String>?> detect() async {
    if (Platform.isLinux) return _detectLinux();
    if (Platform.isMacOS) return _detectMacOS();
    if (Platform.isWindows) return _detectWindows();
    return null;
  }

  static Future<bool> launchInTerminal(List<String> command) async {
    final terminal = await detect();
    if (terminal == null) return false;
    await Process.run(terminal[0], [...terminal.sublist(1), ...command]);
    return true;
  }
}
```

See the `flutter-development` skill section 11 for the full per-platform terminal list.

## Persistent Model Favorites

Store user preferences in a local JSON file:

```dart
class FavoritesStore {
  static Future<void> toggle(String item) async {
    final favs = await load();
    if (favs.contains(item)) { favs.remove(item); }
    else { favs.add(item); if (favs.length > 5) favs.removeAt(0); }
    await save(favs);
  }
}
```

## Screen Architecture

Each screen is self-contained with four states:

| Aspect | Approach |
|--------|----------|
| State | `StatefulWidget` with local state |
| Loading | `CircularProgressIndicator` (only if no cached data) |
| Error | Error card with icon + message + Retry button |
| Empty | Icon + "No items" + contextual hint |
| Data | List/Grid with row selection and detail panel |

## Provider Wiring

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeManager()),
    Provider(create: (_) => HermesClient()),
  ],
  child: const App(),
)
```

`HermesClient` is a `Provider` (no ChangeNotifier) — screens call it and manage their own state.

## Theme System: AppColorScheme

Custom semantic color scheme layered over Material's ThemeData — see the `flutter-development` skill section 2 for the full pattern.

## Navigation: Persistent Sidebar with Callbacks

For desktop apps with 6-8 screens, use a fixed sidebar with a navigation callback:

```dart
DashboardScreen(onNavigate: (i) => setState(() => _selectedIndex = i)),
// Then in DashboardScreen: widget.onNavigate?.call(5)  // jump to Logs tab
```

See the `flutter-development` skill section 14 for the navigation callback pattern.

## Reference Implementation

The full Hermes Wingman project lives at `/home/synth/projects/hermes_wingman/`. Built for the Hermes Agent community (v0.14.0+). 8 themes, 8 screens, cross-platform.
