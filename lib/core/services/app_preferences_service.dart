import 'package:shared_preferences/shared_preferences.dart';
import '../../app/config/app_constants.dart';
import '../localization/app_language.dart';
import '../models/app_config.dart';

class AppPreferencesService {
  static AppPreferencesService? _instance;
  static AppPreferencesService get instance => _instance ??= AppPreferencesService();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<AppConfig> load() async {
    await init();
    final url = _prefs!.getString(AppConstants.prefBackendBaseUrl) ??
        AppConstants.kDefaultBackendBaseUrl;
    final darkMode = _prefs!.getBool(AppConstants.prefDarkMode) ?? false;
    final langCode = _prefs!.getString(AppConstants.prefLanguageCode) ?? 'vi';
    final configured = _prefs!.getBool(AppConstants.prefBackendConfigured) ?? false;

    return AppConfig(
      backendBaseUrl: url,
      darkMode: darkMode,
      language: AppLanguage.fromCode(langCode),
      backendConfigured: configured,
    );
  }

  Future<void> saveBackendBaseUrl(String value) async {
    await init();
    await _prefs!.setString(AppConstants.prefBackendBaseUrl, value.trim());
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

