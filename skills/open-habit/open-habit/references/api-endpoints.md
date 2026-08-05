# open_habit REST API Reference

Base URL: `http://localhost:3000`

All endpoints return JSON. Errors are HTTP status codes with `{"error": "msg"}` body.

---

## Habits

### `GET /habits`
List all active habits.

**Response:** `[Habit]`  
**Example:**
```json
[
  {
    "id": "a1b2c3...",
    "name": "Meditate",
    "description": null,
    "category": "Mindfulness",
    "difficulty": "Easy",
    "frequency": "Daily",
    "status": "Active",
    "created_at": "2026-05-10",
    "last_completed": "2026-05-14",
    "current_streak": 5,
    "best_streak": 12,
    "total_completions": 42,
    "xp_reward": 10
  }
]
```

### `POST /habits`
Create a new habit.

**Body:** `Habit` (id optional; server generates if missing)  
**Response:** `201 Created` + created `Habit`

### `GET /habits/{id}`
Fetch single habit.

**Response:** `200 OK` + `Habit` or `404 Not Found`

### `PUT /habits/{id}`
Partial update. Supply only fields to change.

**Body:** `{ "name": "...", "description": "...", "status": "..." }`  
**Response:** `200 OK` + updated `Habit`

### `DELETE /habits/{id}`
Delete habit.

**Response:** `204 No Content`

### `POST /habits/{id}/complete`
Mark habit complete for today. Triggers XP award, streak update, achievement check.

**Response:** `200 OK` + result object:
```json
{
  "xp_awarded": 10,
  "bonus_xp": 5,
  "achievement_xp": 0,
  "total_xp": 15,
  "streak": 6,
  "levelled_up": [2],
  "new_achievements": []
}
```

---

## Progression

### `GET /progression`
Player state + engine snapshot.

**Response:**
```json
{
  "total_xp": 1540,
  "level": 7,
  "xp_to_next": 320,
  "streaks": [
    {"habit_id": "...", "count": 5, "is_active": true}
  ],
  "database": {
    "total_xp": 1540,
    "level": 7,
    "xp_to_next": 320
  }
}
```

---

## XP & Achievements

### `POST /xp/record`
Manual XP award (debug / bonuses).

**Body:** `{ "amount": 50 }`  
**Response:** `200 OK` + `{ "status": "recorded", "amount": 50 }`

### `GET /achievements`
List all achievements with unlock status.

**Response:** `[Achievement]`
```json
[
  {
    "id": "...",
    "title": "On Fire",
    "description": "Reach a 7-day streak on any habit",
    "icon": "🔥",
    "xp_reward": 50,
    "category": "Beginner",
    "unlocked": true,
    "unlocked_at": "2026-05-14",
    "level_requirement": 1
  }
]
```

---

## Streaks

### `GET /streaks`
Active streaks from the gamification engine.

**Response:** `[Streak]`
```json
[
  {
    "habit_id": "...",
    "count": 5,
    "started_at": "2026-05-10",
    "last_date": "2026-05-14",
    "is_active": true
  }
]
```

---

## Challenges

### `GET /challenges`
Current active challenges (populated by the procedural generator).

**Response:** `[Challenge]`
```json
[
  {
    "id": "...",
    "title": "Push-up Set",
    "description": "Complete a set of push-ups. Form matters more than speed.",
    "challenge_type": {"Streak": 15},
    "status": "Active",
    "progress": 8,
    "target": 15,
    "xp_reward": 25,
    "category": "physical",
    "expires_at": "2026-05-14",
    "completed_at": null
  }
]
```

**Note:** The server's `ChallengeEngine` auto-regenerates challenges at midnight via `last_generated` date check. There is no `POST /challenges` endpoint — challenges are generated server-side.

---

## Types

All dates are ISO 8601 strings `YYYY-MM-DD` (no timezone). UUIDs are hyphenated strings without braces.

Enums serialize as:
- `Difficulty` → `"Easy"`, `"Medium"`, `"Hard"`, `"Extreme"`
- `ChallengeType` → `{"Streak": 10}`, `{"Total": 50}`, `{"CategoryBurst": "fitness"}`, `{"LongStreak": 30}`
- `ChallengeStatus` → `"Active"`, `"Completed"`, `"Failed"`
- `HabitStatus` → `"Active"`, `"Archived"`, `"Completed"`

---

## Error Handling

Standard HTTP codes:

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 204 | No Content (delete) |
| 400 | Bad request (malformed JSON) |
| 404 | Not found |
| 500 | Server error (DB down, etc.) |

Errors return `{ "error": "human readable" }`.

---

## CURL Quick Reference

```bash
# List habits
curl http://localhost:3000/habits

# Create habit
curl -X POST http://localhost:3000/habits \
  -H "Content-Type: application/json" \
  -d '{"name":"Read","category":"Learning","difficulty":"Medium","frequency":"Daily","xp_reward":25}'

# Complete habit
curl -X POST http://localhost:3000/habits/<id>/complete

# Get progression
curl http://localhost:3000/progression

# List challenges
curl http://localhost:3000/challenges

# List streaks
curl http://localhost:3000/streaks
```

---

## Server Configuration

- **Address:** binds to `0.0.0.0:3000` (all interfaces) — change `server/src/main.rs` line 61 to `127.0.0.1:3000` for localhost-only
- **Database path:** `data/open_habit.db` relative to CWD. Ensure `data/` dir exists or server will fail open.
- **Logging:** `tracing` subscriber; set `RUST_LOG=debug` for verbose.
