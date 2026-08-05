# SC Synthesis — External Data Sources

Community-maintained sources for enriching SC Synthesis's reference data (locations, tools, resources).

---

## VerseGuide — Planetary Metadata

**URL:** https://verseguide.com/
**Author:** LordSkippy (Discord, Patreon)
**Updated:** Active (last verified May 2026)
**Systems covered:** Stanton, Pyro, Nyx (via tab navigation)

### What It Provides

Per-location planetary metadata beyond what the basic JSON schema captures:

| Field | Example (Crusader) | Notes |
|-------|-------------------|-------|
| Planet type | Gas Giant | Tags: Gas Giant, Uninhabitable, etc. |
| Population rating | 4 / 10 | 0-10 scale |
| Crime rating | 5 / 10 | 0-10 scale |
| Economy rating | 8 / 10 | 0-10 scale |
| Length of day | 5.1 hours | Varies per body |
| Temperature range | 17 to 35°C | Min/Max in Celsius |
| Diameter | 14900.0 km | In km |
| Kármán line | 300.0 km | Atmospheric boundary |
| Atmospheric pressure | 1.01 bar | In bar |
| Atmospheric composition | N₂ 78.1%, O₂ 20.9%, Ar 0.93%, CO₂ 0.04% | Gas percentages |
| Sub-locations | Cloudrest Retreat (Platform), Orison (City), Prospect Point (Platform), Seraphim Station (Station) | Named POIs per body |
| System jump points | Pyro, Terra, Magnus | Adjacent system links |

### Data Structure (Extracted from Browser)

```
Stanton System
├── Hurston (planet) ── Lorville (city), Everus Harbor (station), R&R HUR, Lagrange stations L1-L2
├── ArcCorp (planet) ── Area18 (city), Baijini Point (station), R&R ARC, Lagrange stations L1-L2
├── Crusader (planet) ── Orison (city), Seraphim Station (station), Cloudrest Retreat, Prospect Point, Empyrean Park, R&R CRU, Lagrange stations L1-L3
├── microTech (planet) ── New Babbage (city), Port Tressler (station), R&R MIC, Lagrange stations L1-L2
└── Jump points → Pyro, Terra, Magnus

Pyro System (available via tab)
  (explore interactively on the site)

Nyx System (available via tab)
  (explore interactively on the site)
```

### Moons (per planet)

Each planet has multiple moons with their own metadata:

| Planet | Moons |
|--------|-------|
| Hurston | Arial, Aberdeen, Magda, Ita |
| Crusader | Cellin, Daymar, Yela |
| ArcCorp | Lyria, Wala |
| microTech | Calliope, Clio, Euterpe |

Each moon has the same metadata shape (type, size, atmosphere, temperature, day length, etc.).

### Interactive Features on Site

- **Map View** — Interactive planetary map with terrain/temperature/labels/daylight layer toggles
- **Globe View** — 3D globe rotation
- **Search** — Full-text search across all systems
- **Custom Coordinates** — Supports XYZ or Lat/Lon/Alt specific location saving
- **Flight Path Generation** — Login-gated feature for optimal route planning

### How to Use for SC Synthesis

1. Browse to https://verseguide.com/ and navigate to the desired system (Stanton/Pyro/Nyx)
2. Click each planet/moon to view its detailed metadata card
3. Extract: type tags, ratings, physical stats, atmosphere composition, sub-locations

### Bulk Data Extraction (pro tip)

VerseGuide is a Nuxt.js app that dumps the full system state into `window.__NUXT__`. Open the browser console and run:

```javascript
JSON.stringify(window.__NUXT__.state.systems.STANTON, null, 2)
```

This returns the **entire system object** including:
- `celestial_objects[]` — every planet, moon, comm array, Lagrange point, and jump point with description, size, subtype, position_x/y/z, orbit_period, sensor_danger/economy/population, and affiliation
- `aggregated_size`, `aggregated_population`, `aggregated_economy`, `aggregated_danger` — system-wide ratings
- Affiliations, jump points, POIs, comm arrays

For other systems, replace the code key: `PYRO`, `NYX`, `CASTRA`, `TERRA`.

**Field mapping from Nuxt JSON to our schema:**

| Nuxt Field | Our Field | Example |
|-----------|-----------|---------|
| `name` | `name` | "Crusader" |
| `description` | `description` | "A low mass gas giant..." |
| `subtype.name` | `bodyType` | "Gas Giant" |
| `habitable` | (use for habitability badge) | true/false |
| `sensor_population` | `population` | "4" → 4 |
| `sensor_danger` | `crime` | "5" → 5 |
| `sensor_economy` | `economy` | "8" → 8 |
| `size` | `diameter` | 74500.0 |
| `texture.images.post` | (image URL if needed) | — |
| `type` (from subtype) | (type classification) | PLANET, SATELLITE, LP, JUMPPOINT |
| `parent_id` | (links moon to planet) | References parent celestial body |
| `designation` | (for RSI nomenclature) | "Stanton II" |

**Moon extraction:** Filter `celestial_objects` where `type == "SATELLITE"`. Each moon has the same schema as planets with `parent_id` referencing its parent planet.

**System meta** is also available:
```javascript
window.__NUXT__.state.systemsMeta  // Array of all systems with URLs, sizes, SVG configs
```

### Pitfalls

- Site uses cookies/analytics — accept to dismiss the banner before interacting
- No public API available — must extract data via browser inspection
- Data is community-maintained, not official CIG — cross-reference with in-game experience
- Map view loads progressively on scroll/interaction
- Login-gated features (saved locations, flight paths) are not accessible without account

---

## Star Citizen Tools Megalist — Community Resource Directory

**URL:** https://starcitizen.tools/Star_Citizen_resources_megalist#Tools-0
**Type:** Wiki page (MediaWiki, star Citizen wiki)
**Last updated:** May 6, 2026 (actively maintained)
**Wiki:** starcitizen.tools (community wiki, not Fandom)

### What It Provides

A categorized directory of 64+ community tools and resources with descriptions, author names, contact info, and access dates.

### Category Breakdown

#### Combat / Loadout Tools
| Tool | Author | Description | URL |
|------|--------|-------------|-----|
| #DPSCalculator | Erkul | Build, compare, find, and share vehicle loadouts | erkul.games (Patreon) |
| SC Ships Performances Viewer | Olakeen | Build, compare, find, and share vehicle loadouts | Discord/Patreon |
| Star Citizen Armory | TheSpaceCoder | Build personal loadout and get a shopping list | Discord/Patreon |
| Ship Performance Analysis Tool | Legacy Instructional | Compare vehicle and weapon performances | Discord/Patreon |
| SnarePlan | DOLUS | Quantum interdiction assistance | Discord/Donate |
| SCOverlay | BlugDeg | In-game overlay (trading, mining, exploration) | GitHub/Donate |

#### Mining Tools
| Tool | Author | Description |
|------|--------|-------------|
| SC Trade Tools | Keider Valier | Mining route planner, mineable prices, refinery yield |
| UEX | Zatec | Mining route planner, mineable prices |

#### Trading / Hauling Tools
| Tool | Author | Description |
|------|--------|-------------|
| SC Trade Tools | Keider Valier | Trading route planner, commodity prices and inventory |
| UEX | Zatec | Trading route planner, commodity prices |
| Star Citizen Hauler | TheSpaceCoder | Hauling route optimization |
| SC Hauling Tools | Heyrros | Hauling route optimization with OCR import (2026) |

#### Exploration Tools
| Tool | Author | Description |
|------|--------|-------------|
| Executive Hangar Timer | Vallexian | PYAM contested zone loop timer |
| VerseGuide | LordSkippy | Location finder (see above) |

#### Universal Tools
| Tool | Author | Description |
|------|--------|-------------|
| Universal Item Finder | Meepowski | Find/view stats of personal and vehicle equipment |
| SC Ship Performances Viewer | Olakeen | Ship and ground vehicle performances |
| SCcommAP | errgoth | In-game overlay for Spectrum, chat, radio, search |
| SC Mission Database | N/A | Missions, crafting, resources, mining database |

#### Other Resources
| Tool | Author | Description |
|------|--------|-------------|
| FleetYards | Torlek Maru | Vehicle database (already integrated via API) |
| Starjump Fleetviewer | STARJUMP | Generate fleet images |
| myfleet.gg | Lesani | 3D fleet viewer (Starship42 successor) |
| Cargo Grid Viewer | bjax | 3D cargo grid visualization |
| Star Citizen Reference Sheets | ChrisGBG | Extensive game data spreadsheets |
| Star Citizen Maps | Dumma | 3D ship maps with POI markers, fuses, engineering |

### How to Use for SC Synthesis

1. Add a **Resources** category card to the Guide screen
2. Load from a new `assets/data/tools.json` file:
   ```json
   [
     {
       "name": "#DPSCalculator",
       "author": "Erkul",
       "description": "Build, compare, find, and share vehicle loadouts",
       "url": "https://erkul.games",
       "category": "combat",
       "support": "Patreon"
     }
   ]
   ```
3. Each tool opens externally via `launchUrl(url, mode: LaunchMode.externalApplication)` with try/catch
4. Category badges (combat/trading/mining/exploration/universal) with color coding
5. Support button shows Patreon/Ko-fi/Donate links

### Tools JSON Schema

When building `assets/data/tools.json`:
```json
{
  "id": "unique-kebab-id",
  "name": "Tool Name",
  "author": "Creator Name",
  "description": "One or two sentence description.",
  "category": "combat|mining|trading|exploration|universal|other",
  "url": "https://example.com",
  "contact": "Discord/Twitter/GitHub handle",
  "support": "Patreon/Ko-Fi/Donate"
}
```

### Pyro System Data

The Pyro system was extracted from `starcitizen.tools/Pyro_system`:
- **Star:** Flare Star | **Status:** Unclaimed | **Size:** 9.83 AU
- **6 planets** (Pyro I–VI), 6 moons, 18 stations, 7 jump points
- **Danger:** 3.02/10 | **Economy:** 3.02/10 | **Population:** 8.13/10

| Planet | Nickname | Type | Description |
|--------|----------|------|-------------|
| Pyro I | — | Silicate crust | Extreme heat, lightning, native ecosystem |
| Pyro II | Monox | Coreless rocky | Toxic CO atmosphere, outlaw haven |
| Pyro III | Bloom | Icy terrestrial | Breathable N₂/O₂, former mining hub |
| Pyro IV | — | Scarred rocky | Collided with planet-body, on crash course |
| Pyro V | — | Gas giant | Green/yellow, hydrogen harvesting |
| Pyro VI | Terminus | Icy terrestrial | Methane-laced atmosphere, Ruin Station |

**Major stations:** Ruin Station (XenoThreat), Checkpoints Kareah/Greehey/Smolensky/Ragnar/Sheriff
**Jump points:** Cano, Castra, Hadrian, Nyx, Oso, Stanton (medium), Terra

---

## Comparison: What Each Source Is Good For

| Data Type | VerseGuide | Megalist | FleetYards API |
|-----------|------------|----------|----------------|
| Planetary metadata | ✅ Rich (ratings, atmosphere, etc.) | ❌ | ❌ |
| Location descriptions | ✅ Per-body | ❌ | ❌ |
| System maps | ✅ Interactive | ❌ | ❌ |
| Ship specs | ❌ | ❌ | ✅ API (238 ships) |
| Component specs | ❌ | ❌ | ✅ API (28,762 items) |
| Community tools | ❌ | ✅ 64+ listed | ❌ |
| Tool descriptions | ❌ | ✅ Rich descriptions | ❌ |
| Trade data | ❌ | ❌ (links to tools) | ❌ |
| Loadout planning | ❌ | ❌ (links to tools) | ❌ |
| Pyro/Nyx data | ✅ Yes | ❌ | ❌ |
| Up-to-date | ✅ Active | ✅ May 2026 | ✅ Live |
| Public API | ❌ | ❌ (wiki-based) | ✅ REST |
