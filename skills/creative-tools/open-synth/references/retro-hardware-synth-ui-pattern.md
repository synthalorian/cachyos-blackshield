# Retro Hardware Synth UI Pattern

Building a hardware synthesizer aesthetic in Flutter — Juno-106 reimagined with synthwave '84 palette.

## Color Palette

User preference: deep purples, purples, pink and yellows. NOT amber/olive CRT colors.

| Role | Hex | Usage |
|------|-----|-------|
| Background | `#240037` | App scaffold, deepest layer |
| Primary accent | `#8f00ff` | Panel gradients, active states |
| Secondary accent | `#ff7edb` | Hot pink — key press glow, knob arcs |
| Highlight | `#ff00ff` | Magenta — warnings, split indicator |
| LED/Warning | `#f3e70f` | Neon yellow — indicators, LCD pixels, knob ticks |
| Text primary | `#E8E0FF` | Warm white — labels, values |
| Text secondary | `#8A84B8` | Muted lavender — secondary labels |
| Panel | `#1A0A2E` | Dark purple — rack module backgrounds |
| Shadow | `#0F001A` | Near-black purple — depth shadows |

## Widget Patterns

### RetroKnob

```dart
class RetroKnob extends StatefulWidget {
  final double value;      // 0.0-1.0
  final ValueChanged<double> onChanged;
  final String label;
  final Color accentColor;
  
  @override
  State<RetroKnob> createState() => _RetroKnobState();
}

class _RetroKnobState extends State<RetroKnob> {
  double _dragStartValue = 0.0;
  double _dragStartY = 0.0;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: (d) {
        _dragStartValue = widget.value;
        _dragStartY = d.globalPosition.dy;
      },
      onVerticalDragUpdate: (d) {
        final delta = (_dragStartY - d.globalPosition.dy) / 100;
        widget.onChanged((_dragStartValue + delta).clamp(0.0, 1.0));
      },
      child: CustomPaint(
        size: const Size(56, 56),
        painter: _KnobPainter(
          value: widget.value,
          accentColor: widget.accentColor,
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double value;
  final Color accentColor;
  
  _KnobPainter({required this.value, required this.accentColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    
    // Tick mark ring
    final tickPaint = Paint()
      ..color = const Color(0xFF3A2A5A)
      ..strokeWidth = 1.5;
    for (int i = 0; i <= 20; i++) {
      final angle = -0.75 * math.pi + (i / 20) * 1.5 * math.pi;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 8);
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(inner, outer, tickPaint);
    }
    
    // Indicator line
    final indicatorAngle = -0.75 * math.pi + value * 1.5 * math.pi;
    final indicatorPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final indicatorStart = center + Offset(math.cos(indicatorAngle), math.sin(indicatorAngle)) * (radius - 12);
    final indicatorEnd = center + Offset(math.cos(indicatorAngle), math.sin(indicatorAngle)) * (radius - 2);
    canvas.drawLine(indicatorStart, indicatorEnd, indicatorPaint);
    
    // Bakelite body
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF2A1A4A), const Color(0xFF1A0A2E)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 14, bodyPaint);
  }
  
  @override
  bool shouldRepaint(covariant _KnobPainter old) => old.value != value;
}
```

### RetroLcd

```dart
class RetroLcd extends StatelessWidget {
  final String text;
  final double fontSize;
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        color: const Color(0xFF0A001A),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Stack(
          children: [
            // Scanlines
            CustomPaint(
              size: Size.infinite,
              painter: _ScanlinePainter(),
            ),
            // Text with phosphor glow
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: fontSize,
                color: const Color(0xFFF3E70F),
                shadows: [
                  Shadow(
                    color: const Color(0xFFF3E70F).withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF000000).withOpacity(0.3)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  
  @override
  bool shouldRepaint(_) => false;
}
```

### RetroRackModule

```dart
class RetroRackModule extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final Color accentColor;
  
  @override
  State<RetroRackModule> createState() => _RetroRackModuleState();
}

class _RetroRackModuleState extends State<RetroRackModule> {
  bool _expanded = false;
  
  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF1A0A2E), const Color(0xFF0F001A)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A2A5A), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with screws and LED
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF2A1A4A), const Color(0xFF1A0A2E)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  // Corner screws (decorative circles)
                  Container(width: 8, height: 8, decoration: BoxDecoration(
                    color: const Color(0xFF5A4A7A),
                    borderRadius: BorderRadius.circular(4),
                  )),
                  const SizedBox(width: 8),
                  // LED indicator
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _expanded ? widget.accentColor : const Color(0xFF3A2A5A),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: _expanded ? [
                        BoxShadow(color: widget.accentColor.withOpacity(0.6), blurRadius: 4),
                      ] : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.title, style: const TextStyle(
                    color: Color(0xFFE8E0FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  )),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF8A84B8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  // Corner screw
                  Container(width: 8, height: 8, decoration: BoxDecoration(
                    color: const Color(0xFF5A4A7A),
                    borderRadius: BorderRadius.circular(4),
                  )),
                ],
              ),
            ),
          ),
          // Expandable body
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(12),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
```

### RetroKeyboard

```dart
class RetroKeyboard extends ConsumerStatefulWidget {
  final int startOctave;
  final int octaveCount;
  final ValueChanged<int>? onNoteOn;
  final ValueChanged<int>? onNoteOff;
  
  @override
  ConsumerState<RetroKeyboard> createState() => _RetroKeyboardState();
}

class _RetroKeyboardState extends ConsumerState<RetroKeyboard> {
  final Set<int> _activeNotes = {};
  final Map<int, int> _pointerToNote = {};
  final Map<int, int> _noteRefCount = {};
  
  void _noteOn(int note) {
    _noteRefCount[note] = (_noteRefCount[note] ?? 0) + 1;
    if (_noteRefCount[note] == 1) {
      setState(() => _activeNotes.add(note));
      widget.onNoteOn?.call(note);
    }
  }
  
  void _noteOff(int note) {
    _noteRefCount[note] = (_noteRefCount[note] ?? 0) - 1;
    if ((_noteRefCount[note] ?? 0) <= 0) {
      _noteRefCount.remove(note);
      setState(() => _activeNotes.remove(note));
      widget.onNoteOff?.call(note);
    }
  }
  
  @override
  void dispose() {
    for (final note in _activeNotes.toList()) {
      widget.onNoteOff?.call(note);
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final whiteKeyWidth = constraints.maxWidth / (widget.octaveCount * 7);
        final whiteKeyHeight = constraints.maxHeight;
        final blackKeyWidth = whiteKeyWidth * 0.6;
        final blackKeyHeight = whiteKeyHeight * 0.62;
        
        return Stack(
          children: [
            // White keys
            Row(
              children: List.generate(widget.octaveCount * 7, (i) {
                final note = widget.startOctave * 12 + [0,2,4,5,7,9,11][i % 7];
                final isActive = _activeNotes.contains(note);
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _noteOn(note),
                  onPointerUp: (_) => _noteOff(note),
                  child: Container(
                    width: whiteKeyWidth,
                    height: whiteKeyHeight,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFFF8E8)
                          : const Color(0xFFFFF0D8),
                      border: Border.all(color: const Color(0xFF2A1A4A), width: 1),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: const Color(0xFFF3E70F).withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ] : null,
                    ),
                  ),
                );
              }),
            ),
            // Black keys (positioned absolutely)
            ...List.generate(widget.octaveCount * 5, (i) {
              final octave = i ~/ 5;
              final offsetInOctave = i % 5;
              final whiteIndex = [0,1,2,3,4,5,6][[0,1,2,3,4][offsetInOctave]];
              final left = (octave * 7 + whiteIndex + 1) * whiteKeyWidth - blackKeyWidth / 2;
              final note = widget.startOctave * 12 + [1,3,6,8,10][offsetInOctave] + octave * 12;
              final isActive = _activeNotes.contains(note);
              
              return Positioned(
                left: left,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _noteOn(note),
                  onPointerUp: (_) => _noteOff(note),
                  child: Container(
                    width: blackKeyWidth,
                    height: blackKeyHeight,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFF1A1A1A),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: const Color(0xFFF3E70F).withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ] : [
                        BoxShadow(
                          color: const Color(0xFF000000).withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
```

## Layout Pattern

```dart
class RetroSynthScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(livePresetSyncProvider);
    ref.watch(unifiedAudioStreamProvider);
    ref.watch(globalMixSyncProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFF240037),
      body: Column(
        children: [
          // Top bar: LCD + controls
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                RetroLcd(text: "Init Patch", fontSize: 16),
                const Spacer(),
                RetroButton(
                  label: "PREV",
                  onPressed: () => ref.read(currentPresetProvider.notifier).previous(),
                ),
                RetroButton(
                  label: "NEXT",
                  onPressed: () => ref.read(currentPresetProvider.notifier).next(),
                ),
              ],
            ),
          ),
          // Scrollable rack modules
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  RetroRackModule(
                    title: "OSCILLATORS",
                    accentColor: const Color(0xFF8F00FF),
                    child: Row(...), // osc controls
                  ),
                  RetroRackModule(
                    title: "FILTER",
                    accentColor: const Color(0xFFFF7EDB),
                    child: Row(...), // filter controls
                  ),
                  // ... more modules
                ],
              ),
            ),
          ),
          // Fixed keyboard
          SizedBox(
            height: 120,
            child: RetroKeyboard(
              startOctave: 3,
              octaveCount: 2,
              onNoteOn: (note) => ref.read(playbackStateProvider.notifier).noteOn(note, 1.0),
              onNoteOff: (note) => ref.read(playbackStateProvider.notifier).noteOff(note),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Key Techniques

1. **CustomPaint for hardware details** — tick marks, scanlines, indicator lines
2. **LinearGradient for panel depth** — top-to-bottom darkening creates 3D effect
3. **BoxShadow for raised/recessed** — keys, buttons, panels all use directional shadows
4. **GestureDetector.onVerticalDragUpdate** for knobs — vertical drag maps to value change
5. **Listener + HitTestBehavior.opaque** for keyboard — fires on pointer down, no lift required
6. **AnimatedCrossFade** for rack module expansion — smooth collapse/expand
7. **Shadow text effect** for LCD glow — `TextStyle.shadows` with matching color
8. **LayoutBuilder** for keyboard sizing — fills available height dynamically
9. **SingleChildScrollView** for rack — modules stack vertically, scroll when overflow
10. **No navigation shells** — single Scaffold, all state in Riverpod
