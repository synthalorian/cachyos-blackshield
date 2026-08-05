# Rust + Flutter Local-First App — Ship Checklist

Reference from open_health v0.1.0 ship session (2026-05-31). Applicable to any Rust-backend + Flutter-frontend local-first app (health, finance, notes, etc.).

## Pre-Ship Audit

### 1. Rust Backend Verification

```bash
cd rust  # or workspace root
cargo test --workspace
cargo clippy --all-targets --all-features -- -D warnings
cargo build --release
```

**Common clippy fixes before ship:**
- `non_snake_case` field names (e.g., `value_mg_dL` → `value_mg_dl`)
- `needless_borrows_for_generic_args` (e.g., `hex::encode(&nonce)` → `hex::encode(nonce)`)
- `result_unit_err` — replace `Result<T, ()>` with a custom `Error` enum implementing `std::error::Error`
- `unused_imports` in test modules (often `use std::sync::Arc`)

**Custom error type pattern:**
```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CryptoError {
    DecryptionFailed,
}

impl std::fmt::Display for CryptoError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CryptoError::DecryptionFailed => write!(f, "decryption failed"),
        }
    }
}

impl std::error::Error for CryptoError {}
```

### 2. Flutter Frontend Verification

```bash
cd flutter
flutter analyze       # must be "No issues found!"
flutter test          # at least smoke tests exist
flutter build apk --release  # or target platform
```

**Common pre-ship Flutter issues:**
- `deprecated_member_use` — replace deprecated APIs (e.g., `RadioListTile.groupValue` → `ListTile` with checkmarks)
- Mock data in user-facing features — charts showing `List.generate()` random data, "coming soon" placeholders
- Missing `test/` directory entirely

### 3. Functional Verification (Critical)

**IPC/Backend communication:**
- [ ] Flutter app talks to Rust backend via REAL protocol (Unix socket, HTTP, FFI) — not mocked responses
- [ ] Connection failure has graceful fallback (mock data or error state)

**Data import:**
- [ ] At least one import format works end-to-end (CSV, JSON, XML)
- [ ] Import pipeline parses real files, not just stubs
- [ ] Imported data appears in the database and UI

**Charts/Dashboard:**
- [ ] Charts query real data from the database
- [ ] No hardcoded `List.generate(7, (i) => FlSpot(...))` placeholder data
- [ ] Empty state shows "No data available" rather than random values

**Encryption (if applicable):**
- [ ] Dump the SQLite file and verify it's unreadable (encrypted at rest)
- [ ] Passphrase verification works

### 4. Theme & Polish

- [ ] Theme uses consistent palette (define as `static const` colors, not hardcoded hex literals scattered through widgets)
- [ ] Dark mode is the default for synthwave/neon aesthetics
- [ ] All deprecated API usage resolved

### 5. CI/CD Verification

```bash
# Check workflow builds correct binary
cargo build --release && ls target/release/ | grep -v "^lib" | grep -v "^\."
```

- [ ] CI workflow references correct binary name (check for underscore vs hyphen mismatches)
- [ ] Release workflow builds both Rust binary AND Flutter APK
- [ ] Flutter `flutter analyze` and `flutter test` run in CI

### 6. Minimum Viable Tests

**Rust:** At minimum, test serde roundtrips and core business logic:
```rust
#[test]
fn test_health_record_serde_roundtrip() {
    let record = HealthRecord { ... };
    let json = serde_json::to_string(&record).unwrap();
    let decoded: HealthRecord = serde_json::from_str(&json).unwrap();
    assert_eq!(record, decoded);
}
```

**Flutter:** At minimum, widget tests for app render and navigation:
```dart
testWidgets('App renders with navigation', (WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: OpenHealthApp()));
  await tester.pumpAndSettle();
  expect(find.text('Open Health'), findsOneWidget);
  expect(find.byType(NavigationBar), findsOneWidget);
});
```

## IPC Bridge Pattern (Unix Socket)

**Rust server (NDJSON protocol):**
```rust
// Each request = one JSON line ending in \n
// Each response = one JSON line ending in \n
async fn handle_client(stream: UnixStream, db: Arc<HealthDatabase>) {
    let (reader, mut writer) = stream.into_split();
    let mut buf_reader = BufReader::new(reader);
    let mut line = String::new();
    while buf_reader.read_line(&mut line).await? > 0 {
        let request: IpcRequest = serde_json::from_str(&line)?;
        let response = process_request(request, &db);
        writer.write_all(serde_json::to_string(&response)?.as_bytes()).await?;
        writer.write_all(b"\n").await?;
        line.clear();
    }
}
```

**Flutter client:**
```dart
class IpcClient {
  Socket? _socket;
  final _responseController = StreamController<Map<String, dynamic>>.broadcast();

  Future<bool> connect() async {
    _socket = await Socket.connect(
      InternetAddress('/tmp/open_health.sock', type: InternetAddressType.unix),
      0,
      timeout: const Duration(seconds: 2),
    );
    _socket!.listen(_onData);
    return true;
  }

  void _onData(List<int> data) {
    // NDJSON: split on newlines, parse each line
  }

  Future<Map<String, dynamic>> send(Map<String, dynamic> request) async {
    _socket!.write('${jsonEncode(request)}\n');
    return await _responseController.stream.first.timeout(
      const Duration(seconds: 5),
    );
  }
}
```

## CSV Import Pipeline Pattern

**Rust crate structure:**
```
crates/import/
  Cargo.toml          # depends on open_health_shared, open_health_db, csv, chrono
  src/lib.rs
    ColumnMapping     # Auto-detect from headers
    import_csv()      # Returns ImportSession
    parse_record_type()  # Flexible type mapping
    parse_timestamp()    # Multiple format support
```

**Auto-detection heuristic:**
```rust
impl ColumnMapping {
    pub fn auto_detect(headers: &[String]) -> Option<Self> {
        let header_map: HashMap<String, usize> = headers
            .iter().enumerate()
            .map(|(i, h)| (h.to_lowercase().replace(' ', "_"), i))
            .collect();

        let timestamp = detect_column(&header_map,
            &["timestamp", "date", "datetime", "time", "created_at"])?;
        let value = detect_column(&header_map,
            &["value", "amount", "measurement", "reading"])?;
        // ...
    }
}
```

**Type mapping:** Normalize 20+ common health metric names to `RecordType` enum:
```rust
match lower.as_str() {
    "heart_rate" | "heartrate" | "hr" => RecordType::HeartRate,
    "sleep_duration" | "sleep" => RecordType::SleepDuration,
    "steps" | "step_count" => RecordType::Steps,
    // ... 20+ more
    _ => RecordType::Custom(s.to_string()),
}
```
