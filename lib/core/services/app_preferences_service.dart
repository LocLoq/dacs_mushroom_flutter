import 'package:shared_preferences/shared_preferences.dart';
import '../../app/config/app_constants.dart';
import 'server_connection_service.dart';
import '../localization/app_language.dart';
import '../models/app_config.dart';
import '../network/api_config.dart';
import '../storage/local_session.dart';

class AppPreferencesService {
  static AppPreferencesService? _instance;
  static AppPreferencesService get instance =>
      _instance ??= AppPreferencesService();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<AppConfig> load() async {
    await init();
    final url =
        _prefs!.getString(AppConstants.prefBackendBaseUrl) ??
        AppConstants.kDefaultBackendBaseUrl;
    final darkMode = _prefs!.getBool(AppConstants.prefDarkMode) ?? false;
    final langCode = _prefs!.getString(AppConstants.prefLanguageCode) ?? 'vi';
    final configured =
        _prefs!.getBool(AppConstants.prefBackendConfigured) ?? false;

    return AppConfig(
      backendBaseUrl: url,
      darkMode: darkMode,
      language: AppLanguage.fromCode(langCode),
      backendConfigured: configured,
    );
  }

  Future<void> saveBackendBaseUrl(String value) async {
    await init();
    final config = ApiConfig.fromInput(value);
    final previous =
        _prefs!.getString(AppConstants.prefBackendBaseUrl) ??
        AppConstants.kDefaultBackendBaseUrl;
    if (ApiConfig.fromInput(previous).serverOrigin != config.serverOrigin)
      await LocalSession.logout();
    await _prefs!.setString(
      AppConstants.prefBackendBaseUrl,
      config.serverOrigin.toString(),
    );
    ApiConfig.useServer(config.serverOrigin.toString());
  }

  Future<PushHostMode> hostMode() async {
    await init();
    final value = _prefs!.getString('push_host_mode');
    return PushHostMode.values.where((m) => m.name == value).firstOrNull ??
        PushHostMode.infer(
          _prefs!.getString(AppConstants.prefBackendBaseUrl) ?? '',
        );
  }

  Future<String> urlForMode(PushHostMode mode) async {
    await init();
    final saved = _prefs!.getString('backend_url_' + mode.name);
    if (saved != null) return saved;
    final legacy = _prefs!.getString(AppConstants.prefBackendBaseUrl);
    return legacy != null && PushHostMode.infer(legacy) == mode ? legacy : '';
  }

  Future<void> saveServerProfile(PushHostMode mode, String value) async {
    final origin = validateServerUrl(value, mode);
    await saveBackendBaseUrl(origin);
    await _prefs!.setString('push_host_mode', mode.name);
    await _prefs!.setString('backend_url_' + mode.name, origin);
  }

  Future<void> saveDarkMode(bool enabled) async {
    await init();
    await _prefs!.setBool(AppConstants.prefDarkMode, enabled);
  }

  Future<void> saveLanguage(AppLanguage language) async {
    await init();
    await _prefs!.setString(AppConstants.prefLanguageCode, language.code);
  }

  Future<bool> isBackendConfigured() async {
    await init();
    return _prefs!.getBool(AppConstants.prefBackendConfigured) ?? false;
  }

  Future<void> markBackendConfigured() async {
    await init();
    await _prefs!.setBool(AppConstants.prefBackendConfigured, true);
  }
}
