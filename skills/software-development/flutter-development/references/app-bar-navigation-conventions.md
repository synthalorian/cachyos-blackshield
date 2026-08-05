# App Bar & Navigation Conventions (synth's preferences)

## App Bar — Clean and Minimal
- **Title:** Plain text only. No emoji, no icons in the title. Capitalize as standard English (e.g. "Open Veterinarian", not "🎹🦞 OPEN VETERINARIAN").
- **Actions:** Only the settings gear icon (`Icons.settings`). No search icon, no redundant logo thumbnail next to the title.
- **No `extendBodyBehindAppBar: true`** — causes content clipping on notched devices. Use default layout with simple ListView padding:
```dart
Scaffold(
  appBar: _buildAppBar(context, appColors),
  body: Stack(children: [
    _buildBackground(appColors),
    ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), ...),
  ]),
);
```

## NavigationBar — 5-7 Destinations
When the bottom nav has 7 tabs, labels must stay visible with compact sizing:
```dart
NavigationBarThemeData(
  height: 72,
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  labelTextStyle: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return labelSmall?.copyWith(fontWeight: FontWeight.w700);
    }
    return labelSmall;
  }),
)
```

## Batch Deprecation Sweeping

When fixing `withOpacity → withValues` or `value → initialValue` across 15-20 files, use Python via `execute_code` for bulk find-and-replace within a defined file section:

```python
from hermes_tools import terminal, write_file

result = terminal("cat path/to/file.dart")
lines = result["output"].split("\n")
# Find section boundaries, then for each line:
for old, new in {"AppColors.neonPink": "AppColors.sw84Purple", ".withOpacity(": ".withValues(alpha: "}.items():
    lines[i] = lines[i].replace(old, new)
write_file("path/to/file.dart", "\n".join(lines))
```

Verify with `flutter analyze` — target is "No issues found."

## Synthwave '84 Dark Theme Palette

Every Flutter app should have a Synthwave '84 dark theme matching the Omarchy system. Canonical palette:

```dart
const Color sw84Background = Color(0xFF240037);
const Color sw84Surface = Color(0xFF1A002A);
const Color sw84Card = Color(0xFF2D0045);
const Color sw84Elevated = Color(0xFF3A0058);
const Color sw84Purple = Color(0xFF8F00FF);     // Primary accent
const Color sw84Yellow = Color(0xFFF3E70F);     // Secondary accent  
const Color sw84Pink = Color(0xFFFF00FF);        // Tertiary accent
const Color sw84PinkSoft = Color(0xFFFF7EDB);
const Color sw84Cyan = Color(0xFF03EDF9);        // Info/accent
const Color sw84Blue = Color(0xFF0080FF);
const Color sw84Red = Color(0xFFFF0040);         // Error
const Color sw84Text = Color(0xFFFFFFFF);
const Color sw84TextDim = Color(0xFFB0A0C0);
```

**Theme setup:** Replace the default dark theme with sw84 colors. Use `DarkColorScheme extends ColorScheme` with sw84Purple as primary, sw84Yellow as secondary, sw84Pink as tertiary. Update all component overrides (button, nav bar, chips, switches, tabs, sliders, progress indicators) to use sw84 color constants. Light theme stays as professional indigo.

**Dashboard gradient:** Use `sw84Gradient: LinearGradient(colors: [sw84Purple, sw84Pink, sw84Cyan])` for the SliverAppBar background.
