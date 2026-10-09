import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/core/utils/json_utils.dart';

/// Kiểm tra backend giả (chế độ dữ liệu mẫu) qua đúng lớp FarmApi mà giao diện dùng.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = FarmApi.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MockConfig.set(true);
    await LocalSession.clear();
  });

  Future<void> loginAs(String u, String p) async {
    await LocalSession.clear();
    await api.login(u, p);
  }

  test('đăng nhập sai bị từ chối, đúng thì vào với đúng vai trò', () async {
    await expectLater(api.login('admin', 'sai-mat-khau'), throwsA(isA<ApiException>()));
    expect(LocalSession.isLoggedIn, isFalse);

    await api.login('manager', 'manager123');
    expect(LocalSession.isLoggedIn, isTrue);
    expect(LocalSession.role, 'manager');
  });

  test('staff không xem được báo cáo (403), manager thì xem được', () async {
    await loginAs('staff', 'staff123');
    await expectLater(
      api.get('/reports/overview'),
      throwsA(predicate((e) => e is ApiException && e.status == 403)),
    );
    await loginAs('manager', 'manager123');
    final r = await api.get('/reports/overview');
    expect(r.m('data')?.m('cultivation')?.i('batchCount'), greaterThan(0));
  });

  test('danh sách lô phân trang đúng', () async {
    await loginAs('manager', 'manager123');
    final p1 = PageData.from(await api.get('/cultivation-batches', query: {'page': 1, 'limit': 5}));
    expect(p1.items.length, 5);
    expect(p1.totalItems, greaterThanOrEqualTo(12));
    expect(p1.totalPages, greaterThanOrEqualTo(3));
    final p3 = PageData.from(await api.get('/cultivation-batches', query: {'page': 3, 'limit': 5}));
    expect(p3.items, isNotEmpty);
  });

  test('tạo lô trùng mã trả 409', () async {
    await loginAs('manager', 'manager123');
    await expectLater(
      api.post('/cultivation-batches', {
        'batchCode': 'LO-2026-001',
        'facilityId': 1,
        'mushroomId': 1,
        'status': 'PREPARATION',
        'startDate': DateTime.now().toUtc().toIso8601String(),
      }),
      throwsA(predicate((e) => e is ApiException && e.isConflict)),
    );
  });

  test('tiền được trả dạng chuỗi Decimal', () async {
    await loginAs('manager', 'manager123');
    final s = (await api.get('/cultivation-batches/5/financial-summary')).m('data')!;
    expect(s['revenue'], isA<String>());
    expect(s['totalCost'], isA<String>());
    expect(s['profit'], isA<String>());
  });

  test('luồng công việc: staff gửi minh chứng, manager duyệt', () async {
    await loginAs('staff', 'staff123');
    final tasks = PageData.from(await api.get('/dashboard/tasks', query: {'assigneeUserId': LocalSession.userId}));
    final todo = tasks.items.firstWhere((t) => t.s('status') == 'TODO' && t.i('batchId') != null);
    final id = todo.s('id');

    final cands = PageData.from(await api.get('/dashboard/tasks/$id/evidence-candidates'));
    expect(cands.items, isNotEmpty);
    final c = cands.items.first;
    await api.post('/dashboard/tasks/$id/submissions', {
      'evidence': [
        {'type': c['type'], 'recordId': c['recordId']},
      ],
    });
    var detail = (await api.get('/dashboard/tasks/$id')).m('data')!;
    expect(detail['status'], 'PENDING_REVIEW');

    // Gửi lần nữa khi đang chờ duyệt phải bị chặn (409).
    await expectLater(
      api.post('/dashboard/tasks/$id/submissions', {
        'evidence': [
          {'type': c['type'], 'recordId': c['recordId']},
        ],
      }),
      throwsA(predicate((e) => e is ApiException && e.isConflict)),
    );

    await loginAs('manager', 'manager123');
    final sub = detail.l('submissions').first;
    await api.post('/dashboard/tasks/$id/submissions/${sub.s('id')}/review', {'decision': 'APPROVE'});
    detail = (await api.get('/dashboard/tasks/$id')).m('data')!;
    expect(detail['status'], 'COMPLETED');
  });

  test('tra cứu công khai không cần đăng nhập; mã lạ trả 404', () async {
    final ok = await api.get('/public/cultivation-batches/LO-2026-001/growth-progress/current', public: true);
    expect(ok.m('data')?['batchCode'], 'LO-2026-001');
    await expectLater(
      api.get('/public/cultivation-batches/KHONG-CO/growth-progress/current', public: true),
      throwsA(predicate((e) => e is ApiException && e.status == 404)),
    );
  });
}
