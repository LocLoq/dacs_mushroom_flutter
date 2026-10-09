import 'package:flutter/material.dart';

/// Bảng màu "rừng xanh + mint" – lấy cảm hứng từ template AI Identifier.
/// Các tên cũ (primary, background, card, textPrimary, ...) được giữ nguyên
/// để các màn hình quản trị chưa sửa vẫn chạy bình thường.
class AppColors {
  // Thương hiệu
  static const primary = Color(0xFF2F6B1E); // xanh rừng
  static const primaryDark = Color(0xFF173F0E); // xanh rừng đậm (hero, nút chính)
  static const leaf = Color(0xFF5FA02F); // xanh lá sáng (điểm nhấn)
  static const mint = Color(0xFFE3EFD6); // nền chip / ô icon
  static const mintSoft = Color(0xFFF0F5E9); // nền ứng dụng

  // Nền & chữ
  static const background = mintSoft;
  static const card = Colors.white;
  static const line = Color(0xFFDCE6CF);
  static const textPrimary = Color(0xFF14200C);
  static const textSecondary = Color(0xFF66765A);

  // Trạng thái
  static const danger = Color(0xFFC62828);
  static const dangerSoft = Color(0xFFFCE8E6);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFFF3D6);
  static const success = Color(0xFF2E7D32);

  // Dark mode
  static const darkBg = Color(0xFF0F160B);
  static const darkCard = Color(0xFF1A2414);
  static const darkLine = Color(0xFF2B3922);

  /// Gradient dùng cho hero card.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F4F12), Color(0xFF173F0E), Color(0xFF0F2A09)],
  );
}
