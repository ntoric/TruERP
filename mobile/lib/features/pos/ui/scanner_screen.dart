import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/tokens.dart';

/// Full-screen camera that returns the first barcode it reads.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().where((c) => c.trim().isNotEmpty).firstOrNull;
    if (code == null) return;
    _done = true;
    Navigator.pop(context, code.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan barcode'),
        actions: [
          IconButton(tooltip: 'Torch', icon: const Icon(Icons.flash_on_rounded), onPressed: () => _controller.toggleTorch()),
          IconButton(tooltip: 'Switch camera', icon: const Icon(Icons.cameraswitch_rounded), onPressed: () => _controller.switchCamera()),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Camera permission is off. Allow camera access for TruERP in Settings to scan barcodes.'
                    : 'The camera couldn\'t start (${error.errorCode.name}).',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(Radii.card)),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 48,
          child: Text('Point at a barcode or QR code', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        ),
      ]),
    );
  }
}
