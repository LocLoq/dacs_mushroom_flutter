import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/localization/app_text_scope.dart';
import '../core/services/app_preferences_service.dart';
import 'home_screen.dart';
import 'theme/app_theme.dart';

class MushroomApp extends StatefulWidget {
  const MushroomApp({super.key});

  @override
  State<MushroomApp> createState() => _MushroomAppState();
}

class _MushroomAppState extends State<MushroomApp> {
  final _prefs = AppPreferencesService.instance;
  bool _darkMode = false;
  AppLanguage _language = AppLanguage.vi;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final config = await _prefs.load();
      if (mounted) {
        setState(() {
          _darkMode = config.darkMode;
          _language = config.language;
          _isReady = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isReady = true);
    }
  }

  void updateTheme(bool isDark) {
    setState(() => _darkMode = isDark);
  }

  void updateLanguage(AppLanguage lang) {
    setState(() => _language = lang);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return AppTextScope(
      language: _language,
      onLanguageChanged: updateLanguage,
      child: MaterialApp(
        title: _language == AppLanguage.en
            ? 'Mushroom Management & AI Recognizer'
            : 'Quản lý Sản xuất & Nhận diện Nấm',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const HomeScreen(),
      ),
    );
  }
}
