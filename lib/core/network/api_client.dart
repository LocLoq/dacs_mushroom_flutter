import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/account/data/account_model.dart';
import '../../features/facility/data/facility_model.dart';
import '../../features/mushroom_catalog/data/catalog_model.dart';
import '../../features/mushroom_strain/data/strain_model.dart';

// Đây là bản MOCK để demo chạy được ngay không cần server.
// Khi nối backend thật, thay toàn bộ class này bằng Dio, ví dụ:
//
//   class ApiClient {
//     late final Dio dio;
//     ApiClient() {
//       dio = Dio(BaseOptions(
//         baseUrl: EnvConfig.baseUrl,
//         connectTimeout: EnvConfig.connectTimeout,
//         receiveTimeout: EnvConfig.receiveTimeout,
//       ));
//       dio.interceptors.add(InterceptorsWrapper(
//         onRequest: (options, handler) async {
//           final token = await SecureStorage.readToken();
//           if (token != null) {
//             options.headers['Authorization'] = 'Bearer $token';
//           }
//           handler.next(options);
//         },
//         onError: (DioException e, handler) async {
//           if (e.response?.statusCode == 401) {
//             // TODO(BACKEND): gọi refresh token hoặc logout + điều hướng về LoginScreen
//           }
//           handler.next(e);
//         },
//       ));
//     }
//   }
//
class ApiClient {
  // TODO(BACKEND): POST {baseUrl}/auth/login/  body: {username, password}
  // Response mẫu: { "access": "...", "refresh": "...", "user": {...} }
  Future<Map<String, dynamic>> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 600)); // giả lập network
    if (username.isEmpty || password.isEmpty) {
      throw Exception('Sai tài khoản hoặc mật khẩu');
    }
    return {
      'access': 'FAKE_JWT_TOKEN',
      'user': {'username': username, 'role': 'Manager'},
    };
  }

  // TODO(BACKEND): GET {baseUrl}/facilities/?search=&status=
  Future<List<FacilityModel>> fetchFacilities() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return mockFacilities;
  }

  // TODO(BACKEND): GET {baseUrl}/strains/
  Future<List<StrainModel>> fetchStrains() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return mockStrains;
  }

  // TODO(BACKEND): POST/PUT {baseUrl}/strains/  hoặc  {baseUrl}/strains/{id}/
  Future<void> saveStrain(StrainModel strain) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO(BACKEND): xử lý response, throw lỗi nếu status != 200/201
  }

  // TODO(BACKEND): GET {baseUrl}/accounts/
  Future<List<AccountModel>> fetchAccounts() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return mockAccounts;
  }

  // TODO(BACKEND): PATCH {baseUrl}/accounts/{id}/  body: {"is_active": bool}
  Future<void> toggleAccountLock(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // TODO(BACKEND): PATCH {baseUrl}/accounts/{id}/  body: {"role": "admin|manager|staff", "assigned_facility": id}
  // Lưu ý: chỉ Admin mới được đổi role người khác — kiểm tra permission ở Django view,
  // không chỉ ẩn UI ở client.
  Future<void> updateAccountRole(String id, AccountRole role, String facility) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // TODO(BACKEND): POST {baseUrl}/accounts/{id}/set-password/
  //   body: {"new_password": "...", "must_change_password": true|false}
  // Không bao giờ trả mật khẩu cũ về client — API chỉ NHẬN mật khẩu mới, không có API "xem" mật khẩu.
  // Nên validate độ mạnh mật khẩu ở cả client (UX nhanh) lẫn backend (bảo mật thật).
  // "must_change_password": true -> backend nên lưu 1 cờ (VD: user.must_change_password = True)
  // và AuthMiddleware chặn mọi API khác cho tới khi user đó gọi xong endpoint đổi mật khẩu riêng
  // (không dùng chung với set-password ở đây, vì lần này người tự đổi biết mk cũ, khác với Admin đặt hộ).
  Future<void> setAccountPassword(
    String id,
    String newPassword, {
    required bool mustChangePassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // GET /api/mushrooms/catalog
  // Không cần đăng nhập. Thử gọi backend FastAPI, nếu lỗi/offline fallback mockCatalogResponse
  Future<MushroomCatalogResponse> fetchMushroomCatalog([String? baseUrl]) async {
    final url = baseUrl ?? 'http://10.0.2.2:8000';
    try {
      final uri = Uri.parse('$url/api/mushrooms/catalog');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return MushroomCatalogResponse.fromJson(decoded);
      }
    } catch (_) {
      // Fallback to mock catalog
    }
    await Future.delayed(const Duration(milliseconds: 300));
    return mockCatalogResponse;
  }
}

