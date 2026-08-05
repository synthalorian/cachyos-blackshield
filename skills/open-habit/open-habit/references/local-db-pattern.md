# LocalDatabaseService — Offline Persistence Pattern

> Captured from v0.3.0 migration: HTTP server → LocalDatabaseService (SharedPreferences).

## When to use this pattern

When a Flutter app needs offline persistence without a server, and the data model
fits in shared_preferences (JSON arrays, < 1MB total). For larger datasets,
switch to SQLite via sqflite or the Rust FFI bridge.

## Architecture

```
Flutter UI → HabitNotifier (Riverpod) → LocalDatabaseService (ChangeNotifier)
                                              ↓
                                     SharedPreferences
                                     (keys: oh_habits, oh_progression, ...)
```

The service extends `ChangeNotifier`. The Riverpod Notifier subscribes via
`addListener(_onDbChanged)` and converts DB models to UI models on each change.

## Implementation Pattern

### 1. Data Models (defined alongside the service)

```dart
class HabitData {
  final String id;
  final String name;
  // ... fields ...
  
  Map<String, dynamic> toJson() => { ... };
  factory HabitData.fromJson(Map<String, dynamic> json) => ...;
}
```

Place models in the same file as the service for single-file import safety.
Do NOT define the same class name in two files — causes import collisions.

### 2. Service Class

```dart
class LocalDatabaseService extends ChangeNotifier {
  static final LocalDatabaseService _instance = LocalDatabaseService._();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._();

  Future<void> init() async {
    // Load all keys from SharedPreferences, decode JSON into model lists
  }

  Future<void> _persist(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
  }
}
```

### 3. Mutations

Each mutation:
1. Mutates the in-memory list
2. Calls `_persist()` to write back to SharedPreferences
3. Calls `notifyListeners()` to trigger UI rebuild

```dart
Future<bool> deleteHabit(String id) async {
  final before = _habits.length;
  _habits.removeWhere((h) => h.id == id);
  if (_habits.length < before) {
    await _persist('oh_habits', _habits.map((h) => h.toJson()).toList());
    notifyListeners();
    return true;
  }
  return false;
}
```

### 4. Provider Wrapper

```dart
class HabitNotifier extends Notifier<AppData> {
  final _db = LocalDatabaseService();

  @override
  AppData build() {
    _initDb();
    return state;
  }

  Future<void> _initDb() async {
    await _db.init();
    _db.addListener(_onDbChanged);
    _refreshFromDb();
  }

  void _onDbChanged() => _refreshFromDb();

  void _refreshFromDb() {
    state = AppData(
      habits: _db.habits.map(_toUiHabit).toList(),
      // ...
    );
  }
}
```

## Common Pitfalls

1. **`removeWhere` returns void** — `_list.removeWhere(...)` returns `void`, not `int`.
   Check by comparing length before/after:
   ```dart
   final before = _list.length;
   _list.removeWhere((item) => item.id == id);
   if (_list.length < before) { /* was removed */ }
   ```

2. **`ChangeNotifier` requires `listeners`** — Always call `notifyListeners()` after
   every mutation. The Riverpod provider depends on this to trigger UI rebuilds.

3. **Call `init()` before use** — The service must be initialized (load from prefs)
   before any getter/mutation is called. The `HabitNotifier.build()` calls `_initDb()`
   which awaits `_db.init()`.

4. **Subscription lifecycle** — `addListener()` in `_initDb()` means the provider
   subscribes to DB changes. The listener should call `_refreshFromDb()` (not do heavy work).

5. **Avoid re-entrant mutations** — `_persist()` is async. If two mutations happen
   quickly, the second `_persist()` might write before the first completes. For MVP
   this is fine; for production add a write queue.
