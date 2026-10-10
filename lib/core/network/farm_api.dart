import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../storage/local_session.dart';
import '../utils/json_utils.dart';
import 'api_client.dart' show ApiClient, ApiConfig, RequestAuth;
import 'api_exception.dart' as transport;
import 'mock_config.dart';
import 'mock_backend.dart';

class ApiException implements Exception {
  const ApiException(this.status, this.message, [this.code]);
  final int status;
  final String message;
  final String? code;
  bool get isConflict => status == 409;
  bool get isForbidden => status == 403;
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}

class DownloadedFile {
  const DownloadedFile(this.bytes, this.filename, this.contentType);
  final Uint8List bytes;
  final String? filename;
  final String contentType;
}

class FarmApi {
  FarmApi({ApiClient? client}) : _api = client ?? ApiClient();
  static final instance = FarmApi();
  final ApiClient _api;
  Future<J> _wrap(Future<J> request) async {
    try {
      return await request;
    } on transport.ApiException catch (error) {
      throw ApiException(error.status, error.message, error.code);
    }
  }

  Future<J> get(
    String path, {
    Map<String, dynamic>? query,
    bool public = false,
  }) => MockConfig.enabled
      ? MockBackend.instance.handle('GET', path, query: query, public: public)
      : _wrap(
          _api.request(
            path,
            query: query,
            auth: public ? RequestAuth.none : RequestAuth.required,
          ),
        );
  Future<J> post(String path, [Object? body]) => MockConfig.enabled
      ? MockBackend.instance.handle('POST', path, body: body)
      : _wrap(
          _api.request(
            path,
            method: 'POST',
            data: body == null ? null : Map<String, dynamic>.from(body as Map),
          ),
        );
  Future<J> put(String path, Object body) => MockConfig.enabled
      ? MockBackend.instance.handle('PUT', path, body: body)
      : _wrap(
          _api.request(
            path,
            method: 'PUT',
            data: Map<String, dynamic>.from(body as Map),
          ),
        );
  Future<J> patch(String path, Object body) => MockConfig.enabled
      ? MockBackend.instance.handle('PATCH', path, body: body)
      : _wrap(
          _api.request(
            path,
            method: 'PATCH',
            data: Map<String, dynamic>.from(body as Map),
          ),
        );
  Future<J> delete(String path) => MockConfig.enabled
      ? MockBackend.instance.handle('DELETE', path)
      : _wrap(_api.request(path, method: 'DELETE'));
  Future<void> login(String username, String password) async {
    if (MockConfig.enabled) {
      final response = await MockBackend.instance.handle(
        'POST',
        '/login',
        body: {'username': username, 'password': password},
        public: true,
      );
      LocalSession.setMockToken(response['token'] as String);
      if (!await confirmProfile())
        throw const ApiException(401, 'Không xác nhận được tài khoản mẫu.');
      await MockConfig.saveToken(response['token'] as String);
      return;
    }
    try {
      await _api.login(username, password);
    } on transport.ApiException catch (error) {
      throw ApiException(error.status, error.message, error.code);
    }
  }

  Future<bool> confirmProfile() async {
    try {
      return LocalSession.setProfile(
        MockConfig.enabled
            ? Map<String, dynamic>.from((await get('/auth/me'))['data'] as Map)
            : await _api.fetchProfile(),
      );
    } on transport.ApiException {
      return false;
    }
  }

  Future<void> restoreSession() async {
    await ApiConfig.load();
    await MockConfig.load();
    if (MockConfig.enabled) {
      final token = await MockConfig.token();
      if (token != null) {
        LocalSession.setMockToken(token);
        await confirmProfile();
      }
    } else {
      await _api.restoreSession();
    }
  }

  Future<J> multipart(
    String method,
    String path, {
    Map<String, String> fields = const {},
    List<XFile> files = const [],
    String fileField = 'images',
    bool public = false,
  }) async {
    if (MockConfig.enabled)
      return MockBackend.instance.handle(
        method,
        path,
        fields: fields,
        files: files,
        public: public,
      );
    final cfg = await _api.config();
    final request = http.MultipartRequest(method, cfg.endpoint(path));
    request.fields.addAll(fields);
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          await file.readAsBytes(),
          filename: file.name,
          contentType: MediaType.parse(mimeOf(file)),
        ),
      );
    }
    return _wrap(
      _api.send(
        request,
        auth: public ? RequestAuth.none : RequestAuth.required,
        serverOrigin: cfg.serverOrigin.toString(),
      ),
    );
  }

  Future<DownloadedFile> download(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (MockConfig.enabled) return MockBackend.instance.download(path, query);
    final response = await _wrap(
      _api.request(path, query: query, binary: true),
    );
    final header = response['disposition'] as String?;
    String? filename;
    if (header != null) {
      final encoded = RegExp(
        r"filename\*=UTF-8''([^;]+)",
        caseSensitive: false,
      ).firstMatch(header);
      filename = encoded == null
          ? RegExp(r'filename="?([^";]+)"?').firstMatch(header)?.group(1)
          : Uri.decodeComponent(encoded.group(1)!);
    }
    return DownloadedFile(
      response['bytes'] as Uint8List,
      filename,
      response['contentType'] as String,
    );
  }

  static String mimeOf(XFile file) {
    final name = file.name.toLowerCase();
    return name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
  }
}
