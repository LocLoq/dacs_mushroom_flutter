import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/utils/batch_qr.dart';

class BatchQrScannerScreen extends StatefulWidget {
  const BatchQrScannerScreen({super.key});
  @override
  State<BatchQrScannerScreen> createState() => _BatchQrScannerScreenState();
}

class _BatchQrScannerScreenState extends State<BatchQrScannerScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  MobileScannerController? _camera;
  bool _accepted = false;
  String? _error;
  bool get _supported =>
      kIsWeb ||
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_supported) {
      _camera = MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
    }
  }

  Future<void> _startCamera() async {
    if (!mounted || _accepted) return;
    try {
      await _camera?.start();
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Không mở được camera. Kiểm tra quyền camera hoặc nhập mã lô bên dưới. Web cần HTTPS hoặc localhost.',
        );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_camera == null || !_camera!.value.hasCameraPermission || _accepted)
      return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_startCamera());
    } else {
      unawaited(_camera!.stop().catchError((Object _) {}));
    }
  }

  Future<void> _accept(String raw) async {
    if (_accepted) return;
    String code;
    try {
      code = normalizeBatchCode(raw);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    _accepted = true;
    try {
      await _camera?.stop();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    if (_camera != null) unawaited(_camera!.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quét QR lô nuôi trồng')),
    body: Column(
      children: [
        Expanded(
          child: _camera == null
              ? const Center(
                  child: Text('Nhập mã lô để tiếp tục trên thiết bị này.'),
                )
              : MobileScanner(
                  controller: _camera!,
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) {
                        unawaited(_accept(barcode.rawValue!));
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Camera không khả dụng hoặc chưa được cấp quyền. Bạn vẫn có thể nhập mã lô.',
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextField(
                controller: _input,
                maxLength: 191,
                textInputAction: TextInputAction.go,
                onSubmitted: _accept,
                decoration: const InputDecoration(
                  labelText: 'Mã lô',
                  hintText: 'DEMO-BATCH-001',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _accept(_input.text),
                child: const Text('Dùng mã lô'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
