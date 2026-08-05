# Flutter Theme / Palette Audit

Use this checklist when the user reports "wrong colors," "colors don't change when switching themes," or "assets missing" after a multi-theme refactor or theme system overhaul.

## Phase 1: Audit the Theme Definitions

Start at the source:

1. **Read `app_theme.dart`** — Check that each `AppColors` palette has all 12+ semantic fields populated (`surface`, `card`, `accent`, `accentSecondary`, `accentTertiary`, `gridColor`, `textDim`, `success`, `warning`, `danger`, `glowColor`, `sectionHeader`).
2. **Check `theme_provider.dart`** — Ensure `appColorsProvider` returns `AppTheme.build(theme).extension<AppColors>()!` (not hardcoded).
3. **Check `main.dart`** — Ensure `MaterialApp(theme: theme)` watches the correct provider and passes it.

## Phase 2: Search Views for Hardcoded Colors

The most common source of "colors don't change" bugs — views that still use `Colors.<name>` instead of `appColors.<field>`:

```bash
# Find ALL hardcoded Colors.* usage outside theme definition files
search_files("Colors\\.", path="lib/", file_glob="*.dart")  # filtered by removing app_theme.dart from results
```

**HIGH-RISK targets in order:**
- Button foreground colors: `foregroundColor: Colors.black` or `Colors.white` — won't adapt to theme. Fix: use `Colors.white` (universal on dark-themed accent/success buttons) or `appColors.surface`.
- `hintStyle: TextStyle(color: Colors.grey)` — fix to `appColors.textDim`.
- Widget default card colors: `color: Colors.white.withValues(alpha: 0.05)` — invisible on Light theme. Fix: `Theme.of(context).cardColor`.
- Search bar / search delegate themes: `Theme.of(context).copyWith(inputDecorationTheme: ...)` — often hardcode colors.
- `Colors.transparent` → usually OK (it's alpha=0, no hue).
- Default constructor params → `this.color = Colors.cyan` — overridden by caller so low risk.

## Phase 3: Find Theme.of() Bypasses

These use the Material theme directly instead of `appColors`, so they WON'T switch when the theme changes:

```bash
search_files("Theme\\.of\\(context\\)\\.", path="lib/", file_glob="*.dart")
```

Look specifically for:
- `Theme.of(context).scaffoldBackgroundColor` → should be `appColors.surface`
- `Theme.of(context).primaryColor` → should be `appColors.accent`
- `Theme.of(context).cardColor` → should be `appColors.card`
- `Theme.of(context).colorScheme.surface` → should be `appColors.surface`
- `Theme.of(context).iconTheme.color` → should use appColors

Some uses of `Theme.of(context).<property>` are legit IF the property is set per-theme in `_baseTheme()`. Cross-reference with `_buildDark/Light/Synthwave/Synthwave84()` to verify.

## Phase 4: Check Deprecated Color APIs

```bash
search_files("\\.withOpacity\\(", path="lib/", file_glob="*.dart")
```

- `withOpacity()` is deprecated in Flutter 3.27+. Replace with:
  - `withValues(alpha: 0.5)` — modern, composable
  - `withAlpha(128)` — direct alpha channel (0-255)

## Phase 5: Check Missing Assets

If the user reports "missing assets" or images/SVGs not loading:

1. List what's declared in `pubspec.yaml` assets section
2. Verify files exist on disk
3. Find all asset path strings in code and cross-reference

```bash
search_files("assets/", path="lib/", file_glob="*.dart")
ls -la assets/images/
```

Missing SVG files in particular won't crash the app unless something tries to load them via `flutter_svg.SvgPicture.asset()` — but they'll show broken placeholders. Create simple placeholder SVGs with the anatomy/layout needed.

## Phase 6: Build & Verify

After all fixes:
```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell dumpsys package <app_id> | grep "lastUpdateTime"
```

Verify the app on the device — cycle through all themes and check:
- Dashboard background gradient changes
- Button text readability on all themes
- Card visibility on Light theme
- Search bar hint text color
- Any SVG/anatomy diagram sections