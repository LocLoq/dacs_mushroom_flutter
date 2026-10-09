import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../storage/local_session.dart';
import '../utils/json_utils.dart';
import 'api_config.dart';
import 'mock_backend.dart';
import 'mock_config.dart';

/// Lỗi API đã chuẩn hoá (specs/API_CONTRACT.md §4).
class ApiException implements Exception {
  final int status; // 0 = mất mạng/timeout
  final String message;
  final String? code;

  const ApiException(this.status, this.message, [this.code]);

  bool get isConflict => status == 409;
  bool get isForbidden => status == 403;
  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

class DownloadedFile {
  final Uint8List bytes;
  final String? filename;
  final String contentType;

  const DownloadedFile(this.bytes, this.filename, this.contentType);
}

/// Client cho API Trại nấm. Mọi hàm trả Map đã giải mã JSON (envelope giữ nguyên).
class FarmApi {
  FarmApi._();
  static final FarmApi instance = FarmApi._();

  static const _timeout = Duration(seconds: 45);

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v == null) return;
      final t = v.toString();
      if (t.isEmpty) return;
      q[k] = t;
    });
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  /// [public] = true: bỏ Authorization (login, tra cứu công khai, classify công khai).
  Map<String, String> _headers({bool public = false, bool json = true}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json';
    final t = LocalSession.token;
    if (!public && t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  ApiException _fromResponse(http.Response r, {required bool public}) {
    String msg = 'Có lỗi xảy ra (HTTP ${r.statusCode}).';
    String? code;
    try {
      final b = jsonDecode(utf8.decode(r.bodyBytes));
      if (b is Map) {
        if (b['message'] != null) msg = b['message'].toString();
        code = b['code']?.toString();
      }
    } catch (_) {}

    final tokenDead = r.statusCode == 401 ||
        (r.statusCode == 403 && code == 'AUTH_INVALID_TOKEN') ||
        msg.contains('Token không hợp lệ hoặc đã hết hạn');
    if (!public && tokenDead) {
      LocalSession.clear(); // 403 AUTH_FORBIDDEN thì KHÔNG vào đây: giữ phiên
    }
    return ApiException(r.statusCode, msg, code);
  }

  Future<J> _run(Future<http.Response> Function() call, {bool public = false}) async {
    try {
      final r = await call().timeout(_timeout);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        if (r.bodyBytes.isEmpty) return {};
        final b = jsonDecode(utf8.decode(r.bodyBytes));
        return b is Map ? Map<String, dynamic>.from(b) : {'data': b};
      }
      throw _fromResponse(r, public: public);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(0, 'Hết thời gian chờ. Kiểm tra mạng hoặc địa chỉ API.');
    } catch (_) {
      throw const ApiException(0, 'Không kết nối được máy chủ. Kiểm tra mạng và địa chỉ API ở Cài đặt.');
    }
  }

  // Chế độ mẫu (MockConfig.enabled): mọi lệnh dưới đây được MockBackend trả lời trong
  // bộ nhớ, không có yêu cầu mạng nào. Tắt ở Cài đặt → API Trại nấm để dùng API thật.

  Future<J> get(String path, {Map<String, dynamic>? query, bool public = false}) {
    if (MockConfig.enabled) return MockBackend.instance.handle('GET', path, query: query, public: public);
    return _run(() => http.get(_uri(path, query), headers: _headers(public: public)), public: public);
  }

  Future<J> post(String path, [Object? body]) {
    if (MockConfig.enabled) return MockBackend.instance.handle('POST', path, body: body);
    return _run(() => http.post(_uri(path), headers: _headers(), body: body == null ? null : jsonEncode(body)));
  }

  Future<J> put(String path, Object body) {
    if (MockConfig.enabled) return MockBackend.instance.handle('PUT', path, body: body);
    return _run(() => http.put(_uri(path), headers: _headers(), body: jsonEncode(body)));
  }

  Future<J> patch(String path, Object body) {
    if (MockConfig.enabled) return MockBackend.instance.handle('PATCH', path, body: body);
    return _run(() => http.patch(_uri(path), headers: _headers(), body: jsonEncode(body)));
  }

  Future<J> delete(String path) {
    if (MockConfig.enabled) return MockBackend.instance.handle('DELETE', path);
    return _run(() => http.delete(_uri(path), headers: _headers()));
  }

  /// multipart: field `images` lặp theo từng file; thư viện tự đặt boundary.
  Future<J> multipart(
    String method,
    String path, {
    Map<String, String> fields = const {},
    List<XFile> files = const [],
    String fileField = 'images',
    bool public = false,
  }) async {
    if (MockConfig.enabled) {
      return MockBackend.instance.handle(method, path, fields: fields, files: files, public: public);
    }
    return _run(() async {
      final req = http.MultipartRequest(method, _uri(path));
      req.headers.addAll(_headers(public: public, json: false));
      req.fields.addAll(fields);
      for (final f in files) {
        final bytes = await f.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: f.name,
          contentType: MediaType.parse(mimeOf(f)),
        ));
      }
      return http.Response.fromStream(await req.send());
    }, public: public);
  }

  /// Tải file nhị phân (xuất báo cáo). Body JSON lỗi vẫn được giải mã để xử lý phiên.
  Future<DownloadedFile> download(String path, {Map<String, dynamic>? query}) async {
    if (MockConfig.enabled) return MockBackend.instance.download(path, query);
    try {
      final r = await http
          .get(_uri(path, query), headers: _headers())
          .timeout(const Duration(minutes: 2));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        final e = _fromResponse(r, public: false);
        if (e.status == 422) {
          throw const ApiException(422, 'Báo cáo quá lớn. Vui lòng thu hẹp khoảng ngày hoặc bộ lọc.');
        }
        throw e;
      }
      final ct = (r.headers['content-type'] ?? '').toLowerCase();
      if (r.bodyBytes.isEmpty || ct.contains('json') || ct.contains('html')) {
        throw const ApiException(500, 'Máy chủ không trả về file báo cáo hợp lệ.');
      }
      return DownloadedFile(r.bodyBytes, _filename(r.headers['content-disposition']), ct);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(0, 'Không tải được báo cáo. Kiểm tra mạng và thử lại.');
    }
  }

  static String? _filename(String? cd) {
    if (cd == null) return null;
    final star = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false).firstMatch(cd);
    if (star != null) {
      try {
        return Uri.decodeComponent(star.group(1)!);
      } catch (_) {}
    }
    final plain = RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(cd);
    return plain?.group(1);
  }

  // ───────────── Xác thực (S01) ─────────────

  /// POST /login (bỏ Authorization) -> lưu token -> GET /auth/me.
  Future<void> login(String username, String password) async {
    final r = await post0Login(username, password);
    final token = r['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException(500, 'Máy chủ không trả về token.');
    }
    await LocalSession.setToken(token);
    final ok = await confirmProfile();
    if (!ok) {
      throw const ApiException(0, 'Chưa xác nhận được hồ sơ người dùng. Thử lại sau.');
    }
  }

  Future<J> post0Login(String username, String password) {
    if (MockConfig.enabled) {
      return MockBackend.instance.handle('POST', '/login', body: {'username': username, 'password': password}, public: true);
    }
    return _run(
      () => http.post(
        _uri('/login'),
        headers: _headers(public: true),
        body: jsonEncode({'username': username, 'password': password}),
      ),
      public: true,
    );
  }

  /// GET /auth/me. true nếu vào được khu nội bộ.
  /// Token chết (401/403 AUTH_INVALID_TOKEN) đã được _fromResponse xoá phiên;
  /// lỗi mạng/503/dữ liệu lạ giữ token ở trạng thái "pending".
  Future<bool> confirmProfile() async {
    try {
      final r = await get('/auth/me');
      final data = r.m('data');
      if (data == null) return false;
      return LocalSession.setProfile(data);
    } on ApiException catch (e) {
      if (LocalSession.token == null) return false;
      if (e.status == 403 && e.code != 'AUTH_INVALID_TOKEN') return false;
      return false;
    }
  }

  /// Gọi khi mở app.
  Future<void> restoreSession() async {
    await ApiConfig.load();
    await MockConfig.load();
    await LocalSession.loadToken();
    if (LocalSession.token != null) await confirmProfile();
  }

  static String mimeOf(XFile f) {
    final n = f.name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
