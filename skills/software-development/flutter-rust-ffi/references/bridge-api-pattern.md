# Bridge API Design Pattern

Pattern for designing flutter_rust_bridge API methods that are exposed to Dart.

## Rust Side

### Function Signature Rules

- Return `Result<T, String>` (not `anyhow::Result`) — flutter_rust_bridge v2 generates
  `Future<T>` for `Result<T, String>`. `anyhow::Error` doesn't auto-convert to Dart.
- Accept `&self` (Database) or primitive types for stateless functions.
- Strings cross the FFI boundary as owned `String`.
- Complex structs go through serde serialization automatically.

### Database Pattern

```rust
use rusqlite::{Connection, params};
use std::sync::Mutex;

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    /// Open/create DB, run migrations. Called once from Dart.
    pub fn open(path: &str) -> Result<Self, String> {
        let conn = Connection::open(path)
            .map_err(|e| format!("Failed to open DB: {e}"))?;
        let db = Self { conn: Mutex::new(conn) };
        db.migrate()?;
        Ok(db)
    }

    /// Check if data exists before seeding
    pub fn has_items(&self) -> Result<bool, String> {
        let conn = self.conn.lock()
            .map_err(|e| format!("Lock error: {e}"))?;
        let count: i64 = conn
            .query_row("SELECT COUNT(*) FROM items", [], |r| r.get(0))
            .map_err(|e| format!("Query failed: {e}"))?;
        Ok(count > 0)
    }

    /// Import from bundled JSON (called once on first launch)
    pub fn import_items(&self, json: &str) -> Result<i64, String> {
        let items: Vec<MyImportItem> = serde_json::from_str(json)
            .map_err(|e| format!("JSON parse: {e}"))?;
        let conn = self.conn.lock()
            .map_err(|e| format!("Lock: {e}"))?;
        conn.execute_batch("BEGIN TRANSACTION")
            .map_err(|e| format!("TX start: {e}"))?;
        let mut imported = 0i64;
        for item in &items {
            conn.execute("INSERT OR REPLACE INTO items (...) VALUES (?1, ...)",
                params![item.field1, item.field2])
                .map_err(|e| format!("Insert failed: {e}"))?;
            imported += 1;
        }
        conn.execute_batch("COMMIT")
            .map_err(|e| format!("TX commit: {e}"))?;
        Ok(imported)
    }

    /// Get all items
    pub fn get_all_items(&self) -> Result<Vec<MyExportItem>, String> {
        let conn = self.conn.lock()
            .map_err(|e| format!("Lock: {e}"))?;
        let mut stmt = conn.prepare("SELECT ... FROM items ORDER BY ...")
            .map_err(|e| format!("Prepare: {e}"))?;
        let rows = stmt.query_map([], |row| {
            Ok(MyExportItem {
                id: row.get(0)?,
                name: row.get(1)?,
            })
        }).map_err(|e| format!("Query: {e}"))?;
        let mut items = Vec::new();
        for row in rows {
            items.push(row.map_err(|e| format!("Row: {e}"))?);
        }
        Ok(items)
    }

    /// Search with dynamic WHERE clauses
    pub fn search_items(
        &self,
        query: &str,
        filter_field: &str,
    ) -> Result<Vec<MyExportItem>, String> {
        let conn = self.conn.lock()
            .map_err(|e| format!("Lock: {e}"))?;

        // Build SQL dynamically
        let mut sql = String::from("SELECT ... FROM items WHERE 1=1");
        let mut params: Vec<String> = Vec::new();

        if !query.is_empty() {
            sql.push_str(" AND LOWER(name) LIKE ?");
            params.push(format!("%{}%", query.to_lowercase()));
        }
        if !filter_field.is_empty() {
            sql.push_str(" AND field = ?");
            params.push(filter_field.to_string());
        }

        sql.push_str(" ORDER BY ...");

        let mut stmt = conn.prepare(&sql)
            .map_err(|e| format!("Prepare: {e}"))?;

        // Convert params to trait object refs for rusqlite
        let param_refs: Vec<&dyn rusqlite::types::ToSql> =
            params.iter().map(|v| v as &dyn rusqlite::types::ToSql).collect();

        let rows = stmt.query_map(param_refs.as_slice(), |row| { ... })
            .map_err(|e| format!("Query: {e}"))?;

        let mut items = Vec::new();
        for row in rows {
            items.push(row.map_err(|e| format!("Row: {e}"))?);
        }
        Ok(items)
    }

    /// Get distinct values for filter popups
    pub fn get_distinct_sizes(&self) -> Result<Vec<String>, String> {
        let conn = self.conn.lock()
            .map_err(|e| format!("Lock: {e}"))?;
        let mut stmt = conn.prepare("SELECT DISTINCT size FROM items ORDER BY size")
            .map_err(|e| format!("Prepare: {e}"))?;
        let rows = stmt.query_map([], |row| row.get::<_, String>(0))
            .map_err(|e| format!("Query: {e}"))?;
        let mut result = Vec::new();
        for row in rows {
            result.push(row.map_err(|e| format!("Row: {e}"))?);
        }
        Ok(result)
    }
}
```

## Dart Side

### Service Wrapper

```dart
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_app/src/rust/frb_generated.dart';
import 'package:my_app/src/rust/api/database.dart';
import 'package:my_app/src/rust/api/model.dart';

class RustService {
  static final RustService _instance = RustService._();
  factory RustService() => _instance;
  RustService._();

  Database? _db;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await RustLib.init();
    final dir = await getApplicationDocumentsDirectory();
    _db = await Database.open(path: '${dir.path}/app.db');
    if (!(await _db!.hasShips())) {
      final json = await rootBundle.loadString('assets/data/seed.json');
      final count = await _db!.importShips(json: json);
      print('Seeded $count items');
    }
    _ready = true;
  }

  Database get db {
    if (!_ready) throw StateError('Not initialized');
    return _db!;
  }

  Future<List<Ship>> getAll() => db.getAllItems();
  Future<List<Ship>> search({String query='', String filter=''}) =>
      db.searchItems(query: query, filterField: filter);
}

// Generated Dart API (flutter_rust_bridge converts Rust naming):
// Future<List<Ship>> db.getAllItems();
// Future<List<Ship>> db.searchItems({required String query, required String filterField});
// Future<Database> Database.open({required String path});
// Future<bool> db.hasItems();
// Future<PlatformInt64> db.importItems({required String json});
```

### App Startup

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  RustService().init();  // Fire and forget — completes before first screen load
  runApp(const MyApp());
}
```

### Screen Usage

```dart
final service = RustService();
await service.init();  // usually already done, this is a no-op if ready
final items = await service.getAll();
```

## Generated Dart Naming Convention

flutter_rust_bridge v2 converts Rust naming to Dart conventions:

| Rust | Dart |
|------|------|
| `get_all_items` | `getAllItems()` |
| `search_items` | `searchItems()` |
| `get_ship_by_id` | `getShipById()` |
| `has_ships` | `hasShips()` |
| `pledge_price` | `pledgePrice` |
| `crew_min` | `crewMin` |
| `import_ships` | `importShips()` |

## SC:Synthesis Reference (Concrete Example)

From the session that created this skill (2026-05-15):

**Rust crate:** `sc_synthesis_bridge` at `app/rust/`
- Models: `Ship` (13 fields: id, name, slug, manufacturer, classification, focus, crew_min/max, cargo, pledge_price, max_speed, size, description)
- Database: 238 ships seeded from `assets/data/ships.json` on first launch
- Search: dynamic SQL with LIKE on name/manufacturer/classification + exact size/manufacturer filters
- Import: transaction-based bulk insert with `INSERT OR REPLACE`

**Data source:** FleetYards API (`api.fleetyards.net/v1/models?perPage=240`), 238 ships. Size heuristic based on crew count + pledge price. Pre-fetched and bundled as `assets/data/ships.json` (152KB).

**Build:** Custom CMakeLists pointing at pre-built `rust/target/debug/libsc_synthesis_bridge.so`. Rustup wrapper for cargokit compatibility (Arch system Rust).
