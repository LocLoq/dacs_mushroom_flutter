import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/core/network/api_client.dart' show ApiClient;
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/storage/local_session.dart';
import 'api_client_test.dart' show MemoryTokenStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalSession.clear();
    await MockConfig.set(true);
  });
  tearDown(() async {
    await MockConfig.set(false);
    LocalSession.clear();
  });
  test('mock login and management work offline without sending HTTP', () async {
    var requests = 0;
    final api = FarmApi(
      client: ApiClient(
        baseUrl: 'http://unavailable.example',
        tokenStore: MemoryTokenStore(),
        client: MockClient((_) async {
          requests++;
          throw StateError('No HTTP expected in mock mode');
        }),
      ),
    );
    await api.login('manager', 'manager123');
    expect(LocalSession.role, 'manager');
    expect((await api.get('/cultivation-batches'))['data'], isNotEmpty);
    expect((await api.get('/reports/overview'))['data'], isNotEmpty);
    expect(LocalSession.tokenFor('http://unavailable.example'), isNull);
    expect(requests, 0);
  });
  test(
    'mock permissions are enforced and switching back to live clears the mock session',
    () async {
      final api = FarmApi();
      await api.login('staff', 'staff123');
      await expectLater(
        api.get('/admin/users'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      expect(LocalSession.isLoggedIn, isTrue);
      await MockConfig.set(false);
      expect(LocalSession.isLoggedIn, isFalse);
      expect(await MockConfig.token(), isNull);
    },
  );
  test(
    'fresh installs default to the real backend and explicit mock choice persists',
    () async {
      SharedPreferences.setMockInitialValues({});
      await MockConfig.load();
      expect(MockConfig.enabled, isFalse);
      await MockConfig.set(true);
      await MockConfig.load();
      expect(MockConfig.enabled, isTrue);
    },
  );
}
