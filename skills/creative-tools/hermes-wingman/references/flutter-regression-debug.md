# Flutter Regression Debug — "It Was Working Before"

Session: 2026-06-01 — Hermes Wingman mobile app reported as "working before, now black screen."

## The Mistake
When the user said "the app was working at one point," the agent chased rabbit holes for 20+ minutes:
- Upgraded Flutter stable → 3.44.0
- Switched to Flutter beta → 3.45.0-0.1.pre
- Disabled Impeller in AndroidManifest.xml
- Reverted git commits one by one
- Checked gralloc5, device lock state, LAN scanning

**Never checked `git log` and `git diff` to see what actually changed.**

## The Lesson

When a user reports a regression ("it was working, now it's not"):

1. **LISTEN FIRST.** The user knows the history. Ask: "When did it last work? What changed since then?"
2. **Check git history IMMEDIATELY** — before touching the toolchain, device, or code:
   ```bash
   git log --oneline -10
   git diff <last-known-good>..HEAD --stat
   git diff <last-known-good>..HEAD -- pubspec.yaml android/
   ```
3. **Common regression sources:**
   - New native plugin added to pubspec.yaml
   - AndroidManifest.xml changes (permissions, metadata)
   - Gradle or Kotlin plugin upgrades
   - Flutter SDK version changed
   - Code changes that add platform-specific behavior
4. **Only after ruling out code changes** should you look at:
   - Device state (locked, dozing)
   - Flutter engine issues (gralloc5, Impeller)
   - Toolchain problems

## User Preference

**synth gets frustrated when agents ignore their direct knowledge and chase diagnostic rabbit holes.** When they say "it was working," that is the primary signal — not a secondary detail to be validated after 10 other checks.
