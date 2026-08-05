# FleetYards.net API Reference

Base URL: `https://api.fleetyards.net/v1`

## Endpoints

### List all ships (models)

```
GET /models?perPage=240
```

**CRITICAL:** The parameter is `perPage=240`, NOT `per=240`. Using `per=` silently returns only the default page of 30. Max perPage is 240, which returns all ~238 ships in one request.

**Headers required:**
```
Accept: application/json
User-Agent: SC:Synthesis/0.1
```

**Response structure:**
```json
{
  "items": [ ... ],
  "meta": {
    "pagination": {
      "totalCount": 238,
      "currentPage": 1,
      "totalPages": 1,
      "perPage": 240,
      "defaultPerPage": 30,
      "maxPerPage": 240,
      "perPageSteps": [15, 30, 60, 120, 240, "all"]
    }
  }
}
```

### Single ship

```
GET /models/{slug}
```

### Manufacturers

```
GET /manufacturers?page=1
GET /manufacturers?page=1&q[withModels]=true
```

### Filters

```
GET /filters/models/production-states
GET /filters/models/classifications
GET /filters/models/focus
GET /filters/models/sizes
```

## Data Model (full)

The ship ("model") object returned by FleetYards has these fields:

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Stable internal ID |
| `scIdentifier` | string | In-game identifier (e.g. `orig_100i`) — use as local ID |
| `name` | string | Display name (e.g. `100i`) |
| `slug` | string | URL slug (e.g. `orig-100i`) |
| `classification` | string | Internal code: `multi`, `fighter`, `explorer`, `cargo`, `competition`, `industrial`, `support`, `transport`, `ground` |
| `classificationLabel` | string | Human label: `Multi`, `Combat`, `Exploration`, etc. |
| `focus` | string | Descriptive role (e.g. `Starter / Touring`) |
| `crew.min` / `crew.max` | int | Crew requirements |
| `description` | string | Full text (can be 1000+ chars) |
| `manufacturer.name` | string | e.g. `Origin Jumpworks` |
| `manufacturer.code` | string | e.g. `ORIG` |
| `manufacturer.slug` | string | e.g. `origin-jumpworks` |
| `pledgePrice` | float | USD store price (nullable) |
| `pledgePriceLabel` | string | Formatted (e.g. `$50`) |
| `price` | float | In-game aUEC price (nullable) |
| `priceLabel` | string | Formatted |
| `productionStatus` | string | e.g. `flight-ready`, `in-concept` |
| `onSale` | boolean |
| `playerOwnable` | boolean |
| `inGame` | boolean | Currently flyable in-game |
| `metrics.cargo` | float | SCU capacity |
| `metrics.beam` | float | Width |
| `metrics.length` | float | Length |
| `metrics.height` | float | Height |
| `speeds.maxSpeed` | float | Max speed in m/s |
| `speeds.maxScmSpeed` | float | SCM speed |
| `rsiId`, `rsiName`, `rsiSlug` | string | RSI website references |
| `links.frontend` | string | FleetYards page URL |
| `links.storeUrl` | string | RSI pledge store URL |
| `links.self` | string | API self link |
| `media.angledView` | object | Image URLs (smallUrl, mediumUrl, largeUrl) |
| `media.fleetchartImage` | string | Side-view image URL |
| `productionStatus` | string | e.g. `flight-ready` |

## Parameter Quirks

- `perPage=` NOT `per=` — this is the most common mistake
- Sorting: Add `q[s]=name` for alphabetical, `q[s]=created_at` for newest
- Filtering: `q[classificationEq]=fighter`, `q[productionStatusEq]=flight-ready`
- All endpoints return paginated results wrapped in `{items, meta}`
- Pagination metadata is at `meta.pagination`

## Harvest Script Pattern (Python)

```python
import json, os

# Fetch from API
import urllib.request
req = urllib.request.Request(
    'https://api.fleetyards.net/v1/models?perPage=240',
    headers={'Accept': 'application/json', 'User-Agent': 'AppName/0.1'}
)
resp = urllib.request.urlopen(req)
data = json.loads(resp.read())

# Compact for bundling
compact = []
for s in data['items']:
    # Size classification heuristic
    cmax = (s.get('crew') or {}).get('max', 1) or 1
    price = s.get('pledgePrice') or 0
    name = s['name'].lower()
    
    if cmax >= 10 or price >= 1000 or any(c in name for c in ['javelin','bengal','idris','kraken']):
        size = 'Capital'
    elif cmax >= 5 or price >= 400:
        size = 'Large'
    elif cmax >= 3 or price >= 150:
        size = 'Medium'
    elif cmax >= 2 or price >= 50:
        size = 'Small'
    else:
        size = 'Snub'
    
    compact.append({
        'id': s.get('scIdentifier') or s['slug'],
        'name': s['name'],
        'slug': s['slug'],
        'manufacturer': (s.get('manufacturer') or {}).get('name', 'Unknown'),
        'classification': s.get('classificationLabel') or '',
        'focus': s.get('focus') or '',
        'crew_min': (s.get('crew') or {}).get('min', 1) or 1,
        'crew_max': cmax,
        'cargo': (s.get('metrics') or {}).get('cargo', 0) or 0,
        'pledge_price': price,
        'max_speed': (s.get('speeds') or {}).get('maxSpeed', 0) or 0,
        'size': size,
        'description': (s.get('description') or '')[:500],
    })

os.makedirs('assets/data', exist_ok=True)
with open('assets/data/ships.json', 'w') as f:
    json.dump(compact, f, indent=2)

print(f"Harvested {len(compact)} ships")
```

## Historical Discovery (2026-05-15)

The FleetYards API was originally approached with `curl -s "https://api.fleetyards.net/v1/ships"` which returned 404. The site's preconnect hint pointed to `api.fleetyards.net/v1`, but the correct resource path is `/models` (not `/ships`). The parameter `perPage=` was discovered by inspecting the browser's network requests via `performance.getEntriesByType('resource')`.

**Lesson:** Always check the frontend's actual API calls via browser devtools before guessing endpoint paths.
