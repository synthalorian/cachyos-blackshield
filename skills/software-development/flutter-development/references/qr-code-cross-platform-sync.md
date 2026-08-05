# QR Code Cross-Platform Sync Pattern

## Overview

A reusable pattern for connecting a mobile Flutter app to a desktop/web backend via QR code scanning. The desktop/web displays a QR code containing `IP:PORT`, and the mobile app scans it to auto-configure the backend connection.

## Packages

```yaml
dependencies:
  qr_flutter: ^4.1.0      # Display QR codes
  mobile_scanner: ^6.0.0   # Scan QR codes (mobile only)
```

## Architecture

```
┌─────────────────┐         QR Code          ┌─────────────────┐
│  Desktop/Web    │  ◄─── IP:9120 ─────►  │   Mobile App    │
│  (displays QR)  │                         │  (scans QR)     │
└─────────────────┘                         └─────────────────┘
       ▲                                            │
       │         HTTP API (after config)            │
       └────────────────────────────────────────────┘
```

## Flutter: Display QR Code (Desktop/Web)

```dart
import 'package:qr_flutter/qr_flutter.dart';

QRCodeDisplay(
  data: '192.168.1.100:9120',
  size: 200,
)
```

Widget implementation:
```dart
class QRCodeDisplay extends StatelessWidget {
  final String data;
  final double size;

  const QRCodeDisplay({super.key, required this.data, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      size: size,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }
}
```

## Flutter: Scan QR Code (Mobile)

```dart
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerDialog extends StatefulWidget {
  const QRScannerDialog({super.key});

  @override
  State<QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<QRScannerDialog> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw != null && raw.isNotEmpty) {
      _scanned = true;
      Navigator.of(context).pop(raw); // Returns scanned string
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withAlpha(180), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Parsing Scanned Result

```dart
final result = await Navigator.of(context).push<String>(
  MaterialPageRoute(builder: (_) => const QRScannerDialog()),
);

if (result != null) {
  final parts = result.split(':');
  final host = parts[0];
  final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9120 : 9120;
  
  // Update settings and reconnect
  final settings = context.read<WingmanSettings>();
  await settings.setBackendUrl(host, port);
  
  final backend = context.read<BackendService>();
  backend.setBaseUrl(host, port);
  await backend.reconnect();
}
```

## Web: Display QR with qrcode.js

```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
<div id="qr-container"></div>
<script>
  new QRCode(document.getElementById('qr-container'), {
    text: '192.168.1.100:9120',
    width: 200,
    height: 200,
    colorDark: '#000000',
    colorLight: '#ffffff',
    correctLevel: QRCode.CorrectLevel.M
  });
</script>
```

## Key Design Decisions

1. **Data format is just `IP:PORT`** — no JSON, no URLs, no schemes. Simplest possible string that survives QR encoding.
2. **White background on QR** — ensures readability across all scanner apps
3. **Error correction level M** — balances density and robustness
4. **Mobile scanner uses `firstOrNull`** — handles cases where multiple barcodes are in frame
5. **`_scanned` flag prevents double-pop** — `MobileScanner` can fire multiple detections for the same code

## Pitfalls

- `mobile_scanner` requires camera permissions on Android/iOS — add to `AndroidManifest.xml` and `Info.plist`
- `QrImageView.foregroundColor` is deprecated in newer `qr_flutter` — omit it
- On web, `mobile_scanner` doesn't work — use a file upload + `qr_code_dart` or a different package
- QR data should NOT include `http://` prefix — the mobile app knows the protocol

## Session Reference

Implemented for Hermes Wingman (May 2026):
- Desktop Config screen shows QR with LAN IP:9120
- Mobile Config screen has "Scan" button that opens camera
- Web app sidebar has 📱 button that opens QR modal
- End-to-end: scan → parse → save settings → reconnect → mobile loads backend data
