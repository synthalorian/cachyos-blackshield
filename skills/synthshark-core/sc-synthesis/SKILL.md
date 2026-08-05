---
name: sc-synthesis
description: "SC Synthesis — a fully offline Star Citizen companion app. Flutter + Rust (flutter_rust_bridge) with SQLite, bundled reference data, and CustomPainter maps."
version: 1.1.0
author: synthclaw
license: MIT
platforms: [linux, android]
metadata:
  hermes:
    tags: [flutter, rust, star-citizen, offline, mobile]
    related_skills: [synthclaw, flutter-development, flutter-rust-ffi, game-data-population, github-repo-management]
---

# SC Synthesis — App Development Guide

## Project Structure

```
app/                          # Flutter app
  lib/
    main.dart                 # Entry point (just runApp)
    app.dart                  # MaterialApp + bottom nav (Fleet, Ships, Guide, Settings)
    src/rust/                 # Generated flutter_rust_bridge bindings (AUTO-GENERATED)
    core/
      data/                   # RustDatabaseService (SQLite via FFI), ReferenceDatabase (JSON), UserShipData (SharedPrefs)
      theme/                  # ThemeManager (singleton), 6 themes + selector
      widgets/                # ShipAvatar, ShipHero, FleetYardsLink, BuyMeACoffeeButton, ShimmerLoading, ComponentAvatar
    features/
      fleet/                  # Local fleet manager (owned + wishlist tabs)
      ships/                  # Ship list browser, detail screen, compare screen
      loadouts/               # Loadout Builder (v0.5.0): loadout_data, loadout_editor_screen, loadout_list_screen
      guide/                  # Guide hub, category screens, Stanton map, trade routes, mining/salvage
      settings/               # Settings/about screen
  rust/                       # Rust bridge crate (rusqlite, serde)
    src/api/
      model.rs                # Ship struct with all fields

app/assets/data/              # Bundled JSON data files
  ships.json                  # 238 ships from FleetYards
  factions.json               # 13 factions with rep tiers
  missions.json               # 26 mission types
  locations.json              # 50 locations (25 Stanton + 12 moons + 13 Pyro)
  commodities.json            # 34 trade goods
  components.json             # 3,525 ship components
  stores.json                 # 42 stores with inventories
  ship_image_map.json         # Slug → asset path for 238 ship photos
  tools.json                  # 22 community tools
  mining_gadgets.json         # 27 mining items
  salvage_data.json           # 9 salvage items

server/                       # REMOVED — app is fully offline now
```

## Architecture

### Data Flow
```
Flutter UI → Dart Service → [ Rust FFI (rusqlite) | JSON Asset (ReferenceDatabase) | SharedPreferences (UserShipData | LoadoutService) ]
```

### Four Data Layers
1. **Rust/SQLite** — Ship database (238 ships, searchable). Loaded from bundled `ships.json` on first launch. Used by ship browser, comparison, fleet, loadout ship picker.
2. **ReferenceDatabase** (Dart JSON) — All reference data. Loads 9 bundled JSON assets via `Future.wait` (indices 0-8: factions, missions, locations, commodities, components, stores, tools, mining_gadgets, salvage_data). Singleton. Used by Guide tab, Loadout Builder component picker, Map.
3. **UserShipData** (SharedPreferences) — Local fleet ownership, wishlist, per-ship notes.
4. **LoadoutService** (SharedPreferences) — Persists user-created ship loadouts as JSON array. Singleton with ChangeNotifier.

### Guide Screen Special Routing (v0.5.0)
Certain Guide cards bypass `GuideCategoryScreen` for custom screens:
- `locations` → `StantonMapScreen` (interactive CustomPainter, moon positions, system filter)
- `mining` → `MiningSalvageScreen` (tabbed mining/salvage browser with tier stars, price formatting)
- `shopping` → `TradeRoutesScreen` (commodity rankings by price/SCU, type filters, search)
- `resources` → `GuideCategoryScreen` with `dbCategory: 'tools'` (external tool links)

### Key Patterns

**ThemeManager singleton** — `ThemeManager.instance` directly, no callbacks.
**URL launching** — Always `try/catch around launchUrl()` not `canLaunchUrl()` (Android 11+).
**Ship visuals** — 238 bundled photos (~40KB each), fallback to `ShipAvatar(manufacturer:)`.
**Component visuals** — No images available. Use `ComponentAvatar(category:, manufacturer:)` for category-colored icons.

### Build Commands

```bash
# Android release APK
export ANDROID_NDK_HOME=/home/synth/.android/sdk/ndk/26.1.10909125
cd app && flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk (~70MB)
# Rust bridge auto-cross-compiles for armv7, aarch64, x86_64

# Linux desktop (development)
cd app && flutter build linux --debug

# Rust bridge (standalone)
cd app/rust && cargo build
```

### Release Process
```bash
cd /path/to/sc-synthesis
git add -A && git commit -m "Summary of changes"
git push
gh release create vX.Y.Z --title "Title" --notes "Notes" \
  app/build/app/outputs/flutter-apk/app-release.apk#SC-Synthesis-vX.Y.Z.apk
```

## Loadout Builder (v0.5.0)

See `references/loadout-builder.md` for full data model, persistence format, screen flow.

### Entry Point
Wrench icon (`Icons.build_outlined`) in Ship List app bar → `LoadoutListScreen`.

### Flow
1. "New Loadout" → ship picker (searchable 238 ships from Rust DB)
2. Select ship → editor with 6 color-coded slots: Weapons (red), Shield (cyan), Power Plant (amber), Cooler (blue), Quantum Drive (purple), Radar (green)
3. Tap slot → `_ComponentPickerScreen` filtered to that category
4. Picker features: search, sort by grade/size/name, size filter
5. Save to SharedPreferences key `"loadouts"`

### Key Classes
- **LoadoutService** — Singleton ChangeNotifier. Methods: load, add, update, delete, duplicate.
- **Loadout** — id, shipId, shipName, shipSlug, 6 slots, name, timestamps. `resolveComponents(db)` populates `slot.componentData`. `totalCost` sums prices.
- **LoadoutSlot** — category, componentId. `componentData` resolved at runtime.

## Trade Routes Screen (v0.5.0)
`lib/features/guide/trade_routes_screen.dart` — 34 commodities ranked by `pricePerScu = averagePrice / bulkSize`. Entry via Shopping card.

Features: 8 type filter chips (color-coded), 3 sort modes (price/SCU, bulk, name), search, detail bottom sheet with illegal warnings.

## Mining & Salvage Guide (v0.5.0)
`lib/features/guide/mining_salvage_screen.dart` — Two-tab screen (Mining | Salvage).

Data files: `mining_gadgets.json` (27 items: lasers, modules, consumables, resources) + `salvage_data.json` (9 items: heads, consumables, resources).

Schema: id, name, type (gadget/module/consumable/resource), subtype, tier (1-3), description, effect, price.

## Enriched Location Data Schema (v0.4.0)

### Core fields (all 50 locations)
| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | kebab-case identifier |
| `name` | yes | Display name |
| `type` | yes | `planet`, `moon`, `station`, `lagrange`, `restStop`, `jumpPoint` |
| `planet` | yes | Parent planet name |
| `orbit` | yes | Orbital position (0-5), null for lagrange/jump |
| `system` | yes | `"Stanton"` or `"Pyro"` |
| `description` | yes | Lore description |
| `services` | yes | Service keys array |

### Planetary metadata (planets & moons)
Add to enable rich detail view (rating bars, stat tiles, atmosphere composition):

```json
{
  "bodyType": "Super-Earth",
  "habitable": false,
  "population": 6,
  "crime": 4,
  "economy": 6,
  "dayLength": "2.5 hours",
  "temperatureRange": "-273 to 273°C",
  "diameter": 2000.0,
  "karmanLine": 200.0,
  "atmosphericPressure": 1.01,
  "atmosphere": [
    {"gas": "Nitrogen", "symbol": "N2", "percentage": 78.2}
  ]
}
```

- **bodyType values:** Gas Giant, Super-Earth, Terrestrial Rocky, Terrestrial (Icy), Planetary Moon
- **population/crime/economy:** Int 1-10 → color-coded progress bars (green < 5, orange 5-7, red ≥ 8)
- **atmosphere:** Array of {gas, symbol, percentage} → labeled progress bars
- **Moon pattern:** bodyType "Planetary Moon", population=1, no atmosphere unless applicable
- **Pyro pattern:** system "Pyro", higher crime (6-10), lower economy (1-5)

## Community Tools Data (v0.4.0)
`assets/data/tools.json` — 22 community tools loaded via `ReferenceDatabase.tools`.

Schema: id, name, author, description, category (combat/mining/trading/exploration/universal/other), url, contact, support.

Display: `_buildToolDetail` in `guide_category_screen.dart` with color-coded category badge, description, author, contact, support, and full-width "Open Tool" button using `launchUrl()`.

## Map Updates

`stanton_map_screen.dart` uses `_derivePosition()` — a flat list of `if (name == '...') checks returning `Offset(radiusFraction, angleDeg)`:

1. **Planets** — unique orbital positions (radius 0.18-0.60, angles 30-300)
2. **Cities** — share parent planet position
3. **Moons** — orbit close to parent (±0.02-0.04 radius, ±5-15° angle)
4. **Stations** — offset from parent planet's angle by ±20-30°
5. **Rest stops** — between planetary orbits
6. **Lagrange points** — spread across interplanetary space
7. **Jump points** — at system edge
8. **Unmapped** — fallback `Offset(0.1, 0)`
9. Map filters by `system == 'Stanton'` (or null for legacy) to exclude Pyro locations

## Adding a New Data Source (checklist)
1. Create JSON in `assets/data/<name>.json`
2. Register in `pubspec.yaml` under `flutter.assets`
3. Add field + load in `ReferenceDatabase.load()` Future.wait (append, not at fixed index)
4. Add getter in ReferenceDatabase
5. Add search case in `ReferenceDatabase.search()`
6. Add Guide category card in `guide_screen.dart` `_categories` list
7. Add `case` in `guide_screen.dart` `_openCategory` switch
8. If custom rendering needed: add case in `guide_category_screen.dart` `_buildDetailContent` + builder method
9. Update `_resolveTypeLabel` / `_resolveTypeColor` / `_hasExtraDetail` if applicable
10. Add import if new package dependency needed (e.g. `url_launcher` for tools)

## Common Pitfalls

1. **`canLaunchUrl` dead-end** — Silent failures on Android 11+. Fix: remove guard, use `try/catch` around `launchUrl`.

2. **Button callbacks not firing** — Dead stub (`onTap: () {}`) or Navigator context issues. Fix: use singleton services or push from correct context.

3. **Map labels overlapping** — Track `_drawnLabelBounds` list in painter, pick from 6 anchor positions to avoid collisions.

4. **InteractiveViewer + GestureDetector** — Nest GestureDetector INSIDE InteractiveViewer as child, not the other way.

5. **Data not appearing after adding new JSON** — Must register in all 4 places: pubspec.yaml, ReferenceDatabase.load(), getter + search, Guide category card + routing.

## Reference Files
- `references/fleetyards-api.md` — FleetYards REST API endpoints, data download patterns, image sizes
- `references/external-links-ui.md` — FleetYards link widget, BuyMeACoffeeButton pattern
- `references/data-sources.md` — VerseGuide extraction guide, megalist tool directory, Pyro system data
- `references/loadout-builder.md` — Full loadout data model, slot architecture, persistence format, screen flow
- `references/spa-data-extraction.md` — Dumping SPA state from browser console (__NUXT__, __NEXT_DATA__, etc.)
