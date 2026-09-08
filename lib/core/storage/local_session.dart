// TODO(BACKEND): thay bằng Hive (cache offline danh sách Cơ sở/Giống nấm)
// và flutter_secure_storage (lưu JWT token). Ví dụ:
//
//   class SecureStorage {
//     static const _storage = FlutterSecureStorage();
//     static Future<void> saveToken(String token) =>
//         _storage.write(key: AppConstants.tokenKey, value: token);
//     static Future<String?> readToken() =>
//         _storage.read(key: AppConstants.tokenKey);
//   }
//
class LocalSession {
  static String? _token;
  static Map<String, dynamic>? _user;

  static void save(String token, Map<String, dynamic> user) {
    _token = token;
    _user = user;
  }

  static bool get isLoggedIn => _token != null;
  static String get username => _user?['username'] ?? '';
  static String get role => _user?['role'] ?? '';

  static void clear() {
    _token = null;
    _user = null;
  }
}
