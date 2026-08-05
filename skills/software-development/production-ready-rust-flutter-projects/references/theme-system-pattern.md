# Flutter Theme System Pattern

## Architecture

Single-file theme definition (`lib/theme/app_theme.dart`) containing:
1. `AppColorScheme` class — 18 color fields, const constructor with defaults
2. All theme constants (28 in current app)
3. `themeDataFromScheme()` — converts scheme to Material ThemeData
4. `allThemes` map — name→scheme for the picker popup
5. `themeNames` list — display order

## Dark/Light Detection

Use `background.computeLuminance()` instead of listing theme constants:

```dart
final isDark = scheme.background.computeLuminance() < 0.3;
```

Luminance ranges: 0.0 (black) to 1.0 (white). Threshold at 0.3 catches all dark themes while correctly classifying pure-white light themes.

## Compact Const Pattern

Each theme constant uses a single-line-per-property compact style. This keeps 28 themes readable in ~200 lines:

```dart
const zeus = AppColorScheme(
  background: Color(0xFF0D0A1A), surface: Color(0xFF1A1530), surfaceAlt: Color(0xFF282045),
  primary: Color(0xFFC9A84C), secondary: Color(0xFF4A7CFF), accent: Color(0xFF00D4FF),
  text: Color(0xFFFFF8F0), textDim: Color(0xFFB0A8C0), textMuted: Color(0xFF706880),
  border: Color(0xFFC9A84C), borderDim: Color(0xFF1A153080),
  cardBackground: Color(0xFF1A1530), selectedBackground: Color(0xFF282045),
  scaffoldBackground: Color(0xFF0D0A1A), appBarBackground: Color(0xFF0D0A1A80), bottomNavBackground: Color(0xFF0D0A1A80),
);
```

## All 28 Themes

### Retro/Synthwave (6)
| Name | Background | Primary | Vibe |
|------|-----------|---------|------|
| Synthwave '84 | #0D0221 | #8F00FF | Deep purple, electric neon |
| Synthwave Light | #F5F0FF | #8F00FF | Inverted purple for daytime |
| Outrun | #0A0A0A | #FF6A00 | Near-black, blazing orange sun |
| Vaporwave | #1A0A2E | #FF6EC7 | Purple base, pink, mint green |
| Cyberpunk | #000000 | #FFD700 | Total black, aggressive yellow |
| Hermes | #051412 | #F5F0E8 | Deep forest teal, cream |

### Greek Pantheon (20)
| Name | Background | Primary | Domain |
|------|-----------|---------|--------|
| Zeus | #0D0A1A | #C9A84C | Sky Father — gold, lightning |
| Hera | #0E0814 | #6A0DAD | Queen — royal purple, peacock |
| Poseidon | #061214 | #0077B6 | Sea — ocean blue, teal |
| Hades | #0A0A0A | #FF6B35 | Underworld — obsidian, flame |
| Ares | #0F0505 | #DC143C | War — blood crimson, iron |
| Apollo | #0F0A05 | #FFB703 | Sun — golden radiance |
| Artemis | #0A0D12 | #C0C0C0 | Hunt — silver, forest green |
| Athena | #0A0D0F | #1D3557 | Wisdom — sapphire, olive |
| Aphrodite | #140A0F | #E91E63 | Love — rose, pearl, gold |
| Dionysus | #120810 | #722F37 | Wine — wine red, grape purple |
| Demeter | #0F0E0A | #D4A373 | Harvest — wheat gold, earth |
| Hephaestus | #080808 | #FF6D00 | Forge — molten orange, steel |
| Hestia | #120E08 | #E76F51 | Hearth — warm amber, brick |
| Nyx | #05030F | #7B2D8E | Night — deep purple, silver |
| Eos | #120A0F | #FF9E9E | Dawn — rosy pink, sky blue |
| Hypnos | #080A14 | #9B72CF | Sleep — lavender, midnight |
| Iris | #0A0A12 | #00BCD4 | Rainbow — cyan, pink, gold |
| Tyche | #080C08 | #2D6A4F | Fortune — emerald, lucky gold |
| Thanatos | #080808 | #D4D4D4 | Death — pale grey, bone white |
| Hecate | #0A0510 | #5B2C8E | Magic — eerie purple, green |

### Professional (2)
| Name | Background | Primary | Use |
|------|-----------|---------|-----|
| Light | #FFFFFF | #2563EB | Daytime, clean |
| Dark | #111118 | #60A5FA | All-night, subtle blue |