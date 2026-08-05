# Android Home Screen Widget Pitfalls (open_habit)

## Stack

- `home_widget` 0.7.0 (Dart plugin, wraps Android `AppWidgetProvider`)
- 4 Kotlin providers in `com.synthwave.open_habit.widgets` subpackage
- XML layouts in `res/layout/`, widget info in `res/xml/`
- Background drawable in `res/drawable/widget_background.xml`

---

## PITFALL 1: `<View>` Not Allowed in RemoteViews (Android 15+)

**Symptom:** Widget shows "Problem loading widget" with logcat error:
```
android.view.InflateException: Binary XML file line #N: Error inflating class android.view.View
Caused by: Class not allowed to be inflated android.view.View
```

**Root cause:** Android 15 restricts RemoteViews inflation to a limited set of view classes. `<View>` (plain android.view.View) is NOT in the allowlist. This applies to:
- Divider lines `<View android:layout_width="match_parent" android:layout_height="1dp" android:background="..." />`
- Progress bar fills `<View android:id="@+id/xp_bar_fill" ... />`

**Fix:** Replace ALL `<View>` elements with `<TextView>` equivalents:
- Dividers: `<TextView android:layout_width="match_parent" android:layout_height="1dp" android:background="..." />`
- Fill bars: `<TextView android:id="@+id/xp_bar_fill" android:layout_width="wrap_content" android:layout_height="match_parent" android:background="..." android:text="" />`

**Proactive check:** `grep -n "<View" res/layout/widget_*.xml` — if any match, they MUST be replaced.

---

## PITFALL 2: `HomeWidgetLaunchIntent` Crashes on Android 15

**Symptom:** Widget receiver crashes immediately with:
```
java.lang.IllegalArgumentException: pendingIntentBackgroundActivityStartMode must not be set when creating a PendingIntent
```

**Root cause:** `HomeWidgetLaunchIntent.getActivity()` in `home_widget 0.7.0` uses `ActivityOptions.pendingIntentBackgroundActivityStartMode` which was removed in Android 15 (API 35).

**Fix:** Do NOT use `HomeWidgetLaunchIntent.getActivity()`. Instead, create a safe PendingIntent directly:

```kotlin
private fun safeLaunchIntent(context: Context, uri: String, cls: Class<*>): PendingIntent {
  val intent = Intent(context, cls)
  intent.data = Uri.parse(uri)
  intent.action = "es.antonborri.home_widget.action.LAUNCH"
  return PendingIntent.getActivity(
    context,
    0,
    intent,
    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
  )
}

// Usage:
setOnClickPendingIntent(R.id.widget_container,
    safeLaunchIntent(context, "openhabit://dashboard", MainActivity::class.java))
```

---

## PITFALL 3: R Class Not Found in Subpackage

**Symptom:** Kotlin compilation error: `Unresolved reference 'R'` in widget providers.

**Root cause:** The R class is generated in `com.synthwave.open_habit` package. Kotlin files in subpackages (`com.synthwave.open_habit.widgets`) need an explicit import.

**Fix:**
```kotlin
import com.synthwave.open_habit.R
```

The existing `import com.synthwave.open_habit.R` is needed in every widget provider file.

---

## PITFALL 4: Widget Data Not Yet Available

**Symptom:** On first widget placement, no data has been pushed to SharedPreferences yet. The widget shows empty/default state.

**Pattern:** Always provide default values:
```kotlin
val data = widgetData.getString("oh_widget_xp", "{}") ?: "{}"  // empty JSON object
val statsJson = widgetData.getString("oh_widget_stats", "[]") ?: "[]"  // empty JSON array
```

Use `optInt`/`optString`/`optBoolean` (not `getInt`/`getString`) on JSONObject to default gracefully.

---

## PITFALL 5: Background Interactivity Crashes

**Symptom:** Tapping a habit toggle on the widget either does nothing or crashes.

**Root cause:** The `HomeWidgetBackgroundIntent.getBroadcast()` works fine on all Android versions (it's a broadcast, not an activity intent). But the Dart callback must be registered at app startup.

**Fix:** Register in `main()` BEFORE `runApp`:
```dart
WidgetsFlutterBinding.ensureInitialized();
HomeWidget.registerInteractivityCallback(WidgetDataService.backgroundCallback);
```

The callback must be a top-level or static function annotated with `@pragma('vm:entry-point')` to prevent tree-shaking.

---

## PITFALL 6: Crash Silencing with try-catch

Always wrap widget `onUpdate` body in try-catch with `Log.e()` to capture any runtime issues that would otherwise show "Problem loading widget" with no diagnostic:

```kotlin
companion object {
  private const val TAG = "OHQuickToggle"
}

override fun onUpdate(...) {
  try {
    // ... widget logic ...
  } catch (e: Exception) {
    Log.e(TAG, "Widget update failed", e)
  }
}
```

This writes to logcat via `adb logcat -s "TAG:*"` so you can diagnose without recompiling.

---

## Anatomy of a Widget Provider

```kotlin
class QuickToggleWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    try {
      // 1. Read JSON from widgetData (home_widget's SharedPreferences)
      val json = widgetData.getString("oh_widget_habits", "[]") ?: "[]"
      val items = JSONArray(json)

      appWidgetIds.forEach { widgetId ->
        // 2. Create RemoteViews from the layout
        val views = RemoteViews(context.packageName, R.layout.widget_foo).apply {
          // 3. Set text, visibility, click handlers
          setTextViewText(R.id.some_text, "Hello")
          setViewVisibility(R.id.some_view, View.VISIBLE)
          setOnClickPendingIntent(R.id.container, safeLaunchIntent(...))
        }

        // 4. Push to the widget host
        appWidgetManager.updateAppWidget(widgetId, views)
      }
    } catch (e: Exception) {
      Log.e(TAG, "Widget update failed", e)
    }
  }
}
```
