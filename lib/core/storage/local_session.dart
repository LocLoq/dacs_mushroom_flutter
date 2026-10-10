import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<Map<String, dynamic>?> read() async {
    final value = await _storage.read(key: 'mushroom_auth_session');
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> write(String token, String serverOrigin) => _storage.write(
    key: 'mushroom_auth_session',
    value: jsonEncode({'token': token, 'server': serverOrigin}),
  );
  Future<void> clear() => _storage.delete(key: 'mushroom_auth_session');
}

enum SessionStatus { guest, pending, signedIn }

class LocalSession {
  static final changes = ValueNotifier<int>(0);
  static final store = TokenStore();
  static String? _token, _serverOrigin;
  static Map<String, dynamic>? _user;
  static void save(
    String token,
    Map<String, dynamic> user, {
    String? serverOrigin,
  }) {
    _token = token;
    _user = Map<String, dynamic>.from(user);
    _serverOrigin = serverOrigin;
    changes.value++;
  }

  static String? tokenFor(String serverOrigin) =>
      _serverOrigin == serverOrigin ? _token : null;
  static Map<String, dynamic>? get user =>
      _user == null ? null : Map<String, dynamic>.from(_user!);
  static void setMockToken(String value) {
    _token = value;
    _serverOrigin = 'mock';
    _user = null;
    changes.value++;
  }

  static String? get token => _token;
  static SessionStatus get status => _token == null
      ? SessionStatus.guest
      : _user == null
      ? SessionStatus.pending
      : SessionStatus.signedIn;
  static bool get isPending => status == SessionStatus.pending;
  static int? get userId => (_user?['id'] as num?)?.toInt();
  static String get fullName => _user?['full_name']?.toString() ?? '';
  static String get displayName => fullName.isEmpty ? username : fullName;
  static bool setProfile(Map<String, dynamic> user) {
    if (user['id'] is! num ||
        (user['id'] as num) <= 0 ||
        !['admin', 'manager', 'staff'].contains(user['role']))
      return false;
    _user = Map<String, dynamic>.from(user);
    changes.value++;
    return true;
  }

  static bool get isLoggedIn => status == SessionStatus.signedIn;
  static String get username => _user?['username']?.toString() ?? '';
  static String get role => _user?['role']?.toString() ?? '';
  static bool get canManage => role == 'admin' || role == 'manager';
  static bool get isAdmin => role == 'admin';
  static void clear() {
    _token = null;
    _user = null;
    _serverOrigin = null;
    changes.value++;
  }

  static Future<void> logout() async {
    clear();
    await store.clear();
    await (await SharedPreferences.getInstance()).remove('farm_mock_token');
  }
}
