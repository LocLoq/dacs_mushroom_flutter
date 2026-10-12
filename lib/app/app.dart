import 'dart:async';

import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/localization/app_text_scope.dart';
import '../core/network/farm_api.dart';
import '../core/storage/local_session.dart';
import '../core/services/backend_queue_service.dart';
import '../core/services/app_preferences_service.dart';
import 'home_screen.dart';
import 'theme/app_theme.dart';

class MushroomApp extends StatefulWidget {
  const MushroomApp({super.key});

  @override
  State<MushroomApp> createState() => _MushroomAppState();
}

class _MushroomAppState extends State<MushroomApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _passwordRequired = false;
  final _prefs = AppPreferencesService.instance;
  bool _darkMode = false;
  AppLanguage _language = AppLanguage.vi;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    LocalSession.changes.addListener(_sessionChanged);
    _bootstrap();
  }

  void _sessionChanged() {
    final required = LocalSession.mustChangePassword;
    if (required && !_passwordRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && LocalSession.mustChangePassword) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      });
    }
    _passwordRequired = required;
  }

  @override
  void dispose() {
    LocalSession.changes.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Đọc token đã lưu rồi GET /auth/me ở nền; không chặn màn hình khởi động.
    unawaited(FarmApi.instance.restoreSession().catchError((Object _) {}));
    try {
      final config = await _prefs.load();
      BackendQueueService.instance.updateBackendBaseUrl(config.backendBaseUrl);
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
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return AppTextScope(
      language: _language,
      onLanguageChanged: updateLanguage,
      darkMode: _darkMode,
      onThemeModeChanged: updateTheme,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
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
