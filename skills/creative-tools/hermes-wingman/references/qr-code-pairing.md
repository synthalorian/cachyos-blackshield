# QR Code Pairing — Desktop to Mobile Backend Connection

## Flow

1. **Desktop app** displays a QR code in Config → Network Share containing `IP:PORT` of the backend
2. **Mobile app** opens Config → Backend Connection → taps **Scan**
3. Camera opens via `mobile_scanner` package, scans the desktop QR code
4. Mobile app parses `IP:PORT`, updates settings, and reconnects to the backend

## Desktop Side (QR Display)

In `lib/screens/config/config_screen.dart`, the Network Share section (desktop-only) renders a `QrImageView`:

```dart
import 'package:qr_flutter/qr_flutter.dart';

// In _buildNetworkSection, inside if (!isMobile) ...[
if (primaryIP != '—') ...[
  Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        QrImageView(
          data: '$primaryIP:9120',  // e.g. "192.168.1.100:9120"
          version: QrVersions.auto,
          size: 180,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        ),
        const Text('Scan with your phone'),
      ],
    ),
  ),
]
```

**Note:** `foregroundColor` is deprecated. Use `eyeStyle` and `dataModuleStyle` instead.

## Mobile Side (QR Scanner)

Add a Scan button in the mobile connection section:

```dart
import 'package:mobile_scanner/mobile_scanner.dart';

// In _buildConnectionSection (mobile), next to the "Change" button:
Material(
  color: scheme.accent.withValues(alpha: 0.12),
  borderRadius: BorderRadius.circular(6),
  child: InkWell(
    onTap: () => _showQRScanner(context),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner, size: 12, color: scheme.accent),
          const SizedBox(width: 4),
          Text('Scan', style: TextStyle(color: scheme.accent, fontSize: 10)),
        ],
      ),
    ),
  ),
)
```

The scanner overlay uses `MobileScanner` with a custom painter frame:

```dart
class _QRScannerOverlay extends StatefulWidget {
  final void Function(String data) onDetect;
  const _QRScannerOverlay({required this.onDetect});

  @override
  State<_QRScannerOverlay> createState() => _QRScannerOverlayState();
}

class _QRScannerOverlayState extends State<_QRScannerOverlay> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            onDetect: (capture) {
              if (_detected) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  setState(() => _detected = true);
                  widget.onDetect(raw);
                  return;
                }
              }
            },
          ),
        ),
        // Custom overlay frame via CustomPaint
        Positioned.fill(child: CustomPaint(painter: _ScannerFramePainter())),
      ],
    );
  }
}
```

On detect, parse `IP:PORT` and reconnect:

```dart
onDetect: (String data) async {
  Navigator.of(ctx).pop();
  final parts = data.split(':');
  if (parts.length >= 2) {
    final host = parts.sublist(0, parts.length - 1).join(':');
    final port = int.tryParse(parts.last) ?? 9120;
    await settings.setBackendUrl(host, port);
    if (mounted && context.mounted) {
      backend.setBaseUrl(host, port);
      await backend.reconnect();
    }
  }
}
```

## Backend Binding

The Rust backend must bind to `0.0.0.0:9120` (not `127.0.0.1`) to accept LAN connections:

```bash
# Check current binding
ss -tlnp | grep 9120

# Should show 0.0.0.0:9120, not 127.0.0.1:9120
```

Set in environment or config:
```bash
export BIND_ADDR=0.0.0.0:9120
```

## Network Requirements

- Desktop and phone must be on the **same local network** (same subnet)
- Wired desktop + wireless phone on same router works fine
- Corporate networks with client isolation may block this

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| QR scans but connection fails | Backend on `127.0.0.1` | Set `BIND_ADDR=0.0.0.0:9120` |
| No QR code on desktop | `_buildNetworkSection` hidden by `!isMobile` check | Verify desktop detection |
| No Scan button on mobile | Platform check cached wrong value | Move check inside `build()` or use getter |
| Camera opens but won't scan | `mobile_scanner` permissions | Grant camera permission in Android settings |
| Black screen after scan | `mobile_scanner` lifecycle bug | Force-stop app, reopen |
| `flutter analyze` fails with `foregroundColor` deprecated | Using old `QrImageView` API | Replace with `eyeStyle` + `dataModuleStyle` |

## Packages

- `qr_flutter: ^4.1.0` — Generate QR codes (works on all platforms)
- `mobile_scanner: ^7.2.0` — Camera-based QR scanning (Android/iOS only)
