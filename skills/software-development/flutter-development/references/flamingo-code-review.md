# Flamingo Code Review Patterns

Session-specific detail for reviewing Flutter multi-tool app code quality.

## Quality Assessment Framework

When reviewing Flutter code from step-flash agents or other developers, use this structured approach:

### 1. Build Verification (First Pass)
- `flutter analyze --fatal-warnings` — check for actual errors, not just style lints
- `flutter build apk --debug` — verify native code compiles (Kotlin/Java side)
- Zero errors required. Info-level style hints (prefer_interpolation, non_constant_identifier_names) are acceptable noise.

### 2. File-by-File Review Checklist

#### Correctness
- Does the code handle the platform channel correctly? (try/catch on PlatformException, null-safe)
- Are sensor readings properly smoothed? (EMA with wrap-around handling for compass/magnetometer)
- Is dispose called to clean up resources? (CameraController, Timer, MediaPlayer)
- Are `mounted` checks present before setState after async operations?

#### Edge Cases
- What happens when the sensor is unavailable?
- What happens when the platform channel is missing?
- Does the app gracefully degrade (vibration-only when sound channel missing)?
- Does it handle Android lifecycle events properly?

#### Architecture
- Are platform channels well-separated (BatteryChannel helper, not inline)?
- Are CustomPainters properly encapsulated with shouldRepaint?
- Is the router pattern consistent (switch-case on toolId)?

### 3. Kotlin Native Bridge Checklist

- `import android.os.BatteryManager` — REQUIRED for BATTERY_PROPERTY_TEMPERATURE
- MethodChannel names must match exactly between Dart and Kotlin
- `onDestroy()` should clean up MediaPlayer/Ringtone instances
- `try/catch` on `invokeMethod` from Dart side is mandatory (channel may be missing in CI/dev)

### 4. Common Flamingo-Specific Issues

| Issue | File | Severity |
|-------|------|----------|
| Missing `BatteryManager` import | MainActivity.kt:88 | BLOCKER |
| No pinch-to-zoom gesture detector (says "Pinch to zoom") | magnifier_screen.dart:145 | MINOR |
| Missing `@override` on dispose | timer_screen.dart:134 | LINT |
| `_setA_count` violates lowerCamelCase | dice_roller_screen.dart:20 | LINT |
| Calculator has most curly-brace lint warnings | calculator_screen.dart | LINT |
| Camera setZoomLevel Future not awaited | magnifier_screen.dart:176 | ACCEPTABLE (plugin limitation) |

### 5. Verdict Scale

- **🔥 Cooked (Top-shelf):** Compiles clean, handles edge cases, no blocking issues. Style lints only.
- **🥬 Cooked Cabbage:** Solid core, but has real issues (build breakers, missing features). Needs fixes before ship.
- **🗑️ Cooked Garbage:** Fundamental architecture problems, non-compiling, wrong API patterns.

### 6. Flamingo Architecture Notes

- 18 tools total, split across Tier 1 (active), Tier 2 (coming soon), Tier 3 (coming soon)
- AppRouter uses GoRouter with switch-case routing
- Tool icons duplicated in both AppConstants and AppRouter (DRY violation — should use one source)
- All tools follow identical Scaffold + CrtBackground pattern
- Custom painters use shouldRepaint with old.field != new.field (correct Flutter pattern)
