# DatabaseClient Migration — open_habit server

**Context:** Migrating the Axum server from `Arc<Mutex<Database>>` to lock-free `Arc<DatabaseClient>` for thread-safe async handlers.

## Before (Mutex-based)

```rust
// AppState
struct AppState {
    db: Arc<Mutex<Database>>,
    engine: Arc<RwLock<GamificationEngine>>,
}

// Handler pattern
async fn list_habits(State(state): State<AppState>) -> JsonReq<Vec<Habit>> {
    let db = state.db.lock().unwrap();
    JsonReq(db.list_habits().expect("Failed"))
}
```

## After (DatabaseClient)

```rust
// AppState
struct AppState {
    db: Arc<DatabaseClient>,
    engine: Arc<RwLock<GamificationEngine>>,
}

// Handler pattern
async fn list_habits(State(state): State<AppState>) -> JsonReq<Vec<Habit>> {
    JsonReq(state.db.list_habits().expect("Failed"))
}
```

## Step-by-Step Migration

1. **Update imports & type**
   - Replace `use open_habit_db::Database;` with `use open_habit_db::DatabaseClient;`
   - Change `AppState.db` field type from `Arc<Mutex<Database>>` to `Arc<DatabaseClient>`

2. **Instantiate `DatabaseClient` in `main()`**
   ```rust
   // Before
   let db = Arc::new(Mutex::new(Database::open(&db_path).unwrap()));
   // After
   let db = Arc::new(DatabaseClient::new(&db_path).expect("Failed to create DB client"));
   ```

3. **Remove lock calls across all handlers**
   - Delete every `.lock().unwrap()` on `state.db`
   - Call DB methods directly on `state.db`

4. **Adapt to method signature changes**
   - `record_xp` originally: `record_xp(amount, source, habit_id_option, date)`
   - `record_xp` now: `record_xp(amount)` — source/habit/date inferred internally
   - Update call sites accordingly (see `complete_habit` handler for typical usage)

5. **Extend `DatabaseClient` if missing methods**
   - Add variant to `DbCommand` enum in `crates/db/src/lib.rs`
   - Match arm in the message loop (`match cmd { ... DbCommand::YourCmd { respond } => { respond.send(db.your_method()).ok(); } }`)
   - Add public method on `DatabaseClient` that sends the command
   - Rebuild (`cargo check -p open_habit_db`) to ensure `DbCommand::YourCmd` is recognized

6. **Fix any lingering `Mutex` imports**
   - Remove `use std::sync::Mutex;` if no longer used
   - Keep `RwLock` for `engine` only

## Common Pitfalls

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `no method named X found for Arc<DatabaseClient>` | Missing `DbCommand` variant/handler or `DatabaseClient` pub method | Add the method to `DbCommand`, handler, and `impl DatabaseClient` |
| Handler still calls `.lock()` | Forgot to remove lock in some handler | Search/replace `state.db.lock()` patterns |
| `record_xp` argument mismatch | Old 4-arg signature still used | Call `state.db.record_xp(amount)` only |
| Compilation fails after adding method | `DatabaseClient` impl not visible / missing `pub` | Ensure method is `pub fn` inside `impl DatabaseClient` |

## Verification

```bash
# Build server only
cargo check -p open_habit_server

# Run all tests (db tests cover save_streak, record_xp, etc.)
cargo test --workspace

# Start server and smoke-test endpoints
cargo run -p open_habit_server --release &
curl http://localhost:3000/habits
curl -X POST http://localhost:3000/habits -d '{"name":"Test","category":"General","difficulty":"Easy","frequency":"Daily"}' -H "Content-Type: application/json"
```

## Related Changes This Session

- **GamificationEngine:** added `set_achievements()` to bulk-load achievements at startup (called from server `main`)
- **Streak persistence:** `complete_habit` constructs `Streak` and calls `db.save_streak(&streak)`; DB preserves `started_at` via `ON CONFLICT` UPDATE (only `count`, `last_date`, `is_active` change)
- **API cleanup:** removed unused routing imports (`delete`, `put`) and variables after migration

---

*Part of `open-habit` skill — retro-synthwave habit tracker with Rust gamification engine.*
