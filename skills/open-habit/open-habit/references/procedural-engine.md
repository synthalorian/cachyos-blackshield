# Procedural Challenge Engine — Deep Dive

This document captures the current implementation and remaining work for Phase 2 (Procedural Challenge Engine) in open_habit.

---

## Overview

The procedural engine generates daily challenges that are deterministic (same date + user_id → same set). It uses a seeded PRNG and a template pool.

Location: `crates/gamification/src/procedural/`

Files:
- `mod.rs` — public `Engine` with `generate_daily()` entry point
- `rng.rs` — `SeededRng` wrapper around `rand::StdRng`
- `generator.rs` — `TEMPLATES` array + `generate_daily()` logic
- `events.rs` — **TODO** (random events)
- `quests.rs` — **TODO** (multi-part quest chains)

---

## Seeded RNG (`rng.rs`)

### Determinism guarantee

```rust
let mut rng = SeededRng::from_date(date, Some(user_id));
```

Seed derivation:
1. Format date as `"%Y-%m-%d"` string (e.g., `"2026-05-14"`)
2. Hash with `DefaultHasher` (stable, non-cryptographic)
3. Mix in `user_id.as_hyphenated().to_string()` if provided
4. Feed 64-bit hash to `StdRng::seed_from_u64()`

**Why this works:** `StdRng` is ChaCha20-based; same seed → identical sequence across all platforms (within same rand version).

**Gotcha:** Changing `rand` version or hasher can break reproducibility. Document any change in PLAN.md.

### Public methods

- `gen_range(low, high)` — `i32` in `[low, high)`
- `shuffle(slice)` — Fisher–Yates in-place shuffle
- `next_u32()` — raw uniform `u32`

---

## Challenge Generation (`generator.rs`)

### Template structure

```rust
pub struct Template {
    pub title: &'static str,
    pub description: &'static str,
    pub category: &'static str,   // "physical", "mental", "social", etc.
    pub base_target: u32,          // unscaled target count
    pub level_multiplier: f32,     // target *= multiplier
    pub min_target: u32,           // floor after scaling
    pub max_target: u32,           // ceiling after scaling
    pub _difficulty_hint: Difficulty,
}
```

### Current TEMPLATES (18 total)

| Category | Templates |
|----------|-----------|
| physical | Push-up Set (10), Cardio Burst (1), Stretch Routine (1) |
| mental | Reading Session (10), Meditation (5), Learn Something New (15) |
| social | Reconnect (1), Random Act of Kindness (1) |
| creative | Free Write (10), Sketch Something (1–3) |
| health | Hydrate (1–3), Early to Bed (1) |
| weird | Digital Detox Hour (1), Learn a Useless Fact (1) |

### Generation algorithm (`generate_daily()`)

1. Determine count via `generate_count(level)`:
   - Levels 1–3 → 3 challenges
   - Levels 4–7 → 4 challenges
   - Level 8+ → 5 challenges

2. Shuffle `TEMPLATES` with `rng.shuffle(&mut shuffled)`

3. Greedy category diversity: iterate shuffled, insert first template of each unseen category until `count` reached.

4. For each selected template:
   - Call `build_challenge_from_template(template, rng, level, date)`
   - Scaling formula: `scaled = base * level_multiplier * (1 + level * 0.05)`
   - Add ±10% randomness via `rng.gen_range(-variance, variance+1)`
   - Clamp to `[min_target, max_target]`
   - Create `Challenge::with_category()` with `ChallengeType::Streak(scaled)`
   - Set `expires_at = Some(date)` (end-of-day marker)

5. Return `Vec<Challenge>` (no DB interaction; caller persists).

---

## Remaining Phase 2 Tasks

### 2.3 — Weekly Challenges (incomplete)

**Implementation:**
- Add `WeeklyTemplate` struct mirroring `Template` plus `day_of_week: u32` (Monday=1)
- In `Engine::generate_daily()`:
  ```rust
  if date.weekday() == Weekday::Mon {
      // pick 1–2 weekly templates from a separate static array
  }
  ```
- Store in separate DB table or prefix title with "[Weekly]" and extend `expires_at` by 7 days.

**XP scaling:** Weekly rewards should be 2×–3× daily to justify focus cost.

### 2.4 — Random Events (events.rs — not started)

**Proposed API:**
```rust
pub struct Event { /* ... */ }
pub enum EventType { BonusXP, ChallengeRush, MysteryBox, GridStorm }

impl Engine {
    pub fn check_events(&mut self, today: NaiveDate, state: &PlayerState) -> Vec<Event> { /* … */ }
}
```

**Triggers (priority order):**
1. **Streak milestone** — every 7 days streak → `BonusXP(mult=1.25, 24h)`
2. **XP threshold** — crossing 100, 500, 1000 total XP → `MysteryBox(achievement_id)`
3. **Daily chance** — 1% roll each midnight → `GridStorm(freeze_streaks_24h)`
4. **Activity burst** — complete 3+ habits in one day → `ChallengeRush(req=2, bonus=50)`

**Storage:** In-memory active events; expired ones pruned at rollover. Persistent storage unnecessary for MVP.

**Flutter UI:** Toast notification in `HomeScreen` when `events` array non-empty in `/progression` response.

### 2.5 — Challenge Completion UI (Flutter side incomplete)

Rust already has `ChallengeEngine::progress_challenge(challenge_id, amount)`. Flutter must call it via new endpoint:

**New endpoint needed** `POST /challenges/{id}/progress` (not yet implemented):
```rust
// server/src/main.rs
.route("/challenges/{id}/progress", post(progress_challenge))

async fn progress_challenge(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    JsonReq(body): JsonReq<{ amount: u32 }>,
) -> (StatusCode, JsonReq<Challenge>) { /* … */ }
```

Or simpler: `POST /challenges/{id}/complete` to instantly complete (for now). Add to server.

Flutter: `ChallengeCardWidget` gets an onComplete callback → call API → refresh state.

---

## Integration Points with Flutter

| Rust type | JSON form | Dart type (suggested) |
|-----------|-----------|-----------------------|
| `NaiveDate` | `"2026-05-14"` | `DateTime` (parse with `DateFormat('yyyy-MM-dd')`) |
| `Uuid` | `"a1b2..."` | `String` |
| `ChallengeType::Streak(n)` | `{"Streak": 15}` | `Map<String, int>` or dedicated `ChallengeType` class |
| `Difficulty::Easy` | `"Easy"` | `enum Difficulty { easy, medium, hard, extreme }` |

**User ID propagation:** For seeded challenges, Flutter must provide `user_id` header `X-User-Id` (or query param). Server reads it in `Engine::generate_daily()` → RNG seed stable per user. Fix: store UUID in SharedPreferences on first launch, attach to all requests via Dio interceptor.

---

## Debugging Tips

- **Challenges not appearing?** Check server logs — `last_generated` persists in-memory; restarting server regenerates. Persist in DB if needed.
- **Same challenge every day?** Verify `rng.rs` seed includes both date AND user_id. Hash collision across different dates unlikely.
- **Flutter not getting updates?** Ensure API base URL is `http://localhost:3000` and server running. Use `adb reverse tcp:3000 tcp:3000` for Android emulator.
- **Thread panic in server?** `DatabaseClient` is `Send + Sync`; wrap in `Arc<Mutex<>>` before sharing across Axum state.

---

## Future: Phase 3 Hooks

The rules engine (`crates/rules/`) will later modify `generate_daily()` to:
- Filter templates by user preference (excluded categories)
- Boost weight for templates that complement recent habits
- Inject rule-derived challenges (e.g., "You meditated 3 days — try 10-minute session")

Hook point: after diversity selection, before `build_challenge_from_template()`.

---

*Keep it neon. Keep it deterministic.* 🎹🦞
