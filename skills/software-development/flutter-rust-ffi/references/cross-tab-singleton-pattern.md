# Cross-Tab Service Access Pattern

When a Flutter app has multiple tabs (via `IndexedStack`) and a service needs to be accessible from any tab (e.g., ThemeManager, UserShipData, RustDatabaseService), use a **singleton pattern** rather than passing callbacks through the widget tree.

## The Problem

```dart
// app.dart — passing callbacks to every tab is fragile
Scaffold(
  body: IndexedStack(
    children: [
      FleetScreen(onTapTheme: _openThemeSelector),   // must pass
      ShipListScreen(onTapTheme: _openThemeSelector), // must pass
      SettingsScreen(onTapTheme: _openThemeSelector), // must pass
    ],
  ),
)
```

Callbacks break when:
- `Navigator.of(context)` resolves from the wrong context
- `AnimatedSwitcher` + `IndexedStack` nesting creates unexpected widget tree
- A new screen is added and the callback is forgotten

## The Fix: Singleton + Direct Navigation

Make the service a proper singleton and have screens navigate directly.

### Step 1: Convert to Singleton

```dart
class ThemeManager extends ChangeNotifier {
  static ThemeManager? _instance;
  static ThemeManager get instance {
    _instance ??= ThemeManager._();
    return _instance!;
  }

  ThemeManager._();  // private constructor
  factory ThemeManager() => instance;  // public factory

  // ... normal implementation
}
```

### Step 2: Navigate from the Screen's Own Context

```dart
class SettingsScreen extends StatelessWidget {
  void _openThemeSelector(BuildContext context) {
    Navigator.of(context).push<AppThemeType>(
      MaterialPageRoute(
        builder: (_) => ThemeSelectorScreen(
          currentType: ThemeManager.instance.currentType,
        ),
      ),
    ).then((result) {
      if (result != null) {
        ThemeManager.instance.setTheme(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => _openThemeSelector(context),
            icon: Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Change Theme'),
            onTap: () => _openThemeSelector(context),
          ),
        ],
      ),
    );
  }
}
```

### Step 3: Simplify app.dart

```dart
// app.dart — no callbacks needed
Scaffold(
  body: IndexedStack(
    children: [
      FleetScreen(),     // no callback
      ShipListScreen(),  // no callback
      SettingsScreen(),  // handles its own navigation
    ],
  ),
)
```

## When to Use vs. When Not To

**Use singleton + direct navigation when:**
- The service is truly global (theme, settings, database)
- Multiple UI entry points need to access it
- The navigation is a push/pop (not a data stream)

**Keep passing callbacks when:**
- The action needs to return a value to the parent (e.g., tab switching)
- The service is scoped to a specific subtree
- Testing/mocking requires injection

## Related Patterns

- `RustDatabaseService` — Same singleton pattern for the Rust FFI bridge
- `UserShipData` — `ChangeNotifier` singleton for local fleet storage (SharedPreferences)
