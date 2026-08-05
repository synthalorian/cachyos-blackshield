# Challenge Progression Endpoint — Implementation Notes

**Endpoint:** `POST /challenges/{id}/progress`  
**Purpose:** Progress a specific challenge by 1 unit and persist all active challenges.

---

## Server Handler

**File:** `crates/server/src/main.rs`

```rust
async fn progress_challenge(
    State(state): State<Arc<Mutex<AppState>>>,
    Path(challenge_id): Path<uuid::Uuid>,
) -> (StatusCode, Json<JsonReq<Challenge>>) {
    let mut state = state.lock().unwrap();
    let engine = &mut state.engine;

    // Progress the challenge by 1
    let progressed = engine.progress_challenge(challenge_id, 1);

    // Persist all active challenges after mutation
    let challenges = engine.active_challenges();
    if state.db.save_challenges(&challenges).is_err() {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            JsonReq(serde_json::json!({"error": "Failed to persist challenges"})),
        );
    }

    // Return the updated challenge if found
    if let Some(challenge) = engine
        .active_challenges()
        .into_iter()
        .find(|c| c.id == challenge_id)
    {
        (StatusCode::OK, JsonReq(Json(challenge)))
    } else {
        (StatusCode::NOT_FOUND, JsonReq(serde_json::json!({"error": "Challenge not found"})))
    }
}
```

---

## Database Layer

**Command:** `SaveChallenges`  
**Client method:** `DatabaseClient::save_challenges(&self, challenges: &[Challenge]) -> Result<()>`

**Implementation (`db/src/lib.rs`):**
```rust
#[derive(Debug)]
enum DbCommand {
    SaveChallenges { challenges: Vec<Challenge> },
    // … other commands
}

// In message loop:
SaveChallenges { challenges } => {
    let conn = &mut *self.conn.lock().unwrap();
    let tx = conn.transaction().unwrap();
    for challenge in challenges {
        tx.execute(
            "INSERT OR REPLACE INTO challenges (id, title, description, type, status, progress, target, xp_reward, category, expires_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params!(
                challenge.id,
                challenge.title,
                challenge.description,
                // serialize ChallengeType as string
                serde_json::to_string(&challenge.challenge_type).unwrap(),
                format!("{:?}", challenge.status), // Active/Completed/Failed
                challenge.progress,
                challenge.target,
                challenge.xp_reward,
                challenge.category,
                challenge.expires_at.map(|d| d.to_string())
            ),
        ).unwrap();
    }
    tx.commit().unwrap();
    resp.send(Ok(()));
}
```

---

## Gamification Engine Fix

### `ChallengeEngine::active_challenges` (fixed)

**Before (broken):**
```rust
pub fn active_challenges(&self) -> Vec<Challenge> {
    self.challenges
        .active_challenges()  // ERROR: `Vec<Challenge>` has no method `active_challenges`
        .into_iter()
        .cloned()
        .collect()
}
```

**After (correct):**
```rust
pub fn active_challenges(&self) -> Vec<Challenge> {
    self.challenges
        .iter()
        .filter(|c| c.status == ChallengeStatus::Active)
        .cloned()
        .collect()
}
```

### `GamificationEngine::active_challenges` (added)

```rust
/// Get all active challenges (for persistence).
pub fn active_challenges(&self) -> Vec<Challenge> {
    self.challenges.active_challenges()
}
```

---

## Route Registration

**File:** `crates/server/src/main.rs` (within `Router::new()`)

```rust
router = router.post(
    "/challenges/{id}/progress",
    handler::progress_challenge,
);
```

---

## Root Cause Analysis

**Compiler error:**
```
error[E0599]: no method named `active_challenges` found for struct `Vec<Challenge>` in the current scope
```

**Cause:** `ChallengeEngine` stores challenges in `challenges: Vec<Challenge>`. The original `active_challenges()` implementation incorrectly tried to delegate to a non-existent `Vec::active_challenges()` method, creating infinite recursion if it had compiled. The correct approach is to iterate the vector and filter by `ChallengeStatus::Active`.

**Pattern:** Struct-field delegation requires mapping over the field; you cannot forward method calls directly unless the field's type already implements a trait with that method (e.g., `self.challenges.iter()` is valid because `Vec::iter` exists).

---

## Related Tests

- `gamification::tests::test_challenge_generation_easy` — generates and checks active count
- `gamification::tests::test_full_completion_flow` — exercises `complete_habit` which now persists challenges
- `server::tests` — manual curl validation recommended

---

**Last updated:** Session continuing open_habit development, 2026-05-14.
