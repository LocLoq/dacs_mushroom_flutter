import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/services/workflow_refresh_service.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/features/audit/audit_log_screen.dart';
import 'package:thu/features/dashboard/dashboard_section.dart';
import 'package:thu/features/manage/presentation/manage_hub_screen.dart';
import 'package:thu/features/users/user_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalSession.clear();
    await MockConfig.set(true);
  });
  tearDown(() async {
    WorkflowRefreshService.instance.stop();
    LocalSession.clear();
    await MockConfig.set(false);
  });

  test(
    'manager assignment scopes recipients and revokes access immediately',
    () async {
      final api = FarmApi();
      final forbidden = throwsA(
        isA<ApiException>().having((e) => e.status, 'status', 403),
      );
      await api.login('admin', 'admin123');
      final roles = (await api.get('/admin/roles'))['data'] as List;
      final staffRole = roles.firstWhere((r) => r['name'] == 'staff')['id'];
      Future<int> employee(String name) async =>
          ((await api.post('/admin/users', {
                    'username': name,
                    'password': 'staff123',
                    'full_name': name,
                    'role_id': staffRole,
                    'email': 'acl@example.test',
                    'phone_number': '0900000000',
                  }))['data']
                  as Map)['id']
              as int;
      final ownStaff = await employee('acl-own-staff');
      final outsideStaff = await employee('acl-outside-staff');
      Future<int> facility(String name) async =>
          ((await api.post('/production-facilities', {
                    'name': name,
                    'address': 'Test',
                    'facilityType': 'HOUSEHOLD',
                    'status': 'ACTIVE',
                  }))['data']
                  as Map)['id']
              as int;
      final own = await facility('ACL managed');
      final outside = await facility('ACL unmanaged');
      await api.post('/production-facilities/$own/staff', {'userId': ownStaff});
      await api.post('/production-facilities/$outside/staff', {
        'userId': outsideStaff,
      });
      final available =
          (await api.get(
                '/production-facilities/$own/managers',
                query: {'available': true},
              ))['data']
              as List;
      expect(available.any((u) => u['id'] == 2), isTrue);
      final grant = await api.post('/production-facilities/$own/managers', {
        'userIds': [2, 2],
      });
      expect(grant['addedCount'], 1);
      expect(
        (await api.get('/production-facilities/$own/managers'))['data'],
        hasLength(1),
      );
      await api.login('manager', 'manager123');
      final candidates =
          (await api.get(
                '/dashboard/task-assignees',
                query: {'limit': 100},
              ))['data']
              as List;
      expect(candidates.any((u) => u['id'] == ownStaff), isTrue);
      expect(candidates.any((u) => u['id'] == outsideStaff), isFalse);
      expect(candidates.every((u) => u['role'] == 'staff'), isTrue);
      await expectLater(
        api.post('/dashboard/tasks', {
          'title': 'Outside',
          'assigneeUserId': outsideStaff,
        }),
        forbidden,
      );
      await expectLater(
        api.post('/dashboard/tasks', {'title': 'Manager', 'assigneeUserId': 2}),
        forbidden,
      );
      await expectLater(
        api.post('/production-facilities/$outside/managers', {'userId': 2}),
        forbidden,
      );
      await expectLater(api.get('/admin/audit-logs'), forbidden);
      await expectLater(api.get('/reports/audit'), forbidden);
      final task =
          (await api.post('/dashboard/tasks', {
                'title': 'Own staff',
                'assigneeUserId': ownStaff,
              }))['data']
              as Map;
      final taskId = task['id'];
      await api.login('admin', 'admin123');
      await api.delete('/production-facilities/$own/managers/2');
      await api.login('manager', 'manager123');
      await expectLater(api.get('/dashboard/tasks/$taskId'), forbidden);
      await expectLater(
        api.patch('/dashboard/tasks/$taskId', {'title': 'Forbidden'}),
        forbidden,
      );
      await expectLater(api.delete('/dashboard/tasks/$taskId'), forbidden);
    },
  );

  testWidgets('manager keeps work tools and cannot see admin dashboard', (
    tester,
  ) async {
    await tester.runAsync(
      () => FarmApi.instance.login('manager', 'manager123'),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ManageHubScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DashboardSection), findsNothing);
    expect(find.text('Nhật ký hệ thống'), findsNothing);
    expect(find.text('Người dùng'), findsNothing);
    expect(find.text('Công việc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin workspace includes dashboard', (tester) async {
    await tester.runAsync(() => FarmApi.instance.login('admin', 'admin123'));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ManageHubScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DashboardSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct admin navigation is blocked for manager and staff', (
    tester,
  ) async {
    for (final role in ['manager', 'staff']) {
      await tester.runAsync(() => FarmApi.instance.login(role, role + '123'));
      for (final screen in [const AuditLogScreen(), const UserListScreen()]) {
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pumpAndSettle();
        expect(
          find.text('Chỉ admin được truy cập chức năng này.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
