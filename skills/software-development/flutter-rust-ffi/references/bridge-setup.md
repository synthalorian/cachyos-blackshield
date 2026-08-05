# Flutter Rust Bridge Setup Workflow

## Step 1: Rust Preparation
- Add `flutter_rust_bridge` to Cargo.toml with `features = ["uuid"]`
- Create `bridge.rs` with `#[frb(sync)]` functions
- Export from `lib.rs`

## Step 2: Code Generation
```bash
cd mobile
flutter_rust_bridge_codegen generate
```

## Step 3: Flutter Initialization
```dart
import 'package:gridos_mobile/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const GridOSApp());
}
```

## Step 4: Calling Rust from Dart
```dart
final result = spawnSynthesisAgent(prompt: "Help with project");
```

## Production Notes
- Keep initial bridge functions synchronous
- Return formatted strings for errors during early development
- Move to async + proper error types after the basic loop works