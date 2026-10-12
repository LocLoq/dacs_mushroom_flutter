import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/app/theme/app_theme.dart';
import 'package:thu/app/app.dart';
import 'package:thu/app/config/app_constants.dart';
import 'package:thu/core/services/backend_queue_service.dart';
import 'package:thu/core/network/api_client.dart' as transport;
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/features/auth/presentation/change_password_form.dart';
import 'package:thu/features/audit/audit_log_screen.dart';
import 'package:thu/features/batches/progress_tab.dart';

import 'api_client_test.dart' show MemoryTokenStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefBackendConfigured: true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    LocalSession.clear();
    await MockConfig.set(true);
  });
  tearDown(() async {
    LocalSession.clear();
    await MockConfig.set(false);
    await BackendQueueService.instance.disconnect();
  });

  test(
    'mock forced password change survives restore and rotates the token',
    () async {
      final api = FarmApi();
      await api.login('admin', 'admin123');
      final created = await api.post('/admin/users', {
        'username': 'password-feature-test',
        'password': ' old password ',
        'full_name': 'Test',
        'phone_number': '0900',
        'email': 'test@example.test',
        'role_id': 3,
        'must_change_password': true,
      });
      final id = (created['data'] as Map)['id'];
      await api.put('/admin/users/$id', {'full_name': 'Updated'});
      await api.login('password-feature-test', ' old password ');
      expect(LocalSession.mustChangePassword, isTrue);
      expect(LocalSession.isLoggedIn, isFalse);
      final oldToken = LocalSession.token;
      LocalSession.clear();
      await api.restoreSession();
      expect(LocalSession.mustChangePassword, isTrue);
      await expectLater(
        api.get('/cultivation-batches'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'PASSWORD_CHANGE_REQUIRED',
          ),
        ),
      );
      expect(
        (await api.get('/mushroom-species', public: true))['data'],
        isNotEmpty,
      );
      await expectLater(
        api.changePassword('wrong', ' new password '),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
      expect(LocalSession.mustChangePassword, isTrue);
      await api.changePassword(' old password ', ' new password ');
      expect(LocalSession.isLoggedIn, isTrue);
      expect(LocalSession.token, isNot(oldToken));
      LocalSession.setMockToken(oldToken!);
      await expectLater(
        api.get('/auth/me'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      await api.login('password-feature-test', ' new password ');
      expect(LocalSession.mustChangePassword, isFalse);
      await api.login('admin', 'admin123');
      await api.delete('/admin/users/$id');
    },
  );

  test(
    'transport preserves a restricted session and stores replacement token',
    () async {
      await MockConfig.set(false);
      final store = MemoryTokenStore();
      const user = {
        'id': 3,
        'username': 'staff',
        'role': 'staff',
        'must_change_password': false,
      };
      LocalSession.save('old', user, serverOrigin: 'http://localhost:8080');
      final api = transport.ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStore: store,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/change-password')) {
            expect(r.headers['Authorization'], 'Bearer old');
            expect(jsonDecode(r.body), {
              'current_password': ' old ',
              'new_password': ' new ',
            });
            return http.Response(
              jsonEncode({'token': 'replacement', 'data': user}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'code': 'PASSWORD_CHANGE_REQUIRED',
              'message': 'Change password',
            }),
            403,
          );
        }),
      );
      await expectLater(
        api.request('/cultivation-batches'),
        throwsA(isA<transport.ApiException>()),
      );
      expect(LocalSession.mustChangePassword, isTrue);
      expect(LocalSession.token, 'old');
      await api.changePassword(' old ', ' new ');
      expect(LocalSession.isLoggedIn, isTrue);
      expect(LocalSession.token, 'replacement');
      expect(store.value?['token'], 'replacement');
    },
  );

  test(
    'mock automatic codes keep their number after deletion and stay fixed on edit',
    () async {
      final api = FarmApi();
      await api.login('manager', 'manager123');
      const body = {
        'facilityId': 1,
        'mushroomId': 2,
        'status': 'PREPARATION',
        'startDate': '2040-12-31T17:00:00Z',
      };
      final first =
          (await api.post('/cultivation-batches', body))['data'] as Map;
      expect(first['batchCode'], 'LO-CS1-2041-001');
      await api.delete('/cultivation-batches/${first['id']}');
      final second =
          (await api.post('/cultivation-batches', body))['data'] as Map;
      expect(second['batchCode'], 'LO-CS1-2041-002');
      final moved =
          (await api.put('/cultivation-batches/${second['id']}', {
                ...body,
                'facilityId': 2,
                'startDate': '2042-01-01',
              }))['data']
              as Map;
      expect(moved['batchCode'], second['batchCode']);
      await expectLater(
        api.put('/cultivation-batches/${second['id']}', {
          ...body,
          'batchCode': 'manual',
        }),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
      await api.delete('/cultivation-batches/${second['id']}');
    },
  );

  test(
    'a late failure for the old JWT cannot clear the replacement session',
    () async {
      await MockConfig.set(false);
      final response = Completer<http.Response>();
      final sent = Completer<void>();
      final store = MemoryTokenStore();
      LocalSession.save('old', {
        'id': 3,
        'username': 'staff',
        'role': 'staff',
      }, serverOrigin: 'http://localhost:8080');
      final api = transport.ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStore: store,
        client: MockClient((_) {
          sent.complete();
          return response.future;
        }),
      );
      final pending = expectLater(
        api.request('/cultivation-batches'),
        throwsA(isA<transport.ApiException>()),
      );
      await sent.future;
      await store.write('replacement', 'http://localhost:8080');
      LocalSession.save('replacement', {
        'id': 3,
        'username': 'staff',
        'role': 'staff',
      }, serverOrigin: 'http://localhost:8080');
      response.complete(
        http.Response(jsonEncode({'code': 'AUTH_INVALID_TOKEN'}), 401),
      );
      await pending;
      expect(LocalSession.token, 'replacement');
      expect(store.value?['token'], 'replacement');
    },
  );

  testWidgets(
    'password confirmation blocks submission and shows an actionable error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: ChangePasswordForm()),
          ),
        ),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'old');
      await tester.enterText(fields.at(1), 'new');
      await tester.enterText(fields.at(2), 'different');
      await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
      await tester.pump();
      expect(find.text('Xác nhận mật khẩu không khớp.'), findsOneWidget);
    },
  );

  testWidgets(
    'a password requirement closes an open internal route and preserves public navigation',
    (tester) async {
      await tester.pumpWidget(const MushroomApp());
      await tester.pumpAndSettle();
      await tester.runAsync(() => BackendQueueService.instance.disconnect());
      LocalSession.save('mock-staff', {
        'id': 3,
        'username': 'staff',
        'role': 'staff',
        'must_change_password': false,
      }, serverOrigin: 'mock');
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Internal test route')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Internal test route'), findsOneWidget);
      LocalSession.requirePasswordChange();
      await tester.pumpAndSettle();
      expect(find.text('Internal test route'), findsNothing);
      expect(find.byType(ChangePasswordForm), findsOneWidget);
      expect(LocalSession.token, 'mock-staff');
      await tester.tap(find.text('Từ điển'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordForm), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'growth combo preserves custom stages and allows selection and free input',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: GrowthForm(
              path: '/unused',
              record: const {'stage': 'Tơ phủ 80%', 'notes': 'Test'},
            ),
          ),
        ),
      );
      final menu = find.byType(DropdownMenu<String>);
      final dropdown = tester.widget<DropdownMenu<String>>(menu);
      expect(dropdown.controller!.text, 'Tơ phủ 80%');
      expect(dropdown.dropdownMenuEntries.map((e) => e.value), [
        'Chuẩn bị',
        'Ủ tơ',
        'Ra quả thể',
        'Thu hoạch',
        'Kết thúc',
      ]);
      final input = find
          .descendant(of: menu, matching: find.byType(TextField))
          .first;
      await tester.tap(
        find
            .descendant(of: menu, matching: find.byType(IconButton))
            .hitTestable()
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(MenuItemButton, 'Ủ tơ').hitTestable().first,
      );
      await tester.pumpAndSettle();
      expect(dropdown.controller!.text, 'Ủ tơ');
      await tester.enterText(input, 'Kiểm tra tùy chỉnh');
      expect(dropdown.controller!.text, 'Kiểm tra tùy chỉnh');
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'audit detail uses themed Vietnamese text (${dark ? 'dark' : 'light'})',
      (tester) async {
        await tester.runAsync(
          () => FarmApi.instance.login('admin', 'admin123'),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const AuditLogScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('BATCH_CREATE').first);
        await tester.pumpAndSettle();
        final rich = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.textSpan?.toPlainText().startsWith('Người thực hiện:') ==
                    true,
          ),
        );
        expect(rich, findsOneWidget);
        final text = tester.widget<Text>(rich);
        final expected = Theme.of(
          tester.element(find.byType(AlertDialog)),
        ).textTheme.bodyMedium!;
        expect(text.style!.fontFamily, 'BeVietnamPro');
        expect(text.style!.fontSize, expected.fontSize);
        expect(text.style!.color, expected.color);
        expect(text.style!.decoration, isNot(TextDecoration.underline));
      },
    );
  }
}
