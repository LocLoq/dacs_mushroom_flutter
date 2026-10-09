import 'package:shared_preferences/shared_preferences.dart';

/// Địa chỉ API Trại nấm (Node). Khác với "Backend URL" của dịch vụ AI nhận diện
/// ở màn Cài đặt. Base URL có hậu tố /api, ví dụ http://10.0.2.2:8080/api
class ApiConfig {
  static const _key = 'farm_api_base_url';
  static const defaultBaseUrl = 'http://10.0.2.2:8080/api';

  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  /// Origin của Node (bỏ /api) — dùng cho ảnh /uploads/... và Socket.IO.
  static String get origin {
    var u = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (u.endsWith('/api')) u = u.substring(0, u.length - 4);
    return u;
  }

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _baseUrl = p.getString(_key) ?? defaultBaseUrl;
  }

  static Future<void> save(String url) async {
    var u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isEmpty) u = defaultBaseUrl;
    _baseUrl = u;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, u);
  }

  /// URL ảnh đầy đủ. /uploads/x.jpg ghép với origin; http(s) giữ nguyên;
  /// rỗng hoặc scheme khác -> null.
  static String? media(String? raw) {
    if (raw == null) return null;
    final u = raw.trim();
    if (u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('/')) return '$origin$u';
    return null;
  }
}
