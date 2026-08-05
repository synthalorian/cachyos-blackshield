# RPG Stats System Reference

## How stat XP flows on habit completion

Current state (v0.2.0): The `complete_habit` endpoint in `crates/server/src/main.rs` only awards player-level XP via the gamification engine. It does **not** yet call `db.award_stat_xp()`.

### Endpoint behavior

The `POST /habits/{id}/complete` handler:
1. Fetches the habit from DB
2. Records completion in DB (updates streak, completions)
3. Runs the gamification engine (XP, streak, achievements)
4. Saves streak to DB
5. Returns completion response

### What needs to happen (TODO)

After step 2, before step 3, the handler should also award stat XP:

```rust
// In complete_habit handler, after db.complete_habit():
if let Some(habit) = state.db.get_habit(id.to_string()).ok().flatten() {
    // Award stat XP — award 1x the base XP to matching stats
    let _ = state.db.award_stat_xp(&habit.category, habit.xp_reward);
    // ... rest of existing logic
}
```

This means completing a "Fitness" habit also gives XP to Strength and Agility (which both map to Fitness).

### Future enhancement

For bad habits (`🚫 ` prefixed), the stat XP should be awarded on the "completion" of a day without the bad habit. Currently, completing a bad habit works the same way — tick the checkbox to mark "today resisted."

Consider adding a separate endpoint for stat adjustments:
- `POST /stats/xp` — body: `{category: "Fitness", amount: 10, source: "habit"}`

### Stat level scaling

PlayerStat uses the same threshold function as PlayerProgression:
```rust
pub fn xp_for_level(level: u32) -> u32 {
    PlayerProgression::xp_threshold(level + 1)
}
```

Thresholds: 100 → 120 → 144 → 172 → 206 → ... (1.2× growth per level).

## Default stats seeding

Stats are auto-seeded on first DB init. The `initialize_table` function checks `COUNT(*)` and only inserts if the table is empty. To reset stats:
```bash
sqlite3 data/open_habit.db "DROP TABLE player_stats;"
# Then restart the server
```

## API model (Dart)

```dart
class PlayerStat {
  final String id;
  String name;
  double value;
  int level;
  int xpInStat;
  int xpToNext;
  String icon;
  String color;
  String categoryMappings;
}
```

The `fromJson` maps from Rust's snake_case: `xp_in_stat`, `xp_to_next`, `category_mappings`.
