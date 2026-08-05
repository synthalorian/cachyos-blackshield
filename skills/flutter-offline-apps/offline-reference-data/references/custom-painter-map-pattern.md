# Custom Painter Interactive Map Pattern

Pattern for rendering interactive star system / geographical maps using Flutter's CustomPainter with pinch-to-zoom and tap-to-inspect.

## Architecture

```
LayoutBuilder → InteractiveViewer → GestureDetector → CustomPaint
```

### Component Responsibilities

| Layer | Role |
|-------|------|
| `LayoutBuilder` | Gets available canvas size, computes scale |
| `InteractiveViewer` | Pinch-to-zoom (minScale 0.5, maxScale 3.0), pan, boundary margin 200px, constrained: false |
| `GestureDetector` | `onTapUp` — hit testing against known marker positions |
| `CustomPaint` | All visual rendering (starfield, orbits, markers, labels, glow effects, scan lines) |

## Data Model

### Positionable Entity
```dart
class _MapEntity {
  final String name;
  final String type;  // 'planet', 'station', 'restStop', 'lagrange'
  final List<String> services;
  final String description;
  final Offset position;  // computed in build(), passed to painter
}
```

### Position Derivation
For orbital maps, compute positions from polar coordinates:

```dart
Offset _polarToCartesian(Offset center, double radius, double angleDeg) {
  final rad = angleDeg * pi / 180;
  return Offset(center.dx + radius * cos(rad), center.dy + radius * sin(rad));
}
```

Orbital positions for Stanton system:
- Hurston: radius 0.18 × halfCanvas, angle 30°
- ArcCorp: radius 0.32, angle 120°
- Crusader: radius 0.46, angle 210°
- microTech: radius 0.60, angle 300°
- Stations: offset ±20-30° from parent planet, radius +30px
- Lagrange: distributed between orbital paths

## Painter Implementation

### Draw Order (back to front)
1. Starfield (120+ scattered white dots, seeded RNG for stability)
2. Central star (multi-layer radial gradient: outer glow → inner glow → bright core)
3. Orbit rings (dashed neon lines per planet color)
4. Scan lines (subtle horizontal cyan lines, 3% opacity)
5. Markers + labels (planets first, then stations, rest stops, lagrange)

### Marker Glow Effect
```dart
// 3-layer glow for planets
final glowPaint = Paint()
  ..shader = RadialGradient(
    colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.05), Colors.transparent],
    stops: [0.0, 0.5, 1.0],
  ).createShader(Rect.fromCircle(center: pos, radius: r * 3));
canvas.drawCircle(pos, r * 3, glowPaint);
// + mid glow layer
// + solid core
// + white highlight offset
```

### Hit Testing
```dart
onTapUp: (details) {
  final tapPos = details.localPosition;
  for (final entry in allPositions.entries) {
    final dist = (tapPos - entry.value).distance;
    final hitRadius = entry.key.type == 'planet' ? 30.0 : 22.0;
    if (dist <= hitRadius) {
      _showDetailSheet(context, entry.key);
      return;
    }
  }
},
```

## Key Considerations

### Canvas Size
Use `max(constraints.maxWidth, constraints.maxHeight)` as a square canvas base so zooming has room in both dimensions. The InteractiveViewer wraps this square.

### Seeded RNG for Stars
```dart
List<Offset> _generateStars(int count, Size size) {
  final rng = Random(42);  // fixed seed prevents flicker on repaint
  return List.generate(count, (_) => Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height));
}
```

### Paint Frame Reset
Always clear `_drawnLabelBounds` at the start of `paint()` to prevent stale collision data.

### shouldRepaint
Compare all fields (stars, center, orbitScale, positions, type map) to avoid unnecessary repaints.

## Synthwave Aesthetic Constants

- Planet colors: Hurston=#39FF14, ArcCorp=#FF6B35, Crusader=#4FC3F7, microTech=#00FFFF
- Stanton star: warm orange/yellow radial gradient
- Background: deep dark (#0A0A1A)
- Scan lines: cyan at 3% opacity, 12 lines evenly spaced
- Labels: monospace font, 10px, colored shadow behind text for readability
