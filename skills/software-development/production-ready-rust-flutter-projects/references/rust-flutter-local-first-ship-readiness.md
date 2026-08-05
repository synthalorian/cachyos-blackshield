# Rust + Flutter Local-First App: Ship-Readiness Case Study

Case study from auditing `open_health` — a privacy-first health data aggregator with encrypted SQLite, Rust backend, Flutter frontend.

## Architecture

- **Rust workspace** (`crates/shared`, `crates/crypto`, `crates/db`, `crates/server`)
- **Flutter app** (`flutter/` — Riverpod, go_router, fl_chart)
- **Communication:** Unix domain socket IPC (JSON-line protocol)
- **Database:** SQLite + AES-GCM-256 encryption via `ring`

## Audit Findings: What "Looks Done" vs "Actually Done"

### Green Flags (Truly Working)
- `cargo test` passes across all crates (5 tests: crypto roundtrip, serde, IPC ping/insert/get)
- `cargo build --release` produces `open_health_server` binary
- Encrypted DB layer works: `HealthDatabase::open()` creates schema, derives key, encrypts records
- Schema has proper indexes (`idx_health_records_type_ts`, `idx_sleep_records_date`)
- IPC message types (`IpcRequest`/`IpcResponse`) are well-designed with serde

### Red Flags (Mocked or Broken)
1. **IPC client is entirely mocked** — `IpcClient` in Flutter tries `WebSocket.connect('ws://localhost')` then falls back to `_mockResponse()` with hardcoded values. Zero real backend communication.
2. **Charts are fake** — `_HeartRateChart` generates `List.generate(7, (i) => FlSpot(i.toDouble(), 55 + (i * 3.5) + ...))`. No DB queries.
3. **Import pipeline is a stub** — `imports_screen.dart` shows "File picker coming soon..." dialog. No CSV parsers exist in Rust.
4. **No Flutter tests** — `flutter test` fails because `test/` directory is empty.
5. **Theme doesn't match user's palette** — using generic reds/teals (`#FF6B6B`, `#4ECDC4`) instead of synth's actual colors (`#240037`, `#8F00FF`, `#FF7EDB`, `#F3E70F`).
6. **CI workflow references wrong binary** — `.github/workflows/release.yml` builds `--bin open-health` but actual binary is `open_health_server`.
7. **Clippy warnings** — `non_snake_case` fields (`hrv_rMSSD`, `value_mg_dL`), needless borrows, `Result<T, ()>` instead of custom error type.

## Ship-Ready Definition for This Class of App

For a Rust + Flutter local-first MVP to be ship-ready:

1. **Real IPC bridge** — Flutter connects to Rust backend via actual Unix socket (or HTTP localhost), not mocks
2. **At least one import works** — Generic CSV parser with user-defined column mapping
3. **Charts show real data** — Query DB for last N days, feed into `fl_chart`
4. **Zero clippy warnings** — `cargo clippy --all-targets --all-features -- -D warnings` passes
5. **Flutter tests exist** — At minimum widget tests for core screens
6. **Theme matches brand** — Use the user's actual palette, not generic Material defaults
7. **CI builds correct artifacts** — Workflow binary names match `Cargo.toml` outputs

## Verification Commands

```bash
# Rust side
cd rust
cargo test
cargo clippy --all-targets --all-features -- -D warnings
cargo build --release
ls target/release/ | grep -v "^lib" | grep -v "^\."

# Flutter side
cd flutter
flutter analyze
flutter test
flutter build apk --release   # or linux, ios, etc.
```

## Common Patterns in This Architecture

### Encrypted SQLite + Rust
- Use `ring` for AES-GCM-256, PBKDF2 for key derivation
- Store salt in `meta` table, derive key on open
- Encrypt each record as JSON blob + nonce
- Plaintext columns (id, record_type, timestamp) for querying; encrypted blob for sensitive data

### Unix Socket IPC
- Rust: `tokio::net::UnixListener` with `tokio::io::AsyncBufReadExt` for JSON lines
- Flutter: `dart:io` `Socket` (not WebSocket) connecting to `/tmp/open_health.sock`
- Protocol: One JSON object per line, newline-delimited

### Flutter Provider Pattern for Backend
```dart
final ipcClientProvider = Provider<IpcClient>((ref) {
  final client = IpcClient();
  client.connect();  // real connect, not mock
  ref.onDispose(() => client.disconnect());
  return client;
});
```

## Pitfalls Specific to This Stack

- **WebSocket vs Unix Socket:** Flutter's `WebSocket` class is for WebSocket protocol (HTTP upgrade), NOT raw Unix domain sockets. Use `dart:io Socket` for Unix sockets.
- **Mock creep:** It's tempting to leave `_mockResponse()` for "later." Later never comes. Replace mocks with real calls before any UI polish.
- **Hardcoded chart data:** `fl_chart` examples use `List.generate` with math. Copy-pasting these into production creates the illusion of functionality.
- **Empty test directories:** `flutter test` failing on "no test files" is an easy fix — add at least one widget test per screen.
