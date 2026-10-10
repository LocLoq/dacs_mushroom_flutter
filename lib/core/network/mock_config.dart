import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/local_session.dart';

class MockConfig {
  static const _key = 'farm_mock_mode';
  static final notifier = ValueNotifier<bool>(false);
  static bool get enabled => notifier.value;
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    notifier.value = prefs.getBool(_key) ?? false;
  }

  static Future<void> set(bool value) async {
    if (value != enabled) await LocalSession.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    notifier.value = value;
  }

  static Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString('farm_mock_token');
  static Future<void> saveToken(String value) async =>
      (await SharedPreferences.getInstance()).setString(
        'farm_mock_token',
        value,
      );
  static const demoAccounts = <(String, String, String)>[
    ('admin', 'admin123', 'Quản trị viên'),
    ('manager', 'manager123', 'Quản lý'),
    ('staff', 'staff123', 'Nhân viên'),
  ];
}
