# Flutter API Client + AuthManager Pattern (Dio + ChangeNotifier)

An alternative to Riverpod for apps that want minimal state management dependencies. Uses Dio for HTTP, a singleton ApiClient, and a ChangeNotifier-based AuthManager for authentication state that persists across restarts.

## Architecture

```
ApiClient (Singleton, Dio)
  ├── login(username, password)
  ├── getFleet()
  ├── healthCheck()
  └── interceptors: logging, error handling

LoginApiResponse (value object)
  ├── success, requires2fa, sessionId, message
  └── returned from login()

FleetShip (data model)
  └── fromJson factory

AuthManager (ChangeNotifier)
  ├── login() → calls ApiClient → updates status
  ├── logout() → clears session
  ├── Loads session_id from SharedPreferences on init
  ├── Exposes: status, isAuthenticated, sessionId, username
  └── +listener → setState() in parent widget
```

## When to Use This vs. Riverpod

| Factor | Dio + ChangeNotifier (this) | Riverpod |
|--------|---------------------------|----------|
| Dependencies | dio, shared_preferences | flutter_riverpod, riverpod_annotation, build_runner |
| Boilerplate | Low — just write the class | Medium — providers, code gen |
| State sharing | Pass via constructor/prop | `ref.watch()` anywhere |
| Complexity ceiling | Moderate — fine for auth + basic state | High — scales to complex state graphs |
| Build time | Instant | `build_runner` pass needed |

**Use this when:** the app needs auth state and a few shared values, doesn't already use Riverpod, and you want to ship fast without code generation.

**Use Riverpod when:** complex state graphs, multiple interdependent providers, or the app already uses it.

## Core Files

### `lib/core/api/api_endpoints.dart`

```dart
class ApiEndpoints {
  static const String baseUrl = 'http://localhost:3001';
  static const String apiPrefix = '/api/v1';
  static const String login = '$apiPrefix/auth/login';
  static const String fleet = '$apiPrefix/fleet';
  static const String ships = '$apiPrefix/ships';
  static String ship(String id) => '$apiPrefix/ships/$id';
  static const String status = '$apiPrefix/status';
}
```

### `lib/core/api/api_client.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(LogInterceptor(logPrint: (o) => debugPrint('[API] $o')));
  }

  Future<LoginApiResponse> login(String username, String password) async {
    try {
      final response = await _dio.post(ApiEndpoints.login, data: {
        'username': username, 'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      return LoginApiResponse(
        success: data['success'] as bool? ?? false,
        requires2fa: data['requires_2fa'] as bool? ?? false,
        sessionId: data['session_id'] as String?,
        message: data['message'] as String? ?? '',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final msg = (e.response?.data as Map<String, dynamic>?)?
            .cast<String, dynamic>()['message'] as String? ?? 'Login failed';
        return LoginApiResponse(success: false, message: msg);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return LoginApiResponse(success: false,
            message: 'Cannot connect to server. Is it running?');
      }
      return LoginApiResponse(success: false, message: 'Network error: ${e.message}');
    }
  }

  Future<List<FleetShip>> getFleet() async {
    try {
      final response = await _dio.get(ApiEndpoints.fleet);
      final data = response.data as List<dynamic>;
      return data.map((e) => FleetShip.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> healthCheck() async {
    try {
      final r = await _dio.get(ApiEndpoints.status);
      return r.statusCode == 200;
    } catch (_) { return false; }
  }
}

class LoginApiResponse {
  final bool success, requires2fa;
  final String? sessionId;
  final String message;
  const LoginApiResponse({
    required this.success, this.requires2fa = false,
    this.sessionId, required this.message,
  });
}

class FleetShip {
  final String id, name, manufacturer, size, role;
  const FleetShip({required this.id, required this.name, required this.manufacturer, required this.size, required this.role});
  factory FleetShip.fromJson(Map<String, dynamic> json) => FleetShip(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    manufacturer: json['manufacturer'] as String? ?? '',
    size: json['size'] as String? ?? '',
    role: json['role'] as String? ?? '',
  );
}
```

### `lib/core/api/auth_manager.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, requires2fa, error }

class AuthManager extends ChangeNotifier {
  static const String _sessionKey = 'auth_session_id';
  static const String _usernameKey = 'auth_username';

  AuthStatus _status = AuthStatus.unauthenticated;
  String? _sessionId;
  String? _username;
  final ApiClient _api = ApiClient();  // singleton

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get sessionId => _sessionId;
  String? get username => _username;

  AuthManager() { _loadSession(); }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sid = prefs.getString(_sessionKey);
    final un = prefs.getString(_usernameKey);
    if (sid != null && un != null) {
      _sessionId = sid; _username = un;
      _status = AuthStatus.authenticated;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _status = AuthStatus.authenticating; notifyListeners();
    final resp = await _api.login(username, password);
    if (resp.success && !resp.requires2fa) {
      _status = AuthStatus.authenticated;
      _sessionId = resp.sessionId; _username = username;
      final prefs = await SharedPreferences.getInstance();
      if (resp.sessionId != null) await prefs.setString(_sessionKey, resp.sessionId!);
      await prefs.setString(_usernameKey, username);
    } else if (resp.requires2fa) {
      _status = AuthStatus.requires2fa;
    } else {
      _status = AuthStatus.error;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _status = AuthStatus.unauthenticated;
    _sessionId = null; _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_usernameKey);
    notifyListeners();
  }
}
```

## Wiring in App Shell

```dart
class AppRoot extends StatefulWidget { ... }

class AppRootState extends State<AppRoot> {
  final _themeManager = ThemeManager();
  final _authManager = AuthManager();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _themeManager.addListener(() => setState(() {}));
    _authManager.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _themeManager.removeListener(() => setState(() {}));
    _authManager.removeListener(() => setState(() {}));
    _themeManager.dispose();
    _authManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _themeManager.currentTheme,
      home: Scaffold(
        body: IndexedStack(index: _tab, children: [
          FleetScreen(authManager: _authManager),
          const ShipListScreen(),
          AuthScreen(authManager: _authManager),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.rocket_launch_outlined), label: 'Fleet'),
            NavigationDestination(icon: Icon(Icons.scanner_outlined), label: 'Ships'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
```

**Key design decisions:**
- `IndexedStack` keeps all 3 tabs alive (no rebuild on tab switch) — simpler than ShellRoute
- `ThemeManager` and `AuthManager` are both `ChangeNotifier`, both wired with `addListener(() => setState(() {}))`
- AuthManager is passed via constructor (not inherited widget) — makes screens testable
- AuthScreen and FleetScreen both listen to AuthManager and react to auth state changes

## Auth-Aware Screen Patterns

### Dual-state screen (login form vs. connected view)

```dart
class AuthScreen extends StatefulWidget {
  final AuthManager authManager;
  const AuthScreen({required this.authManager});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  void initState() {
    super.initState();
    widget.authManager.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.authManager.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authManager;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(child: auth.isAuthenticated
          ? _buildConnectedView(theme, auth)
          : _buildLoginForm(theme, auth)),
    );
  }

  Widget _buildLoginForm(ThemeData theme, AuthManager auth) { ... }
  Widget _buildConnectedView(ThemeData theme, AuthManager auth) { ... }
}
```

### Auth-gated content screen

```dart
class FleetScreen extends StatefulWidget {
  final AuthManager authManager;
  const FleetScreen({required this.authManager});
  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  @override
  void initState() {
    super.initState();
    widget.authManager.addListener(_onAuthChanged);
    if (widget.authManager.isAuthenticated) _loadFleet();
  }

  @override
  void dispose() {
    widget.authManager.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
    if (widget.authManager.isAuthenticated) _loadFleet();
  }

  @override
  Widget build(BuildContext context) {
    return widget.authManager.isAuthenticated
        ? _buildFleetContent()
        : _buildSignInPrompt();
  }
}
```

## Pitfalls

1. **ChangeNotifier listener must be removed in dispose()** — always pair `addListener` with `removeListener` in `dispose()`. Missing this causes stale references and memory leaks in long-running apps with tab switching.

2. **DioException vs base Exception** — catch `DioException` specifically, not generic `Exception`. Dio throws typed errors for timeouts, connection failures, HTTP errors, and cancellations. A generic catch masks the real problem.

3. **Singleton ApiClient with mutable state** — the `_dio` instance is created once. Don't modify `_dio.options.baseUrl` at runtime. Create a new instance if the server URL changes (different IP for dev vs prod).

4. **LoginApiResponse fields may be null from JSON** — the server might return non-standard error shapes. Use `as bool? ?? false` and `as String? ?? ''` for safe deserialization.

5. **Auth session persistence means stale sessions** — a saved `session_id` might be expired server-side. The AuthManager doesn't validate on init. Future improvement: call `GET /auth/status` or similar on init.

6. **Android back button + IndexedStack** — all screens stay mounted. When auth screen shows "Connected" and user presses back, they go to launcher, not fleet tab. Consider `PopScope` or custom back navigation.

7. **use_build_context_synchronously in async callbacks** — when calling `authManager.login()` from a button `onPressed`, the context may be invalid after `await`. Capture `ScaffoldMessenger.of(context)` before the await, or check `mounted` after.

8. **IndexedStack keeps ALL screens alive** — even invisible ones run their build methods. If a screen makes heavy API calls in initState, they fire immediately. Use lazy initialization or guard with `isAuthenticated` checks.

## Source

SC:Synthesis session (2026-05-15). Flutter 3.41.9, Dio 5.7.0, shared_preferences 2.3.4.
