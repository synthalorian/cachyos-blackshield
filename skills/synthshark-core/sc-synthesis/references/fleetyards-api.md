# FleetYards.net API Reference

Base URL: `https://api.fleetyards.net/v1/`
Type: Public REST API (no auth required)
Used by: SC:Synthesis — 100% offline companion app

## Endpoints

| Endpoint | Description | Max per page |
|----------|-------------|-------------|
| `GET /models?perPage=240` | All ships (238 total, 1 page) | 240 |
| `GET /components?perPage=240&page={1..120}` | All components (28,762 total) | 240 |
| `GET /models/{slug}` | Single ship detail | — |
| `GET /version` | API version | — |
| `GET /manufacturers` | Manufacturer list | — |

**Important:** `perPage` is the correct parameter. `per` silently returns 30 (default). Must use `perPage`.

## Ship Data (GET /models)

### Response Shape
```json
{
  "items": [ ... ],
  "meta": {
    "pagination": {
      "totalCount": 238,
      "totalPages": 1,
      "perPage": 240,
      "maxPerPage": 240
    }
  }
}
```

### Ship Field Reference
```json
{
  "id": "c2a0a2a0-...",
  "scIdentifier": "orig_100i",
  "name": "100i",
  "slug": "orig-100i",
  "classification": "multi",
  "classificationLabel": "Multi",
  "crew": { "min": 1, "max": 1 },
  "description": "The 100i is Origin Jumpworks'...",
  "focus": "Starter / Touring",
  "manufacturer": {
    "name": "Origin Jumpworks",
    "longName": "Origin Jumpworks GmbH",
    "slug": "origin-jumpworks",
    "code": "ORIG"
  },
  "pledgePrice": 50.0,
  "productionStatus": "flight-ready",
  "onSale": true,
  "inGame": true,
  "metrics": {
    "cargo": 4.0, "beam": 10.0, "length": 18.0, "height": 4.0
  },
  "speeds": {
    "maxSpeed": 1230.0, "maxScmSpeed": 200.0
  },
  "links": {
    "frontend": "https://fleetyards.net/ships/orig-100i",
    "storeUrl": "https://robertsspaceindustries.com/pledge/..."
  },
  "rsiSlug": "100i",
  "media": { ... }
}
```

### Image Types Per Ship
| Field | Format | Notes |
|-------|--------|-------|
| `storeImage` | JPG | Full render — best for cards/details |
| `angledView` | PNG | With transparency |
| `fleetchartImage` | PNG (string URL) | Side-silhouette |
| `frontView`, `sideView`, `topView` | PNG | Orthographic views |

Each image object (except `fleetchartImage` which is a bare URL string) has size variants:
```json
{
  "url": "https://fleetyards.net/files/blobs/redirect/...",
  "smallUrl": "https://api.fleetyards.net/files/representations/redirect/...",
  "mediumUrl": "...",
  "largeUrl": "...",
  "xlargeUrl": "...",
  "width": 1920, "height": 1080,
  "contentType": "image/jpeg"
}
```

### Image Size & Download Stats
| Variant | Avg Size | 238 Ships Total | Best For |
|---------|----------|-----------------|----------|
| smallUrl | ~40 KB | ~9.3 MB | List cards, grid |
| mediumUrl | ~100 KB | ~23 MB | Detail screen hero |
| full url | ~300 KB | ~70 MB | Avoid (APK bloat) |

All 238 ships have store images. 229 have fleetchart images.

## Component Data (GET /components)

### Response
Same pagination shape as models. 28,762 items across 120 pages at 240 per page.

**Filtering does NOT work server-side.** Query params like `?category=weapons`, `?filter[category]=weapons`, `?q[category]=weapons` all return unfiltered results. Must download all pages and filter client-side.

### Component Category Breakdown
| Category | Total | Has typeData? |
|----------|-------|--------------|
| weapons | 1,286 | ~329 (mostly empty) |
| armor | 716 | ~183 |
| powerplant | 342 | ~81 |
| radar | 331 | All |
| cooler | 301 | ~75 |
| shieldgenerator | 290 | All |
| quantumdrive | 259 | All |
| paints | ~20,000 | No (liveries, skip) |
| **Useful total** | **3,525** | |

### Component JSON Structure
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
  "itemClassLabel": "Civilian",
  "manufacturer": { "name": "KnightBridge Arms" },
  "typeData": {
    "maxHealth": 8000.0,      // shields
    "maxRegen": 720.0,         // shields
    "coolingRate": 26.0,       // coolers
    "powerOutput": 1800.0,     // power plants
    "speed": 275000.0,         // quantum drives
    "detectionRange": 40000.0, // radar
    "damagePhysical": 0.2      // armor
  }
}
```

**IMPORTANT:** Components have NO images. 0 out of 28,762 items have any media. Use `ComponentAvatar` widget for code-generated visuals with dual-axis styling (category icon × manufacturer color).

## Data Download Patterns

### Pattern A: Concurrent Page Download (Python, Components)
```python
import json, urllib.request, concurrent.futures

HEADERS = {"Accept": "application/json", "User-Agent": "SC-Synthesis/1.0"}

def fetch_page(page):
    url = f"https://api.fleetyards.net/v1/components?perPage=240&page={page}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

target_cats = {"weapons", "shieldgenerator", "armor", "powerplant",
               "cooler", "quantumdrive", "radar"}
useful = []
with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
    futures = {pool.submit(fetch_page, p): p for p in range(1, 121)}
    for f in concurrent.futures.as_completed(futures):
        items = f.result().get("items", [])
        useful.extend(i for i in items if i.get("category") in target_cats)
```

### Pattern B: Sequential Image Download (Python, Ships)
```python
import json, urllib.request

url = "https://api.fleetyards.net/v1/models?perPage=240"
req = urllib.request.Request(url, headers=HEADERS)
with urllib.request.urlopen(req, timeout=30) as resp:
    ships = json.loads(resp.read())["items"]

for s in ships:
    img_url = s.get("media", {}).get("storeImage", {}).get("smallUrl", "")
    if not img_url: continue
    req = urllib.request.Request(img_url, headers={"User-Agent": "SC-Synthesis/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = resp.read()
    ext = ".jpg" if "jpeg" in resp.headers.get("Content-Type", "") else ".png"
    with open(f"assets/images/ships/{s['slug']}{ext}", "wb") as f:
        f.write(data)
```

## Stores / Shops

**No dedicated shops endpoint exists on FleetYards.** `GET /v1/shops` returns 404. Store data must be compiled manually from community knowledge (players, wikis, patch notes) and saved as a bundled JSON asset.

## API Notes

- **No rate limiting** observed during 120-page concurrent download
- **No auth required** — fully public
- **Data freshness:** Ships ~Dec 2025, Components ~Apr 2026
- **Headers to include:** `Accept: application/json`, `User-Agent: SC-Synthesis/1.0`
