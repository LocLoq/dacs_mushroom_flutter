import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trạng thái phiên (specs/S01_LOGIN.md):
///  - guest: chưa đăng nhập
///  - pending: có token nhưng chưa xác nhận được profile (mất mạng/503)
///  - signedIn: GET /auth/me hợp lệ, role là admin|manager|staff
enum SessionStatus { guest, pending, signedIn }

class LocalSession {
  static const _tokenKey = 'farm_token';
  static const _roles = {'admin', 'manager', 'staff'};

  static String? _token;
  static Map<String, dynamic>? _user;
  static SessionStatus _status = SessionStatus.guest;

  /// UI lắng nghe để vẽ lại khi đăng nhập/đăng xuất/hết phiên.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static String? get token => _token;
  static SessionStatus get status => _status;
  static bool get isLoggedIn => _status == SessionStatus.signedIn;
  static bool get isPending => _status == SessionStatus.pending;

  static int? get userId => _user?['id'] is int ? _user!['id'] as int : null;
  static String get username => (_user?['username'] ?? '').toString();
  static String get fullName => (_user?['full_name'] ?? '').toString();
  static String get role => (_user?['role'] ?? '').toString();
  static String get displayName => fullName.isNotEmpty ? fullName : username;

  static bool get isAdmin => isLoggedIn && role == 'admin';
  static bool get canManage => isLoggedIn && (role == 'admin' || role == 'manager');

  static void _notify() => changes.value++;

  /// Đọc token đã lưu (chưa gọi mạng).
  static Future<void> loadToken() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString(_tokenKey);
    _status = _token == null ? SessionStatus.guest : SessionStatus.pending;
    _notify();
  }

  static Future<void> setToken(String token) async {
    _token = token;
    _status = SessionStatus.pending;
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, token);
    _notify();
  }

  /// Chỉ vào khu nội bộ khi profile có id dương, username và role hợp lệ.
  /// Trả về true nếu hợp lệ.
  static bool setProfile(Map<String, dynamic> user) {
    final id = user['id'];
    final ok = id is int &&
        id > 0 &&
        (user['username'] ?? '').toString().isNotEmpty &&
        _roles.contains(user['role']);
    if (ok) {
      _user = user;
      _status = SessionStatus.signedIn;
    } else {
      _user = null;
      _status = SessionStatus.pending;
    }
    _notify();
    return ok;
  }

  /// Đăng xuất / hết phiên: xoá token lưu và token trong bộ nhớ.
  static Future<void> clear() async {
    _token = null;
    _user = null;
    _status = SessionStatus.guest;
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    _notify();
  }
}
