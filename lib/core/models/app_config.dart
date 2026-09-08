import '../localization/app_language.dart';

class AppConfig {
  final String backendBaseUrl;
  final bool darkMode;
  final AppLanguage language;
  final bool backendConfigured;

  const AppConfig({
    required this.backendBaseUrl,
    required this.darkMode,
    required this.language,
    required this.backendConfigured,
  });

  AppConfig copyWith({
    String? backendBaseUrl,
    bool? darkMode,
    AppLanguage? language,
    bool? backendConfigured,
  }) {
    return AppConfig(
      backendBaseUrl: backendBaseUrl ?? this.backendBaseUrl,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      backendConfigured: backendConfigured ?? this.backendConfigured,
    );
  }
}

