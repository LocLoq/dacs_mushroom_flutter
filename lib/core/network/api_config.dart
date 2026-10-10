import '../../app/config/app_constants.dart';
import '../services/app_preferences_service.dart';
import '../services/backend_queue_service.dart';

class ApiConfig {
  static String _current = AppConstants.kDefaultBackendBaseUrl;
  static void useServer(String value) { _current=ApiConfig.fromInput(value).serverOrigin.toString(); }
  static String get baseUrl =>
      ApiConfig.fromInput(_current).apiBaseUri.toString();
  static String get origin =>
      ApiConfig.fromInput(_current).serverOrigin.toString();
  static Future<void> load() async {
    _current = (await AppPreferencesService.instance.load()).backendBaseUrl;
  }

  static Future<void> save(String value) async {
    await AppPreferencesService.instance.saveBackendBaseUrl(value);
    _current = ApiConfig.fromInput(value).serverOrigin.toString();
    BackendQueueService.instance.updateBackendBaseUrl(_current);
    await BackendQueueService.instance.reconnect(_current);
  }

  static String? media(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    if (uri.hasScheme && !['http', 'https'].contains(uri.scheme)) return null;
    return Uri.parse(origin).resolve(raw.trim()).toString();
  }

  ApiConfig._(this.serverOrigin);
  final Uri serverOrigin;
  Uri get apiBaseUri => serverOrigin.replace(path: '/api');
  factory ApiConfig.fromInput(String input) {
    var text = input.trim();
    if (text.isEmpty) text = AppConstants.kDefaultBackendBaseUrl;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Địa chỉ máy chủ không hợp lệ.');
    }
    return ApiConfig._(
      Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      ),
    );
  }
  Uri endpoint(String path, [Map<String, dynamic>? query]) =>
      serverOrigin.replace(
        path: '/api/${path.replaceFirst(RegExp(r'^/+'), '')}',
        queryParameters: query == null
            ? null
            : {
                for (final entry in query.entries)
                  if (entry.value != null) entry.key: entry.value.toString(),
              },
      );
  Uri mediaUrl(String value) => serverOrigin.resolve(value);
}
