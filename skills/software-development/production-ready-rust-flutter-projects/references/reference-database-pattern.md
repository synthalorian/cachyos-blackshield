# ReferenceDatabase Pattern — Multi-File JSON Asset Loading

For apps that bundle multiple reference datasets (factions, locations, missions, commodities, components), the ReferenceDatabase pattern provides a single entry point for all read-only reference data.

## Architecture Decision

Use this pattern when:
- Data is **read-only** (never modified by the user)
- Data changes **infrequently** (only when you update the app)
- You have **multiple datasets** (5-20 JSON files)
- You want **cross-category search**

Do NOT use this pattern for:
- User data (use SharedPreferences or SQLite)
- Data that needs complex queries or joins (use Rust bridge + SQLite)
- Data that needs to be updated without an app update

## Pattern

```
assets/data/
├── factions.json          # 13 factions with rep tiers
├── missions.json          # 26 mission types with rewards
├── locations.json         # 25 Stanton system locations
├── commodities.json       # 34 trade goods
├── ships.json             # 238 ships (optional — can use Rust bridge instead)
```

### Singleton Service

```dart
class ReferenceDatabase {
  static final ReferenceDatabase _instance = ReferenceDatabase._();
  factory ReferenceDatabase() => _instance;
  ReferenceDatabase._();

  List<Map<String, dynamic>> _data1 = [];
  List<Map<String, dynamic>> _data2 = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final futures = await Future.wait([
      rootBundle.loadString('assets/data/data1.json'),
      rootBundle.loadString('assets/data/data2.json'),
    ]);
    _data1 = List<Map<String, dynamic>>.from(json.decode(futures[0]));
    _data2 = List<Map<String, dynamic>>.from(json.decode(futures[1]));
    _loaded = true;
  }

  List<Map<String, dynamic>> get data1 => List.unmodifiable(_data1);
  List<Map<String, dynamic>> get data2 => List.unmodifiable(_data2);
}
```

### Cross-Category Search

```dart
List<Map<String, dynamic>> search(String query) {
  final q = query.toLowerCase();
  return [
    ..._data1.where((d) => (d['name'] as String).toLowerCase().contains(q)),
    ..._data2.where((d) => (d['name'] as String).toLowerCase().contains(q)),
  ];
}
```

### Registration

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/data/data1.json
    - assets/data/data2.json
```

### Preload at Startup (Mandatory)

```dart
// In app's initState or main():
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ReferenceDatabase().load();  // Fire and forget — screen handles loading state
  runApp(const MyApp());
}
```

## Category-Based UI Navigation

Create a hub screen with category cards, each navigating to a generic detail screen that renders items from one category:

```dart
// Guide screen — category cards in a 2-column grid
GridView.count(
  crossAxisCount: 2,
  children: [
    CategoryCard(icon: Icons.groups, title: 'Factions', color: Colors.magenta,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => GuideCategoryScreen(category: 'factions')))),
    // ...
  ],
)

// Generic category screen
class GuideCategoryScreen extends StatelessWidget {
  final String category;
  // maps category → data from ReferenceDatabase
  // renders each item as a glassmorphism card with name, type badge, description
}
```

## vs. Rust Bridge SQLite Seeding

| Approach | Use Case | Load Time | Query Capability |
|----------|----------|-----------|------------------|
| Dart JSON asset (ReferenceDB) | Read-only reference data | Instant (Synchronous after load) | Simple iteration + filters |
| Rust SQLite (seeded from JSON) | Complex queries, writeable data, joins | ~100ms (FFI overhead) | SQL queries, joins, indexes |

Both patterns can coexist in the same app. Use ReferenceDatabase for guides/settings/reference and Rust SQLite for ship stats/fleet management.
