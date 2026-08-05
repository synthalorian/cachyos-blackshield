# Rust Bridge Crate — Architecture & Codegen Setup

The Rust bridge at `flutter_app/rust/` follows the same patterns as SC Synthesis (`app/rust/`).  
It provides an embedded SQLite-backed gamification engine that will replace the Dart `LocalDatabaseService` once codegen is complete.

## Crate Structure

```
flutter_app/rust/
├── Cargo.toml           # cdylib + staticlib, flutter_rust_bridge 2.12.0
└── src/
    ├── lib.rs           # mod api; pub mod frb_generated;
    ├── frb_generated.rs # PLACEHOLDER — run codegen to populate
    └── api/
        ├── mod.rs       # pub mod model; pub mod database;
        ├── model.rs     # 5 enums + 8 structs
        └── database.rs  # 20 methods, 971 lines
```

## Current Status

- **Compiles:** `cd flutter_app/rust && cargo build` → 0 errors, 0 warnings
- **Workspace isolation:** Has its own `[workspace]` table in Cargo.toml to avoid being picked up by the root workspace
- **FFI not wired:** `frb_generated.rs` is a placeholder. Dart cannot call Rust yet.
- **Dart service still active:** `LocalDatabaseService` handles all persistence. The Rust bridge replaces it when ready.

## Data Model (model.rs)

5 enums + 8 structs, all with `Serialize, Deserialize`:

- `Frequency` — Daily, Weekly, Monthly
- `Difficulty` — Easy, Medium, Hard, Extreme
- `HabitStatus` — Active, Paused, Archived
- `ChallengeType` — Streak(u32), Completions(u32)
- `ChallengeStatus` — Active, Completed, Failed
- `Habit` — id, name, description, category, difficulty, frequency, status, xp_reward, streak_count, last_completed, created_at
- `PlayerProgression` — total_xp, level, xp_to_next
- `Achievement` — id, title, description, icon, xp_reward, unlocked
- `Streak` — habit_id, count, is_active
- `Challenge` — id, title, description, challenge_type, xp_reward, progress, target, status
- `PlayerStat` — id, name, value, level, xp_in_stat, xp_to_next, icon, color, category_mappings
- `CompletionResult` — xp_awarded, bonus_xp, total_xp, streak, levelled_up, new_achievements (Vec<String>)

## Database API (database.rs)

20 public methods, all return `Result<T, String>`:

```rust
pub fn new(db_path: String) -> Result<Self, String>
pub fn get_all_habits(&self) -> Result<Vec<Habit>, String>
pub fn get_habit(&self, id: String) -> Result<Option<Habit>, String>
pub fn create_habit(&self, habit: Habit) -> Result<(), String>
pub fn update_habit(&self, id: String, name: Option<String>, description: Option<String>, status: Option<String>) -> Result<(), String>
pub fn delete_habit(&self, id: String) -> Result<(), String>
pub fn complete_habit(&self, id: String) -> Result<CompletionResult, String>
pub fn get_progression(&self) -> Result<PlayerProgression, String>
pub fn record_xp(&self, amount: u32) -> Result<(), String>
pub fn get_all_achievements(&self) -> Result<Vec<Achievement>, String>
pub fn get_all_streaks(&self) -> Result<Vec<Streak>, String>
pub fn get_all_challenges(&self) -> Result<Vec<Challenge>, String>
pub fn save_challenges(&self, challenges: Vec<Challenge>) -> Result<(), String>
pub fn progress_challenge(&self, id: String, amount: u32) -> Result<Challenge, String>
pub fn get_all_stats(&self) -> Result<Vec<PlayerStat>, String>
pub fn upsert_stat(&self, stat: PlayerStat) -> Result<(), String>
pub fn delete_stat(&self, id: String) -> Result<(), String>
pub fn get_default_stats(&self) -> Result<Vec<PlayerStat>, String>
pub fn reset_all_data(&self) -> Result<(), String>
```

## Codegen Setup (to be done)

To wire the Dart FFI bindings:

1. **Add flutter_rust_bridge_codegen to PATH:**
   ```bash
   export PATH="$HOME/.cargo/bin:$PATH"
   which flutter_rust_bridge_codegen  # should find the installed binary
   ```

2. **Create config file** `flutter_app/flutter_rust_bridge.yaml`:
   ```yaml
   rust_input: rust/src/
   dart_output: lib/src/rust/
   ```

3. **Run codegen:**
   ```bash
   cd flutter_app
   flutter_rust_bridge_codegen generate
   ```

4. **Create RustDatabaseService** (pattern from SC Synthesis):
   ```dart
   class RustDatabaseService {
     static final RustDatabaseService _instance = RustDatabaseService._();
     factory RustDatabaseService() => _instance;
     RustDatabaseService._();

     Future<void> init() async {
       await RustLib.init();
       // Open DB at applicationDocumentsDirectory()
     }

     // Same method signatures as LocalDatabaseService
   }
   ```

5. **Swap provider**: Change `HabitNotifier` to use `RustDatabaseService` instead of `LocalDatabaseService`.
