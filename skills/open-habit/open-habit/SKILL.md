---
name: open-habit
description: Development guide for open_habit — retro-synthwave habit tracker with offline-first Flutter persistence, LocalDatabaseService, RPG stats, bad habits, and a Rust bridge crate awaiting FFI codegen. Covers architecture, challenge generation, rules engine, and Flutter stack.
triggers:
  - open_habit project work
  - flutter habit tracker
  - offline-first flutter persistence
  - shared_preferences changenotifier
  - local database service
  - flutter_rust_bridge codegen setup
  - rpg stats character sheet
  - bad habits quit tracking
  - habit category icons
  - habit library
  - xp streak achievement engine
  - home screen widgets
  - home_widget package
  - synthwave84 theme
  - omarchy palette matching
  - reset all data clean slate
---

# open-habit — Retro-Synthwave Habit Tracker Development

> **Class:** Application Development — Flutter habit tracker with offline-first persistence  \n> **Domain:** Productivity software, gamification, habit tracking  \n> **Tech Stack:** Flutter (Riverpod, shared_preferences, google_fonts) + Rust bridge crate (rusqlite, flutter_rust_bridge @2.12.0)  \n> **Status:** v0.4.1 — 4 Android home screen widgets (Quick Toggle, XP Summary, Stat Snapshot, Challenges) with tap-to-complete via background callback. Synthwave '84 theme reworked to deep purple palette matching Omarchy desktop theme. Auto-sync from LocalDatabaseService. All v0.4.0 features retained. Full offline persistence. Rust bridge crate awaiting codegen.

---

## TL;DR

open_habit is a neon-drenched habit tracker where completing habits grants XP, unlocks achievements, and triggers daily challenges. The app is **100% offline** — no server required. Persistence uses `SharedPreferences` (JSON-serialized in-memory state) via `LocalDatabaseService`. A Rust bridge crate (`flutter_app/rust/`) is created and compiles, waiting for `flutter_rust_bridge_codegen` to wire FFI. Features include RPG stats, bad habits (reverse tracking), 80 pre-populated habits, Habit Library, pull-to-refresh, clean-slate reset, and a full character sheet with achievements.

---

## 1 · Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    open_habit stack (v0.4.1)               │
├──────────────────────────────────────────────────────────┤
│  Android Home Screen Widgets (4 types)                    │
│  • Quick Toggle — 6 habits, tap to complete from launcher │
│  • XP Summary — level, XP bar, best streak               │
│  • Stat Snapshot — up to 6 RPG stats with levels          │
│  • Challenges — active daily challenges with progress     │
│  • WidgetDataService (Dart) → home_widget → Kotlin        │
│  • Auto-updates on every LDB mutation                     │
├──────────────────────────────────────────────────────────┤
│  Flutter UI (flutter_app/)                               │
│  • Dashboard • Habits • Challenges • Stats • Settings    │
│  • Riverpod NotifierProvider (HabitNotifier)              │
│  • Neon synthwave theme (3 modes)                        │
├──────────────────────────────────────────────────────────┤
│  LocalDatabaseService (Dart)                             │
│  • SharedPreferences-backed JSON persistence             │
│  • XP/streak/level/achievement engine (pure Dart)        │
│  • 7 tables: habits, streaks, achievements,              │
│    xp_records, challenges, player_stats, progression     │
│  • Notifies listeners on every mutation                  │
├──────────────────────────────────────────────────────────┤
│  Rust Bridge Crate (flutter_app/rust/) — COMPILES        │
│  • Wraps gamification engine + SQLite in FFI functions   │
│  • Awaits flutter_rust_bridge_codegen to generate Dart   │
│  • Same patterns as SC Synthesis (cdylib + staticlib)    │
│  • 20 public methods: CRUD habits, complete, stats, etc. │
├──────────────────────────────────────────────────────────┤
│  Legacy crates/ (Rust Axum server — DEPRECATED)          │
│  • crates/server, crates/db, crates/gamification         │
│  • No longer required for app operation                  │
└──────────────────────────────────────────────────────────┘
```

**Key insight:** The app works fully offline with zero external dependencies. The Flutter `HabitNotifier` reads/writes through `LocalDatabaseService`, which persists everything to SharedPreferences as JSON arrays. The Rust bridge crate is a future optimization path — when codegen is run, it replaces the Dart persistence layer with embedded SQLite via FFI.

---

## 2 · Project Structure

```
open_habit/
├── Cargo.toml                 # Workspace (members: crates/*) — LEGACY
├── crates/                    # LEGACY Rust crates (server no longer required)
│   ├── shared/                # Shared domain types (Habit, Challenge, etc.)
│   ├── gamification/          # Core engine (XP, streaks, achievements)
│   ├── db/                    # SQLite persistence + thread-safe client
│   ├── server/                # Axum HTTP server (port 3000) — DEPRECATED
│   └── cli/                   # [unused] CLI binary
├── flutter_app/               # MAIN Flutter project
│   ├── android/
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml       # Widget receivers registered here
│   │       ├── kotlin/com/synthwave/open_habit/
│   │       │   ├── MainActivity.kt
│   │       │   └── widgets/              # 4 home screen widget providers
│   │       │       ├── QuickToggleWidgetProvider.kt
│   │       │       ├── XpSummaryWidgetProvider.kt
│   │       │       ├── StatSnapshotWidgetProvider.kt
│   │       │       └── ChallengesWidgetProvider.kt
│   │       └── res/
│   │           ├── drawable/widget_background.xml   # Neon dark background
│   │           ├── layout/                          # 4 widget XML layouts
│   │           │   ├── widget_quick_toggle.xml
│   │           │   ├── widget_xp_summary.xml
│   │           │   ├── widget_stat_snapshot.xml
│   │           │   └── widget_challenges.xml
│   │           └── xml/                            # Widget info (size, update)
│   │               ├── widget_quick_toggle_info.xml
│   │               ├── widget_xp_summary_info.xml
│   │               ├── widget_stat_snapshot_info.xml
│   │               └── widget_challenges_info.xml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   │   ├── app_state.dart      # UI models (Habit, AppChallenge, AppData, Recommendation, PlayerStat)
│   │   │   ├── models.dart         # LEGACY API models (keep until FFI migration)
│   │   │   └── habit_categories.dart # Category icons, emoji, colors + HabitLibrary (80 habits) + StatIconGallery
│   │   ├── screens/
│   │   │   ├── home_screen.dart     # Navigation shell (4-tab bottom nav)
│   │   │   ├── dashboard_screen.dart # Pull-to-refresh, XP bar, habit list, stat grid, challenges, streaks
│   │   │   ├── habits_screen.dart   # Habits list + add dialog with bad habit toggle
│   │   │   ├── challenges_screen.dart
│   │   │   ├── stats_screen.dart    # Character sheet: stats + achievements + streaks
│   │   │   └── settings_screen.dart # Theme picker + Habit Library + Bad Habit guide + Reset All Data
│   │   ├── widgets/
│   │   │   ├── neon_widgets.dart    # GradientBackground, NeonCard, XPProgressBar
│   │   │   ├── habit_card.dart      # Category emoji badges, bad habit styling
│   │   │   ├── challenge_card.dart
│   │   │   ├── stat_card.dart
│   │   │   ├── stat_bar.dart        # RPG stat bar
│   │   │   ├── stat_dialogs.dart    # StatCreateDialog + StatCustomizeDialog
│   │   │   ├── recommendation_card.dart
│   │   │   └── section_header.dart
│   │   ├── services/
│   │   │   ├── local_database_service.dart  # ACTIVE — offline persistence via SharedPreferences
│   │   │   ├── widget_data_service.dart      # Pushes LDB state to Android home screen widgets
│   │   │   └── api_client.dart              # LEGACY — HTTP client, no longer imported
│   │   └── providers/
│   │       ├── habit_provider.dart  # HabitNotifier — uses LocalDatabaseService, not HTTP
│   │       └── theme_provider.dart  # ThemeNotifier (3 modes: light, dark, synthwave84)
│   ├── rust/                    # Rust FFI bridge crate — COMPILES, awaits codegen
│   │   ├── Cargo.toml           # cdylib + staticlib, flutter_rust_bridge 2.12.0
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── frb_generated.rs # Placeholder — run codegen to populate
│   │       └── api/
│   │           ├── mod.rs
│   │           ├── model.rs     # 5 enums + 8 structs matching shared types
│   │           └── database.rs  # 20 methods: CRUD habits, complete, stats, reset
│   └── pubspec.yaml           # v0.3.0 — http removed, shared_preferences retained
```

**CRITICAL:** All Flutter code lives in `flutter_app/`. The empty `flutter/` dir is a placeholder from the README scaffold. Ignore it.

---

## 3 · Current State Checklist

### ✅ Completed (v0.4.0)

**Core Engine (Dart-native, offline):**
- `LocalDatabaseService` — 650-line singleton with SharedPreferences persistence
- Data models: `HabitData`, `ProgressionData`, `CompletionResultData`, `AchievementData`, `StreakData`, `ChallengeData`, `StatData`
- XP system: base XP per difficulty (easy=10, medium=25, hard=50, extreme=100), streak bonus (streak × 5)
- Level system: `xpToNext = level × 100`
- Achievement system: 9 achievements (5 XP milestones + 4 streak milestones), auto-unlock on completion, progress bars shown on locked achievements
- Daily challenges: 3 auto-generated on first load, with progress tracking and completion XP, snackbar feedback on progress
- Stat XP award: `completeHabit()` parses each stat's `categoryMappings`, checks habit category match, awards half XP to matching stat. Stats have own XP/level (`xpToNext = level × 100`).
- Per-habit streaks: `streakCount` on `HabitData` displayed on every card and dashboard streaks section
- Bad habits: `🚫 ` prefix marker on name, reverse tracking, distinct card styling
- Category system: 9 categories with icons/emojis/colors via `HabitCategories`
- Habit Library: 80 pre-populated habits across all categories
- Stat icon gallery: 130+ emojis organized by RPG archetype
- Stat CRUD: create, update, delete via `StatData` model (now tracks xpInStat, level, xpToNext)
- Reset All Data: confirmation dialog in Settings, clears everything
- 8 default stats: Strength, Intelligence, Vitality, Agility, Wisdom, Charisma, Luck, Spirit (🙏)

**UI Features:**
- Material 3 with neon synthwave theme (3 modes: light, dark, synthwave84)
- 4-tab bottom nav (Dashboard, Habits, Challenges, Stats)
- Dashboard: XP bar, habit list with toggle, stat grid, challenges, achievement preview
- Character sheet: overview cards, RPG stat bars with customization, achievement gallery, active streaks
- Pull-to-refresh on Dashboard and Habits
- Habit Library + Bad Habit guide in Settings
- Loading shimmer placeholders (# state.ref)
- Empty states with CTAs

**Rust Bridge Crate (prepared, awaiting codegen):**
- `flutter_app/rust/` — full crate at `/home/synth/projects/open_habit/flutter_app/rust/`
- `model.rs` — 5 enums + 8 structs with Serialize/Deserialize
- `database.rs` — 20 methods wrapping SQLite operations
- Compiles clean (1 warning fixed)
- Awaits `flutter_rust_bridge_codegen generate` from `flutter_app/` directory

### ⚠️ Remaining / To Do

- **`flutter_rust_bridge_codegen` needs config file** — Add `flutter_rust_bridge.yaml` to project root with `rust_input` pointing at `flutter_app/rust/src/`
- **Procedural engine** — `events.rs` and `quests.rs` in `crates/gamification/src/procedural/` are stubs (legacy Rust crate)
- **Rules engine** — Phase 3 (`crates/rules/`) doesn't exist yet (legacy Rust crate)
- **Widget enhancements** — Background update via WorkManager, more widget sizes, Glance-based composable widgets (blocked by AGP 9.1+ requirement)

### ✅ Completed (v0.4.1)

**4 Android Home Screen Widgets:**
- **Quick Toggle** — up to 6 today's habits with ○/✅/⛔ markers, tap to toggle via background callback
- **XP Summary** — current level, XP bar, XP ratio, best streak with 🔥
- **Stat Snapshot** — up to 6 RPG stats with emoji icons and levels, ⬡ header
- **Challenges** — up to 3 active daily challenges with progress (+XpXP)
- `WidgetDataService.pushAll(db)` called from every `LocalDatabaseService` mutation (addHabit, completeHabit, deleteHabit, progressChallenge, addStat, updateStat, deleteStat, resetAllData)
- Auto-update on app launch via `main()` → `HomeWidget.registerInteractivityCallback(backgroundCallback)` + initial `pushAll`
- Each widget opens the relevant app tab on tap via `HomeWidgetLaunchIntent`
- Neon dark background via `widget_background.xml` (drawable with stroke + radius)

**Synthwave '84 Theme Rework**
- Entire palette switched from coral/cyan to deep purple matching Omarchy synthwave84 desktop theme
- New palette: bg `#0d0221`, surface `#240037`, accent `#8F00FF` (electric purple), text `#FFFF66` (warm yellow), secondary `#df00ff` (magenta)
- `GradientBackground` widget detection updated to check for `0xFF8F00FF` primary instead of old `0xFFFF9B71`
- See `references/omarchy-synthwave84-palette.md` for the full color mapping

### 🎯 Phase 2 Status

| Task | Status | Notes |
|------|--------|-------|
| 2.1 Challenge definitions | 90% | 18 templates done; need weekly & difficulty scaling |
| 2.2 Seeded PRNG | 100% | `SeededRng::from_date()` deterministic |
| 2.3 Challenge generator | 80% | Daily works; weekly & preference filtering TBD |
| 2.4 Random events | 0% | `events.rs` unimplemented |
| 2.5 Challenge UI | 90% | Full list, progress buttons, persistence wired |
| 2.6 Challenge progression API | 100% | POST endpoint + persistence implemented |

---

## 4 · Build & Run

```bash
# Build & run Flutter desktop (Linux)
cd /home/synth/projects/open_habit/flutter_app
flutter build linux --debug
./build/linux/x64/debug/bundle/open_habit

# Flutter analyze
cd /home/synth/projects/open_habit/flutter_app && flutter analyze

# Rust bridge crate (standalone compilation check)
cd /home/synth/projects/open_habit/flutter_app/rust && cargo build

# Run flutter_rust_bridge_codegen (when FFI bridge needed)
export PATH="$HOME/.cargo/bin:$PATH"
cd /home/synth/projects/open_habit/flutter_app
# First create flutter_rust_bridge.yaml with rust_input pointing at rust/src/
flutter_rust_bridge_codegen generate

# Legacy Rust crates (compilation only — no longer required to run)
cd /home/synth/projects/open_habit && cargo build --workspace
```

## 5 · LocalDatabaseService Reference

Located at `flutter_app/lib/services/local_database_service.dart`.

### Data Models (all defined in the same file)

| Model | Persistence Key | Fields |
|-------|----------------|--------|
| `HabitData` | `oh_habits` | id, name, category, difficulty, xpReward, streakCount, lastCompleted, createdAt, isBad |
| `ProgressionData` | `oh_progression` | totalXp, level, xpToNext |
| `AchievementData` | `oh_achievements` | id, title, description, icon, xpReward, unlocked |
| `ChallengeData` | `oh_challenges` | id, title, description, xpReward, progress, target, status |
| `StatData` | `oh_stats` | id, name, icon, color, categoryMappings, xpInStat, level, xpToNext |

### Key Methods

```dart
class LocalDatabaseService extends ChangeNotifier {
  Future<void> init();                                           // Load all from SharedPreferences
  Future<void> addHabit(HabitData);                              // Append + persist
  Future<bool> deleteHabit(String id);                           // Remove by id + persist
  Future<CompletionResultData> completeHabit(String id);         // Streak calc + XP + achievements
  Future<ChallengeData> progressChallenge(String id, {int amount});
  Future<void> addStat(StatData);
  Future<void> updateStat(StatData);
  Future<bool> deleteStat(String id);
  Future<void> resetAllData();                                    // Clear everything
}
```

### XP & Achievement Engine (built into `completeHabit`)

- **Base XP:** `easy=10`, `medium=25`, `hard=50`, `extreme=100`
- **Streak bonus:** `(streak - 1) × 5` when streak > 1
- **Level up:** `while totalXp >= xpToNext { totalXp -= xpToNext; level++; xpToNext = level × 100 }`
- **XP achievements:** First Steps (10XP), Century (25XP), Iron Will (50XP), Unstoppable (100XP), Legendary (250XP)
- **Streak achievements:** Threepeat 3d (15XP), Week Warrior 7d (30XP), Fortnight Force 14d (50XP), Monthly Master 30d (100XP)
- **Daily challenges:** 3 auto-generated on first init, progress tracks toward target, completion awards XP

### Bad Habits Pattern

Bad habits use a `🚫 ` prefix stored in the name. The `HabitData.isBad` constructor parameter sets this automatically. The `_toUiHabit` conversion in `HabitNotifier` strips the prefix and sets the `isBad` display flag. Card rendering in `habit_card.dart` checks this for rose accent, QUIT badge, and shield icon.

---

## 6 · Flutter Frontend Architecture (v0.3.0)

### File Layout

```
flutter_app/lib/
├── models/
│   ├── app_state.dart         # UI models: Habit, AppChallenge, AppData, Recommendation, PlayerStat
│   └── models.dart            # LEGACY — API models mirroring Rust serde JSON
├── services/
│   ├── local_database_service.dart  # ACTIVE — offline persistence singleton
│   └── api_client.dart              # LEGACY — HTTP client for old Axum server
├── providers/
│   ├── habit_provider.dart    # HabitNotifier — Riverpod v3 Notifier using LocalDatabaseService
│   └── theme_provider.dart    # ThemeNotifier (3 modes)
├── screens/
│   ├── home_screen.dart       # Navigation shell (4-tab bottom nav)
│   ├── dashboard_screen.dart  # XP bar, habit list, stat grid, challenges, streaks, recommendations
│   ├── habits_screen.dart     # Habit list + add dialog with build/quit toggle
│   ├── challenges_screen.dart
│   ├── stats_screen.dart      # Character sheet with stat bars, achievements, streaks
│   └── settings_screen.dart   # Theme picker, Habit Library, Bad Habit guide, Reset All Data
├── widgets/
│   ├── neon_widgets.dart      # GradientBackground, NeonCard, XPProgressBar
│   ├── habit_card.dart        # Category emoji, bad-habit styling, delete support
│   ├── challenge_card.dart
│   ├── stat_card.dart
│   ├── stat_bar.dart          # RPG stat bar
│   ├── stat_dialogs.dart      # StatCreateDialog + StatCustomizeDialog (⚠️ still references ApiClient)
│   ├── recommendation_card.dart
│   └── section_header.dart
└── main.dart                  # ProviderScope + OpenHabitApp
```

### Key Design Decisions

- **No server required** — `LocalDatabaseService` owns all state, backed by SharedPreferences. Instant persistence, offline-first.
- **Single model layer for new code** — `local_database_service.dart` defines its own `HabitData`, `CompletionResultData`, etc. with `toJson`/`fromJson`. No need to import `models.dart` for new features.
- **Provider listens to DB** — `LocalDatabaseService` extends `ChangeNotifier`. `HabitNotifier` subscribes in `_onDbChanged`, converts DB models to UI models (`_toUiHabit`, `_toUiChallenge`), and emits new `AppData`.
- **Bad habits** — Same marker prefix pattern (`🚫 `) stored in name. `HabitData.isBad` constructor param sets it automatically.
- **Riverpod v3 `Notifier`** — `build()` kicks off async `_initDb()`. State updates trigger via `_onDbChanged` callback from `LocalDatabaseService`.
- **Completion feedback** — `toggleHabit()` returns `CompletionResultData?` which the Dashboard uses to show XP/streak/level-up/achievement dialog.
- **Reset All Data** — `LocalDatabaseService.resetAllData()` clears all SharedPreferences keys, reinitializes with defaults, and notifies listeners.

### Common Pitfalls

1. **CompletionResultData field mismatch** — The old `api.models.CompletionResponse` had `achievementXp` (a single int) while the new `CompletionResultData` has `newAchievements` (a list of objects). When porting dialog code, replace `response.achievementXp` with `response.newAchievements.fold(0, (sum, a) => sum + a.xpReward)` if total XP display is needed.

2. **`removeWhere` returns void** — `_list.removeWhere(...)` returns `void`, not `int`.
   Check deletion by comparing length before/after:
   ```dart
   final before = _list.length;
   _list.removeWhere((item) => item.id == id);
   if (_list.length < before) { /* was removed */ }
   ```

3. **`LocalDatabaseService` must be initialized** — Call `await db.init()` before any
   getter or mutation. The Riverpod provider's `build()` method should kick this off.

---

## 6 · Phase 2 Implementation Guide

### 2.3 Challenge Generator (remaining)

**Weekly challenges** — modify `generator.rs`:
- Add `WeeklyTemplate` struct with `day_of_week: u32` (0=Sun)
- In `generate_daily()`, also generate weekly if `date.weekday() == Monday`
- Higher XP rewards (×2), higher targets

**User preference filtering**:
- Extend `Engine::generate_daily()` to accept `excluded_categories: Vec<String>`
- In sampling loop, skip templates whose category in excluded set
- Add Flutter setting: "Hide categories" (store in SharedPreferences)

### 2.4 Random Events (events.rs — new file)

```rust
pub enum EventType {
    BonusXP { multiplier: f32, duration_hours: u32 },
    ChallengeRush { required_completions: u32, bonus_reward: u32 },
    MysteryBox { achievement_id: Uuid },
    GridStorm { duration_hours: u32 },
}

pub struct Event {
    pub id: Uuid,
    pub event_type: EventType,
    pub triggered_at: NaiveDate,
    pub expires_at: NaiveDate,
    pub active: bool,
}

impl Engine {
    pub fn check_events(&mut self, state: &PlayerState) -> Vec<Event> { /* … */ }
}
```

**Triggers to implement:**
- Time-based: midnight roll checks `expires_at < today` → deactivate
- Streak-based: `streak_count % 7 == 0` → BonusXP event
- XP milestone: `total_xp crosses 100, 500, 1000` → MysteryBox
- GridStorm: rare (1% daily chance) → freezes all streaks for 24h

**Notification pathway:** Server should push events via SSE or include in `/progression` response.

### 2.5 Flutter Challenge UI

Needed widgets:
- `ChallengeProgressButton` — tap to add progress (call `progress_challenge()`)
- `EventToast` — overlay when event triggers (animated neon border)
- `ChallengeHistoryList` — separate tab for past challenges

---

### 2.6 Challenge Persistence & Progression Endpoint

**Backend fixes (gamification engine):**
- `ChallengeEngine::active_challenges()` — fixed incorrect recursive call. Properly filters active challenges:
  ```rust
  pub fn active_challenges(&self) -> Vec<Challenge> {
      self.challenges
          .iter()
          .filter(|c| c.status == ChallengeStatus::Active)
          .cloned()
          .collect()
  }
  ```
- Added `GamificationEngine::active_challenges()` delegator to expose active challenges for persistence.
- DB layer extended: `SaveChallenges` command + `save_challenges()` client method.
- Server route: `POST /challenges/{id}/progress` — calls `engine.progress_challenge()`, then persists all active challenges via `db.save_challenges(&engine.active_challenges())`.

**Common pitfall:** When a struct field (e.g., `challenges: Vec<Challenge>`) needs to expose a method, don't call `self.field.method()` recursively; iterate and filter with `self.field.iter()`. The original implementation mistakenly called `self.challenges.active_challenges()` on a `Vec`, causing a "method not found" compile error.

**Status:** Endpoint functional; challenge progress updates persist between server restarts.

---

## Phase 3.5 — RPG Stats Implementation Guide

### PlayerStat Model

```rust
// In crates/shared/src/lib.rs
pub struct PlayerStat {
    pub id: Uuid,
    pub name: String,           // e.g. "Strength", "Intelligence"
    pub value: f64,             // current numeric value (mirrors level)
    pub level: u32,             // current stat level
    pub xp_in_stat: u32,        // XP accumulated toward next level
    pub xp_to_next: u32,        // XP needed for next level
    pub icon: String,           // emoji like "💪"
    pub color: String,          // hex color like "#FF5500"
    pub category_mappings: String, // JSON array: ["Fitness","Nutrition"]
    pub created_at: NaiveDate,
}
```

**Key methods:**
- `add_xp(amount)` — adds XP, handles level-up, returns bool for leveled
- `xp_for_level(level)` — uses `PlayerProgression::xp_threshold()` for consistent scaling

### Category → Stat Mapping

Each stat's `category_mappings` is a JSON string like `["Fitness","Nutrition"]`. When a habit is completed, `Database::award_stat_xp()` parses each stat's mappings, checks if the habit's category matches, and awards XP.

**7 default stats with their mappings:**
- Strength 💪 → Fitness, Nutrition
- Intelligence 🧠 → Learning, Creative
- Vitality ❤️ → Mindfulness, Nutrition
- Agility ⚡ → Fitness, Productivity
- Wisdom 🔮 → Mindfulness, Learning
- Charisma 🎭 → Social, Creative
- Luck 🍀 → Finance, General

### DB Layer Pattern

Adding a new persistence concern (like player_stats) follows this pattern:
1. Create a `crates/db/src/<feature>.rs` module with pure `Connection` functions
2. Add `mod <feature>;` and `initialize_table()` call in `db/src/lib.rs`
3. Add `DbCommand` variants to the enum
4. Add match arms in the message loop
5. Add `DatabaseClient` methods that follow the channel send/recv pattern
6. Add delegator methods on `Database` that call the module functions

### Stat Icon Gallery

`StatIconGallery` in `habit_categories.dart` provides 130+ emojis organized by RPG-themed groups:
- Strength: 💪🏋️🦾🔥⚡🛡️⚔️💢
- Magic: 🔮✨🪄🧙🌟🌙💫🌀
- Elements: 🔥💧🌪️🌍⚡❄️🌋💨
- Weapons: ⚔️🗡️🛡️🏹🔫💣🔪🪓
- Cosmic: 🌌⭐🌙☀️🪐🌠🚀👽
- All icons available via `StatIconGallery.allIcons`

### Stat Customization Dialogs

- `StatCustomizeDialog` — edit existing stat: name, icon (scrollable emoji grid), color (12 swatches), category remapping (FilterChips)
- `StatCreateDialog` — same fields + name input for creating new stats
- Both call API and return `true` on success so caller can refresh provider

---

## Phase 4.5 — Bad Habits Implementation Guide

### Architecture

Bad habits use a **marker prefix pattern** instead of a schema change:
1. When creating a bad habit, the name is stored as `"🚫 <name>"` on the backend
2. `_toUiHabit()` checks `name.startsWith('🚫 ')`, strips the prefix in display, sets `isBad: true`
3. The card renders with rose/red accent colors, a "QUIT" badge, and a shield icon
4. XP and streak tracking work identically — the emotional difference is the reverse psychology

### Creating a Bad Habit

```dart
// In HabitNotifier
Future<void> addBadHabit(String name, String category, int xp) async {
  final newHabit = api.Habit.create(
    name: "🚫 $name",
    category: category,
    difficulty: api.Difficulty.easy,
    frequency: api.Frequency.daily,
  );
  await _api.createHabit(newHabit);
  await refresh();
}
```

### UI Model Conversion

```dart
Habit _toUiHabit(api.Habit h) {
  final name = h.name;
  return Habit(
    id: h.id,
    name: name.startsWith('🚫 ') ? name.substring(2) : name,
    category: h.category,
    xp: h.xp_reward,
    completed: completed,
    isBad: name.startsWith('🚫 '),
  );
}
```

### Card Styling (habit_card.dart)

- Bad habits get `accentColor = Color(0xFFFF007F)` (neon magenta/rose)
- Category emoji badge uses the rose accent
- Check circle shows `Icons.block_rounded` instead of `Icons.check_rounded`
- "QUIT" label above the habit name in a small pill badge
- XP badge shows shield icon: `'+${habit.xp} 🛡️'`
- Strike-through on name when completed

### Add Habit Dialog

The add dialog in `habits_screen.dart` has a `Build/Quit` toggle switch:
- Build mode: shows difficulty dropdown with XP values
- Quit mode: shows info banner explaining reverse tracking
- Bad habit creation bypasses difficulty (always Easy/10 XP)

---

## Phase 4.7 — Category Icons & Habit Library

### HabitCategories (`habit_categories.dart`)

```dart
class HabitCategoryInfo {
  final String name;       // "Fitness"
  final IconData icon;     // Icons.fitness_center
  final String emoji;      // "🏋️"
  final Color color;       // Color(0xFFFF5500)
  final String description;
}
```

**9 categories:** Fitness, Mindfulness, Learning, Nutrition, Finance, Social, Creative, Productivity, General

**Static helpers:** `find()`, `iconFor()`, `emojiFor()`, `colorFor()` — all safe (return defaults if category not found)

### HabitLibrary

80 pre-populated habits across all 9 categories (10 per category + 5 bad habits). Each `SuggestedHabit` has:
- name, category, description, difficulty, emoji

Access via Settings → Habit Library with category filter chips. One-tap add via `notifier.addHabit()`.

---
## Phase 9 — Home Screen Widgets (v0.4.1)

### Architecture

```
LocalDatabaseService (Dart singleton)
    ↓ every mutation calls WidgetDataService.pushAll(this)
WidgetDataService (Dart, flutter_app/lib/services/widget_data_service.dart)
    ↓ HomeWidget.saveWidgetData() + HomeWidget.updateWidget()
home_widget SharedPreferences (Android widget storage)
    ↓ Kotlin AppWidgetProvider reads widgetData.getString(key)
Android RemoteViews (XML layout populated at runtime)
```

4 widget types, each with its own Kotlin provider + XML layout + widget info file.

### Data Flow

1. User mutates data → `LocalDatabaseService` fires `notifyListeners()` + `WidgetDataService.pushAll(this)`
2. PushAll serializes relevant data as JSON, calls `HomeWidget.saveWidgetData(key, json)` per widget
3. Then calls `HomeWidget.updateWidget(qualifiedAndroidName:)` for each widget type
4. Android calls the widget provider's `onUpdate()` → reads JSON → populates `RemoteViews`

### Widget Keys

| Key | Widget | Data Shape |
|-----|--------|------------|
| `oh_widget_habits` | Quick Toggle | `[{id, name, category, difficulty, xp, isBad, completed}]` (max 6) |
| `oh_widget_xp` | XP Summary | `{level, totalXp, xpToNext, bestStreak}` |
| `oh_widget_stats` | Stat Snapshot | `[{id, name, icon, level, color}]` (max 6) |
| `oh_widget_challenges` | Challenges | `[{title, description, progress, target, xpReward}]` (max 3) |

### Interactivity (Tap-to-Complete)

Quick Toggle supports tapping a habit row to complete it without opening the app:
1. Kotlin creates `HomeWidgetBackgroundIntent` with URI `quickToggle://complete?id=<id>`
2. Dart `WidgetDataService.backgroundCallback` receives the URI in a background isolate
3. Callback calls `LocalDatabaseService().completeHabit(id)` → auto-pushes widget updates
4. Widget refreshes showing the habit as completed

### PITFALL: home_widget Version Constraints

`home_widget 0.9.x` depends on `androidx.glance:glance-appwidget:1.3.0-alpha01` requiring **compileSdk 37** and **AGP 9.1.0+**. Use `home_widget:0.7.0` which depends on `glance-appwidget:1.0.0` — compatible with AGP 8.11.1 + SDK 36.

If upgrading, the AGP 9 migration requires: remove `kotlin-android` plugin from `app/build.gradle.kts`, AGP 9.1.0+ in `settings.gradle.kts`, Gradle 9.3.1+, and override `compileSdk = 37`.

### PITFALL: Kotlin R Class in Subpackages

Kotlin providers in subpackages (`com.synthwave.open_habit.widgets`) need an explicit `import com.synthwave.open_habit.R`. Without it, `R.layout.widget_foo` fails with "Unresolved reference 'R'".

### PITFALL: Synthwave Theme Detection in neon_widgets.dart

`GradientBackground` detects synthwave mode by comparing `theme.colorScheme.primary.toARGB32()` against the primary color value. If the palette changes, update both:
1. The comparison value in `neon_widgets.dart` line 21
2. The gradient's default start/end colors (also in `neon_widgets.dart`)
Reference the `references/omarchy-synthwave84-palette.md` mapping for the correct values.

### PITFALL: Dynamic XML View Population

Declare ALL views in the layout XML (habit_1 through habit_6). Use `context.resources.getIdentifier("habit_$i", "id", context.packageName)` for runtime lookup by string name.

### Testing

1. Install APK: `flutter build apk --release && flutter install --release`
2. Long-press home screen → Widgets → Open Habit → place a widget
3. Open the app, create/toggle habits, verify widget auto-updates
4. Tap a habit on Quick Toggle → verify it marks completed in the app
---

## Phase 6.5 — Flutter Compilation Patterns (open_habit specific)

### Import collision resolution

Both `app_state.dart` and `models.dart` define a `Habit` class. When a file needs both:
```dart
import '../models/models.dart';
import '../models/app_state.dart' hide Habit;
```

### Re-export Pattern for Shared Models

```dart
// api_client.dart
import '../models/models.dart';
import '../models/app_state.dart' hide Habit;
export '../models/models.dart' show CompletionResponse, ProgressionResponse;
export '../models/app_state.dart' show PlayerStat;
```

This lets consumers import just `api_client.dart` and get `CompletionResponse`, `ProgressionResponse`, and `PlayerStat`.

---

## Phase 3 — Habit Stacking (Rules Engine)

**New crate:** `crates/rules/` (parallel to `gamification/`)

Structure:
```
rules/
├── mod.rs          # pub mod engine; pub mod definitions;
├── definitions.rs  # Rule set: if-then recommendations
├── engine.rs       # Rule evaluator + scorer
└── categorizer.rs  # Auto-categorize new habits by keywords
```

**Rule types:**
1. **Co-occurrence** — "Users who do A also do B" (from DB analytics, future)
2. **Temporal** — "After completing A, suggest B within 1h"
3. **Prerequisite** — "Streak(A) ≥ 7 → unlock B"
4. **Recovery** — "Missed A 3 days → suggest recovery habit C"

**Recommendation service:**
```rust
pub struct Recommender {
    rules: Vec<Rule>,
    user_history: Vec<Habit>,
}
impl Recommender {
    pub fn recommend(&self, today: NaiveDate) -> Vec<Recommendation> { /* score & sort */ }
}
```

**Flutter UI:** Add "Recommended" section below Today's Habits on Dashboard. Swipe-to-add.

---

## 8 · IPC Strategy — LEGACY (HTTP server deprecated)

> **Note:** The app is now fully offline with `LocalDatabaseService` persistence. The old Axum HTTP server (`crates/server/`) is no longer required or used. This section is kept for reference only.

**Original plan** (from README): Unix domain socket (Linux/macOS) or named pipe (Windows) for zero-copy local IPC.

**What shipped:** The MVP used HTTP loopback (`http://127.0.0.1:3000`). This was replaced in v0.3.0 by `LocalDatabaseService` (SharedPreferences persistence). No server is needed.

**Rust FFI future:** The `flutter_app/rust/` bridge crate exists and compiles. When `flutter_rust_bridge_codegen` is run, it will replace the Dart persistence layer with embedded SQLite via FFI — the same pattern as SC Synthesis. No server process required even then.

---

## 7 · Testing Matrix

| Layer | Tool | Command |
|-------|------|---------|
| Flutter analyze | `flutter analyze` | `cd flutter_app && flutter analyze` (target: 0 errors, 0 warnings, info-only OK) |
| Flutter unit | `flutter test` | `cd flutter_app && flutter test` |
| Rust bridge crate | `cargo build` | `cd flutter_app/rust && cargo build` |
| Legacy Rust workspace | `cargo build --workspace` | `cd /home/synth/projects/open_habit && cargo build --workspace` |
| E2E (manual) | — | 1. `cd flutter_app && flutter run` 2. Add habit, toggle, verify XP + streaks |

**Missing:** Automated E2E (integration_test package) — future.

---

## 10 · Common Pitfalls & Gotchas

### RemoteViews: `<View>` Not Allowed (Android 15+)
Widget XML layouts that use plain `<View>` as dividers or progress bars crash on Android 15 with "Class not allowed to be inflated android.view.View". Replace ALL `<View>` elements with `<TextView>` equivalents (1dp divider, fill bar). See `references/android-home-widget-pitfalls.md`.

### HomeWidgetLaunchIntent Crashes on Android 15
`home_widget 0.7.0`'s `HomeWidgetLaunchIntent.getActivity()` uses a removed API and crashes on Android 15. Replace with manual `PendingIntent.getActivity()` using `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT`. See `references/android-home-widget-pitfalls.md`.

### Rust → Flutter data mismatches
- Rust `chrono::NaiveDate` serializes as `"YYYY-MM-DD"` string. Flutter must parse with `DateFormat('yyyy-MM-dd')`.
- Rust `uuid::Uuid` → Flutter `String` (JSON). keep consistent.
- Challenge `ChallengeType::Streak(n)` serializes as `{"Streak": n}` — match in Dart.

### Database thread safety & DatabaseClient migration
**Never use `Database` directly across threads.** Use `DatabaseClient` (channel-based, thread-safe) wrapped in `Arc`.

**Migration pattern (Mutex → DatabaseClient):**
1. Change `AppState.db` from `Arc<Mutex<Database>>` to `Arc<DatabaseClient>`
2. Remove all `lock().unwrap()` calls — `DatabaseClient` methods are direct (internally channel)
3. Update each handler: `db.method(args)` instead of `db.lock().unwrap().method(args)`
4. If DB method signature changed (e.g., `record_xp` simplified), adapt call sites
5. Ensure `DatabaseClient` has all needed methods; add `DbCommand` variants and handler if missing

**Key DBClient methods:** `list_habits`, `get_habit(id)`, `create_habit(&Habit)`, `update_habit(&Uuid, name?, desc?, status?)`, `delete_habit(id)`, `complete_habit(id) -> u32`, `record_xp(amount)`, `list_achievements()`, `list_streaks()`, `list_challenges()`, `save_streak(&Streak)`, `get_progression()`.

**Pitfall:** When adding new persistence needs, extend `DbCommand` enum, match arm in `db/src/lib.rs` message loop, and expose a `DatabaseClient` method. Don't revert to `Mutex`.

### Rust workspace edition and async compilation
**Symptom:** `error[E0670]: async fn is not permitted in Rust 2015` even though workspace sets `edition = "2024"`.

**Fix:** Explicitly set `edition = "2024"` (or `"2021"`) in the **crate's own** `Cargo.toml` under `[package]`, not just `edition.workspace = true`. Some dependencies or toolchain caching can cause the workspace value to be ignored. After changing, run `cargo clean -p <crate>` then rebuild.

**Version:** Requires Rust 2021+ edition features; ensure `rustc` is reasonably recent (2026 toolchain fine).

### Seeded RNG determinism
- `SeededRng::from_date(date, user_id)` must hash consistently. Current impl uses `DefaultHasher` on formatted date string — works.
- Changing hasher algorithm breaks reproducibility. If you modify RNG, keep old seeds migratable or invalidate old challenges.

### Code hygiene (Rust)
- Remove unused imports/variables promptly. Use `cargo check --workspace` to catch.
- When refactoring, update all call sites (e.g., function renames like `cmd_add` → `cmd_create_habit`).
- Prefer `_` prefix for intentionally unused bindings (`_engine`, `_description`).
- Run `cargo fix` to apply suggested lint fixes automatically.

### Flutter compilation pitfalls

**1. Keyboard-aware dialogs (overflow prevention)**
When a dialog contains form fields (text + dropdowns), the keyboard pushes the dialog up but the content doesn't scroll, causing `BOTTOM OVERFLOWED BY N PIXELS`. Wrap the `content:` parameter in `SingleChildScrollView`:
```dart
AlertDialog(
  content: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [...],
    ),
  ),
)
```
### Flutter compilation pitfalls

**1. Keyboard-aware dialogs (overflow prevention)**
When a dialog contains form fields (text + dropdowns), the keyboard pushes the dialog up but the content doesn't scroll, causing `BOTTOM OVERFLOWED BY N PIXELS`. Wrap the `content:` parameter in `SingleChildScrollView`:
```dart
AlertDialog(
  content: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [...],
    ),
  ),
)
```
Without this, dropdown menus + text fields overflow when the keyboard is active.

**2. AppBar shadow clipping with custom fonts**
Rajdhani and other display fonts have tall ascenders that clip against the AppBar's elevation shadow. Two fixes:
- Remove AppBar `elevation` and `shadowColor` (set to 0) so no shadow line cuts across the title
- Set `toolbarHeight: 72` (or higher) to give the font room
- Also add `scrolledUnderElevation: 0` to prevent shadow re-appearing on scroll
```dart
appBar: AppBar(
  toolbarHeight: 72,
  ...
)
// In theme:
appBarTheme: const AppBarTheme(
  elevation: 0,
  scrolledUnderElevation: 0,
  ...
)
```

**3. Color.value deprecation (Flutter 3.31+)**
`Color.value` is deprecated — use `Color.toARGB32()` instead for comparison:
```dart
// Old — deprecated:
theme.colorScheme.primary.value == 0xFFFF9B71;
// New:
theme.colorScheme.primary.toARGB32() == 0xFFFF9B71;
```

**4. Relative import paths from within lib/screens/**
When a file lives in `lib/screens/`, importing a sibling screen with `'screens/foo_screen.dart'` resolves to `lib/screens/screens/foo_screen.dart` — wrong. Use `'foo_screen.dart'` (same-directory relative) or `'../screens/foo_screen.dart'` (package-relative from deeper dirs).

**5. Re-export pattern for shared response DTOs**
`CompletionResponse` and `ProgressionResponse` are consumed by both `api_client.dart` (method return types) and `habit_provider.dart` (result conversion). Define them once in `models.dart`, then re-export from `api_client.dart`:
```dart
export '../models/models.dart' show CompletionResponse, ProgressionResponse;
```
This lets consumers import just `api_client.dart` without needing a second import. Do NOT define the same class in both files — that's a compile error about duplicate definitions once both are imported.

**6. Extension static member access**
Static members inside Dart extensions must be accessed via `<ExtensionName>.<member>`, not `<member>` directly — even from within the same file. Example:
```dart
extension DifficultyX on Difficulty {
  static const List<int> DifficultyXP = [10, 25, 50, 100];
}
// WRONG:
xp_reward: DifficultyXP[difficulty.index];
// RIGHT:
xp_reward: DifficultyX.DifficultyXP[difficulty.index];
```

**4. Named vs positional parameters on method calls**
When a method declares positional + named params:
```dart
Future<void> progressChallenge(String challengeId, {int amount = 1})
```
Call with: `_api.progressChallenge(id, amount: 3)` — NOT `_api.progressChallenge(id, 3)` (the named amount becomes a positional mismatch).

**5. Two model layers pattern**
Maintain separate API and UI model classes. API models (`models.dart`) mirror Rust's serde JSON (snake_case fields, exact `fromJson`/`toJson`). UI models (`app_state.dart`) use clean Dart conventions (camelCase, `copyWith`, no serialization logic). The provider/notifier layer handles conversion between them. This prevents Rust serialization concerns from leaking into UI code and vice versa.

### Provider method visibility (`_refresh` → `refresh`)

Keep data-loading methods public when external widgets need to trigger reloads. In this project:
- `HabitNotifier._refresh()` was renamed to `HabitNotifier.refresh()` because Stats screen, stat dialogs, and pull-to-refresh widgets all call it externally
- **Rule of thumb:** If a screen outside the provider's "home" needs to reload data, the method should be public. Keep `_` prefix only for methods called exclusively from within the provider itself.

### Flutter state rebuilds
- Riverpod `NotifierProvider` should emit new `AppData` on every mutation (copyWith pattern).
- Loading states: use `AsyncValue` (loading, data, error). Current `HabitNotifier` is synchronous — upgrade to `AsyncNotifier` or `FutureProvider` when API calls added.

### f64 in `#[derive(Eq)]` causes compile error
`f64` does not implement `Eq`. Any struct deriving `Eq` that contains an `f64` field will fail with `the trait bound 'f64: Eq' is not satisfied`.
**Fix:** Remove `Eq` from the derive and keep only `PartialEq`.

### `Self::` in standalone module functions
Inside a `pub mod` that is NOT an `impl` block, `Self::` refers to the module, not the struct. Using `Self::some_method()` where `some_method` is defined on `struct PlayerStat` will fail with `cannot find 'Self' in this scope`.
**Fix:** Use `PlayerStat::method()` instead of `Self::method()`.

### Re-export + direct import collision in api_client
When `api_client.dart` imports both `models.dart` (for `Habit`) and `app_state.dart` (for `PlayerStat`), and both define `Habit`, the import is ambiguous. 
**Fix:** `import '../models/app_state.dart' hide Habit;` in the api client. The `hide` keyword prevents the collision.

### Switch activeColor deprecation (Flutter 3.31+)
`Switch.activeColor` is deprecated in favor of `Switch.activeThumbColor`. For Flutter 3.31+, update to use the new property.

### DropdownButtonFormField `value` deprecation (Flutter 3.33+)
`DropdownButtonFormField.value` is deprecated in favor of `DropdownButtonFormField.initialValue`. Update when targeting SDKs above 3.33.

---

## Immediate Next Steps (Session-To-Session)

If continuing development, tackle in this order:

1. **Set up flutter_rust_bridge_codegen** — Add config file, run codegen, replace `LocalDatabaseService` with FFI calls to `flutter_app/rust/`
2. **Implement stat XP award** — `completeHabit()` should parse each stat's `categoryMappings` JSON, check if the habit's category matches, and award stat XP
3. **Wire challenge progress** — Ensure `challenges_screen.dart` passes `onProgress` callback to `ChallengeCardWidget` that calls `HabitNotifier.progressChallenge()`
4. **Achievement gallery polish** — Show progress toward locked achievements (e.g., "3/7 days" for streak achievements)
5. **Implement random events** — `events.rs` triggers (Bonus XP on 7-day streak, MysteryBox on milestones)
6. **Add fl_chart** — XP timeline chart on Stats tab
7. **Real recommendation engine** — hardcoded recommendations exist, real ones need rules engine (Phase 3)
8. **Surface per-habit streaks** — already tracked in `HabitData.streakCount`, not displayed per-habit on Dashboard

---

## 12 · Useful Snippets

**Complete a habit and check result:**
```dart
final db = LocalDatabaseService();
await db.init();
final result = await db.completeHabit('habit-id-here');
print('XP: ${result.xpAwarded}, Streak: ${result.streak}');
print('Level up: ${result.levelledUp}');
for (final ach in result.newAchievements) {
  print('Achievement unlocked: ${ach.title} (+${ach.xpReward}XP)');
}
```

**Reset all data:**
```dart
final db = LocalDatabaseService();
await db.init();
await db.resetAllData();
```

**Add a stat from a dialog without WidgetRef:**
```dart
final db = LocalDatabaseService();
await db.init();
await db.addStat(StatData(
  name: 'New Stat',
  icon: '💪',
  color: '#FF5500',
  categoryMappings: '["Fitness","General"]',
));
```

**Rust bridge crate: Add a new challenge template** (`generator.rs` → `TEMPLATES`):
```rust
Template {
    title: "Cold Shower",
    description: "End your shower with 30 seconds of cold water.",
    category: "health",
    base_target: 1,
    level_multiplier: 1.0,
    min_target: 1,
    max_target: 1,
    _difficulty_hint: Difficulty::Hard,
},
```

---

## 13 · References & Resources

**Absorbed skill: procedural-challenge-engine** (consolidated 2026-05-27) — deterministic, template-driven challenge generation with seeded PRNG, category diversity, and daily regeneration. A core subsystem of open_habit.

- **Android home screen widget pitfalls** — `references/android-home-widget-pitfalls.md` (RemoteViews `<View>` restriction, HomeWidgetLaunchIntent Android 15 crash, safe PendingIntent pattern)
- **PLAN.md** — full Phase 1–6 breakdown
- **README.md** — public overview
- **local-db-pattern.md** — Offline persistence with SharedPreferences, LocalDatabaseService pattern, common pitfalls
- **Rust bridge crate** — `flutter_app/rust/` with full API docs in `references/rust-bridge-crate.md`
- **LocalDatabaseService** — `flutter_app/lib/services/local_database_service.dart`
- **Flutter UI entry** — `flutter_app/lib/main.dart` → `HomeScreen` with tab layout
- **Old server code** — `crates/server/src/main.rs` (Axum handlers, DEPRECATED)
- **Challenge progression implementation** — `references/challenge-progression.md`

---

## 14 · Known Open Questions

- Should random events be stored in DB or ephemeral? → likely ephemeral (session-only)
- How to sync user_id across Rust and Flutter? → generate UUID on first launch, store in SharedPreferences, send in API header `X-User-Id`
- Cross-app integrations (open_health, open_grid) are Phase 5 — not urgent
- Avatar evolution: currently no avatar system in UI — future cosmetic unlocks

---

*Your habits shape your world. Make them legendary.* 🎹🦞
