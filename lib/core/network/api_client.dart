import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../features/account/data/account_model.dart';
import '../../features/cultivation_batch/data/batch_model.dart';
import '../../features/facility/data/facility_model.dart';
import '../../features/mushroom_catalog/data/catalog_model.dart';
import '../../features/mushroom_strain/data/strain_model.dart';
import '../services/app_preferences_service.dart';
import '../storage/local_session.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'mock_config.dart';
import 'mock_seed.dart';
export 'api_config.dart';
export 'api_exception.dart';

enum RequestAuth { none, optional, required }

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, TokenStore? tokenStore})
    : _client = client,
      _baseUrl = baseUrl,
      _store = tokenStore ?? LocalSession.store;
  final http.Client? _client;
  final String? _baseUrl;
  final TokenStore _store;

  Future<ApiConfig> config([String? baseUrl]) async => ApiConfig.fromInput(
    baseUrl ??
        _baseUrl ??
        (await AppPreferencesService.instance.load()).backendBaseUrl,
  );

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
    RequestAuth auth = RequestAuth.required,
    String? token,
    String? baseUrl,
    bool binary = false,
  }) async {
    final cfg = await config(baseUrl);
    final request = http.Request(method, cfg.endpoint(path, query));
    request.headers['Accept'] = 'application/json';
    if (data != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(data);
    }
    return send(
      request,
      auth: auth,
      token: token,
      serverOrigin: cfg.serverOrigin.toString(),
      binary: binary,
    );
  }

  Future<Map<String, dynamic>> send(
    http.BaseRequest request, {
    RequestAuth auth = RequestAuth.required,
    String? token,
    required String serverOrigin,
    bool binary = false,
  }) async {
    request.headers.remove('Authorization');
    final bearer = token ?? LocalSession.tokenFor(serverOrigin);
    if (auth != RequestAuth.none && bearer != null) {
      request.headers['Authorization'] = 'Bearer $bearer';
    }
    final client = _client ?? http.Client();
    try {
      final response =
          await (() async {
            final streamed = await client.send(request);
            return http.Response.fromStream(streamed);
          })().timeout(
            binary ? const Duration(minutes: 2) : const Duration(seconds: 30),
          );
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {}
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = decoded is Map ? decoded['code']?.toString() : null;
        if (auth != RequestAuth.none &&
            (response.statusCode == 401 || code == 'AUTH_INVALID_TOKEN')) {
          LocalSession.clear();
          await _store.clear();
        }
        throw ApiException(
          decoded is Map
              ? decoded['message']?.toString() ?? 'Máy chủ từ chối yêu cầu.'
              : 'Máy chủ trả về lỗi HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
          code: code,
          requestId: response.headers['x-request-id'],
          kind: response.statusCode == 401
              ? ApiErrorKind.unauthorized
              : response.statusCode == 403
              ? ApiErrorKind.forbidden
              : response.statusCode >= 500
              ? ApiErrorKind.server
              : ApiErrorKind.validation,
        );
      }
      if (binary) {
        final type = response.headers['content-type'] ?? '';
        if (response.bodyBytes.isEmpty ||
            type.contains('json') ||
            type.contains('html')) {
          throw const ApiException(
            'Máy chủ không trả về file hợp lệ.',
            kind: ApiErrorKind.invalidResponse,
          );
        }
        return {
          'bytes': response.bodyBytes,
          'contentType': type,
          'disposition': response.headers['content-disposition'],
        };
      }
      if (decoded is! Map) {
        throw const ApiException(
          'Phản hồi máy chủ không đúng định dạng.',
          kind: ApiErrorKind.invalidResponse,
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw const ApiException(
        'Máy chủ phản hồi quá chậm. Vui lòng thử lại.',
        kind: ApiErrorKind.timeout,
      );
    } on http.ClientException {
      throw const ApiException(
        'Không kết nối được máy chủ. Kiểm tra địa chỉ và kết nối mạng.',
        kind: ApiErrorKind.network,
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final cfg = await config();
    final response = await request(
      '/login',
      method: 'POST',
      auth: RequestAuth.none,
      baseUrl: cfg.serverOrigin.toString(),
      data: {'username': username, 'password': password},
    );
    final token = response['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        'Máy chủ không trả về token đăng nhập.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    final profile = await request(
      '/auth/me',
      token: token,
      baseUrl: cfg.serverOrigin.toString(),
    );
    final user = Map<String, dynamic>.from(profile['data'] as Map);
    if (!['admin', 'manager', 'staff'].contains(user['role'])) {
      throw const ApiException(
        'Vai trò không hợp lệ.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    if ((await config()).serverOrigin != cfg.serverOrigin) {
      throw const ApiException(
        'Máy chủ đã thay đổi. Vui lòng đăng nhập lại.',
        kind: ApiErrorKind.unauthorized,
      );
    }
    await _store.write(token, cfg.serverOrigin.toString());
    LocalSession.save(token, user, serverOrigin: cfg.serverOrigin.toString());
    return {'token': token, 'user': user};
  }

  Future<void> restoreSession() async {
    final saved = await _store.read();
    if (saved == null) return;
    final cfg = await config();
    if (saved['server'] != cfg.serverOrigin.toString()) {
      await _store.clear();
      return;
    }
    final response = await request('/auth/me', token: saved['token'] as String);
    LocalSession.save(
      saved['token'] as String,
      Map<String, dynamic>.from(response['data'] as Map),
      serverOrigin: cfg.serverOrigin.toString(),
    );
  }

  Future<Map<String, dynamic>> fetchProfile() async =>
      Map<String, dynamic>.from((await request('/auth/me'))['data'] as Map);

  Future<List<Map<String, dynamic>>> fetchRawList(
    String path, {
    Map<String, dynamic>? query,
    String? baseUrl,
  }) async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final response = await request(
        path,
        query: {...?query, 'page': page, 'limit': 50},
        baseUrl: baseUrl,
      );
      rows.addAll(
        (response['data'] as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      );
      final pagination = response['pagination'];
      if (pagination is! Map ||
          page >= (pagination['totalPages'] as num).toInt()) {
        break;
      }
      page++;
    }
    return rows;
  }

  Future<List<FacilityModel>> fetchFacilities() async => (await fetchRawList(
    '/production-facilities',
  )).map(FacilityModel.fromJson).toList();
  Future<List<StrainModel>> fetchStrains() async => (await fetchRawList(
    '/mushroom-species',
  )).map(StrainModel.fromJson).toList();
  Future<void> saveStrain(StrainModel strain) async {
    await request(
      '/mushroom-species${strain.id.isEmpty ? '' : '/${strain.id}'}',
      method: strain.id.isEmpty ? 'POST' : 'PUT',
      data: strain.toJson(),
    );
  }

  Future<List<BatchModel>> fetchBatches() async => (await fetchRawList(
    '/cultivation-batches',
  )).map(BatchModel.fromJson).toList();
  Future<void> saveBatch(BatchModel batch) async {
    await request(
      '/cultivation-batches${batch.id.isEmpty ? '' : '/${batch.id}'}',
      method: batch.id.isEmpty ? 'POST' : 'PUT',
      data: batch.toJson(),
    );
  }

  Future<List<AccountModel>> fetchAccounts() async =>
      (await fetchRawList('/admin/users')).map(AccountModel.fromJson).toList();
  Future<List<Map<String, dynamic>>> fetchRoles() =>
      fetchRawList('/admin/roles');
  Future<void> updateAccount(AccountModel account, {String? password}) async {
    await request(
      '/admin/users/${account.id}',
      method: 'PUT',
      data: {
        'full_name': account.fullName,
        'phone_number': account.phoneNumber,
        'email': account.email,
        'role_id': account.roleId,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
  }

  Future<MushroomCatalogResponse> fetchMushroomCatalog([
    String? baseUrl,
  ]) async {
    final rows = MockConfig.enabled
        ? MockSeed.species()
        : await fetchRawList('/mushroom-species', baseUrl: baseUrl);
    final items = rows
        .map(
          (row) => MushroomCatalogItem(
            edibilityStatus: row['edibilityStatus'] as String?,
            name: row['commonName'] as String,
            scientificName: row['scientificName'] as String,
            isPoisonous: [
              'POISONOUS',
              'DEADLY',
            ].contains(row['edibilityStatus']),
          ),
        )
        .toList();
    final poisonous = items.where((item) => item.isPoisonous).toList();
    return MushroomCatalogResponse(
      source: 'mushroom-species',
      total: items.length,
      poisonousCount: poisonous.length,
      safeCount: items.where((item)=>['CHOICE','EDIBLE'].contains(item.edibilityStatus)).length,
      mushrooms: items,
      poisonousMushrooms: poisonous,
    );
  }
}
