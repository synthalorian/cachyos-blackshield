# Riverpod Notifier Pattern with API Backend

## State notifier skeleton

```dart
final habitProvider = NotifierProvider<HabitNotifier, AppData>(HabitNotifier.new);

class HabitNotifier extends Notifier<AppData> {
  late final ApiClient _api;
  bool _initialized = false;

  @override
  AppData build() {
    _api = ApiClient(); // or inject via ref.read
    if (!_initialized) {
      _initialized = true;
      _loadFromBackend();
    }
    return AppData.empty();
  }

  Future<void> _loadFromBackend() async {
    final habits = await _api.fetchHabits();
    final progression = await _api.fetchProgression();
    state = state.copyWith(habits: habits, totalXp: progression.totalXp, level: progression.level);
  }

  Future<void> _refresh() async {
    await _loadFromBackend();
  }

  // Optimistic add for recommendations
  Future<void> addRecommendationAsHabit(Recommendation r) async {
    final placeholder = r.toUiHabit(); // create Habit object locally
    state = state.copyWith(habits: [...state.habits, placeholder]);
    try {
      await _api.createHabit(placeholder);
      await _refresh();
    } catch (_) {
      await _refresh(); // rollback on error
    }
  }
}
```

## Key points

- `_initialized` guard prevents double-fetch on provider rebuilds (Riverpod may rebuild multiple times).
- Convert API model to UI model inside `_loadFromBackend` or via `_toUiHabit()` helper.
- Mutating methods (`toggleHabit`, `addHabit`, `deleteHabit`) should:
  1. Call API (`await`)
  2. Call `_refresh()` to re-sync full state (ensures computed fields like `completed` are accurate)
- For immediate feedback (recommendations), optimistically update state before API call, then reconcile with `_refresh()` on error.
- Never mutate `state` directly without copying: `state = state.copyWith(field: newValue)`.
- Show snackbars or error UI in the widget layer, not inside the notifier.

## Debugging

If habits don't appear:
- Verify backend running: `curl http://localhost:3000/habits`
- Check Flutter debug console for JSON parsing errors (often mismatched enum casing or date format).
- Ensure `models.dart` uses `@JSONKey()` with exact snake_case names matching Rust struct fields.
