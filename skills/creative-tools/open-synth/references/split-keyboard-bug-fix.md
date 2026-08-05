# Split Keyboard Bug Fix — "Only Right Side Works"

## Bug Description

When keyboard split mode is enabled (Zone A left, Zone B right), only Zone B produces audio. Zone A is silent.

## Root Cause

The audio architecture has two mutually exclusive audio streams:

1. **Single-engine stream**: `synthAudioStreamProvider` → bound to `synthEngineProvider` → renders Zone A engine
2. **Pair-engine stream**: `synthPairAudioStreamProvider` → bound to `synthPairProvider` → renders Zone A + Zone B mixed

The problem was that:
- `PlaybackStateNotifier` (Zone A) called `_ref.read(synthAudioStreamProvider)` to start audio — the single-engine stream
- `ZoneBPlaybackNotifier` called `_ref.read(synthPairAudioStreamProvider)` — but this provider was never `ref.watch`ed by any UI widget, so it was never instantiated
- Zone B notes went to the pair's engine B, but the pair stream never rendered them
- Zone A notes went to the single engine, which WAS running
- Result: Only Zone B "worked" because it was the only thing making sound through the pair... actually wait, that means only Zone B worked? No — re-reading: Zone A was silent, Zone B worked. That's because the pair stream WAS running in some cases but the single stream wasn't. Actually the exact behavior depends on which stream grabs the audio device first.

The actual behavior: Zone A is silent because its notes go to the single engine, but if the pair stream grabbed the audio device, the single stream callback never fires. Zone B works because its notes go to the pair's engine B which IS being rendered by the pair stream.

## Files Changed

### 1. `lib/screens/synth_screen.dart`
```dart
// BEFORE:
ref.watch(synthPairProvider);
ref.watch(zoneBPresetSyncProvider);

// AFTER:
ref.watch(synthPairProvider);
ref.watch(synthPairAudioStreamProvider);  // START THE PAIR STREAM
ref.watch(zoneBPresetSyncProvider);
ref.watch(zoneBMixSyncProvider);          // KEEP VOLUME SYNC ALIVE
```

### 2. `lib/screens/mobile_synth_screen.dart`
Same changes as synth_screen.dart, PLUS fix panic button:
```dart
// BEFORE:
ref.read(playbackStateProvider.notifier).allNotesOff();

// AFTER:
ref.read(noteRouterProvider).allNotesOff();
```

### 3. `lib/providers/synth_providers.dart` — PlaybackStateNotifier
```dart
class PlaybackStateNotifier extends StateNotifier<Set<int>> {
  // ...

  OpenAmpSynth? get _engine {
    final split = _ref.read(keyboardSplitProvider);
    if (split.enabled) {
      final pair = _ref.read(synthPairProvider);
      if (pair != null) {
        return OpenAmpSynth.fromHandle(pair.engineA);  // Non-owning wrapper!
      }
    }
    return _ref.read(synthEngineProvider);
  }

  void _ensureAudioRunning() {
    final split = _ref.read(keyboardSplitProvider);
    if (split.enabled) {
      _ref.read(synthPairAudioStreamProvider);
    } else {
      _ref.read(synthAudioStreamProvider);
    }
  }
}
```

### 4. `lib/screens/synth_screen.dart` — Desktop panic button
```dart
// BEFORE:
ref.read(playbackStateProvider.notifier).allNotesOff();

// AFTER:
ref.read(noteRouterProvider).allNotesOff();
```

## Key Insight

`OpenAmpSynth.fromHandle()` creates a non-owning wrapper around an existing native handle. This is critical because:
- `pair.engineA` returns a raw pointer to engine A inside the pair
- The pair owns both engines and destroys them on `pair.dispose()`
- If we created a new `OpenAmpSynth` with `create()`, it would double-free
- `fromHandle()` sets `_ownsHandle = false`, so `dispose()` is a no-op

## Prevention

Any feature that adds a new audio stream path must:
1. Ensure the stream provider is `ref.watch`ed in the UI lifecycle
2. Ensure note routing uses the correct engine handle
3. Ensure panic/all-notes-off uses `NoteRouter` not individual zone notifiers
