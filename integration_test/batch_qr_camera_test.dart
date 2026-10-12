import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thu/features/batch_qr/batch_qr_dialog.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android native camera starts and decodes the exported Unicode batch QR',
    (tester) async {
      final controller = MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
      );
      File? file;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobileScanner(controller: controller, onDetect: (_) {}),
            ),
          ),
        );
        await controller.start();
        expect(controller.value.hasCameraPermission, isTrue);
        expect(controller.value.isInitialized, isTrue);
        await controller.stop();

        const code = 'LO / Đà Lạt #01?%';
        final generated = Completer<Uint8List>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BatchQrDialog(
                batchCode: code,
                savePng: (name, bytes) async {
                  generated.complete(bytes);
                  return null;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu PNG'));
        await tester.pump();
        final bytes = await generated.future.timeout(
          const Duration(seconds: 15),
        );
        file = File(
          '${(await getTemporaryDirectory()).path}/batch-qr-camera-test.png',
        );
        await file.writeAsBytes(bytes);
        final capture = await controller.analyzeImage(file.path);
        expect(capture, isNotNull);
        expect(
          capture!.barcodes.map((barcode) => barcode.rawValue),
          contains(code),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.dispose();
        if (file != null && await file.exists()) await file.delete();
      }
    },
  );
}
