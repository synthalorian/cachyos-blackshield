# Global Mix Provider Pattern

Unifies master volume control across multiple concurrent audio engines (synth, sample, split pair).

## The Problem

When synth and sample engines run on separate audio streams, each has independent volume:
- Synth engine: `masterVolume` via ParamQueue (ParamId 130)
- Sample engine: `volumeDb` via sfizz (dB scale)
- Split pair: `setMixA()` / `setMixB()` on `SynthEnginePair`

No single slider controls all of them.

## Solution

File: `lib/providers/global_mix_provider.dart`

### Providers

```dart
/// User-facing master volume (0.0 - 1.0)
final globalMasterVolumeProvider = StateProvider<double>((ref) => 1.0);

/// Side-effect provider that pushes volume to all engines
final globalMixSyncProvider = Provider<void>((ref) {
  final globalVol = ref.watch(globalMasterVolumeProvider);

  // Synth engine (linear)
  final synth = ref.watch(synthEngineProvider);
  if (synth != null) synth.masterVolume = globalVol;

  // Sample engine (linear -> dB conversion)
  final sampleEngine = ref.watch(sampleEngineProvider);
  final samplePreset = ref.watch(samplePresetProvider);
  if (sampleEngine != null && samplePreset != null) {
    final db = globalVol <= 0.001 ? -100.0 : (20.0 * log(globalVol) / ln10);
    sampleEngine.volumeDb = db.clamp(-60.0, 6.0);
  }

  // Split pair
  final pair = ref.watch(synthPairProvider);
  if (pair != null) {
    pair.setMixA(globalVol);
    pair.setMixB(globalVol);
  }
});
```

### Usage

Every screen with audio output watches the sync provider:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.watch(globalMixSyncProvider);  // Keeps volume sync alive
  // ... rest of build
}
```

### UI Integration

A master volume slider can update the global provider:
```dart
Slider(
  value: ref.watch(globalMasterVolumeProvider),
  onChanged: (v) => ref.read(globalMasterVolumeProvider.notifier).state = v,
)
```

All engines update simultaneously.

## Note on dB Conversion

sfizz uses dB for volume. The conversion:
- `0.0` -> `-100 dB` (effectively silent)
- `0.001` -> `-60 dB`
- `0.5` -> `-6 dB`
- `1.0` -> `0 dB`

Formula: `db = 20.0 * log10(volume)` where `log10(x) = log(x) / ln(10)`.
