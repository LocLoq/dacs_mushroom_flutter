import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/core/network/api_config.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/services/app_preferences_service.dart';
import 'package:thu/core/services/backend_queue_service.dart';
import 'package:thu/core/services/server_connection_service.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/features/settings/presentation/push_settings_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalSession.clear();
    await MockConfig.set(true);
    ApiConfig.useServer('http://192.168.1.12:8080');
  });
  tearDown(() async {
    await BackendQueueService.instance.disconnect();
    LocalSession.clear();
    await MockConfig.set(false);
  });
  test(
    'manual push address accepts LAN IP, API suffix and HTTPS tunnel; rejects unsafe input',
    () {
      expect(
        normalizePushServerAddress('192.168.1.18:8080'),
        'http://192.168.1.18:8080',
      );
      expect(
        normalizePushServerAddress('http://192.168.1.18:8080/api'),
        'http://192.168.1.18:8080',
      );
      expect(
        normalizePushServerAddress('app-8080.eu.devtunnels.ms'),
        'https://app-8080.eu.devtunnels.ms',
      );
      for (final value in [
        '',
        'http://public.example.test',
        'https://user:pass@example.test',
        'https://example.test/other',
      ])
        expect(() => normalizePushServerAddress(value), throwsFormatException);
    },
  );
  testWidgets(
    'guest can save a manually entered IP and it persists with the backend profile',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PushSettingsCard())),
      );
      expect(find.byKey(const Key('push-server-address')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('push-server-address')),
        '192.168.1.18:8080',
      );
      await tester.tap(find.byKey(const Key('save-push-address')));
      await tester.pumpAndSettle();
      expect(ApiConfig.origin, 'http://192.168.1.18:8080');
      expect(
        await AppPreferencesService.instance.urlForMode(PushHostMode.lan),
        'http://192.168.1.18:8080',
      );
      expect(find.text('Đã lưu địa chỉ API và thông báo.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('configuration refresh preserves an IP draft being edited', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PushSettingsCard())),
    );
    await tester.enterText(
      find.byKey(const Key('push-server-address')),
      '192.168.1.99:8080',
    );
    ApiConfig.useServer('https://other.example.test');
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('push-server-address')),
    );
    expect(field.controller!.text, '192.168.1.99:8080');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
