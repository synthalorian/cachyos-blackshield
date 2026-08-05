# Open Synth — Mobile UX Shell Architecture

## Design Decisions (synth's choices, May 2026)

- **Hamburger drawer** (not bottom nav) — keeps thumb reach natural, two-hand friendly
- **Landscape-first** — keyboard gets maximum horizontal space
- **Target device**: Pixel 8a (1080x2400px, ~730x320dp landscape at 3x)
- **Collapsible panels** — all collapsed by default, tap to expand

## File Structure

| File | Purpose |
|------|---------|
| `lib/screens/mobile_shell.dart` | Hamburger drawer shell (replaces MainShell on mobile) |
| `lib/screens/mobile_synth_screen.dart` | Split-view synth (landscape) / stacked (portrait) |
| `lib/widgets/collapsible_section.dart` | Reusable ExpansionTile wrapper with synthwave theme |
| `lib/ffi/audio_platform.dart` | `isMobile`, `isAndroid`, `hasAudioDeviceEnumeration` |

## Platform Routing

Both desktop shells check `isMobile` at the TOP of `build()` and redirect:

```dart
// main_shell.dart
if (isMobile) return const MobileShell();

// synth_screen.dart  
if (isMobile) return const MobileSynthScreen();
```

No separate `main_mobile.dart` entry point. Both shells share `mainShellIndexProvider` and the same `IndexedStack`, so tab state persists.

## Landscape Layout (Primary)

```
┌──────────────────────────┬──────────────────────┐
│  Oscilloscope (50px)     │                      │
│  Spectrum (50px)         │   KEYBOARD            │
│  ─────────────────────   │   (KeyboardWidget)    │
│  Scrollable panels       │   Fixed, not scroll   │
│  (CollapsibleSection)    │   Always tappable     │
│  - Oscillators           │                      │
│  - Filter + Amp Env      │                      │
│  - Arpeggiator           │                      │
│  - FX                    │                      │
│  - etc                   │                      │
│  ~60% width              │   ~40% width          │
└──────────────────────────┴──────────────────────┘
```

Split achieved via `Row` with `Expanded(flex: 6)` for panels and `Expanded(flex: 4)` for keyboard.

## Portrait Layout (Fallback)

```
┌──────────────────────┐
│ AppBar (compact)      │
├──────────────────────┤
│ Oscilloscope (40px)   │
├──────────────────────┤
│ Scrollable panels     │
│ (all collapsed)       │
├──────────────────────┤
│ Keyboard (fixed)      │
│ 2 octaves             │
└──────────────────────┘
```

Uses `Orientation.landscape` vs `Orientation.portrait` from `MediaQuery`.

## Hamburger Drawer

- Header: "OPEN SYNTH" in Orbitron font + magenta→purple→cyan gradient bar
- 5 nav items: Presets, Synth, Split, Recorder, Performance
- Active item: magenta left border + background tint
- Footer: version + audio backend name from `audioBackendName`
- No bottom navigation bar

## Collapsible Sections

`CollapsibleSection` widget wraps Flutter's `ExpansionTile`:
- Props: `title`, `accentColor`, `initiallyExpanded` (default false), `child`
- Header: colored dot (glows when expanded) + title text
- Body: padded child content
- Dark synthwave card theme matching SynthTheme

Panel pairs (OSC 1+2, Filter+Amp Env, etc.) use `Row` with `Expanded` children inside the collapsible body.

## Remaining Work

- Multitouch glide (slide between keys)
- Velocity via Android pressure API
- Pinch-to-zoom octave range
- Hold/sustain button tied to arp hold/latch
- Buffer sizing tuning for Android latency
