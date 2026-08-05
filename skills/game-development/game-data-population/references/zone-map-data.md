# Zone-to-Continent Mapping — Project Ascension Mystic Enchants

**Extracted:** 2026-05-24
**Source:** `mystic_enchants.json` (176 enchants, 65 zones)
**App screen:** `/map` — `zone_map_screen.dart`, powered by `zone_map.json`

## Continent Breakdown

### Eastern Kingdoms — 23 zones
| Zone | Enchants | Notable |
|------|----------|---------|
| Stranglethorn | 7 | Arena zone, cape |
| Scarlet Monastery | 6 | Dungeon — Arcanist Doan, Mograine |
| Stratholme | 5 | Dungeon — Balnazzar, Rivendare |
| Shadowfang Keep | 4 | Dungeon — Arugal |
| Swamp of Sorrows | 4 | Sunken Temple entrance |
| Western Plaguelands | 4 | Caer Darrow, Hearthglen |
| Eastern Plaguelands | 4 | Tyr's Hand, Naxxramas |
| Arathi | 4 | Dalaran crater |
| Blasted Lands | 3 | Dark Portal, Bloodmage questline |
| Alterac | 3 | Yeti caves, Dalaran |
| Scholomance | 3 | Dungeon — Gandling |
| Wetlands | 3 | Dun Algaz |
| Hinterlands | 3 | Jintha'alor, Quel'Danil |
| Burning Steppes | 2 | Blackrock Mountain |
| Searing Gorge | 2 | Blackrock Depths entrance |
| Badlands | 2 | Uldaman |
| Hillsbrad | 2 | Southshore, Tarren Mill |
| Silverpine Forest | 1 | Sepulcher, Dalaran |
| Plaguelands | 1 | Generic |
| Ghostlands | 1 | Tranquillien |
| Duskwood | 1 | Raven Hill |
| Eversong Woods | 1 | Fairbreeze |
| Stranglethorn Vale | 1 | Booty Bay |

### Kalimdor — 15 zones
| Zone | Enchants | Notable |
|------|----------|---------|
| Winterspring | 10 | Frostsaber area, Banshees |
| Un'Goro | 7 | Crater, pylon quests |
| Feralas | 5 | Isle of Dread, Dire Maul |
| Felwood | 5 | Timbermaw, Icy veins |
| Tanaris | 5 | Gadgetzan, Zul'Farrak |
| Azshara | 4 | Ravencrest, goblins |
| Moonglade | 4 | Cenarion Circle |
| Ashenvale | 3 | Astranaar, Satyr |
| Barrens | 3 | Crossroads, WC |
| Stonetalon | 3 | Charred Vale |
| Thousand Needles | 2 | Shimmering Flats |
| Silithus | 2 | Twilight Hammer |
| Desolace | 2 | Maraudon |
| Dustwallow Marsh | 2 | Theramore |
| Darkshore | 1 | Lor'danel |

### Outlands — 7 zones
| Zone | Enchants | Notable |
|------|----------|---------|
| Netherstorm | 4 | Area 52, Mana Forges |
| Nagrand | 2 | Halaa, Telaar |
| Terokkar | 2 | Auchindoun |
| Blade's Edge | 2 | Ogri'la |
| Zangarmarsh | 2 | Sporeggar |
| Hellfire Peninsula | 2 | Thrallmar/Honor Hold |
| Shadowmoon | 1 | Illidan's temple |

### Dungeons/Other — 20 zones
Includes Ragefire Chasm (4), Razorfen Downs (4), Wailing Caverns (3), Blackfathom Deeps (3), Blackrock Depths (3), Deadmines (2), Molten Core (2), Dire Maul East/West, Maraudon Falls/Orange, Gnomeregan, Stockades, Zul'Farrak, Uldaman, Shattrath, Stormwind, Bloodmyst, and one "Unknown" entry.

## Data Model

```dart
@immutable
class ZoneMapData {
  final List<ZoneContinent> easternKingdoms;
  final List<ZoneContinent> kalimdor;
  final List<ZoneContinent> outlands;
  final List<ZoneContinent> other;
}

@immutable
class ZoneContinent {
  final String zone;
  final int count;
  final List<String> enchants;
}
```

## Flutter Screen Structure

- `zone_map_screen.dart` — TabBar with 4 tabs (EK/Kalimdor/Outlands/Other)
- `zoneMapProvider` — `FutureProvider.autoDispose` loading `assets/data/zone_map.json`
- Each zone is a `Card` with color-coded density bar, count badge, and animated entrance
- Tap opens `showModalBottomSheet` with `DraggableScrollableSheet` (50%-85% height)

## Regeneration

If the enchant data changes, regenerate `zone_map.json`:

```python
import json
with open('assets/data/mystic_enchants.json') as f:
    enchants = json.load(f)

# Group by zone
zones = {}
for e in enchants:
    zone = e.get('zone') or 'Unknown'
    zones.setdefault(zone, []).append(e['name'])

# Categorize by continent (use the zone lists above)
# Write to assets/data/zone_map.json
```