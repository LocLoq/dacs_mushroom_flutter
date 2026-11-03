import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/mushroom_catalog/data/catalog_model.dart';

/// Client của dịch vụ AI nhận diện nấm (FastAPI, mặc định http://10.0.2.2:8000).
/// Dữ liệu quản trị trại nấm (lô, cơ sở, công việc, báo cáo...) đi qua
/// core/network/farm_api.dart, KHÔNG đi qua class này.
class ApiClient {
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

