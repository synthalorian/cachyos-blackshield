# API Endpoints (Rust Axum backend)

Base URL (dev): `http://localhost:3000`

## Habits
- `GET /habits` → `Vec<Habit>`
  - Returns all habits with current streak, best streak, total completions, last_completed date.
- `POST /habits` (JSON body) → `Habit`
  - Creates a new habit. Body includes: `id`, `name`, `description`, `category`, `difficulty` (string), `frequency` (string), `status` (string), `created_at`, `xp_reward`.
- `POST /habits/{id}/complete` → Completion result (XP earned, new streak info)
  - Marks habit complete for today. Updates last_completed, current_streak, total_completions, and awards XP.
- `DELETE /habits/{id}` → status 204
  - Removes habit.

## Progression
- `GET /progression` → `PlayerProgression { total_xp, level, xp_to_next }`
  - Global player progression across all habits.

## Other (exists but not yet wired)
- `GET /achievements` → `Vec<Achievement>`
- `GET /streaks` → `Vec<Streak>`
- `GET /challenges` → `Vec<Challenge>`
- `POST /xp/record` → records bonus XP events

## Notes
- All dates are `YYYY-MM-DD` strings.
- Enums (`difficulty`, `frequency`, `status`) are capitalized strings (`Easy`, `Daily`, `Active`).
- IDs are UUID v4 strings.
- Database is SQLite at `data/open_habit.db`.
