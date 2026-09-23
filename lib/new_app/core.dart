import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppMode { live, demo }

enum RequestAuth { none, optional, required }

enum UserRole { staff, manager, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.staff => 'Staff',
        UserRole.manager => 'Manager',
        UserRole.admin => 'Admin',
      };

  static UserRole? parse(Object? value) {
    switch (value?.toString().toLowerCase()) {
      case 'staff': return UserRole.staff;
      case 'manager': return UserRole.manager;
      case 'admin': return UserRole.admin;
    }
    return null;
  }
}

class ApiConfig {
  const ApiConfig._(this.apiBaseUri, this.serverOrigin);

  final Uri apiBaseUri;
  final Uri serverOrigin;

  factory ApiConfig.fromInput(String input) {
    var raw = input.trim();
    if (raw.isEmpty) raw = const String.fromEnvironment(
      'API_BASE_URL', defaultValue: 'http://10.0.2.2:8080/api');
    final uri = Uri.parse(raw);
    if (!uri.hasScheme || !uri.hasAuthority || uri.userInfo.isNotEmpty ||
        uri.hasQuery || uri.hasFragment ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Địa chỉ máy chủ không hợp lệ.');
    }
    final origin = uri.replace(path: '', query: null, fragment: null);
    final api = origin.replace(path: '/api');
    if (kIsWeb && Uri.base.scheme == 'https' && api.scheme == 'http' &&
        api.host != 'localhost' && api.host != '127.0.0.1') {
      throw const FormatException('Web HTTPS chỉ kết nối HTTPS hoặc localhost.');
    }
    return ApiConfig._(api, origin);
  }

  Uri absoluteMediaUrl(String? value) {
    if (value == null || value.isEmpty) return serverOrigin;
    final media = Uri.tryParse(value);
    if (media != null && media.hasScheme) return media;
    return serverOrigin.resolve(value.startsWith('/') ? value.substring(1) : value);
  }

  @override
  String toString() => apiBaseUri.toString();
}

class ApiException implements Exception {
  const ApiException({this.statusCode, required this.message, this.requestId,
    required this.kind, this.cause});
  final int? statusCode;
  final String message;
  final String? requestId;
  final ApiErrorKind kind;
  final Object? cause;
  @override
  String toString() => message;
}

enum ApiErrorKind { network, timeout, unauthorized, forbidden, validation, server, unknown }

class AuthSession {
  const AuthSession({required this.token, required this.userId, required this.username,
    required this.role, required this.expiresAt, required this.tokenVersion});
  final String token;
  final String userId;
  final String username;
  final UserRole role;
  final DateTime expiresAt;
  final int tokenVersion;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt);

  static AuthSession? fromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final json = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final id = json['id']?.toString();
      final username = json['username']?.toString();
      final role = UserRoleX.parse(json['role']);
      final exp = json['exp'];
      if (id == null || username == null || role == null || exp is! num) return null;
      return AuthSession(token: token, userId: id, username: username, role: role,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true),
        tokenVersion: (json['tokenver'] as num?)?.toInt() ?? 0);
    } catch (_) { return null; }
  }
}

class Pagination {
  const Pagination({required this.page, required this.limit, required this.total, required this.totalPages});
  final int page, limit, total, totalPages;
  bool get hasMore => page < totalPages;
  factory Pagination.fromJson(Map<String, dynamic>? json) => Pagination(
    page: (json?['page'] as num?)?.toInt() ?? 1,
    limit: (json?['limit'] as num?)?.toInt() ?? 20,
    total: (json?['total'] as num?)?.toInt() ?? 0,
    totalPages: (json?['totalPages'] as num?)?.toInt() ?? 1,
  );
}

class PaginatedResult<T> {
  const PaginatedResult(this.items, this.pagination);
  final List<T> items;
  final Pagination pagination;
}

class MediaInput {
  const MediaInput({required this.name, required this.bytes, required this.mimeType});
  final String name;
  final Uint8List bytes;
  final String mimeType;
  int get size => bytes.lengthInBytes;
}

class ApiClient {
  ApiClient(this.config, {String? token, required this.onInvalidSession}) {
    _token = token;
    dio = Dio(BaseOptions(baseUrl: config.apiBaseUri.toString(),
      connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'}));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final auth = options.extra['auth'] as RequestAuth? ?? RequestAuth.required;
      if (auth != RequestAuth.none && _token != null) options.headers['Authorization'] = 'Bearer $_token';
      handler.next(options);
    }, onError: (error, handler) {
      final response = error.response;
      final data = response?.data;
      final message = data is Map ? (data['message']?.toString() ?? data['error']?.toString()) : null;
      final text = message ?? (data is String && data.isNotEmpty ? 'Máy chủ trả về lỗi không hợp lệ.' : 'Không thể kết nối máy chủ.');
      final status = response?.statusCode;
      final invalidToken = (status == 401 || status == 403) &&
        (text.toLowerCase().contains('token') || text.toLowerCase().contains('phiên'));
      if (invalidToken) scheduleMicrotask(onInvalidSession);
      handler.reject(error.copyWith(error: ApiException(
        statusCode: status, message: text, requestId: response?.headers.value('x-request-id'),
        kind: _kind(status, error.type), cause: error,
      )));
    }));
  }

  late final Dio dio;
  final ApiConfig config;
  final VoidCallback onInvalidSession;
  String? _token;
  void setToken(String? value) => _token = value;

  ApiErrorKind _kind(int? status, DioExceptionType type) {
    if (status == 401) return ApiErrorKind.unauthorized;
    if (status == 403) return ApiErrorKind.forbidden;
    if (status == 422 || status == 400) return ApiErrorKind.validation;
    if (status != null && status >= 500) return ApiErrorKind.server;
    if (type == DioExceptionType.connectionTimeout || type == DioExceptionType.receiveTimeout) return ApiErrorKind.timeout;
    return ApiErrorKind.network;
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query, RequestAuth auth = RequestAuth.required}) =>
    dio.get(path, queryParameters: query, options: Options(extra: {'auth': auth}));
  Future<Response<dynamic>> post(String path, {Object? data, Map<String, dynamic>? query, RequestAuth auth = RequestAuth.required}) =>
    dio.post(path, data: data, queryParameters: query, options: Options(extra: {'auth': auth}));
  Future<Response<dynamic>> put(String path, {Object? data, RequestAuth auth = RequestAuth.required}) =>
    dio.put(path, data: data, options: Options(extra: {'auth': auth}));
  Future<Response<dynamic>> patch(String path, {Object? data, RequestAuth auth = RequestAuth.required}) =>
    dio.patch(path, data: data, options: Options(extra: {'auth': auth}));
  Future<Response<dynamic>> delete(String path, {RequestAuth auth = RequestAuth.required}) =>
    dio.delete(path, options: Options(extra: {'auth': auth}));
}

class SessionStore {
  static const _key = 'mushroom_auth_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}
