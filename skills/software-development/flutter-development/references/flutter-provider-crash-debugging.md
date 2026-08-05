# Flutter Provider/Service Crash Debugging

## Pattern: Uninitialized Singleton on Navigation

### Symptom
Navigating to a specific screen (e.g., Settings) produces a full red error screen or Flutter exception. Other screens work fine.

### Root Cause
The crashed view depends on a provider or service that accesses an uninitialized singleton. The singleton happens to not be accessed until that specific screen is navigated to, so the crash only manifests there.

### Debugging Chain
Trace the view's dependency chain backwards:

```
View → Provider build() → Service.client → Singleton.instance
```

1. **View**: What providers does the view `ref.watch()` or `ref.read()`?
2. **Provider build()**: What does the provider's `build()` method access?
3. **Service.client**: Is the service calling a static singleton getter (e.g., `Supabase.instance.client`)?
4. **Singleton.instance**: Was the singleton's `initialize()` or `init()` EVER called in main.dart?

### Common Culprits
- `Supabase.instance.client` without `Supabase.initialize()` being called in `main()`
- `Firebase.initializeApp()` not called
- Hive box accessed with `Hive.box()` before `Hive.openBox()` completes
- Database client created lazily but never configured

### Fix Pattern
**Option A: Initialize in main.dart** — Add the missing `initialize()` call before `runApp()`.

**Option B: Graceful degradation** — Wrap the provider's `build()` in try/catch and return a sensible default (null, empty list, fallback object):

```dart
@override
User? build() {
  try {
    return SyncService.client.auth.currentUser;
  } catch (_) {
    return null;  // view checks for null and shows login form
  }
}
```

### Theme Refactoring Bugs

When converting a single-theme app to a multi-theme system via `ThemeExtension<AppColors>`, these specific bugs appear:

1. **Hardcoded Colors.* values** in views that were only tested on one theme. Common offenders: `Colors.white`, `Colors.black`, `Colors.grey`, `Colors.transparent`. Fix: replace with `appColors.surface`, `appColors.textDim`, or a context-aware color.

2. **Theme.of(context).scaffoldBackgroundColor** bypasses the appColors system entirely. Fix: use `appColors.surface` instead.

3. **extendBodyBehindAppBar + hardcoded padding** — content clips behind the app bar on devices with different status bar heights. Fix: use `MediaQuery.of(context).padding.top + kToolbarHeight` instead of a fixed px value.

4. **Missing assets** referenced in data files (SVGs, images) but not present in the assets directory. Fix: create the assets or add a placeholder fallback.
