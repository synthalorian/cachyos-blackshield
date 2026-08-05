# Synthwave UI Techniques (Flutter + Rails Cross-Platform)

## CRT / Scanline Effects

### Flutter
Use `CustomPaint` in Flutter with line segments at 3px intervals, or a `ShaderMask` overlay with `RepeatingLinearGradient`:

```dart
ShaderMask(
  shaderCallback: (bounds) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: List.generate(100, (i) =>
      i.isEven ? Colors.transparent : Colors.black.withValues(alpha: 0.03)),
  ).createShader(bounds),
  child: child,
)
```

### Rails (CSS)
CSS `::after` pseudo-element with a repeating linear gradient overlay:

```css
body::after {
  content: "";
  position: fixed;
  inset: 0;
  background: repeating-linear-gradient(
    0deg,
    transparent,
    transparent 2px,
    rgba(0, 0, 0, var(--crt-opacity)) 2px,
    rgba(0, 0, 0, var(--crt-opacity)) 4px
  );
  pointer-events: none;
  z-index: 9999;
  animation: scanline-scroll var(--crt-speed) linear infinite;
}

@keyframes scanline-scroll {
  0% { background-position: 0 0; }
  100% { background-position: 0 4px; }
}
```

Control CRT visibility via `--crt-opacity` (0 = off, 0.03 = subtle, 0.06 = strong). Many light/professional themes set this to 0.

## Grid Background

### Rails (CSS)
A `::before` pseudo-element with two linear gradients for the grid:

```css
body::before {
  content: "";
  position: fixed;
  inset: 0;
  background-image:
    linear-gradient(rgba(143, 0, 255, var(--grid-opacity)) 1px, transparent 1px),
    linear-gradient(90deg, rgba(143, 0, 255, var(--grid-opacity)) 1px, transparent 1px);
  background-size: 40px 40px;
  pointer-events: none;
  z-index: -1;
}
```

## Glass-Morphism Cards

Used consistently across both platforms:

### Flutter
```dart
Container(
  decoration: BoxDecoration(
    color: scheme.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: scheme.borderDim),
  ),
  padding: const EdgeInsets.all(14),
)
```

### Rails (CSS class)
```css
.glass-card {
  background: color-mix(in srgb, var(--bg-surface) 70%, transparent);
  backdrop-filter: blur(12px);
  border: 1px solid var(--border-glow);
  border-radius: var(--radius-lg);
}

.glass-card-hover:hover {
  border-color: var(--accent-primary);
  box-shadow: var(--glow-primary);
}
```

## Theme System Pattern (30+ Themes)

### Canonical Source: Flutter AppColorScheme
The `app_theme.dart` file defines each theme as a Dart constant with 19 color fields. This is the single source of truth.

```dart
const synthwave84 = AppColorScheme(
  background: Color(0xFF0D0221),  // Deep purple-black
  surface: Color(0xFF240037),      // Rich purple
  surfaceAlt: Color(0xFF2D0047),  // Brighter purple
  primary: Color(0xFF8F00FF),      // Electric purple
  secondary: Color(0xFFFF00FF),    // Hot pink
  accent: Color(0xFF00FFFF),       // Cyan
  text: Color(0xFFFFFFFF),         // White
  textDim: Color(0xFFC0A0D0),     // Muted lavender
  textMuted: Color(0xFF663388),   // Dim purple
  border: Color(0xFF8F00FF),      // Purple border
  borderDim: Color(0xFF4A0068),   // Dim border
  // plus scaffoldBackground, appBarBackground, bottomNavBackground,
  // cardBackground, selectedBackground
);
```

### Web Replica: Rails CSS Custom Properties
Each theme gets a `[data-theme="name"]` block with the same hex values:

```css
[data-theme="synthwave84"] {
  --bg-primary: #0D0221;
  --bg-secondary: #240037;
  --accent-primary: #8F00FF;
  --accent-secondary: #FF00FF;
  /* ... all 19 colors map to --css-variables */
}
```

### Available Themes in Both Platforms
- Synthwave '84, Synthwave Light, Outrun, Vaporwave, Cyberpunk
- Hermes (brand: deep teal/cream)
- 17 Greek pantheon themes: Zeus, Hera, Poseidon, Hades, Ares, Apollo, Artemis, Athena, Aphrodite, Dionysus, Demeter, Hephaestus, Hestia, Nyx, Eos, Hypnos, Iris, Tyche, Thanatos, Nemesis, Hecate (21 total — all 12 Olympians + underworld/night/magic gods)
- Professional: Light + Dark

### Adding a New Theme
1. Add `const themeName = AppColorScheme(...)` in the Flutter `app_theme.dart`
2. Add to `allThemes` map with a display name
3. Add `[data-theme="name"] { ... }` block in the Rails `application.css`
4. Add to the Rails theme picker dialog's `themes` list
5. Add to `ThemeController::VALID_THEMES` in Rails

## Neon Edge Glow

### Rails (CSS)
```css
.neon-border {
  border: 1px solid var(--border-glow);
  box-shadow: var(--glow-primary);
}

.text-glow {
  text-shadow: 0 0 10px var(--accent-primary), 0 0 20px var(--accent-primary);
}
```

### Flutter
```dart
Container(
  decoration: BoxDecoration(
    border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
    boxShadow: [
      BoxShadow(color: scheme.primary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2),
    ],
  ),
)
```

## Status Dot Indicators

Used for live/connected/disconnected status:

### Flutter
```dart
Container(
  width: 8, height: 8,
  decoration: BoxDecoration(
    color: isConnected ? scheme.success : scheme.error,
    shape: BoxShape.circle,
    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
  ),
)
```

### Rails (CSS class)
```css
.status-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
.status-dot.connected { background-color: var(--success); box-shadow: 0 0 6px var(--success); }
.status-dot.disconnected { background-color: var(--error); box-shadow: 0 0 6px var(--error); }
.status-dot.pending { background-color: var(--warning); box-shadow: 0 0 6px var(--warning); animation: pulse-dot 1.5s ease-in-out infinite; }
```

## Production Tips
- Always provide theme switcher for user control (sidebar button → dialog picker)
- Match desktop and mobile aesthetics closely for cohesive experience
- CRT scanlines should be opt-in per theme (dark themes get them, light/professional don't)
- glass-morphism + thin neon borders + monospace fonts = the core synthwave UI identity