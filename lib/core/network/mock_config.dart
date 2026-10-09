import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chế độ dữ liệu mẫu cho khu "Quản lý": khi BẬT, mọi lệnh gọi của [FarmApi]
/// được trả lời bởi [MockBackend] trong bộ nhớ, không cần backend thật.
/// Mặc định BẬT để chạy thử giao diện ngay; tắt ở Cài đặt → API Trại nấm.
class MockConfig {
  static const _key = 'farm_mock_mode';

  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(true);

  static bool get enabled => notifier.value;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    notifier.value = p.getBool(_key) ?? true;
  }

  static Future<void> set(bool value) async {
    notifier.value = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, value);
  }

  /// Tài khoản có sẵn trong chế độ mẫu (hiển thị ở màn Đăng nhập).
  static const demoAccounts = <(String, String, String)>[
    ('admin', 'admin123', 'Quản trị viên'),
    ('manager', 'manager123', 'Quản lý'),
    ('staff', 'staff123', 'Nhân viên'),
  ];
}
