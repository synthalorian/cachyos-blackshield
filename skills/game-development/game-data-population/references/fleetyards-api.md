# FleetYards.net API Reference

**Source:** https://api.fleetyards.net/v1/
**Type:** Public REST API (no auth required)
**Used by:** SC:Synthesis

## Endpoints

### GET /v1/models — List all ships

```
GET https://api.fleetyards.net/v1/models?page=1&per=240
```

**Parameters:**
- `page` (int, default: 1) — Page number
- `per` (int, default: 30, max: 240) — Items per page
- `q[name]` (string) — Search by name
- `q[manufacturer]` (string) — Filter by manufacturer slug
- `q[classification]` (string) — Filter by classification code
- `q[productionStatus]` (string) — Filter by status

**Response shape:**
```json
{
  "items": [ ... ],
  "meta": {
    "pagination": {
      "totalCount": 238,
      "currentPage": 1,
      "totalPages": 8,
      "perPage": 30,
      "maxPerPage": 240
    }
  }
}
```

### GET /v1/models/:slug — Single ship detail

```
GET https://api.fleetyards.net/v1/models/orig-100i
```

Returns a single model object with full media and metadata.

### GET /v1/components — Ship components database

```
GET https://api.fleetyards.net/v1/components?perPage=240&page=1
```

**Parameters:** Same pagination as models.

**Response shape:** Same as models (`{ items: [...], meta: { pagination: {...} } }`).

**Key facts:**
- **28,762 total items** across 120 pages (at 240 per page)
- **3,525 useful items** after filtering to: weapons, shieldgenerator, armor, powerplant, cooler, quantumdrive, radar
- Remaining ~25,000 items are mostly paints/liveries (ship skins)

**Category breakdown of useful items:**
| Category | Count | Has typeData stats |
|----------|-------|-------------------|
| weapons | 1,286 | 329 |
| armor | 716 | 183 |
| powerplant | 342 | 81 |
| radar | 331 | 331 |
| cooler | 301 | 75 |
| shieldgenerator | 290 | 290 |
| quantumdrive | 259 | 259 |

**Item schema (stripped for app):**
```json
{
  "id": "uuid",
  "name": "10-Series Greatsword Cannon",
  "slug": "10-series-greatsword-cannon",
  "category": "weapons",
  "type": "WeaponGun",
  "subType": "Gun",
  "size": "2",
  "grade": "A",
  "itemClass": "civilian",
  "manufacturer": "KnightBridge Arms",
  "typeData": {
    "maxHealth": 8000.0,
    "maxRegen": 720.0,
    "coolingRate": 26.0,
    // category-specific stats
  }
}
```

**Note:** The API does NOT support category filtering via query parameters (tried `?category=weapons`, `filter[category]=weapons`, `q[category]=weapons` — all return unfiltered results). To get specific categories, download all pages and filter client-side.

**Python bulk download pattern (works, not blocked):**
```python
import json, urllib.request, concurrent.futures

HEADERS = {"Accept": "application/json", "User-Agent": "SC-Synthesis/1.0"}

def fetch_page(page):
    url = f"https://api.fleetyards.net/v1/components?perPage=240&page={page}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

# Fetch all 120 pages concurrently
target_cats = {"weapons", "shieldgenerator", "armor", "powerplant",
               "cooler", "quantumdrive", "missile", "thruster", "radar"}
useful = []
with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
    futures = {pool.submit(fetch_page, p): p for p in range(1, 121)}
    for f in concurrent.futures.as_completed(futures):
        items = f.result().get("items", [])
        useful.extend(i for i in items if i.get("category") in target_cats)
```

### Other endpoints (discovered via frontend network requests)

```
GET /v1/version
GET /v1/users/me                          (requires auth)
GET /v1/manufacturers?page=1&q[withModels]=true
GET /v1/filters/models/production-states
GET /v1/filters/models/classifications
GET /v1/filters/models/focus
GET /v1/filters/models/sizes
GET /v1/models/with-docks?page=1
```

## Image Handling

Every ship has multiple image types with size variants. Available via the `media` object on each model:

### Image Types
| Field | Format | Description |
|-------|--------|-------------|
| `storeImage` | JPG | Full rendered ship image (best for cards/details) |
| `angledView` | PNG | Angled view with transparency |
| `angledViewColored` | PNG | Colored angled view |
| `fleetchartImage` | PNG | Side/top silhouette (small) |
| `frontView` | PNG | Front view |
| `sideView` | PNG | Side view |
| `topView` | PNG | Top-down view |
| `holo` | - | 3D hologram viewer |
| `brochure` | - | Ship brochure PDF |

### Size Variants
Each image object (except fleetchartImage which is a string) contains:
```json
{
  "url": "https://fleetyards.net/files/blobs/redirect/...",   // full size
  "smallUrl": "https://api.fleetyards.net/files/representations/redirect/...",  // ~40KB thumbnail
  "mediumUrl": "...",   // ~80-140KB
  "largeUrl": "...",
  "xlargeUrl": "...",
  "width": 1920,
  "height": 1080,
  "contentType": "image/jpeg"
}
```

### Image Download Stats
| Variant | Avg Size | 238 ships total |
|---------|----------|-----------------|
| smallUrl | ~40 KB | ~9.3 MB |
| mediumUrl | ~100 KB | ~23 MB |
| full url | ~300 KB | ~70 MB |

**Recommendation:** Use `smallUrl` for list cards and `mediumUrl` for detail headers. Download via Python with `urllib.request` (not blocked, works fine):

```python
import json, urllib.request, os

def download_ship_images():
    url = "https://api.fleetyards.net/v1/models?perPage=240"
    req = urllib.request.Request(url, headers={"Accept":"application/json","User-Agent":"SC-Synthesis/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        ships = json.loads(resp.read())["items"]
    
    for s in ships:
        img_url = s.get("media", {}).get("storeImage", {}).get("smallUrl", "")
        if not img_url: continue
        req2 = urllib.request.Request(img_url, headers={"User-Agent":"SC-Synthesis/1.0"})
        with urllib.request.urlopen(req2, timeout=15) as resp2:
            data = resp2.read()
        ext = ".jpg" if "jpeg" in resp2.headers.get("Content-Type","") else ".png"
        with open(f"assets/images/ships/{s['slug']}{ext}", "wb") as f:
            f.write(data)
```

## Model Schema (FleetYards ship object)

| JSON Field | Type | Description | Mapped to Ship field |
|------------|------|-------------|---------------------|
| `id` | string | UUID | — (for reference only) |
| `scIdentifier` | string | Game ID (e.g. `orig_100i`) | `ship.id` |
| `name` | string | Display name | `ship.name` |
| `slug` | string | URL slug | — (FleetYards link) |
| `classification` | string | Code (e.g. `"multi"`) | → `ship.size` |
| `classificationLabel` | string | Human label (e.g. `"Multi"`) | `ship.role` |
| `crew.min` / `crew.max` | int | Crew requirements | `ship.crew_min/max` |
| `description` | string | Full text description | `ship.description` (truncated) |
| `focus` | string | Role description | — |
| `manufacturer.name` | string | Manufacturer display | `ship.manufacturer` |
| `manufacturer.code` | string | Short code (e.g. "ORIG") | — |
| `manufacturer.slug` | string | URL slug | — |
| `pledgePrice` | float | Store price USD | `ship.pledge_price` |
| `price` | float | In-game aUEC price | — |
| `productionStatus` | string | E.g. "flight-ready" | — |
| `onSale` | bool | Available for purchase | — |
| `inGame` | bool | Flyable in current build | — |
| `metrics.cargo` | float | Cargo capacity (SCU) | `ship.cargo_capacity` |
| `metrics.beam` | float | Ship width | — |
| `metrics.length` | float | Ship length | — |
| `metrics.height` | float | Ship height | — |
| `speeds.maxSpeed` | float | Max speed (m/s) | `ship.max_speed` |
| `speeds.maxSCMSpeed` | float | SCM speed | — |
| `links.frontend` | string | FleetYards URL | — |
| `links.storeUrl` | string | RSI store URL | — |
| `rsiSlug` | string | RSI store slug | — |
| `media.storeImage` | object | Ship renders with size variants | — |

## Size Classification Mapping

| API `classification` | Internal `size` |
|---------------------|-----------------|
| `"capital"` | Capital |
| `"large"` | Large |
| `"medium"` | Medium |
| `"small"` | Small |
| `"snub"` | Small |
| `"vehicle"` | Small |
| anything else | Unknown |

## Rust Client Implementation (Deprecated — Offline-First Replaced This)

The original SC:Synthesis used a Rust Axum server with a FleetYards API client for live sync. The app went 100% offline in v0.2.0 — the server was removed. Data is now bundled as JSON assets and loaded via the Rust FFI bridge.

**If you're building a new app that needs live FleetYards sync,** the pattern was:
- `FleetYardsClient::new()` — creates reqwest client with 60s timeout
- `.fetch_all_ships()` — GET `/v1/models?per=240`, returns `Vec<FleetYardsModel>`
- `FleetYardsModel::to_ship()` — converts to internal model

**For the offline approach (recommended for companion apps):**
1. Download data once via Python (see "Data Download Patterns" above)
2. Bundle as JSON assets in `assets/data/`
3. Seed into SQLite on first launch via Rust FFI bridge
4. No server, no network, no auth needed
