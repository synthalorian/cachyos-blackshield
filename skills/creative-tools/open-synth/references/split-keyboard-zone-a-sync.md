# Zone A Preset Sync Bug — Split Keyboard

## Symptom

Split keyboard mode: Zone B (right side) plays the correct preset, but Zone A (left side) plays a default/init patch instead of its assigned preset.

## Root Cause

The `SynthEnginePair` contains two engines:
- `engineA` — Zone A (left side)
- `engineB` — Zone B (right side)

`zoneBPresetSyncProvider` existed to sync preset B to engine B. But there was NO equivalent `zoneAPresetSyncProvider` syncing preset A to engine A.

Zone A notes routed correctly to `pair.engineA` via `PlaybackStateNotifier._engine`, but engine A had no preset loaded — it played the default init patch.

## Fix

Add `zoneAPresetSyncProvider` in `lib/providers/keyboard_split_provider.dart`:

```dart
final zoneAPresetSyncProvider = Provider<void>((ref) {
  final pair = ref.watch(synthPairProvider);
  final split = ref.watch(keyboardSplitProvider);
  if (pair == null) return;

  final preset = split.presetA;
  final engineA = OpenAmpSynth.fromHandle(pair.engineA);
  applyPresetToSynth(engineA, preset);
});
```

## Required Watchers

Every screen with audio output must watch BOTH sync providers:
```dart
ref.watch(zoneAPresetSyncProvider);
ref.watch(zoneBPresetSyncProvider);
ref.watch(zoneBMixSyncProvider);
```

Screens affected:
- `lib/screens/synth_screen.dart`
- `lib/screens/mobile_synth_screen.dart`
- `lib/screens/split_screen.dart`

## Verification

1. Enable split mode (Split/Layer tab)
2. Assign different presets to Zone A and Zone B
3. Play notes below split point → should hear Zone A preset
4. Play notes above split point → should hear Zone B preset
5. Both zones should sound distinct, not the same init patch
