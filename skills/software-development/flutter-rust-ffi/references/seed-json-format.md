# Seed JSON Format for flutter_rust_bridge Data Import

When bundling static data to be imported into SQLite on first app launch, the JSON structure must match the Rust import function's deserialization expectations.

## SC:Synthesis Example (238 ships)

```json
[
  {
    "id": "orig_100i",
    "name": "100i",
    "slug": "orig-100i",
    "manufacturer": "Origin Jumpworks",
    "classification": "Multi",
    "focus": "Starter / Touring",
    "crew_min": 1,
    "crew_max": 1,
    "cargo": 2.0,
    "pledge_price": 50.0,
    "max_speed": 1230.0,
    "size": "Small",
    "description": "Tour the universe with the perfect coupling..."
  }
]
```

## Rust Deserialization Pattern

```rust
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct ImportItem {
    pub id: String,
    pub name: String,
    pub slug: String,
    pub manufacturer: String,
    pub classification: String,
    pub focus: String,
    pub crew_min: i32,
    pub crew_max: i32,
    pub cargo: f64,
    pub pledge_price: f64,
    pub max_speed: f64,
    pub size: String,
    pub description: String,
}

pub fn import_items(&self, json: &str) -> Result<i64, String> {
    let items: Vec<ImportItem> = serde_json::from_str(json)
        .map_err(|e| format!("JSON parse error: {e}"))?;
    // ... transaction + INSERT OR REPLACE ...
}
```

## Best Practices

1. **Top-level array** — The JSON should be a list of objects, not wrapped in `{ "data": [...] }` unless the Rust struct accounts for it
2. **Use `INSERT OR REPLACE`** — Allows re-importing without duplicates
3. **Wrap in a transaction** — Much faster for 100+ items (1 commit vs N commits)
4. **Keep descriptions short** — Truncate to ~500 chars in the seed file to keep bundle size down
5. **Use `f64` for numeric fields** — Dart's `double` maps to Rust's `f64` via flutter_rust_bridge
6. **Snake_case in JSON** — Rust struct fields use `snake_case` by default with `serde`

## Fetch Pattern (FleetYards API Example)

```bash
# Fetch all items in one request using the API's max per_page
curl "https://api.example.com/v1/items?perPage=240" \
  -H "Accept: application/json" \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data['items']
# Transform into compact format matching ImportItem
compact = [{'id': s['scIdentifier'], 'name': s['name'], ...} for s in items]
json.dump(compact, sys.stdout, indent=2)
" > assets/data/seed.json
```

The `perPage` parameter name varies by API — check `meta.pagination.maxPerPage` from the response. FleetYards uses `perPage` (not `per`).
