# Loadout Builder — Architecture & Data Model

## Overview

The Loadout Builder lets users create, save, and manage ship loadouts. A loadout is a named collection of component assignments for 6 slot categories on a specific ship. Persisted via SharedPreferences as JSON.

## File Layout

```
lib/features/loadouts/
├── loadout_data.dart          # LoadoutSlot, Loadout, LoadoutService (model + persistence)
├── loadout_editor_screen.dart # Main editor: ship picker + slot editor + component picker
└── loadout_list_screen.dart   # Saved loadout card list with popup menu (edit/duplicate/delete)
```

## Data Model

### LoadoutSlot
```dart
class LoadoutSlot {
  final String category;      // weapons, shieldgenerator, powerplant, cooler, quantumdrive, radar
  String? componentId;        // ReferenceDatabase components[].id
  Map<String, dynamic>? componentData; // Populated by resolveComponents()
}
```
Six default slots per loadout, one per category. `componentData` is resolved from ReferenceDatabase after load to avoid stale references. `toJson()`/`fromJson()` for SharedPreferences serialization (saves only `category` and `componentId`).

### Loadout
```dart
class Loadout {
  String id;                   // millisecondsSinceEpoch string
  String shipId;               // matches Rust DB Ship.id
  String shipName;             // display name
  String shipSlug;             // for ShipAvatar lookup
  String name;                 // user-given friendly name
  List<LoadoutSlot> slots;     // always 6, one per category
  DateTime createdAt;
  DateTime updatedAt;
}
```
`resolveComponents(ReferenceDatabase db)` — iterates slots, queries `db.components` by id, populates `componentData`. Call after deserialization before displaying.
`totalCost` — sums `price` field from each slot's componentData.

### LoadoutService
```dart
class LoadoutService extends ChangeNotifier {
  static final LoadoutService _instance = LoadoutService._();
  factory LoadoutService() => _instance;

  List<Loadout> _loadouts = [];

  Future<void> load();          // from SharedPreferences key "loadouts"
  Future<void> addLoadout(Loadout);     // append + save
  Future<void> updateLoadout(Loadout);  // find by id, replace + save
  Future<void> deleteLoadout(String id);
  Future<void> duplicateLoadout(String id); // copy with "(copy)" suffix
}
```
Singleton. `load()` called once on app init (in `LoadoutListScreen.initState`). All mutations auto-call `_save()` and `notifyListeners()`.

## Slot Visuals

Each slot category has a fixed icon and color used across the editor:

| Category | Icon | Color |
|----------|------|-------|
| `weapons` | `Icons.gps_fixed` | Red (0xFFFF4444) |
| `shieldgenerator` | `Icons.shield` | Cyan (0xFF00BCD4) |
| `powerplant` | `Icons.bolt` | Amber (0xFFFFC107) |
| `cooler` | `Icons.ac_unit` | Light Blue (0xFF03A9F4) |
| `quantumdrive` | `Icons.rocket` | Purple (0xFF9C27B0) |
| `radar` | `Icons.radar` | Green (0xFF4CAF50) |

## Component Picker (_ComponentPickerScreen)

Internal screen, not exported. Opened by slot tap with filter arguments.

### Features
- **Search** — by component name or manufacturer
- **Size filter** — dropdown showing all available sizes for the category (S1, S2, etc.)
- **Sort modes** — by grade (S/A/B/C/D descending), size ascending, name alphabetical
- **Grade value ordering**: S=6, A=5, B=4, C=3, D=2, unknown=1

### Component Card Display
- Left color stripe by grade (S=purple, A=red, B=orange, C=blue, D=grey)
- Name + manufacturer + item class label
- Grade badge (color-coded background)
- Size badge: "S1", "S2", etc.
- Selected state: thicker border + checkmark icon

## Persistence Format

Saved as JSON array in SharedPreferences key `"loadouts"`:
```json
[{
  "id": "1712345678000",
  "shipId": "avenger_titan",
  "shipName": "Avenger Titan",
  "shipSlug": "avenger_titan",
  "name": "My Titan Build",
  "slots": [
    {"category": "weapons", "componentId": "behring_m5a"},
    {"category": "shieldgenerator", "componentId": "rsi_guardian"},
    {"category": "powerplant", "componentId": null},
    {"category": "cooler", "componentId": null},
    {"category": "quantumdrive", "componentId": null},
    {"category": "radar", "componentId": null}
  ],
  "createdAt": "2026-05-16T10:00:00.000",
  "updatedAt": "2026-05-16T10:00:00.000"
}]
```

Note: `componentData` is NOT saved to SharedPreferences — it's expensive and stale-prone. Only `componentId` is persisted. `resolveComponents()` populates live data on load.

## Screen Flow

```
Ship List Screen (wrench icon)
  └→ LoadoutListScreen (saved loadouts + "New Loadout" button)
       ├→ (tap existing) → LoadoutEditorScreen(existingLoadout: loadout)
       └→ (tap new) → LoadoutEditorScreen()
            ├→ Ship picker (searchable list, tap to select)
            └→ Editor: 6 slot cards
                 └→ (tap slot) → _ComponentPickerScreen(category, components, currentId)
                      └→ (tap component) → returns data → slot populated
                 └→ Save button → populates SharedPreferences → pops to list
```

## Entry Point Wiring

In `ship_list_screen.dart`:
```dart
IconButton(
  icon: const Icon(Icons.build_outlined),
  onPressed: () => Navigator.push(context,
    MaterialPageRoute(builder: (_) => const LoadoutListScreen())),
  tooltip: 'Ship loadouts',
),
```

## Testing / Debugging

- Loadouts survive app restarts (SharedPreferences)
- Delete SharedPreferences key `"loadouts"` to reset
- Empty state shows illustration + "No Loadouts Yet" + "New Loadout" button
- Pull-to-refresh on list screen
