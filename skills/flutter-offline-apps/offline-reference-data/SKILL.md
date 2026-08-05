---
name: offline-reference-data
description: Patterns for bundled offline reference data in Flutter apps — JSON assets, searchable Dart services, category navigation, interactive maps, code-generated entity visuals.
version: 1.0.0
author: synthclaw
license: MIT
metadata:
  tags: [flutter, offline, reference-data, custom-painter, static-data]
---

# Offline Reference Data Patterns

Patterns for building feature-rich offline Flutter apps that bundle all data in the APK. No server, no API calls, no network required.

## 1. Bundled JSON Asset Architecture

### Data Files
Static JSON files stored in `assets/data/` — registered in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/data/ships.json
    - assets/data/factions.json
    - assets/data/locations.json
```

### Dart Service Layer
Singleton service loads all JSON on app startup:

```dart
class ReferenceDatabase {
  static final ReferenceDatabase _instance = ReferenceDatabase._();
  factory ReferenceDatabase() => _instance;

  List<Map<String, dynamic>> _items = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final jsonString = await rootBundle.loadString('assets/data/factions.json');
    _items = List<Map<String, dynamic>>.from(json.decode(jsonString));
    _loaded = true;
  }
}
```

Preload at startup in `app.dart`:
```dart
void initState() {
  super.initState();
  ReferenceDatabase().load();
}
```

### Category Hub Screen
Grid of category cards, each navigating to a detail screen filtered by category.

Key implementation details in `references/category-screen-pattern.md`.

## 2. Interactive CustomPainter Maps

For rendering star systems, maps, or any orbital/geographical data entirely in code.

### Structure
```
InteractiveViewer → GestureDetector → CustomPaint
```

- `InteractiveViewer`: pinch-to-zoom (0.5x–3.0x), pan, boundary margin
- `GestureDetector`: tap detection with position-based hit testing
- `CustomPaint`: all visual rendering (starfield, orbits, markers, labels, glow effects, scan lines)

See `references/custom-painter-map-pattern.md` for detailed implementation.

### Label Collision Detection
Track drawn label bounding boxes and try multiple anchor positions:

```dart
final List<Rect> _drawnLabelBounds = [];

// In paint():
_drawnLabelBounds.clear();
// ... draw markers ...

// In _drawLabel():
final anchors = <Offset>[
  Offset(pos.dx - textW / 2, pos.dy + offsetY),   // below
  Offset(pos.dx - textW / 2, pos.dy - offsetY - h), // above
  Offset(pos.dx + offsetY, pos.dy - h / 2),         // right
  Offset(pos.dx - offsetY - textW, pos.dy - h / 2), // left
  // ... more positions ...
];

Offset? chosenPos;
for (final anchor in anchors) {
  final labelRect = Rect.fromLTWH(anchor.dx - padding, anchor.dy - padding, textW + padding*2, textH + padding*2);
  if (!_drawnLabelBounds.any((r) => r.overlaps(labelRect))) {
    chosenPos = anchor;
    break;
  }
}
_drawnLabelBounds.add(labelRect);
```

## 3. Code-Generated Entity Visuals (No Image Bundling)

Instead of bundling ship/character/item images (which bloat the APK), generate colored icon visuals from entity metadata.

### Manufacturer/Entity Style Map
Map entity names to color schemes + icons:

```dart
class EntityStyle {
  final Color primary;
  final Color secondary;
  final IconData icon;

  static final Map<String, EntityStyle> _styles = {
    'origin': EntityStyle(primary: Color(0xFFE0E0FF), secondary: Color(0xFF6B6BFF), icon: Icons.diamond_outlined),
    'aegis': EntityStyle(primary: Color(0xFFFF4444), secondary: Color(0xFF8B0000), icon: Icons.shield_outlined),
  };

  static EntityStyle forName(String name) {
    final key = name.toLowerCase();
    return _styles.entries.firstWhere(
      (e) => key.contains(e.key),
      orElse: () => defaultStyle,
    ).value;
  }
}
```

### Avatar Widget
```dart
class EntityAvatar extends StatelessWidget {
  final String entityName;
  final double size;
  
  Widget build(context) {
    final style = EntityStyle.forName(entityName);
    return Container(
      width: size, height: size,
      decoration: style.decoration(), // gradient + border
      child: Icon(style.icon, color: style.primary),
    );
  }
}
```

### Hero Banner Widget
Full-width gradient banner for detail screens with entity name + type badge + price.

## 4. Category Hub → List → Detail Flow

For reference apps with multiple data categories (factions, contracts, locations, commodities, components, stores), build a hub screen with tappable category cards that navigate to a generic list screen with category-specific detail bottom sheets.

### Hub Screen Structure
Grid of category cards (2 columns). Each card has: icon (Material Icons), title, subtitle, color.

```dart
static const List<_Category> _categories = [
  _Category(id: 'factions', title: 'Factions', icon: Icons.groups, color: Color(0xFFFF00FF),
    dbCategory: 'factions'),
  _Category(id: 'shopping', title: 'Shopping', icon: Icons.shopping_bag_outlined, color: Color(0xFFFF69B4),
    dbCategory: 'stores'),
  // ...
];
```

### Category Detail Screen
A single generic `GuideCategoryScreen` that receives `categoryId`, `items` list, and renders styled cards. Each card is tappable and opens a detail bottom sheet.

**Bottom sheet adapts per category:**
```dart
Widget _buildDetailContent(ThemeData theme, Map<String, dynamic> item) {
  switch (categoryId) {
    case 'factions':
      // Show name, type badge, description, reputationTiers list
    case 'missions':
      // Show name, type badge, reward range, locations
    case 'commodities':
      // Show name, type badge, price, bulk size, legality warning
    case 'locations':
      // Show name, type badge, planet, services as icon chips
    case 'components':
      // Show name, type badge, size, grade, manufacturer, stats (typeData)
    case 'stores':
      // Show name, type badge, location, planet, sells list, brands
  }
}
```

### Per-Item Visuals
When a category has sub-types (like components with weapons/shields/armor), replace the generic category icon with a sub-type-specific avatar:

```dart
if (categoryId == 'components')
  ComponentAvatar(
    category: item['category'],  // 'weapons', 'shieldgenerator', etc.
    manufacturer: item['manufacturer'],
    size: 40,
  )
else
  Container(child: Icon(categoryIcon, color: categoryIconColor)),
```

### Data Registration Checklist
When adding a new data category to an offline app:
1. Create the JSON file in `assets/data/`
2. Register it in `pubspec.yaml` under `flutter.assets`
3. Add the `_items` list + deserialization in the singleton service's `load()` method
4. Add a getter + search case
5. Add a category card + switch case in the hub screen

## 5. Code-Generated Visuals for Components (ComponentAvatar)

Extend the code-generated visuals pattern to cover **ship components** (weapons, shields, armor, power plants, coolers, quantum drives, radar) where no source images exist.

Unlike ShipAvatar (which uses manufacturer alone), ComponentAvatar uses **two dimensions**:
- **Category** determines the icon (weapon crosshair, shield, bolt, snowflake, speedometer)
- **Manufacturer** determines the color scheme

### Category Style Map
```dart
static const Map<String, _CategoryStyle> _categoryStyles = {
  'weapons':         _CategoryStyle(icon: Icons.gps_fixed, color: Color(0xFFFF5555)),
  'shieldgenerator': _CategoryStyle(icon: Icons.shield_outlined, color: Color(0xFF4488FF)),
  'armor':           _CategoryStyle(icon: Icons.security_outlined, color: Color(0xFF999999)),
  'powerplant':      _CategoryStyle(icon: Icons.bolt_outlined, color: Color(0xFFFFD700)),
  'cooler':          _CategoryStyle(icon: Icons.ac_unit_outlined, color: Color(0xFF55CCFF)),
  'quantumdrive':    _CategoryStyle(icon: Icons.speed_outlined, color: Color(0xFFFF69B4)),
  'radar':           _CategoryStyle(icon: Icons.radar_outlined, color: Color(0xFF66FF99)),
};
```

### Component Manufacturer Color Map
Map known component manufacturers to color accents:
```dart
static const Map<String, Color> _manufacturerColors = {
  'behring': Color(0xFFCC3333),
  'klaus': Color(0xFFFF8800),
  'juno': Color(0xFF00CCFF),
  'gorgon': Color(0xFF6666FF),
  'firestorm': Color(0xFFFF6600),
  // 14+ manufacturers mapped
};
```

### ComponentAvatar Widget
```dart
class ComponentAvatar extends StatelessWidget {
  final String category;
  final String manufacturer;
  final double size;

  Widget build(context) {
    final catStyle = _categoryStyles[category] ?? _defaultStyle;
    final mfrColor = _manufacturerColor(manufacturer) ?? catStyle.color;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: LinearGradient(colors: [
          mfrColor.withValues(alpha: 0.15),
          mfrColor.withValues(alpha: 0.05),
        ]),
        border: Border.all(color: mfrColor.withValues(alpha: 0.3)),
      ),
      child: Icon(catStyle.icon, size: size * 0.5, color: mfrColor),
    );
  }
}
```

## 6. Button & Link Reliability (Android)

**Critical lesson:** `canLaunchUrl()` silently returns `false` on Android 11+ without matching `<queries>` in the manifest. **Never use it.** Use try/catch around `launchUrl`:

```dart
void openLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // Browser unavailable — silently handle
  }
}
```

**Theme/Navigation pattern:** When a child widget needs to push a route and apply a result, prefer direct navigation + singleton access over callback chains. ThemeManager singleton avoids Navigator context resolution issues:

```dart
// In child screen:
Navigator.of(context).push<AppThemeType>(MaterialPageRoute(...))
  .then((result) {
    if (result != null) ThemeManager.instance.setTheme(result);
  });
```
