# Rust ↔ Dart Type Mapping

## Rust `Habit` (from `open_habit_shared`)

```rust
pub struct Habit {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub category: String,
    pub difficulty: Difficulty,   // enum: Easy, Medium, Hard
    pub frequency: Frequency,     // enum: Daily, Weekly, Monthly
    pub status: HabitStatus,      // enum: Active, Paused, Completed
    pub created_at: NaiveDate,
    pub last_completed: Option<NaiveDate>,
    pub current_streak: i32,
    pub best_streak: i32,
    pub total_completions: i32,
    pub xp_reward: i32,
}
```

## Dart `Habit` (UI model in `lib/models/models.dart`)

```dart
class Habit {
  final String id;
  final String name;
  final String? description;
  final String category;
  final Difficulty difficulty;
  final Frequency frequency;
  final HabitStatus status;
  final DateTime created_at; // stored as YYYY-MM-DD (no time)
  final DateTime? last_completed;
  final int current_streak;
  final int best_streak;
  final int total_completions;
  final int xp;

  bool get completed => last_completed != null && isSameDay(last_completed, today);
}
```

## Enums: Capitalized string serialization

Rust enums serialize as `"Easy"`, `"Daily"`, `"Active"`.

Dart side helpers:

```dart
enum Difficulty { easy, medium, hard }
String capitalizeEnum(Difficulty d) => d.name.capitalize(); // "Easy"

Difficulty fromString(String s) => Difficulty.values.firstWhere(
  (e) => e.name.capitalize() == s,
  orElse: () => Difficulty.easy,
);
```

Same pattern for `Frequency` (`daily`, `weekly`, `monthly`) and `HabitStatus` (`active`, `paused`, `completed`).

## Date handling

- Storage: `YYYY-MM-DD` strings (no time component).
- Dart format helper:

```dart
String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
```

- Comparison for completion:

```dart
bool isSameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;
```

## JSON keys

Use `@JSONKey(name: 'snake_case_field')` on each Dart field so `toJson()`/`fromJson()` emit/consume exactly what Rust expects.
