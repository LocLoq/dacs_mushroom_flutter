import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/services/workflow_refresh_service.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/features/batches/care_tab.dart';
import 'package:thu/core/widgets/async_views.dart';

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
    'mock requires both facility membership and batch assignment, scopes tasks, and preserves revoked history',
    () async {
      final api = FarmApi();
      await api.login('admin', 'admin123');
      final facility =
          (await api.post('/production-facilities', {
                'name': 'ACL fixture',
                'address': 'Test',
                'status': 'ACTIVE',
                'facilityType': 'HOUSEHOLD',
              }))['data']
              as Map;
      final fid = facility['id'];
      final batch =
          (await api.post('/cultivation-batches', {
                'facilityId': fid,
                'mushroomId': 1,
                'status': 'PREPARATION',
                'startDate': '2026-10-13',
              }))['data']
              as Map;
      final bid = batch['id'];
      await expectLater(
        api.post('/cultivation-batches/$bid/staff', {'userId': 3}),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
      await api.post('/production-facilities/$fid/staff', {'userId': 3});
      await api.login('staff', 'staff123');
      await expectLater(
        api.get('/cultivation-batches/$bid'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      await api.login('admin', 'admin123');
      await api.post('/cultivation-batches/$bid/staff', {'userId': 3});
      final task =
          (await api.post('/dashboard/tasks', {
                'title': 'Own assigned work',
                'batchId': bid,
                'assigneeUserId': 3,
              }))['data']
              as Map;
      final tid = task['id'];
      await api.login('staff', 'staff123');
      final tasks =
          (await api.get(
                '/dashboard/tasks',
                query: {'status': 'ALL', 'assigneeUserId': 4},
              ))['data']
              as List;
      expect(tasks.every((row) => row['assigneeUserId'] == 3), isTrue);
      final records = await api.multipart(
        'POST',
        '/cultivation-batches/$bid/care-logs',
        fields: {'actionType': 'Kiểm tra giá thể', 'notes': 'Photo proof'},
        files: [
          XFile.fromData(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6ZQAAAABJRU5ErkJggg==',
            ),
            name: 'proof.png',
            mimeType: 'image/png',
          ),
        ],
      );
      final care = records['data'] as Map;
      expect(care['createdByUserId'], 3);
      expect(care['images'], hasLength(1));
      await api.post('/dashboard/tasks/$tid/submissions', {
        'evidence': [
          {'type': 'CARE_LOG', 'recordId': care['id']},
        ],
      });
      final notices = (await api.get('/notifications'))['data'] as List;
      expect(notices, isNotEmpty);
      expect(notices.every((row) => row['userId'] == 3), isTrue);
      final noticeId = notices.first['id'];
      await api.patch('/notifications/$noticeId/read', {});
      await api.login('admin', 'admin123');
      await expectLater(
        api.get('/notifications/$noticeId'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
      await api.delete('/production-facilities/$fid/staff/3');
      expect(
        ((await api.get('/dashboard/tasks/$tid'))['data'] as Map)['status'],
        'PENDING_REVIEW',
      );
      await api.login('staff', 'staff123');
      await expectLater(
        api.get('/dashboard/tasks/$tid'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      await expectLater(
        api.get('/cultivation-batches/$bid'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    },
  );

  testWidgets(
    'care form switches from preset to custom and saves optional photo-free evidence',
    (tester) async {
      final api = FarmApi();
      final bid = await tester.runAsync(() async {
        await api.login('staff', 'staff123');
        final rows = (await api.get('/cultivation-batches'))['data'] as List;
        return rows.first['id'];
      });
      Map<String, dynamic>? created;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CareForm(
                    path: '/cultivation-batches/$bid/care-logs',
                    onCreated: (record) => created = record,
                  ),
                ),
                child: const Text('Mở form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tự nhập').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Theo dõi nhiệt độ',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Đã kiểm tra');
      await tester.ensureVisible(find.text('Lưu'));
      await tester.tap(find.text('Lưu'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(created?['actionType'], 'Theo dõi nhiệt độ');
      expect(created?['images'], isEmpty);
      WorkflowRefreshService.instance.stop();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a permission refresh clears previously loaded private data on 403',
    (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FutureBody<String>(
              refreshResources: const ['tasks'],
              load: () async {
                if (++reads > 1)
                  throw const ApiException(403, 'Quyền đã bị thu hồi');
                return 'Private task details';
              },
              builder: (_, value, _) => Text(value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private task details'), findsOneWidget);
      WorkflowRefreshService.instance.invalidate('permissions');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Private task details'), findsNothing);
      expect(find.text('Quyền đã bị thu hồi'), findsOneWidget);
      WorkflowRefreshService.instance.stop();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'refresh coalesces identical signals and ignores unknown resources',
    () async {
      final service = WorkflowRefreshService();
      final signals = <RefreshSignal>[];
      final subscription = service.events.listen(signals.add);
      service.invalidate('tasks', 'one');
      service.invalidate('tasks', 'one');
      service.invalidate('unknown', 'one');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(signals.length, 1);
      expect(signals.single.resource, 'tasks');
      expect(signals.single.id, 'one');
      service.stop();
      await subscription.cancel();
    },
  );
}
