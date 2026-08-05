# FleetYards API Reference

Base URL: `https://api.fleetyards.net/v1/`

## Endpoints

| Endpoint | Description | Page Size |
|----------|-------------|-----------|
| `/models?perPage=240` | All ships (238 total) | 240 max |
| `/components?perPage=240` | All components (28,762 total, 120 pages) | 240 max |
| `/models/{slug}` | Single ship detail | — |
| `/version` | API version | — |

## Pagination

All list endpoints use cursor-based pagination:
```
/perPage=240&page=1  → page 1 (240 items)
/perPage=240&page=2  → page 2 (next 240)
...
```

Response includes:
```json
{
  "items": [...],
  "meta": {
    "pagination": {
      "totalCount": 28762,
      "currentPage": 1,
      "totalPages": 120,
      "perPage": 240,
      "maxPerPage": 240
    }
  }
}
```

Use `perPage=240` to minimize page count. `per` is NOT the same as `perPage` — must use `perPage`.

## Filtering

The API does NOT support server-side filtering despite accepting `?category=weapons` as a parameter — it returns the same results as unfiltered. All filtering must be done client-side after fetching all pages.

## Images

Each ship model has a `media` object with multiple image types:
```json
"media": {
  "storeImage": {          // Full rendered ship (JPG)
    "url": "...",          // Original (~200KB avg)
    "smallUrl": "...",     // Thumbnail (~40KB avg, 15KB-41KB range)
    "mediumUrl": "...",    // Medium (~80-140KB)
    "largeUrl": "...",     // Large
    "xlargeUrl": "..."     // Extra large
  },
  "angledView": { ... },   // Same size variants (PNG)
  "fleetchartImage": "...", // Side-view silhouette (string URL, not object)
  "frontView": { ... },
  "sideView": { ... },
  "topView": { ... }
}
```

All 238 ships have store images. 229 have fleetchart images. Use `smallUrl` for thumbnails in card views (total ~9.3MB for all 238 ships).

Images are served from two CDN domains:
- `fleetyards.net/files/blobs/redirect/<hash>/<filename>` — original/full
- `api.fleetyards.net/files/representations/redirect/<hash>/<filename>` — resized variants
- `api.fleetyards.net/files/blobs/redirect/<hash>/<filename>` — some originals

## Image Download Pattern (Python)

```python
import concurrent.futures, json, urllib.request

HEADERS = {"Accept": "application/json", "User-Agent": "MyApp/1.0"}

def fetch_page(page):
    url = f"https://api.fleetyards.net/v1/models?perPage=240&page={page}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

# Fetch all in parallel
all_ships = []
with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
    futures = {pool.submit(fetch_page, p): p for p in range(1, 2)}  # 2 pages for models
    for f in concurrent.futures.as_completed(futures):
        all_ships.extend(f.result()['items'])

# Download images
for s in all_ships:
    media = s.get('media', {})
    store = media.get('storeImage', {})
    img_url = store.get('smallUrl') or store.get('url', '')
    if img_url:
        req = urllib.request.Request(img_url, headers={'User-Agent': 'MyApp/1.0'})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = resp.read()
        ext = '.jpg' if b'jpeg' in resp.headers.get('Content-Type', '').encode() else '.png'
        with open(f"assets/images/ships/{s['slug']}{ext}", 'wb') as f:
            f.write(data)
```

## Components Data

Components have NO images (0 out of 28,762 items have any media). Use ComponentAvatar widget for code-generated visuals instead.

Each component has:
- `id`, `name`, `slug` — identifiers
- `category` — `weapons`, `shieldgenerator`, `armor`, `powerplant`, `cooler`, `quantumdrive`, `radar`, `paints`
- `type` — `WeaponGun`, `Shield`, `Armor`, etc.
- `subType` — `Gun`, `Medium`, `Missile`, `Torpedo`, etc.
- `size` — slot size (string like "1", "2", "3")
- `grade` / `gradeLabel` — quality tier (1-3, A-C)
- `manufacturer.name` — manufacturer name
- `typeData` — stat block (varies by category):
  - Shield: `maxHealth`, `maxRegen`, `decayRatio`, `damagedRegenDelay`, `downedRegenDelay`
  - Armor: `damagePhysical`, `damageEnergy`, `damageDistortion`
  - Power plant: `powerOutput`, `draw`
  - Cooler: `coolingRate`
  - Quantum drive: `speed`, `fuelUse`, `prepTime`
  - Radar: `detectionRange`, `signal`
  - Weapons: mostly empty typeData in the API

## Stores Data

No dedicated shops endpoint exists on FleetYards. Store data must be compiled manually from community knowledge and saved as a JSON asset.
