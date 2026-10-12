import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/core/network/api_config.dart';
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/core/utils/batch_qr.dart';
import 'package:thu/features/batch_qr/batch_qr_actions.dart';
import 'package:thu/features/batch_qr/batch_qr_dialog.dart';
import 'package:thu/features/batch_qr/batch_qr_scanner_screen.dart';
import 'package:thu/features/batches/batch_detail_screen.dart';
import 'package:thu/features/public_growth/public_growth_screen.dart';

void desktopTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(
    description,
    callback,
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalSession.clear();
    MockConfig.notifier.value = true;
  });
  tearDown(() {
    LocalSession.clear();
    MockConfig.notifier.value = false;
  });

  test(
    'QR retains the batch code and encodes special characters exactly once',
    () {
      const code = 'LO / Đà Lạt #01?%';
      expect(normalizeBatchCode(' $code '), code);
      for (final invalid in ['', '  ', 'x' * 192]) {
        expect(() => normalizeBatchCode(invalid), throwsFormatException);
      }
      final uri = ApiConfig.fromInput(
        'http://localhost:8080/api',
      ).endpoint('/cultivation-batches/by-code/${Uri.encodeComponent(code)}');
      expect(uri.pathSegments.last, code);
      expect(uri.pathSegments, ['api', 'cultivation-batches', 'by-code', code]);
      expect(batchQrFilename(code), isNot(contains('/')));
    },
  );

  desktopTestWidgets(
    'desktop manual fallback rejects empty codes and returns the trimmed code',
    (tester) async {
      final results = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async => results.add(
                  await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const BatchQrScannerScreen(),
                    ),
                  ),
                ),
                child: const Text('Mở quét'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở quét'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nhập mã lô để tiếp tục trên thiết bị này.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Dùng mã lô'));
      await tester.pumpAndSettle();
      expect(find.text('Mã lô phải dài từ 1 đến 191 ký tự.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' LO-2026-001 ');
      await tester.tap(find.text('Dùng mã lô'));
      await tester.pumpAndSettle();
      expect(results, ['LO-2026-001']);
    },
  );

  for (final saved in [true, false]) {
    desktopTestWidgets(
      'QR export produces a real PNG and handles ${saved ? 'saving' : 'cancellation'}',
      (tester) async {
        Uint8List? exported;
        String? filename;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BatchQrDialog(
                batchCode: 'LO-2026-001',
                savePng: (name, bytes) async {
                  filename = name;
                  exported = bytes;
                  return saved ? 'Downloads/$name.png' : null;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('LO-2026-001'), findsOneWidget);
        await tester.tap(find.text('Lưu PNG'));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pumpAndSettle();
        expect(filename, 'qr-lo-LO-2026-001');
        expect(exported, isNotNull);
        final png = image.decodePng(exported!);
        expect(png, isNotNull);
        expect(png!.width, greaterThan(800));
        expect(png.getPixel(0, 0).r, 255);
        expect(
          find.text('Đã lưu ảnh QR.'),
          saved ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  desktopTestWidgets('public lookup accepts a scanned code without a session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PublicGrowthScreen()));
    await tester.tap(find.text('Quét QR'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'LO-2026-002');
    await tester.tap(find.text('Dùng mã lô'));
    await tester.pumpAndSettle();
    expect(find.text('Giai đoạn hiện tại'), findsOneWidget);
    expect(LocalSession.isLoggedIn, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final action in const {
    'progress': 'Sinh trưởng',
    'care': 'Chăm sóc',
    'harvest': 'Thu hoạch',
  }.entries) {
    desktopTestWidgets(
      'staff scanning opens the correct batch and ${action.value} tab without submitting',
      (tester) async {
        await tester.runAsync(
          () => FarmApi.instance.login('staff', 'staff123'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => scanBatchForUpdate(context),
                  child: const Text('Quét cập nhật'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Quét cập nhật'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'LO-2026-002');
        await tester.tap(find.text('Dùng mã lô'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('Cập nhật lô LO-2026-002'), findsOneWidget);
        await tester.tap(find.text(action.value));
        await tester.pumpAndSettle();
        final detail = tester.widget<BatchDetailScreen>(
          find.byType(BatchDetailScreen),
        );
        expect(detail.batchId, 2);
        expect(detail.initialTab, action.key);
        expect(find.text('Tài chính'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
