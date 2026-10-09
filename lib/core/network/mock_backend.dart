import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../storage/local_session.dart';
import '../utils/json_utils.dart';
import 'farm_api.dart';
import 'mock_seed.dart';

/// Backend GIẢ trong bộ nhớ cho chế độ mẫu (xem [MockConfig]). Trả lời đúng
/// định dạng của API thật mà giao diện đang gọi, kể cả phân trang, lọc, phân quyền
/// và các mã lỗi 401/403/404/409/422, để thử toàn bộ luồng UI mà không cần server.
/// Dữ liệu chỉ sống trong phiên chạy của app (mở lại app là về dữ liệu khởi tạo).
class MockBackend {
  MockBackend._() {
    _seed();
  }

  static final MockBackend instance = MockBackend._();

  final List<J> _species = [];
  final List<J> _facilities = [];
  final List<J> _batches = [];
  final List<J> _users = [];
  final List<J> _tasks = [];
  final List<J> _audit = [];
  final List<J> _history = [];
  final Map<int, String> _pw = {};
  final Map<int, List<J>> _care = {};
  final Map<int, List<J>> _harvests = {};
  final Map<int, List<J>> _growth = {};
  final Map<int, List<J>> _expenses = {};
  final Map<int, List<J>> _sales = {};
  final Map<String, List<J>> _images = {};
  int _nextId = 1000;

  int _next() => _nextId++;

  // ───────────────────────── Khởi tạo dữ liệu ─────────────────────────

  J _rec(J m) => {'id': _next(), ...m};

  String _money(double v) => v.toStringAsFixed(2);

  void _seed() {
    _species.addAll(MockSeed.species());
    _facilities.addAll(MockSeed.facilities());
    _users.addAll(MockSeed.users());
    MockSeed.passwords.forEach((k, v) => _pw[k] = v);

    for (final r in MockSeed.batchRows) {
      final (id, code, fac, mush, status, startAgo, expAhead, bags, substrate) = r;
      final closed = status == 'COMPLETED' || status == 'FAILED';
      _batches.add({
        'id': id,
        'batchCode': code,
        'facilityId': fac,
        'mushroomId': mush,
        'status': status,
        'startDate': isoAgo(days: startAgo),
        'expectedHarvestDate': isoAhead(days: expAhead),
        'endDate': closed ? isoAgo(days: max(0, -expAhead - 2)) : null,
        'substrateType': substrate,
        'spawnSource': 'Viện Giống Đà Lạt',
        'bagQuantity': bags,
        'defectRate': status == 'FAILED' ? 38.5 : (2 + (id % 5)).toDouble(),
        'notes': status == 'FAILED' ? 'Nhiễm mốc xanh, loại bỏ toàn bộ lô' : null,
      });

      if (status != 'PREPARATION') {
        _care[id] = [
          _rec({'batchId': id, 'actionType': 'Tưới nước', 'notes': 'Tưới phun sương 2 lần/ngày', 'recordedAt': isoAgo(days: max(1, startAgo - 3))}),
          _rec({'batchId': id, 'actionType': 'Kiểm tra độ ẩm', 'notes': 'Độ ẩm 85–90%, nhiệt độ 24°C', 'recordedAt': isoAgo(days: max(1, startAgo ~/ 2))}),
          _rec({'batchId': id, 'actionType': 'Vệ sinh nhà nấm', 'notes': 'Phun sát khuẩn, dọn bịch hỏng', 'recordedAt': isoAgo(days: 1, hours: id)}),
        ];
        final stage = switch (status) {
          'INCUBATION' => 'Ủ tơ',
          'FRUITING' => 'Ra quả thể',
          'HARVESTING' => 'Thu hoạch',
          'COMPLETED' => 'Hoàn thành',
          _ => 'Nhiễm mốc',
        };
        _growth[id] = [
          _rec({'batchId': id, 'stage': 'Ủ tơ', 'notes': 'Sợi tơ lan khoảng 60% bịch', 'recordedAt': isoAgo(days: max(2, startAgo - 8)), 'images': <J>[]}),
          if (status != 'INCUBATION')
            _rec({'batchId': id, 'stage': stage, 'notes': 'Ghi nhận giai đoạn $stage', 'recordedAt': isoAgo(days: 2), 'images': <J>[]}),
        ];
      }

      if (status == 'HARVESTING' || status == 'COMPLETED') {
        final kgs = status == 'COMPLETED' ? [120.0, 96.5, 80.0] : [38.5, 42.0];
        _harvests[id] = [
          for (var k = 0; k < kgs.length; k++)
            _rec({
              'batchId': id,
              'totalYieldKg': kgs[k],
              'qualityGrade': k == 0 ? 'Loại A' : 'Loại B',
              'harvestedAt': isoAgo(days: 3 + k * 4),
              'notes': 'Đợt thu hoạch ${k + 1}',
            }),
        ];
      }

      final price = 40000.0 + id * 1500;
      _expenses[id] = [
        _rec({'batchId': id, 'name': 'Giống nấm', 'category': 'MATERIAL', 'quantity': '${bags ~/ 20}', 'unit': 'kg', 'unitPrice': _money(price), 'amount': _money(price * (bags ~/ 20)), 'incurredAt': isoAgo(days: startAgo), 'notes': null}),
        _rec({'batchId': id, 'name': 'Mùn cưa', 'category': 'MATERIAL', 'quantity': '300', 'unit': 'kg', 'unitPrice': _money(3500), 'amount': _money(3500.0 * 300), 'incurredAt': isoAgo(days: startAgo), 'notes': null}),
        _rec({'batchId': id, 'name': 'Máy phun sương', 'category': 'TOOL', 'quantity': '1', 'unit': 'cái', 'unitPrice': _money(850000), 'amount': _money(850000), 'incurredAt': isoAgo(days: max(1, startAgo - 2)), 'notes': null}),
      ];

      if (status == 'COMPLETED' || status == 'HARVESTING') {
        final n = status == 'COMPLETED' ? 2 : 1;
        _sales[id] = [
          for (var k = 0; k < n; k++)
            _rec({
              'batchId': id,
              'quantityKg': '${40 + k * 25}',
              'unitPrice': _money(85000),
              'amount': _money(85000.0 * (40 + k * 25)),
              'soldAt': isoAgo(days: 2 + k * 5),
              'buyer': k == 0 ? 'Chợ Đà Lạt' : 'Siêu thị Co.op',
              'notes': null,
            }),
        ];
      }
    }

    String tid(int n) => 'c0a80101-0000-4000-8000-0000000000${n.toString().padLeft(2, '0')}';
    J task(int n, String title, int? batch, int? assignee, String status, {int? due, String? desc}) => {
          'id': tid(n),
          'title': title,
          'description': desc,
          'status': status,
          'batchId': batch,
          'assigneeUserId': assignee,
          'dueAt': due == null ? null : isoAhead(days: due),
          'createdAt': isoAgo(days: 6),
          'submissions': <J>[],
        };
    _tasks.addAll([
      task(1, 'Tưới nước và kiểm tra độ ẩm lô LO-2026-002', 2, 3, 'TODO', due: 1, desc: 'Giữ độ ẩm 85–90%, ghi lại nhiệt độ.'),
      task(2, 'Thu hoạch đợt 3 lô LO-2026-001', 1, 3, 'IN_PROGRESS', due: 2),
      task(3, 'Phun sát khuẩn nhà nấm số 2', null, 4, 'TODO', due: 3),
      task(4, 'Ghi nhận sinh trưởng lô LO-2026-003', 3, 3, 'PENDING_REVIEW', due: 1),
      task(5, 'Chuẩn bị giá thể cho lô LO-2026-011', 11, 4, 'IN_PROGRESS', due: 5),
      task(6, 'Kiểm kê vật tư cuối tháng', null, null, 'TODO', due: 10),
      task(7, 'Thu hoạch lô LO-2026-005', 5, 3, 'COMPLETED', due: -20),
      task(8, 'Xử lý lô nhiễm mốc LO-2026-006', 6, 4, 'CANCELLED', due: -15),
    ]);
    final g3 = _growth[3]!.first;
    final c3 = _care[3]!.first;
    _tasks[3]['submissions'] = [
      {
        'id': 'sub-seed-1',
        'status': 'PENDING',
        'submittedAt': isoAgo(hours: 3),
        'submittedByUserId': 3,
        'notes': 'Đã ghi sinh trưởng và chăm sóc hôm nay.',
        'reviewedAt': null,
        'reviewedByUserId': null,
        'reason': null,
        'evidence': [
          {'type': 'GROWTH_PROGRESS', 'recordId': g3['id'], 'record': g3},
          {'type': 'CARE_LOG', 'recordId': c3['id'], 'record': c3},
        ],
      }
    ];

    const actions = [
      ('LOGIN', 'USER', 'POST', '/login'),
      ('BATCH_CREATE', 'CULTIVATION_BATCH', 'POST', '/cultivation-batches'),
      ('BATCH_UPDATE', 'CULTIVATION_BATCH', 'PUT', '/cultivation-batches/3'),
      ('CARE_LOG_CREATE', 'CARE_LOG', 'POST', '/cultivation-batches/2/care-logs'),
      ('HARVEST_CREATE', 'HARVEST', 'POST', '/cultivation-batches/1/harvests'),
      ('TASK_CREATE', 'TASK', 'POST', '/dashboard/tasks'),
      ('TASK_SUBMIT', 'TASK', 'POST', '/dashboard/tasks/4/submissions'),
      ('SPECIES_UPDATE', 'MUSHROOM_SPECIES', 'PUT', '/mushroom-species/2'),
      ('USER_CREATE', 'USER', 'POST', '/admin/users'),
      ('REPORT_EXPORT', 'REPORT', 'GET', '/reports/financial/export'),
    ];
    for (var i = 0; i < 60; i++) {
      final a = actions[i % actions.length];
      final u = _users[i % _users.length];
      final fail = i % 7 == 6;
      _audit.add({
        'id': _next(),
        'action': a.$1,
        'entityType': a.$2,
        'entityId': '${1 + i % 12}',
        'outcome': fail ? 'FAILURE' : 'SUCCESS',
        'statusCode': fail ? (i % 2 == 0 ? 403 : 422) : (a.$3 == 'POST' ? 201 : 200),
        'actorUserId': u['id'],
        'actorUsername': u['username'],
        'actorRole': _roleName(u.i('role_id')),
        'method': a.$3,
        'path': a.$4,
        'durationMs': 20 + (i * 13) % 180,
        'createdAt': isoAgo(hours: i * 9),
      });
    }

    for (var i = 0; i < 14; i++) {
      final sp = _species[(i * 3) % _species.length];
      final failed = i % 7 == 3;
      final queued = i == 0;
      final deadly = sp.s('edibilityStatus') == 'DEADLY';
      _history.add({
        'id': 'h0000000-0000-4000-8000-0000000000${(i + 1).toString().padLeft(2, '0')}',
        'originalName': 'anh_nam_${i + 1}.jpg',
        'mimeType': 'image/jpeg',
        'fileSize': 180000 + i * 12345,
        'status': queued ? 'QUEUED' : (failed ? 'FAILED' : 'SUCCEEDED'),
        'predictedName': (queued || failed) ? null : sp.s('commonName'),
        'scientificName': (queued || failed) ? null : sp.s('scientificName'),
        'edibility': (queued || failed) ? 'UNKNOWN' : (deadly ? 'POISONOUS' : 'NON_POISONOUS'),
        'confidence': (queued || failed) ? null : 0.62 + (i * 0.027) % 0.36,
        'errorMessage': failed ? 'Ảnh quá mờ để nhận diện' : null,
        'userId': 3 + i % 2,
        'queuedAt': isoAgo(days: i, hours: 1),
        'completedAt': (queued) ? null : isoAgo(days: i),
        'createdAt': isoAgo(days: i, hours: 1),
      });
    }
  }

  // ───────────────────────── Tiện ích chung ─────────────────────────

  ApiException _err(int s, String m, [String? c]) => ApiException(s, m, c);

  String _roleName(int? id) => MockSeed.roles.firstWhere((r) => r.$1 == id, orElse: () => (0, '')).$2;

  /// Người dùng của token hiện tại. Token sai/hết hạn -> 401 và xóa phiên (giống server thật).
  J _me() {
    final t = LocalSession.token;
    final found = _users.where((u) => 'mock-${u.s('username')}' == t).toList();
    if (found.isEmpty) {
      LocalSession.clear();
      throw _err(401, 'Token không hợp lệ hoặc đã hết hạn.', 'AUTH_INVALID_TOKEN');
    }
    return found.first;
  }

  String _role() => _roleName(_me().i('role_id'));

  void _need(List<String> roles) {
    if (!roles.contains(_role())) {
      throw _err(403, 'Bạn không có quyền thực hiện thao tác này.', 'AUTH_FORBIDDEN');
    }
  }

  void _req(J b, List<String> keys) {
    final miss = keys.where((k) => b[k] == null || b[k].toString().trim().isEmpty).toList();
    if (miss.isNotEmpty) {
      throw _err(422, 'Thiếu hoặc sai dữ liệu: ${miss.join(', ')}.', 'VALIDATION_ERROR');
    }
  }

  void _log(String action, String entityType, Object? entityId, {bool ok = true}) {
    try {
      final u = _me();
      _audit.insert(0, {
        'id': _next(),
        'action': action,
        'entityType': entityType,
        'entityId': '$entityId',
        'outcome': ok ? 'SUCCESS' : 'FAILURE',
        'statusCode': ok ? 200 : 422,
        'actorUserId': u['id'],
        'actorUsername': u['username'],
        'actorRole': _roleName(u.i('role_id')),
        'method': 'POST',
        'path': '/mock',
        'durationMs': 12,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Bọc danh sách theo envelope { data, pagination }.
  J _env(List<J> items, J q, {int defLimit = 10}) {
    final limit = (int.tryParse('${q['limit'] ?? ''}') ?? defLimit).clamp(1, 100).toInt();
    final page = (int.tryParse('${q['page'] ?? ''}') ?? 1).clamp(1, 1 << 20).toInt();
    final total = items.length;
    final pages = total == 0 ? 0 : (total / limit).ceil();
    final start = (page - 1) * limit;
    final slice = start >= total ? <J>[] : items.sublist(start, min(start + limit, total));
    return {
      'data': slice,
      'pagination': {'currentPage': page, 'totalPages': pages, 'totalItems': total, 'itemsPerPage': limit},
    };
  }

  bool _inRange(String? iso, String? from, String? to) {
    final t = DateTime.tryParse(iso ?? '')?.toUtc();
    if (t == null) return false;
    final f = (from == null || from.isEmpty) ? null : DateTime.tryParse(from)?.toUtc();
    var e = (to == null || to.isEmpty) ? null : DateTime.tryParse(to)?.toUtc();
    if (e != null && to!.length == 10) e = e.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    if (f != null && t.isBefore(f)) return false;
    if (e != null && t.isAfter(e)) return false;
    return true;
  }

  String _per(String iso, String groupBy) => iso.substring(0, groupBy == 'day' ? 10 : 7);

  List<J> _desc(List<J> l, String key) => List<J>.from(l)..sort((a, b) => b.s(key).compareTo(a.s(key)));

  // ───────────────────────── Điểm vào ─────────────────────────

  Future<J> handle(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    Map<String, String> fields = const {},
    List<XFile> files = const [],
    bool public = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220)); // mô phỏng độ trễ mạng
    final s = path.split('/').where((e) => e.isNotEmpty).toList();
    final q = <String, dynamic>{...?query};
    final b = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final out = _route(method, s, q, b, fields, files);
    return jsonDecode(jsonEncode(out)) as Map<String, dynamic>; // bản sao sâu, giống dữ liệu qua mạng
  }

  J _route(String m, List<String> s, J q, J b, Map<String, String> f, List<XFile> files) {
    if (s.isEmpty) throw _err(404, 'Không tìm thấy đường dẫn.');
    switch (s[0]) {
      case 'login':
        return _login(b);
      case 'auth':
        final u = _me();
        return {'data': {'id': u['id'], 'username': u['username'], 'full_name': u['full_name'], 'role': _roleName(u.i('role_id'))}};
      case 'public':
        return _publicGrowth(s);
      case 'cultivation-batches':
        return _batchesRoute(m, s, q, b, f, files);
      case 'mushroom-species':
        return _speciesRoute(m, s, q, b, f, files);
      case 'production-facilities':
        return _facilitiesRoute(m, s, q, b, f, files);
      case 'dashboard':
        return _dashboardRoute(m, s, q, b);
      case 'admin':
        return _adminRoute(m, s, q, b);
      case 'reports':
        if (s.length < 2) throw _err(404, 'Không tìm thấy đường dẫn.');
        return _report(s[1], q);
      case 'mushroom-classifier':
        return _classifierRoute(s, q);
    }
    throw _err(404, 'Không tìm thấy đường dẫn.');
  }

  J _login(J b) {
    final name = (b['username'] ?? '').toString().trim();
    final pass = (b['password'] ?? '').toString();
    final found = _users.where((u) => u.s('username') == name).toList();
    if (found.isEmpty || _pw[found.first.i('id')] != pass) {
      throw _err(401, 'Sai tên đăng nhập hoặc mật khẩu.', 'AUTH_INVALID_CREDENTIALS');
    }
    final u = found.first;
    return {
      'token': 'mock-$name',
      'data': {'id': u['id'], 'username': name, 'full_name': u['full_name'], 'role': _roleName(u.i('role_id'))},
    };
  }

  // ───────────────────────── Thư viện ảnh (S19) ─────────────────────────

  List<J> _imgList(String res, int id) => _images.putIfAbsent('$res:$id', () => <J>[]);

  J _imgMeta(String res, int id) {
    final l = _imgList(res, id);
    final cover = l.where((e) => e['isCover'] == true).toList();
    return {'coverImageUrl': cover.isEmpty ? null : cover.first['imageUrl'], 'imageCount': l.length};
  }

  J _gallery(String res, int id, String m, List<String> rest, J q, J b, Map<String, String> f, List<XFile> files) {
    final list = _imgList(res, id);
    if (rest.isEmpty) {
      if (m == 'GET') return _env(List<J>.from(list), q);
      if (m == 'POST') {
        _need(['admin', 'manager']);
        if (files.isEmpty || files.length > 5) throw _err(422, 'Chọn từ 1 đến 5 ảnh.', 'VALIDATION_ERROR');
        final cap = f['caption'];
        final created = <J>[];
        for (final x in files) {
          final nid = _next();
          created.add({
            'id': nid,
            'imageUrl': '/uploads/mock/$nid.jpg', // ảnh mẫu không có file thật nên giao diện hiện placeholder
            'caption': (cap == null || cap.isEmpty) ? null : cap,
            'isCover': list.isEmpty && created.isEmpty,
            'originalName': x.name,
          });
        }
        list.addAll(created);
        _log('IMAGE_UPLOAD', res, id);
        return {'data': created};
      }
    } else {
      final imgId = int.tryParse(rest[0]);
      final idx = list.indexWhere((e) => e.i('id') == imgId);
      if (idx < 0) throw _err(404, 'Không tìm thấy ảnh.');
      if (m == 'PATCH') {
        _need(['admin', 'manager']);
        if (b.containsKey('caption')) list[idx]['caption'] = b['caption'];
        if (b['isCover'] == true) {
          for (final e in list) {
            e['isCover'] = false;
          }
          list[idx]['isCover'] = true;
        }
        return {'data': list[idx]};
      }
      if (m == 'DELETE') {
        _need(['admin', 'manager']);
        final wasCover = list[idx]['isCover'] == true;
        list.removeAt(idx);
        if (wasCover && list.isNotEmpty) list.first['isCover'] = true;
        return {'message': 'Đã xóa ảnh'};
      }
    }
    throw _err(405, 'Phương thức không được hỗ trợ.');
  }

  // ───────────────────────── Giống nấm (S08) ─────────────────────────

  J _speciesOut(J x) => {...x, ..._imgMeta('mushroom-species', x.i('id')!), 'imageUrl': null};

  J _speciesRoute(String m, List<String> s, J q, J b, Map<String, String> f, List<XFile> files) {
    _me();
    if (s.length == 1) {
      if (m == 'GET') {
        final se = '${q['search'] ?? ''}'.toLowerCase();
        final l = _species
            .where((x) => se.isEmpty || ['commonName', 'scientificName', 'family', 'genus'].any((k) => x.s(k).toLowerCase().contains(se)))
            .map(_speciesOut)
            .toList();
        return _env(l, q);
      }
      if (m == 'POST') {
        _need(['admin', 'manager']);
        _req(b, ['commonName', 'scientificName', 'family', 'genus', 'edibilityStatus']);
        final x = <String, dynamic>{'id': _next()};
        _copy(x, b, _speciesKeys);
        _species.add(x);
        _log('SPECIES_CREATE', 'MUSHROOM_SPECIES', x['id']);
        return {'data': _speciesOut(x)};
      }
    }
    final id = int.tryParse(s[1]);
    final i = _species.indexWhere((x) => x.i('id') == id);
    if (i < 0) throw _err(404, 'Không tìm thấy giống nấm.');
    if (s.length == 2) {
      if (m == 'GET') return {'data': _speciesOut(_species[i])};
      _need(['admin', 'manager']);
      if (m == 'PUT') {
        _req(b, ['commonName', 'scientificName', 'family', 'genus', 'edibilityStatus']);
        _copy(_species[i], b, _speciesKeys);
        _log('SPECIES_UPDATE', 'MUSHROOM_SPECIES', id);
        return {'data': _speciesOut(_species[i])};
      }
      if (m == 'DELETE') {
        if (_batches.any((x) => x.i('mushroomId') == id)) {
          throw _err(409, 'Giống nấm đang được sử dụng bởi lô nuôi, không thể xóa.', 'CONFLICT');
        }
        _species.removeAt(i);
        _images.remove('mushroom-species:$id');
        _log('SPECIES_DELETE', 'MUSHROOM_SPECIES', id);
        return {'message': 'Đã xóa'};
      }
    }
    if (s.length < 3) throw _err(405, 'Phương thức không được hỗ trợ.');
    if (s[2] == 'images') return _gallery('mushroom-species', id!, m, s.sublist(3), q, b, f, files);
    throw _err(404, 'Không tìm thấy đường dẫn.');
  }

  static const _speciesKeys = [
    'commonName', 'scientificName', 'family', 'genus', 'edibilityStatus', 'cultivationDifficulty', 'ecologyType',
    'otherNames', 'habitat', 'fruitingSeason', 'capDescription', 'gillsDescription', 'stemDescription',
    'sporePrintColor', 'bruisingBehavior', 'toxicitySymptoms', 'medicinalProperties',
  ];

  /// Chỉ chép các field nằm trong allowlist; null được giữ để xóa giá trị.
  void _copy(J dst, J src, List<String> keys) {
    for (final k in keys) {
      if (src.containsKey(k)) dst[k] = src[k];
    }
  }

  // ───────────────────────── Cơ sở (S09) ─────────────────────────

  J _facilityOut(J x, {bool detail = false}) {
    final ids = (x['mushroom_ids'] as List).cast<int>();
    final mush = _species.where((sp) => ids.contains(sp.i('id'))).map((sp) => {'id': sp['id'], 'commonName': sp['commonName']}).toList();
    final out = {...x, ..._imgMeta('production-facilities', x.i('id')!), 'mushrooms': mush};
    out.remove('mushroom_ids');
    return out;
  }

  static const _facilityKeys = [
    'name', 'address', 'province', 'facilityType', 'status', 'taxCode', 'contactPhone', 'contactEmail',
    'capacityTonsPerYear', 'totalAreaSqm', 'certifications',
  ];

  J _facilitiesRoute(String m, List<String> s, J q, J b, Map<String, String> f, List<XFile> files) {
    _me();
    if (s.length == 1) {
      if (m == 'GET') {
        final se = '${q['search'] ?? ''}'.toLowerCase();
        final l = _facilities
            .where((x) => se.isEmpty || ['name', 'address', 'province', 'taxCode'].any((k) => x.s(k).toLowerCase().contains(se)))
            .map((x) => _facilityOut(x))
            .toList();
        return _env(l, q);
      }
      if (m == 'POST') {
        _need(['admin', 'manager']);
        _req(b, ['name', 'address', 'facilityType', 'status']);
        final x = <String, dynamic>{'id': _next(), 'mushroom_ids': <int>[]};
        _copy(x, b, _facilityKeys);
        if (b['mushrooms'] is List) x['mushroom_ids'] = (b['mushrooms'] as List).map((e) => (e as num).toInt()).toList();
        _facilities.add(x);
        _log('FACILITY_CREATE', 'PRODUCTION_FACILITY', x['id']);
        return {'data': _facilityOut(x)};
      }
    }
    final id = int.tryParse(s[1]);
    final i = _facilities.indexWhere((x) => x.i('id') == id);
    if (i < 0) throw _err(404, 'Không tìm thấy cơ sở.');
    if (s.length == 2) {
      if (m == 'GET') return {'data': _facilityOut(_facilities[i], detail: true)};
      _need(['admin', 'manager']);
      if (m == 'PUT') {
        _req(b, ['name', 'address', 'facilityType', 'status']);
        _copy(_facilities[i], b, _facilityKeys);
        if (b['mushrooms'] is List) {
          _facilities[i]['mushroom_ids'] = (b['mushrooms'] as List).map((e) => (e as num).toInt()).toList();
        }
        _log('FACILITY_UPDATE', 'PRODUCTION_FACILITY', id);
        return {'data': _facilityOut(_facilities[i], detail: true)};
      }
      if (m == 'DELETE') {
        if (_batches.any((x) => x.i('facilityId') == id)) {
          throw _err(409, 'Cơ sở đang có lô nuôi, không thể xóa.', 'CONFLICT');
        }
        _facilities.removeAt(i);
        _images.remove('production-facilities:$id');
        _log('FACILITY_DELETE', 'PRODUCTION_FACILITY', id);
        return {'message': 'Đã xóa'};
      }
    }
    if (s.length < 3) throw _err(405, 'Phương thức không được hỗ trợ.');
    if (s[2] == 'images') return _gallery('production-facilities', id!, m, s.sublist(3), q, b, f, files);
    throw _err(404, 'Không tìm thấy đường dẫn.');
  }

  // ───────────────────────── Lô nuôi (S03–S07, S18) ─────────────────────────

  J _batchOut(J x, {bool detail = false}) {
    final sp = _species.where((e) => e.i('id') == x.i('mushroomId')).toList();
    final fa = _facilities.where((e) => e.i('id') == x.i('facilityId')).toList();
    final out = <String, dynamic>{
      ...x,
      ..._imgMeta('cultivation-batches', x.i('id')!),
      'mushroom': sp.isEmpty ? null : {'id': sp.first['id'], 'commonName': sp.first['commonName'], 'scientificName': sp.first['scientificName']},
      'facility': fa.isEmpty ? null : {'id': fa.first['id'], 'name': fa.first['name'], 'province': fa.first['province']},
    };
    if (detail) {
      final hv = _harvests[x.i('id')] ?? [];
      out['actualYieldKg'] = hv.isEmpty ? null : hv.fold<double>(0, (a, e) => a + (e.d('totalYieldKg') ?? 0));
    }
    return out;
  }

  static const _batchKeys = [
    'batchCode', 'facilityId', 'mushroomId', 'status', 'startDate', 'expectedHarvestDate', 'endDate',
    'substrateType', 'spawnSource', 'bagQuantity', 'defectRate', 'notes',
  ];

  J _batchSave(J? existing, J b) {
    _req(b, ['batchCode', 'facilityId', 'mushroomId', 'status', 'startDate']);
    final code = b['batchCode'].toString().trim();
    if (_batches.any((x) => x.s('batchCode') == code && x != existing)) {
      throw _err(409, 'Mã lô "$code" đã tồn tại.', 'CONFLICT');
    }
    if (!_facilities.any((x) => x.i('id') == (b['facilityId'] as num?)?.toInt())) throw _err(422, 'Cơ sở không tồn tại.', 'VALIDATION_ERROR');
    if (!_species.any((x) => x.i('id') == (b['mushroomId'] as num?)?.toInt())) throw _err(422, 'Giống nấm không tồn tại.', 'VALIDATION_ERROR');
    final x = existing ?? <String, dynamic>{'id': _next()};
    _copy(x, b, _batchKeys);
    if (existing == null) _batches.add(x);
    _log(existing == null ? 'BATCH_CREATE' : 'BATCH_UPDATE', 'CULTIVATION_BATCH', x['id']);
    return {'data': _batchOut(x, detail: true)};
  }

  J _batchesRoute(String m, List<String> s, J q, J b, Map<String, String> f, List<XFile> files) {
    _me();
    if (s.length == 1) {
      if (m == 'GET') {
        final st = q['status']?.toString();
        final fac = int.tryParse('${q['facilityId'] ?? ''}');
        final mu = int.tryParse('${q['mushroomId'] ?? ''}');
        final se = '${q['search'] ?? ''}'.toLowerCase();
        final l = _desc(
          _batches
              .where((x) =>
                  (st == null || x['status'] == st) &&
                  (fac == null || x.i('facilityId') == fac) &&
                  (mu == null || x.i('mushroomId') == mu) &&
                  (se.isEmpty || x.s('batchCode').toLowerCase().contains(se)))
              .toList(),
          'startDate',
        );
        return _env(l.map((x) => _batchOut(x)).toList(), q);
      }
      if (m == 'POST') {
        _need(['admin', 'manager']);
        return _batchSave(null, b);
      }
    }
    final id = int.tryParse(s[1]);
    final bi = _batches.indexWhere((x) => x.i('id') == id);
    if (bi < 0) throw _err(404, 'Không tìm thấy lô nuôi.');
    final batch = _batches[bi];
    if (s.length == 2) {
      if (m == 'GET') return {'data': _batchOut(batch, detail: true)};
      if (m == 'PUT') return _batchSave(batch, b);
      if (m == 'DELETE') {
        _need(['admin', 'manager']);
        _batches.removeAt(bi);
        for (final mp in [_care, _harvests, _growth, _expenses, _sales]) {
          mp.remove(id);
        }
        _images.remove('cultivation-batches:$id');
        _log('BATCH_DELETE', 'CULTIVATION_BATCH', id);
        return {'message': 'Đã xóa lô'};
      }
    }
    if (s.length < 3) throw _err(405, 'Phương thức không được hỗ trợ.');
    final bid = id!;
    switch (s[2]) {
      case 'images':
        return _gallery('cultivation-batches', bid, m, s.sublist(3), q, b, f, files);
      case 'care-logs':
        return _careRoute(m, bid, q, b);
      case 'harvests':
        return _harvestRoute(m, bid, q, b, batch);
      case 'growth-progress':
        return _growthRoute(m, s, bid, q, f, files);
      case 'financial-summary':
        _need(['admin', 'manager']);
        return {'data': _financeSummary(bid)};
      case 'expenses':
        _need(['admin', 'manager']);
        return _entryRoute(m, s, bid, q, b, _expenses, 'incurredAt');
      case 'sales':
        _need(['admin', 'manager']);
        return _entryRoute(m, s, bid, q, b, _sales, 'soldAt');
    }
    throw _err(404, 'Không tìm thấy đường dẫn.');
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  J _careRoute(String m, int bid, J q, J b) {
    final l = _care.putIfAbsent(bid, () => <J>[]);
    if (m == 'GET') return {'data': _desc(l, 'recordedAt')};
    _req(b, ['actionType', 'notes']);
    final r = _rec({'batchId': bid, 'actionType': b['actionType'].toString().trim(), 'notes': b['notes'].toString().trim(), 'recordedAt': b['recordedAt'] ?? _nowIso()});
    l.add(r);
    _log('CARE_LOG_CREATE', 'CARE_LOG', r['id']);
    return {'data': r};
  }

  J _harvestRoute(String m, int bid, J q, J b, J batch) {
    final l = _harvests.putIfAbsent(bid, () => <J>[]);
    if (m == 'GET') return {'data': _desc(l, 'harvestedAt')};
    final kg = (b['totalYieldKg'] as num?)?.toDouble();
    if (kg == null || kg < 0) throw _err(422, 'Sản lượng phải là số không âm.', 'VALIDATION_ERROR');
    final r = _rec({
      'batchId': bid,
      'totalYieldKg': kg,
      'qualityGrade': b['qualityGrade'],
      'harvestedAt': b['harvestedAt'] ?? _nowIso(),
      'notes': b['notes'],
    });
    l.add(r);
    // Trạng thái lô do "server" quyết định.
    if (b['finalizeBatch'] == true) {
      batch['status'] = 'COMPLETED';
      batch['endDate'] = _nowIso();
    } else if (!['HARVESTING', 'COMPLETED', 'FAILED'].contains(batch['status'])) {
      batch['status'] = 'HARVESTING';
    }
    _log('HARVEST_CREATE', 'HARVEST', r['id']);
    return {'data': r};
  }

  List<J> _newImages(List<XFile> files) => [
        for (final x in files) {'id': _next(), 'imageUrl': '/uploads/mock/${_nextId}.jpg', 'originalName': x.name},
      ];

  J _growthRoute(String m, List<String> s, int bid, J q, Map<String, String> f, List<XFile> files) {
    final l = _growth.putIfAbsent(bid, () => <J>[]);
    if (m == 'GET') return {'data': _desc(l, 'recordedAt')};
    if (files.length > 5) throw _err(422, 'Tối đa 5 ảnh mỗi lần.', 'VALIDATION_ERROR');
    if (m == 'POST') {
      _req(f.map((k, v) => MapEntry(k, v as dynamic)), ['stage', 'notes']);
      final r = _rec({
        'batchId': bid,
        'stage': f['stage']!.trim(),
        'notes': f['notes']!.trim(),
        'recordedAt': f['recordedAt'] ?? _nowIso(),
        'images': _newImages(files),
      });
      l.add(r);
      _log('GROWTH_CREATE', 'GROWTH_PROGRESS', r['id']);
      return {'data': r};
    }
    // PATCH: cập nhật field và THÊM ảnh mới, không xóa ảnh cũ.
    final rid = int.tryParse(s.length > 3 ? s[3] : '');
    final i = l.indexWhere((e) => e.i('id') == rid);
    if (i < 0) throw _err(404, 'Không tìm thấy bản ghi sinh trưởng.');
    if (f.containsKey('stage')) l[i]['stage'] = f['stage'];
    if (f.containsKey('notes')) l[i]['notes'] = f['notes'];
    if (f.containsKey('recordedAt')) l[i]['recordedAt'] = f['recordedAt'];
    (l[i]['images'] as List).addAll(_newImages(files));
    return {'data': l[i]};
  }

  J _entryRoute(String m, List<String> s, int bid, J q, J b, Map<int, List<J>> store, String dateKey) {
    final l = store.putIfAbsent(bid, () => <J>[]);
    final isExp = identical(store, _expenses);
    final reqKeys = isExp ? ['name', 'category', 'quantity', 'unit', 'unitPrice'] : ['quantityKg', 'unitPrice'];
    final keys = isExp
        ? ['name', 'category', 'quantity', 'unit', 'unitPrice', 'incurredAt', 'notes']
        : ['quantityKg', 'unitPrice', 'soldAt', 'buyer', 'notes'];
    double amount(J r) => (double.tryParse(r.s(isExp ? 'quantity' : 'quantityKg')) ?? 0) * (double.tryParse(r.s('unitPrice')) ?? 0);
    if (s.length == 3) {
      if (m == 'GET') return _env(_desc(l, dateKey), q);
      _req(b, reqKeys);
      final r = _rec({'batchId': bid, dateKey: b[dateKey] ?? _nowIso()});
      _copy(r, b, keys);
      r['amount'] = _money(amount(r));
      l.add(r);
      _log(isExp ? 'EXPENSE_CREATE' : 'SALE_CREATE', isExp ? 'EXPENSE' : 'SALE', r['id']);
      return {'data': r};
    }
    final eid = int.tryParse(s[3]);
    final i = l.indexWhere((e) => e.i('id') == eid);
    if (i < 0) throw _err(404, 'Không tìm thấy bản ghi.');
    if (m == 'PATCH') {
      _copy(l[i], b, keys); // chỉ field trong allowlist, amount do server tính lại
      l[i]['amount'] = _money(amount(l[i]));
      return {'data': l[i]};
    }
    if (m == 'DELETE') {
      l.removeAt(i);
      return {'message': 'Đã xóa'};
    }
    throw _err(405, 'Phương thức không được hỗ trợ.');
  }

  double _sum(List<J>? l, String k) => (l ?? []).fold<double>(0, (a, e) => a + (double.tryParse(e.s(k)) ?? e.d(k) ?? 0));

  J _financeSummary(int bid) {
    final harvest = _sum(_harvests[bid], 'totalYieldKg');
    final sold = _sum(_sales[bid], 'quantityKg');
    final revenue = _sum(_sales[bid], 'amount');
    final cost = _sum(_expenses[bid], 'amount');
    final profit = revenue - cost;
    final byCat = <String, double>{};
    for (final e in _expenses[bid] ?? <J>[]) {
      byCat[e.s('category')] = (byCat[e.s('category')] ?? 0) + (double.tryParse(e.s('amount')) ?? 0);
    }
    return {
      'totalHarvestKg': harvest,
      'totalSoldKg': sold,
      'revenue': _money(revenue),
      'totalCost': _money(cost),
      'profit': _money(profit),
      'profitMarginPercent': revenue > 0 ? _money(profit / revenue * 100) : null,
      'costPerHarvestKg': harvest > 0 ? _money(cost / harvest) : null,
      'costsByCategory': {for (final e in byCat.entries) e.key: _money(e.value)},
    };
  }

  // ───────────────────────── Công việc (S17) ─────────────────────────

  static const _openStatuses = ['TODO', 'IN_PROGRESS', 'PENDING_REVIEW'];

  J _personOf(int? id) {
    final u = _users.where((e) => e.i('id') == id).toList();
    if (u.isEmpty) return {};
    return {'id': u.first['id'], 'username': u.first['username'], 'full_name': u.first['full_name'], 'role': _roleName(u.first.i('role_id'))};
  }

  J _taskOut(J t, {bool detail = false}) {
    final batch = _batches.where((e) => e.i('id') == t.i('batchId')).toList();
    final out = <String, dynamic>{
      ...t,
      'batchCode': batch.isEmpty ? null : batch.first['batchCode'],
      'assignee': t.i('assigneeUserId') == null ? null : _personOf(t.i('assigneeUserId')),
    };
    if (!detail) out.remove('submissions');
    if (detail) {
      out['submissions'] = [
        for (final s in _desc(List<J>.from(t['submissions'] as List), 'submittedAt'))
          {
            ...s,
            'submittedBy': _personOf(s.i('submittedByUserId')),
            'reviewedBy': s.i('reviewedByUserId') == null ? null : _personOf(s.i('reviewedByUserId')),
          }
      ];
    }
    return out;
  }

  J? _recordFor(String type, int id) {
    final store = switch (type) {
      'CARE_LOG' => _care,
      'GROWTH_PROGRESS' => _growth,
      'HARVEST' => _harvests,
      _ => null,
    };
    if (store == null) return null;
    for (final l in store.values) {
      for (final r in l) {
        if (r.i('id') == id) return r;
      }
    }
    return null;
  }

  J _dashboardRoute(String m, List<String> s, J q, J b) {
    final me = _me();
    final myId = me.i('id')!;
    final role = _roleName(me.i('role_id'));
    final canManage = role == 'admin' || role == 'manager';
    if (s.length >= 2 && s[1] == 'task-assignees') {
      final se = '${q['search'] ?? ''}'.toLowerCase();
      final l = _users
          .where((u) => se.isEmpty || u.s('username').toLowerCase().contains(se) || u.s('full_name').toLowerCase().contains(se))
          .map((u) => _personOf(u.i('id')))
          .toList();
      return _env(l, q);
    }
    if (s.length < 2 || s[1] != 'tasks') throw _err(404, 'Không tìm thấy đường dẫn.');

    if (s.length == 2) {
      if (m == 'GET') {
        final st = q['status']?.toString();
        final asg = int.tryParse('${q['assigneeUserId'] ?? ''}');
        final bat = int.tryParse('${q['batchId'] ?? ''}');
        final se = '${q['search'] ?? ''}'.toLowerCase();
        final l = _tasks
            .where((t) =>
                (st == null ? _openStatuses.contains(t['status']) : (st == 'ALL' || t['status'] == st)) &&
                (asg == null || t.i('assigneeUserId') == asg) &&
                (bat == null || t.i('batchId') == bat) &&
                (se.isEmpty || t.s('title').toLowerCase().contains(se)))
            .toList()
          ..sort((a, c) => (a.sn('dueAt') ?? '9999').compareTo(c.sn('dueAt') ?? '9999'));
        return _env(l.map((t) => _taskOut(t)).toList(), q);
      }
      if (m == 'POST') {
        _need(['admin', 'manager']);
        _req(b, ['title']);
        final t = <String, dynamic>{
          'id': 'c0a80101-0000-4000-8000-${(_next()).toString().padLeft(12, '0')}',
          'title': b['title'].toString().trim(),
          'description': b['description'],
          'status': 'TODO',
          'batchId': b['batchId'],
          'assigneeUserId': b['assigneeUserId'],
          'dueAt': b['dueAt'],
          'createdAt': _nowIso(),
          'submissions': <J>[],
        };
        _tasks.add(t);
        _log('TASK_CREATE', 'TASK', t['id']);
        return {'data': _taskOut(t, detail: true)};
      }
    }

    if (s.length < 3) throw _err(405, 'Phương thức không được hỗ trợ.');
    final ti = _tasks.indexWhere((t) => t.s('id') == s[2]);
    if (ti < 0) throw _err(404, 'Không tìm thấy công việc.');
    final t = _tasks[ti];
    final st = t.s('status');
    final isAssignee = t.i('assigneeUserId') == myId;
    final open = st == 'TODO' || st == 'IN_PROGRESS';

    if (s.length == 3) {
      if (m == 'GET') return {'data': _taskOut(t, detail: true)};
      if (m == 'DELETE') {
        _need(['admin', 'manager']);
        if ((t['submissions'] as List).isNotEmpty) {
          throw _err(409, 'Công việc đã có lịch sử gửi minh chứng, hãy dùng Hủy việc.', 'CONFLICT');
        }
        _tasks.removeAt(ti);
        _log('TASK_DELETE', 'TASK', t['id']);
        return {'message': 'Đã xóa'};
      }
      if (m == 'PATCH') {
        if (!canManage) {
          // Nhân viên: chỉ đổi TODO/IN_PROGRESS cho việc mở được giao cho mình.
          if (b.keys.any((k) => k != 'status') || !isAssignee) {
            throw _err(403, 'Bạn không có quyền thực hiện thao tác này.', 'AUTH_FORBIDDEN');
          }
          final ns = b['status'];
          if (ns != 'TODO' && ns != 'IN_PROGRESS') throw _err(403, 'Bạn không có quyền đổi sang trạng thái này.', 'AUTH_FORBIDDEN');
          if (!open) throw _err(409, 'Trạng thái công việc đã thay đổi.', 'CONFLICT');
          t['status'] = ns;
          return {'data': _taskOut(t, detail: true)};
        }
        if (st == 'PENDING_REVIEW' && (b.containsKey('batchId') || b.containsKey('assigneeUserId'))) {
          throw _err(409, 'Không đổi lô hoặc người nhận khi đang chờ duyệt.', 'CONFLICT');
        }
        if (b.containsKey('status')) {
          final ns = b['status'];
          final ok = ((ns == 'TODO' || ns == 'IN_PROGRESS') && open) ||
              (ns == 'CANCELLED' && (open || st == 'PENDING_REVIEW')) ||
              (ns == 'IN_PROGRESS' && (st == 'COMPLETED' || st == 'CANCELLED'));
          if (!ok) throw _err(409, 'Trạng thái công việc đã thay đổi.', 'CONFLICT');
          t['status'] = ns;
          if (ns == 'CANCELLED') {
            for (final sub in t['submissions'] as List) {
              if (sub['status'] == 'PENDING') sub['status'] = 'CANCELLED';
            }
          }
        }
        if (b.containsKey('title')) {
          _req(b, ['title']);
          t['title'] = b['title'].toString().trim();
        }
        _copy(t, b, ['description', 'batchId', 'assigneeUserId', 'dueAt']);
        _log('TASK_UPDATE', 'TASK', t['id']);
        return {'data': _taskOut(t, detail: true)};
      }
    }

    if (s.length < 4) throw _err(405, 'Phương thức không được hỗ trợ.');
    if (s[3] == 'evidence-candidates' && m == 'GET') {
      final type = q['type']?.toString();
      final bid = t.i('batchId');
      final out = <J>[];
      void add(String ty, Map<int, List<J>> store, String dateKey) {
        if (type != null && type != ty) return;
        store.forEach((batchId, list) {
          if (bid != null && batchId != bid) return;
          for (final r in list) {
            out.add({'type': ty, 'recordId': r['id'], 'record': r, '_d': r.s(dateKey)});
          }
        });
      }

      add('CARE_LOG', _care, 'recordedAt');
      add('GROWTH_PROGRESS', _growth, 'recordedAt');
      add('HARVEST', _harvests, 'harvestedAt');
      out.sort((a, c) => c.s('_d').compareTo(a.s('_d')));
      for (final e in out) {
        e.remove('_d');
      }
      return _env(out, q);
    }

    if (s[3] == 'submissions' && s.length == 4 && m == 'POST') {
      if (!isAssignee) throw _err(403, 'Chỉ người nhận việc mới được gửi minh chứng.', 'AUTH_FORBIDDEN');
      if (!open) throw _err(409, 'Công việc không còn ở trạng thái cho phép gửi minh chứng.', 'CONFLICT');
      final ev = b['evidence'];
      if (ev is! List || ev.isEmpty || ev.length > 20) throw _err(422, 'Cần từ 1 đến 20 minh chứng.', 'VALIDATION_ERROR');
      final snaps = <J>[];
      for (final e in ev) {
        final type = e is Map ? e['type']?.toString() : null;
        final rid = e is Map ? (e['recordId'] as num?)?.toInt() : null;
        final rec = (type == null || rid == null) ? null : _recordFor(type, rid);
        if (rec == null) throw _err(422, 'Minh chứng không hợp lệ hoặc không tồn tại.', 'VALIDATION_ERROR');
        snaps.add({'type': type, 'recordId': rid, 'record': Map<String, dynamic>.from(rec)}); // snapshot lúc gửi
      }
      final sub = <String, dynamic>{
        'id': 'sub-${_next()}',
        'status': 'PENDING',
        'submittedAt': _nowIso(),
        'submittedByUserId': myId,
        'notes': b['notes'],
        'reviewedAt': null,
        'reviewedByUserId': null,
        'reason': null,
        'evidence': snaps,
      };
      (t['submissions'] as List).add(sub);
      t['status'] = 'PENDING_REVIEW';
      _log('TASK_SUBMIT', 'TASK', t['id']);
      return {'data': sub};
    }

    if (s[3] == 'submissions' && s.length == 6 && s[5] == 'review' && m == 'POST') {
      _need(['admin', 'manager']);
      final sub = (t['submissions'] as List).cast<J>().where((e) => e.s('id') == s[4]).toList();
      if (sub.isEmpty) throw _err(404, 'Không tìm thấy lần gửi.');
      final sb = sub.first;
      if (sb.i('submittedByUserId') == myId) throw _err(403, 'Không thể tự duyệt minh chứng của chính mình.', 'AUTH_FORBIDDEN');
      if (sb['status'] != 'PENDING' || st != 'PENDING_REVIEW') throw _err(409, 'Lần gửi này không còn chờ duyệt.', 'CONFLICT');
      final dec = b['decision'];
      if (dec == 'APPROVE') {
        sb['status'] = 'APPROVED';
        t['status'] = 'COMPLETED';
      } else if (dec == 'REJECT') {
        _req(b, ['reason']);
        sb['status'] = 'REJECTED';
        sb['reason'] = b['reason'].toString().trim();
        t['status'] = 'IN_PROGRESS';
      } else {
        throw _err(422, 'decision phải là APPROVE hoặc REJECT.', 'VALIDATION_ERROR');
      }
      sb['reviewedAt'] = _nowIso();
      sb['reviewedByUserId'] = myId;
      _log('TASK_REVIEW', 'TASK', t['id']);
      return {'data': _taskOut(t, detail: true)};
    }
    throw _err(404, 'Không tìm thấy đường dẫn.');
  }

  // ───────────────────────── Quản trị: người dùng, vai trò, audit ─────────────────────────

  J _userOut(J u) => {...u, 'role': {'id': u['role_id'], 'name': _roleName(u.i('role_id'))}};

  J _adminRoute(String m, List<String> s, J q, J b) {
    if (s.length < 2) throw _err(404, 'Không tìm thấy đường dẫn.');
    if (s[1] == 'audit-logs') {
      _need(['admin', 'manager']);
      final act = '${q['action'] ?? ''}';
      final ent = '${q['entityType'] ?? ''}';
      final eid = '${q['entityId'] ?? ''}';
      final out = '${q['outcome'] ?? ''}';
      final code = int.tryParse('${q['statusCode'] ?? ''}');
      final actor = int.tryParse('${q['actorUserId'] ?? ''}');
      final from = q['from']?.toString();
      final to = q['to']?.toString();
      final l = _desc(
        _audit
            .where((a) =>
                (act.isEmpty || a.s('action') == act) &&
                (ent.isEmpty || a.s('entityType') == ent) &&
                (eid.isEmpty || a.s('entityId') == eid) &&
                (out.isEmpty || a.s('outcome') == out) &&
                (code == null || a.i('statusCode') == code) &&
                (actor == null || a.i('actorUserId') == actor) &&
                ((from == null && to == null) || _inRange(a.sn('createdAt'), from, to)))
            .toList(),
        'createdAt',
      );
      return _env(l, q, defLimit: 20);
    }
    _need(['admin']);
    if (s[1] == 'roles') {
      return {'data': [for (final r in MockSeed.roles) {'id': r.$1, 'name': r.$2}]};
    }
    if (s[1] != 'users') throw _err(404, 'Không tìm thấy đường dẫn.');
    if (s.length == 2) {
      if (m == 'GET') {
        final se = '${q['search'] ?? ''}'.toLowerCase();
        final l = _users
            .where((u) => se.isEmpty || u.s('username').toLowerCase().contains(se) || u.s('full_name').toLowerCase().contains(se))
            .map(_userOut)
            .toList();
        return _env(l, q);
      }
      if (m == 'POST') {
        _req(b, ['username', 'password', 'full_name', 'phone_number', 'email', 'role_id']);
        final name = b['username'].toString().trim();
        if (_users.any((u) => u.s('username') == name)) throw _err(409, 'Tên đăng nhập đã tồn tại.', 'CONFLICT');
        final rid = (b['role_id'] as num?)?.toInt();
        if (!MockSeed.roles.any((r) => r.$1 == rid)) throw _err(422, 'Vai trò không hợp lệ.', 'VALIDATION_ERROR');
        final u = <String, dynamic>{
          'id': _next(),
          'username': name,
          'full_name': b['full_name'],
          'email': b['email'],
          'phone_number': b['phone_number'],
          'role_id': rid,
        };
        _users.add(u);
        _pw[u['id'] as int] = b['password'].toString();
        _log('USER_CREATE', 'USER', u['id']);
        return {'data': _userOut(u)};
      }
    }
    if (s.length < 3) throw _err(405, 'Phương thức không được hỗ trợ.');
    final uid = int.tryParse(s[2]);
    final i = _users.indexWhere((u) => u.i('id') == uid);
    if (i < 0) throw _err(404, 'Không tìm thấy người dùng.');
    if (m == 'GET') return {'data': _userOut(_users[i])};
    if (m == 'PUT') {
      _req(b, ['full_name']);
      _copy(_users[i], b, ['full_name', 'phone_number', 'email', 'role_id']);
      final pw = b['password']?.toString() ?? '';
      if (pw.isNotEmpty) _pw[uid!] = pw;
      _log('USER_UPDATE', 'USER', uid);
      return {'data': _userOut(_users[i])};
    }
    if (m == 'DELETE') {
      if (uid == _me().i('id')) throw _err(409, 'Không thể xóa chính tài khoản đang đăng nhập.', 'CONFLICT');
      _users.removeAt(i);
      _pw.remove(uid);
      _log('USER_DELETE', 'USER', uid);
      return {'message': 'Đã xóa'};
    }
    throw _err(405, 'Phương thức không được hỗ trợ.');
  }

  // ───────────────────────── Lịch sử nhận diện trên máy chủ (S11) ─────────────────────────

  J _classifierRoute(List<String> s, J q) {
    _need(['admin', 'manager']);
    if (s.length < 2 || s[1] != 'history') throw _err(404, 'Không tìm thấy đường dẫn.');
    if (s.length == 3) {
      final h = _history.where((e) => e.s('id') == s[2]).toList();
      if (h.isEmpty) throw _err(404, 'Không tìm thấy lượt nhận diện.');
      final x = h.first;
      return {
        'data': {
          ...x,
          'user': {'username': _personOf(x.i('userId'))['username']},
          'result': x['scientificName'] == null ? null : {'scientificName': x['scientificName']},
        }
      };
    }
    final se = '${q['predictedName'] ?? ''}'.toLowerCase();
    final st = q['status']?.toString();
    final from = q['from']?.toString();
    final to = q['to']?.toString();
    final l = _desc(
      _history
          .where((x) =>
              (se.isEmpty || x.s('predictedName').toLowerCase().contains(se)) &&
              (st == null || x['status'] == st) &&
              ((from == null && to == null) || _inRange(x.sn('createdAt'), from, to)))
          .toList(),
      'createdAt',
    );
    return _env(l, q, defLimit: 20);
  }

  // ───────────────────────── Tra cứu công khai (S16) ─────────────────────────

  J _publicGrowth(List<String> s) {
    // /public/cultivation-batches/{code}/growth-progress/current — không cần token.
    if (s.length < 5 || s[1] != 'cultivation-batches') throw _err(404, 'Không tìm thấy đường dẫn.');
    final code = Uri.decodeComponent(s[2]);
    final b = _batches.where((x) => x.s('batchCode').toLowerCase() == code.toLowerCase()).toList();
    if (b.isEmpty) throw _err(404, 'Không tìm thấy lô với mã "$code".', 'NOT_FOUND');
    final x = b.first;
    final out = _batchOut(x);
    final g = _desc(_growth[x.i('id')] ?? <J>[], 'recordedAt');
    return {
      'data': {
        'batchCode': x['batchCode'],
        'status': x['status'],
        'startDate': x['startDate'],
        'expectedHarvestDate': x['expectedHarvestDate'],
        'mushroom': out['mushroom'],
        'facility': out['facility'],
        'currentProgress': g.isEmpty ? null : g.first,
      }
    };
  }

  // ───────────────────────── Báo cáo (S12, S13) ─────────────────────────

  List<J> _filteredBatches(J q) {
    final from = q['from']?.toString();
    final to = q['to']?.toString();
    final fac = int.tryParse('${q['facilityId'] ?? ''}');
    final mu = int.tryParse('${q['mushroomId'] ?? ''}');
    final st = q['status']?.toString();
    return _batches
        .where((x) =>
            (fac == null || x.i('facilityId') == fac) &&
            (mu == null || x.i('mushroomId') == mu) &&
            (st == null || x['status'] == st) &&
            _inRange(x.sn('startDate'), from, to))
        .toList();
  }

  List<MapEntry<String, double>> _series(Iterable<(String, double)> pts, String gb) {
    final mp = <String, double>{};
    for (final p in pts) {
      mp[_per(p.$1, gb)] = (mp[_per(p.$1, gb)] ?? 0) + p.$2;
    }
    return mp.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  J _report(String kind, J q) {
    _need(['admin', 'manager']);
    final from = q['from']?.toString();
    final to = q['to']?.toString();
    final gb = q['groupBy']?.toString() == 'day' ? 'day' : 'month';
    final fb = _filteredBatches(q);

    switch (kind) {
      case 'overview':
        {
          final hv = <(String, double)>[];
          var totalKg = 0.0;
          for (final x in fb) {
            for (final h in _harvests[x.i('id')] ?? <J>[]) {
              if (_inRange(h.sn('harvestedAt'), from, to)) {
                hv.add((h.s('harvestedAt'), h.d('totalYieldKg') ?? 0));
                totalKg += h.d('totalYieldKg') ?? 0;
              }
            }
          }
          final now = DateTime.now().toUtc();
          final overdue = fb.where((x) {
            final e = DateTime.tryParse(x.s('expectedHarvestDate'));
            return !['COMPLETED', 'FAILED'].contains(x['status']) && e != null && e.isBefore(now);
          }).length;
          final cls = _history.where((h) => _inRange(h.sn('createdAt'), from, to)).toList();
          final ok = cls.where((h) => h['status'] == 'SUCCEEDED').toList();
          final aud = _audit.where((a) => _inRange(a.sn('createdAt'), from, to)).toList();
          return {
            'data': {
              'cultivation': {
                'facilities': fb.map((x) => x['facilityId']).toSet().length,
                'species': fb.map((x) => x['mushroomId']).toSet().length,
                'batchCount': fb.length,
                'statusBreakdown': {
                  for (final k in ['PREPARATION', 'INCUBATION', 'FRUITING', 'HARVESTING', 'COMPLETED', 'FAILED'])
                    k: {'count': fb.where((x) => x['status'] == k).length},
                },
                'overdueBatches': overdue,
                'totalHarvestKg': totalKg,
                'harvestSeries': [for (final e in _series(hv, gb)) {'period': e.key, 'totalYieldKg': e.value}],
              },
              'classifier': {
                'total': cls.length,
                'succeeded': ok.length,
                'failed': cls.where((h) => h['status'] == 'FAILED').length,
                'averageConfidence': ok.isEmpty ? null : ok.fold<double>(0, (a, h) => a + (h.d('confidence') ?? 0)) / ok.length,
                'series': [for (final e in _series(cls.map((h) => (h.s('createdAt'), 1.0)), gb)) {'period': e.key, 'count': e.value.toInt()}],
              },
              'audit': {
                'totalActions': aud.length,
                'failedActions': aud.where((a) => a['outcome'] == 'FAILURE').length,
                'series': [for (final e in _series(aud.map((a) => (a.s('createdAt'), 1.0)), gb)) {'period': e.key, 'count': e.value.toInt()}],
              },
            }
          };
        }
      case 'cultivation':
        {
          final rows = _desc(fb, 'startDate').map((x) {
            final o = _batchOut(x);
            final g = _desc(_growth[x.i('id')] ?? <J>[], 'recordedAt');
            return {
              'batchCode': x['batchCode'],
              'facility': o.m('facility')?['name'],
              'province': o.m('facility')?['province'],
              'mushroom': o.m('mushroom')?['commonName'],
              'status': x['status'],
              'startDate': x['startDate'],
              'totalHarvestKg': _sum(_harvests[x.i('id')], 'totalYieldKg'),
              'defectRate': x['defectRate'],
              'latestGrowthStage': g.isEmpty ? null : g.first['stage'],
              'latestGrowthRecordedAt': g.isEmpty ? null : g.first['recordedAt'],
            };
          }).toList();
          return _env(rows, q, defLimit: 20);
        }
      case 'financial':
        {
          var rev = 0.0, cost = 0.0, hk = 0.0, sk = 0.0;
          final revPts = <(String, double)>[], costPts = <(String, double)>[];
          final rows = <J>[];
          for (final x in fb) {
            final id = x.i('id');
            final sl = (_sales[id] ?? <J>[]).where((e) => _inRange(e.sn('soldAt'), from, to)).toList();
            final ex = (_expenses[id] ?? <J>[]).where((e) => _inRange(e.sn('incurredAt'), from, to)).toList();
            final r = _sum(sl, 'amount'), c = _sum(ex, 'amount');
            rev += r;
            cost += c;
            sk += _sum(sl, 'quantityKg');
            hk += _sum((_harvests[id] ?? <J>[]).where((e) => _inRange(e.sn('harvestedAt'), from, to)).toList(), 'totalYieldKg');
            revPts.addAll(sl.map((e) => (e.s('soldAt'), double.tryParse(e.s('amount')) ?? 0)));
            costPts.addAll(ex.map((e) => (e.s('incurredAt'), double.tryParse(e.s('amount')) ?? 0)));
            final o = _batchOut(x);
            rows.add({
              'batchId': id,
              'batchCode': x['batchCode'],
              'status': x['status'],
              'facility': {'name': o.m('facility')?['name']},
              'mushroom': {'commonName': o.m('mushroom')?['commonName']},
              'revenue': _money(r),
              'totalCost': _money(c),
              'profit': _money(r - c),
            });
          }
          final rs = {for (final e in _series(revPts, gb)) e.key: e.value};
          final cs = {for (final e in _series(costPts, gb)) e.key: e.value};
          final periods = {...rs.keys, ...cs.keys}.toList()..sort();
          final env = _env(rows, q, defLimit: 20);
          return {
            ...env,
            'summary': {
              'totalHarvestKg': hk,
              'totalSoldKg': sk,
              'revenue': _money(rev),
              'totalCost': _money(cost),
              'profit': _money(rev - cost),
              'profitMarginPercent': rev > 0 ? _money((rev - cost) / rev * 100) : null,
            },
            'series': [
              for (final p in periods)
                {'period': p, 'revenue': _money(rs[p] ?? 0), 'totalCost': _money(cs[p] ?? 0), 'profit': _money((rs[p] ?? 0) - (cs[p] ?? 0))},
            ],
          };
        }
      case 'classifier':
        {
          final rows = _desc(_history.where((h) => _inRange(h.sn('createdAt'), from, to)).toList(), 'createdAt')
              .map((h) => {
                    'originalName': h['originalName'],
                    'status': h['status'],
                    'predictedName': h['predictedName'],
                    'edibility': h['edibility'],
                    'confidence': h['confidence'],
                    'user': {'username': _personOf(h.i('userId'))['username']},
                    'createdAt': h['createdAt'],
                  })
              .toList();
          return _env(rows, q, defLimit: 20);
        }
      case 'audit':
        {
          final rows = _desc(_audit.where((a) => _inRange(a.sn('createdAt'), from, to)).toList(), 'createdAt')
              .map((a) => {
                    'action': a['action'],
                    'outcome': a['outcome'],
                    'statusCode': a['statusCode'],
                    'actorUsername': a['actorUsername'],
                    'method': a['method'],
                    'path': a['path'],
                    'createdAt': a['createdAt'],
                  })
              .toList();
          return _env(rows, q, defLimit: 20);
        }
    }
    throw _err(404, 'Không có loại báo cáo "$kind".');
  }

  /// Xuất báo cáo: bản mẫu LUÔN là CSV (bất kể chọn CSV/XLSX/PDF) để thử luồng tải/lưu file.
  Future<DownloadedFile> download(String path, Map<String, dynamic>? query) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final s = path.split('/').where((e) => e.isNotEmpty).toList();
    if (s.length < 3 || s[0] != 'reports' || s[2] != 'export') throw _err(404, 'Không tìm thấy đường dẫn.');
    final kind = s[1];
    final r = _report(kind, {...?query, 'page': 1, 'limit': 100});
    final sb = StringBuffer('\uFEFF');
    String cell(Object? v) {
      final t = v is Map ? v.values.join(' / ') : (v ?? '').toString();
      return '"${t.replaceAll('"', '""')}"';
    }

    final data = r['data'];
    if (data is List && data.isNotEmpty) {
      final rows = data.whereType<Map>().toList();
      final cols = rows.first.keys.toList();
      sb.writeln(cols.map(cell).join(','));
      for (final row in rows) {
        sb.writeln(cols.map((c) => cell(row[c])).join(','));
      }
    } else if (data is Map) {
      sb.writeln('Chỉ số,Giá trị');
      void flat(String p, Object? v) {
        if (v is Map) {
          v.forEach((k, e) => flat(p.isEmpty ? '$k' : '$p.$k', e));
        } else if (v is! List) {
          sb.writeln('${cell(p)},${cell(v)}');
        }
      }

      flat('', data);
    } else {
      sb.writeln('Không có dữ liệu');
    }
    _log('REPORT_EXPORT', 'REPORT', kind);
    return DownloadedFile(Uint8List.fromList(utf8.encode(sb.toString())), 'mock-$kind-report.csv', 'text/csv');
  }
}
