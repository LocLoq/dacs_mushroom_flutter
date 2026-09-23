import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core.dart';

final preferencesProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());
final sessionStoreProvider = Provider((_) => SessionStore());

class AppSettings {
  const AppSettings({required this.mode, required this.themeMode, required this.locale, this.backendOverride});
  final AppMode mode;
  final ThemeMode themeMode;
  final Locale locale;
  final String? backendOverride;
  String get backendInput => backendOverride ?? const String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'http://10.0.2.2:8080/api');
  AppSettings copyWith({AppMode? mode, ThemeMode? themeMode, Locale? locale, String? backendOverride, bool clearBackend = false}) =>
    AppSettings(mode: mode ?? this.mode, themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale, backendOverride: clearBackend ? null : backendOverride ?? this.backendOverride);
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(preferencesProvider);
    return AppSettings(
      mode: prefs.getString('app_mode') == 'demo' ? AppMode.demo : AppMode.live,
      themeMode: ThemeMode.values.byName(prefs.getString('theme_mode') ?? 'system'),
      locale: Locale(prefs.getString('locale') ?? 'vi'),
      backendOverride: prefs.getString('backend_override'),
    );
  }
  Future<void> update(AppSettings value) async {
    state = value;
    final prefs = ref.read(preferencesProvider);
    await prefs.setString('app_mode', value.mode.name);
    await prefs.setString('theme_mode', value.themeMode.name);
    await prefs.setString('locale', value.locale.languageCode);
    if (value.backendOverride == null) await prefs.remove('backend_override');
    else await prefs.setString('backend_override', value.backendOverride!);
  }
}
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
final apiConfigProvider = Provider<ApiConfig>((ref) => ApiConfig.fromInput(ref.watch(settingsProvider).backendInput));

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  @override
  FutureOr<AuthSession?> build() async {
    final token = await ref.read(sessionStoreProvider).read();
    final session = token == null ? null : AuthSession.fromJwt(token);
    if (session == null || session.isExpired) {
      if (token != null) await ref.read(sessionStoreProvider).clear();
      return null;
    }
    return session;
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    try {
      final config = ref.read(apiConfigProvider);
      final raw = DioForLogin(config);
      final response = await raw.login(username, password);
      final token = (response['token'] as String?);
      final session = token == null ? null : AuthSession.fromJwt(token);
      if (session == null || session.isExpired) throw const ApiException(message: 'Token đăng nhập không hợp lệ.', kind: ApiErrorKind.unauthorized);
      await ref.read(sessionStoreProvider).write(token!);
      state = AsyncData(session);
    } on ApiException catch (error, stack) {
      state = AsyncError(error, stack);
    } catch (error, stack) {
      state = AsyncError(ApiException(message: 'Không thể đăng nhập.', kind: ApiErrorKind.network, cause: error), stack);
    }
  }

  Future<void> logout() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(null);
  }
}

class DioForLogin {
  DioForLogin(this.config) : _dio = Dio(BaseOptions(baseUrl: config.apiBaseUri.toString(), connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30)));
  final ApiConfig config;
  final Dio _dio;
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final result = await _dio.post('/login', data: {'username': username, 'password': password});
      return Map<String, dynamic>.from(result.data as Map);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      throw ApiException(statusCode: e.response?.statusCode, message: message ?? 'Không thể kết nối máy chủ.',
        requestId: e.response?.headers.value('x-request-id'), kind: e.response?.statusCode == 401 ? ApiErrorKind.unauthorized : ApiErrorKind.network, cause: e);
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);
final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(authProvider).asData?.value;
  return ApiClient(ref.watch(apiConfigProvider), token: session?.token, onInvalidSession: () => ref.read(authProvider.notifier).logout());
});

bool canManage(UserRole? role) => role == UserRole.manager || role == UserRole.admin;
bool isAdmin(UserRole? role) => role == UserRole.admin;

String jsonText(Object? value) => const JsonEncoder.withIndent('  ').convert(value);
