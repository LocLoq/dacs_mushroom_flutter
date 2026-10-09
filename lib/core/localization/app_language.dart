enum AppLanguage {
  vi,
  en;

  String get code {
    switch (this) {
      case AppLanguage.vi:
        return 'vi';
      case AppLanguage.en:
        return 'en';
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.vi:
        return 'Tiếng Việt';
      case AppLanguage.en:
        return 'English';
    }
  }

  static AppLanguage fromCode(String? code) {
    if (code == 'en') return AppLanguage.en;
    return AppLanguage.vi;
  }
}

