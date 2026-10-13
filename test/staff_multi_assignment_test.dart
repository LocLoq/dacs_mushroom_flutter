import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/services/workflow_refresh_service.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/core/widgets/form_sheet.dart';
import 'package:thu/core/utils/json_utils.dart';
import 'package:thu/features/staff/staff_assignment_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalSession.clear();
    await MockConfig.set(true);
    await FarmApi.instance.login('admin', 'admin123');
  });
  tearDown(() async {
    WorkflowRefreshService.instance.stop();
    LocalSession.clear();
    await MockConfig.set(false);
  });
  Future<(String, String, int)> fixture(String name) async {
    final facility =
        (await FarmApi.instance.post('/production-facilities', {
              'name': name,
              'address': 'Test',
              'facilityType': 'HOUSEHOLD',
              'status': 'ACTIVE',
            }))['data']
            as Map;
    final fid = facility['id'] as int;
    final batch =
        (await FarmApi.instance.post('/cultivation-batches', {
              'facilityId': fid,
              'mushroomId': 1,
              'status': 'PREPARATION',
              'startDate': '2026-10-13',
            }))['data']
            as Map;
    return (
      '/production-facilities/$fid/staff',
      '/cultivation-batches/${batch['id']}/staff',
      fid,
    );
  }

  test(
    'mock filters candidates before pagination, accepts legacy and bulk, and rolls back invalid groups',
    () async {
      final (facility, batch, _) = await fixture('Multi mock');
      final first = await FarmApi.instance.post(facility, {'userId': 3});
      expect(first['data'], isA<Map>());
      final available = await FarmApi.instance.get(
        facility,
        query: {'available': true, 'limit': 1},
      );
      expect((available['data'] as List).map((u) => u['id']), [4]);
      expect((available['pagination'] as Map)['totalItems'], 1);
      final added = await FarmApi.instance.post(facility, {
        'userIds': [3, 4, 4],
      });
      expect(added['addedCount'], 1);
      expect((added['data'] as List).length, 2);
      expect(
        (await FarmApi.instance.post(facility, {
          'userIds': [3, 4],
        }))['addedCount'],
        0,
      );
      await FarmApi.instance.delete('$facility/4');
      await expectLater(
        FarmApi.instance.post(batch, {
          'userIds': [3, 4],
        }),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'ASSIGNMENT_INELIGIBLE',
          ),
        ),
      );
      expect((await FarmApi.instance.get(batch))['data'], isEmpty);
      await expectLater(
        FarmApi.instance.post(facility, {
          'userIds': [4, 2],
        }),
        throwsA(isA<ApiException>()),
      );
      expect((await FarmApi.instance.get(facility))['data'], hasLength(1));
      expect(
        (await FarmApi.instance.get(batch, query: {'available': true}))['data'],
        hasLength(1),
      );
    },
  );
  for (final isBatch in [false, true]) {
    testWidgets(
      'staff screen selects two ${isBatch ? 'batch' : 'facility'} employees and hides them when reopened',
      (tester) async {
        final (facility, batch, fid) = (await tester.runAsync(
          () => fixture('Widget ${isBatch ? 'batch' : 'facility'}'),
        ))!;
        if (isBatch)
          await tester.runAsync(
            () => FarmApi.instance.post(facility, {
              'userIds': [3, 4],
            }),
          );
        final path = isBatch ? batch : facility;
        await tester.pumpWidget(
          MaterialApp(
            home: StaffAssignmentScreen(
              path: path,
              title: 'Staff',
              facilityId: isBatch ? fid : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thêm nhân viên'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Xác nhận (0 đã chọn)'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.widgetWithText(ListTile, 'Lê Nhân Viên'));
        await tester.pump();
        await tester.tap(find.widgetWithText(ListTile, 'Phạm Thị Hoa'));
        await tester.pump();
        await tester.tap(find.text('Xác nhận (2 đã chọn)'));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(() => FarmApi.instance.get(path)))!['data'],
          hasLength(2),
        );
        await tester.tap(find.text('Thêm nhân viên'));
        await tester.pumpAndSettle();
        expect(
          find.text('Không còn nhân viên đủ điều kiện để thêm.'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(ListTile),
          ),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  }
  testWidgets(
    'picker preserves choices across pages/search and keeps them on failed save; off-page choice can be removed',
    (tester) async {
      var calls = 0;
      List<int?>? submitted;
      final source = PickerSource(
        title: 'Multi picker',
        fetch: (page, search) async => PageData.from({
          'data': search.isEmpty
              ? [
                  {
                    'id': page,
                    'name': page == 1 ? 'First employee' : 'Second employee',
                  },
                ]
              : <J>[],
          'pagination': {
            'currentPage': page,
            'totalPages': search.isEmpty ? 2 : 0,
            'totalItems': search.isEmpty ? 2 : 0,
            'pageSize': 1,
          },
        }),
        label: (item) => item.s('name'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pickManyFrom(
                  context,
                  source,
                  maxSelected: 100,
                  onConfirm: (items) async {
                    calls++;
                    submitted = items.map((x) => x.i('id')).toList();
                    if (calls == 1)
                      throw const ApiException(
                        400,
                        'Second employee không còn hợp lệ.',
                      );
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'First employee'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Second employee'));
      await tester.pump();
      await tester.tap(find.text('Xác nhận (2 đã chọn)'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(submitted, [1, 2]);
      expect(find.text('Second employee không còn hợp lệ.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no matches');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận (2 đã chọn)'), findsOneWidget);
      final chip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, 'Second employee'),
      );
      chip.onDeleted!();
      await tester.pump();
      await tester.tap(find.text('Xác nhận (1 đã chọn)'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(submitted, [1]);
      expect(find.text('Multi picker'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'picker does not submit twice or close while the request is pending',
    (tester) async {
      final done = Completer<void>();
      var calls = 0;
      final source = PickerSource(
        title: 'Pending picker',
        fetch: (p, s) async => PageData.from({
          'data': [
            {'id': 1, 'name': 'Employee'},
          ],
          'pagination': {
            'currentPage': 1,
            'totalPages': 1,
            'totalItems': 1,
            'pageSize': 20,
          },
        }),
        label: (item) => item.s('name'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pickManyFrom(
                  context,
                  source,
                  onConfirm: (items) {
                    calls++;
                    return done.future;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Employee'));
      await tester.pump();
      await tester.tap(find.text('Xác nhận (1 đã chọn)'));
      await tester.pump();
      expect(calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.close_rounded),
            )
            .onPressed,
        isNull,
      );
      done.complete();
      await tester.pumpAndSettle();
      expect(find.text('Pending picker'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
