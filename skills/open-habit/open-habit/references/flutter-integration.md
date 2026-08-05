# Flutter → Rust Integration — Actual Architecture

This documents the integration pattern currently shipped in open_habit (as of May 2026).

---

## Architecture Overview

```
┌──────────────────────────────────┐
│  Flutter UI                      │
│  ┌──────────────────────────┐   │
│  │  app_state.dart (UI)     │   │
│  │  • Habit (simplified)    │   │
│  │  • AppChallenge          │   │
│  │  • AppData               │   │
│  └──────────────────────────┘   │
│         ↕ conversion            │
│  ┌──────────────────────────┐   │
│  │  models.dart (API)       │   │
│  │  • Habit (fromJson +    │   │
│  │    toJson mirror Rust)   │   │
│  │  • CompletionResponse    │   │
│  │  • ProgressionResponse   │   │
│  └──────────────────────────┘   │
│         ↕ HTTP                  │
│  ┌──────────────────────────┐   │
│  │  api_client.dart         │   │
│  │  (REST calls via `http`  │   │
│  │   package)               │   │
│  └──────────────────────────┘   │
└──────────────────────────────────┘
         ↕ JSON over localhost:3000
┌──────────────────────────────────┐
│  Rust Axum Server                │
│  • POST /habits/{id}/complete    │
│  • GET /progression              │
│  • GET /challenges               │
│  • POST /challenges/{id}/progress│
└──────────────────────────────────┘
```

## Key Design Decisions

### http over dio
We use `package:http` instead of `dio`. Simpler API, fewer transitive dependencies. For MVP, we don't need interceptors, retry logic, or request transformers. If logging becomes necessary, wrap calls in a helper.

### Riverpod v3 Notifier (not StateNotifier)
```
class HabitNotifier extends Notifier<AppData> { … }
final habitProvider = NotifierProvider<HabitNotifier, AppData>(…);
```
- Synchronous initial state (`AppData.empty()`)
- Async load triggered in `build()` — loads from backend on first access
- No `AsyncValue` wrapper: state is always `AppData` (initially empty, refreshed dynamically)
- On failure, falls back to `AppData.initial()` mock data

### Two model layers
**API models** (`models.dart`):
- Snake_case field names mirroring Rust `serde` JSON
- `fromJson`/`toJson` serialization
- Include response DTOs: `CompletionResponse`, `ProgressionResponse`

**UI models** (`app_state.dart`):
- CamelCase, no serialization
- `copyWith` for immutable updates
- Simplified fields appropriate for rendering
- Includes `Recommendation`, `AppChallenge`

**Provider converts between them** — keeps serialization concerns out of widgets.

### Response DTO re-export
`CompletionResponse` and `ProgressionResponse` are defined in `models.dart`. They're re-exported from `api_client.dart` so consumers only need one import:
```dart
// In api_client.dart:
export '../models/models.dart' show CompletionResponse, ProgressionResponse;
```

---

## Provider Loading Pattern

```dart
class HabitNotifier extends Notifier<AppData> {
  final ApiClient _api = ApiClient();
  bool _initialized = false;

  @override
  AppData build() {
    if (!_initialized) {
      _initialized = true;
      state = AppData.empty();
      _loadFromBackend();
    }
    return state;
  }

  Future<void> _loadFromBackend() async {
    try {
      final results = await Future.wait([
        _api.fetchHabits(),
        _api.fetchProgression(),
        _api.fetchChallenges(),
        _api.fetchStreaks(),
      ]);
      // ...convert and set state...
    } catch (e) {
      if (state.habits.isEmpty) state = AppData.initial();
    }
  }
}
```

Uses `Future.wait` to load all data in parallel. Single catch-all for fallback.

---

## Completion Feedback Flow

```
User taps habit → HabitNotifier.toggleHabit(id)
  → ApiClient.completeHabit(id)
    → POST /habits/{id}/complete
    ← CompletionResponse (xp, streak, achievements, level up)
  → _refresh() (reload all state)
  ← returns CompletionResponse to UI
```

Dashboard shows a rich AlertDialog with:
- Base XP, streak bonus, achievement XP breakdown
- "LEVEL UP!" in gold if levelled
- List of newly unlocked achievements with icons

Habits tab shows a compact SnackBar: "+25 XP! 🏆"

---

## Android Emulator Networking

On the Android emulator, `localhost` refers to the emulator itself, not the host. Use `10.0.2.2` instead:
```dart
// In ApiConfig:
static const String baseUrl = 'http://10.0.2.2:3000';  // Android emulator
static const String baseUrl = 'http://localhost:3000';  // Desktop
```

For production, detect at runtime:
```dart
import 'dart:io' show Platform;
static String get baseUrl =>
    Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
```

---

## File Structure (as shipped)

```
flutter_app/lib/
├── models/
│   ├── app_state.dart      ← UI models (no serialization)
│   └── models.dart         ← API models (fromJson/toJson)
├── providers/
│   ├── habit_provider.dart ← State + API calls
│   └── theme_provider.dart ← ThemeState
├── screens/
│   ├── home_screen.dart     ← Navigation shell only
│   ├── dashboard_screen.dart
│   ├── habits_screen.dart
│   ├── challenges_screen.dart
│   ├── stats_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── neon_widgets.dart
│   ├── habit_card.dart
│   ├── challenge_card.dart
│   ├── stat_card.dart
│   ├── recommendation_card.dart
│   └── section_header.dart
├── services/
│   └── api_client.dart
└── main.dart
```
