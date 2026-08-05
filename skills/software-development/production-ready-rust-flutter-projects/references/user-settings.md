# User-Customizable Settings Pattern

For Flutter desktop apps with user-configurable display strings (dashboard title, app name), persist settings to a JSON file in a known location and expose them via a `ChangeNotifier`.

## Architecture

```
WingmanSettings (ChangeNotifier)
  ├── dashboardTitle: String
  ├── appTitle: String
  ├── setTitle(String) → persists to file
  ├── _load() → reads from ~/.hermes/wingman_settings.json
  └── _save() → writes to ~/.hermes/wingman_settings.json
```

## Implementation

```dart
class WingmanSettings extends ChangeNotifier {
  String _dashboardTitle = 'Default Title';
  String _appTitle = 'Default Title';

  static String get _settingsPath {
    final home = Platform.environment['HOME'] ?? '/home/synth';
    return '$home/.hermes/wingman_settings.json';
  }

  WingmanSettings() { _load(); }

  void _load() {
    try {
      final file = File(_settingsPath);
      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync());
        _dashboardTitle = data['dashboard_title'] ?? 'Default Title';
        _appTitle = data['app_title'] ?? 'Default Title';
      }
    } catch (_) {}
  }

  void _save() {
    File(_settingsPath).parent.createSync(recursive: true);
    File(_settingsPath).writeAsStringSync(jsonEncode({
      'dashboard_title': _dashboardTitle,
      'app_title': _appTitle,
      'updated_at': DateTime.now().toIso8601String(),
    }));
  }

  void setTitle(String title) {
    _dashboardTitle = title;
    _appTitle = title;
    _save();
    notifyListeners();
  }
}
```

## Provider Registration

```dart
ChangeNotifierProvider(create: (_) => WingmanSettings()),
```

## Usage in Widget

```dart
final settings = context.watch<WingmanSettings>();
Text(settings.dashboardTitle);
```

## Edit Dialog

Trigger on double-tap of the title widget:

```dart
GestureDetector(
  onDoubleTap: () => WingmanSettings.showEditDialog(context),
  child: Text(settings.dashboardTitle),
)
```

The dialog uses a `TextField` with the current title, and calls `settings.setTitle(result)` on save.
