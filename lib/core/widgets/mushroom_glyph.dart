import 'package:flutter/material.dart';

/// Hình cây nấm vẽ bằng code (không cần asset ảnh).
/// Dùng làm minh hoạ cho hero card, ô loài nấm trong từ điển, màn đăng nhập.
class MushroomGlyph extends StatelessWidget {
  final double size;
  final Color capColor;
  final Color stemColor;
  final Color spotColor;

  const MushroomGlyph({
    super.key,
    this.size = 96,
    this.capColor = const Color(0xFFC8935A),
    this.stemColor = const Color(0xFFF3EAD3),
    this.spotColor = const Color(0xFFFFF8E6),
  });

  /// Chọn màu mũ nấm ổn định theo tên loài (cùng tên -> cùng màu).
  static MushroomGlyph forSpecies(
    String name, {
    required bool poisonous,
    double size = 96,
  }) {
    const safeCaps = [
      Color(0xFFC8935A), // nâu vàng
      Color(0xFFA9714B), // nâu
      Color(0xFFD9BE8C), // kem
      Color(0xFFB98A62), // nâu nhạt
      Color(0xFF8E6B4F), // nâu đậm
    ];
    const poisonCaps = [
      Color(0xFFC94B3B), // đỏ
      Color(0xFFD9722E), // cam
      Color(0xFF9B4A6B), // tím đỏ
    ];
    final palette = poisonous ? poisonCaps : safeCaps;
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return MushroomGlyph(
      size: size,
      capColor: palette[h % palette.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(capColor, stemColor, spotColor),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final Color cap;
  final Color stem;
  final Color spot;

  _GlyphPainter(this.cap, this.stem, this.spot);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Thân nấm
    final stemPath = Path()
      ..moveTo(0.36 * w, 0.52 * h)
      ..lineTo(0.64 * w, 0.52 * h)
      ..quadraticBezierTo(0.68 * w, 0.82 * h, 0.72 * w, 0.92 * h)
      ..quadraticBezierTo(0.5 * w, 0.99 * h, 0.28 * w, 0.92 * h)
      ..quadraticBezierTo(0.32 * w, 0.82 * h, 0.36 * w, 0.52 * h)
      ..close();
    canvas.drawPath(stemPath, Paint()..color = stem);
    // Bóng nhẹ bên phải thân
    canvas.drawPath(
      stemPath,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.10)],
        ).createShader(Rect.fromLTWH(0.28 * w, 0, 0.44 * w, h)),
    );

    // Mũ nấm
    final capPath = Path()
      ..moveTo(0.05 * w, 0.56 * h)
      ..cubicTo(0.05 * w, 0.06 * h, 0.95 * w, 0.06 * h, 0.95 * w, 0.56 * h)
      ..quadraticBezierTo(0.5 * w, 0.68 * h, 0.05 * w, 0.56 * h)
      ..close();
    canvas.drawPath(capPath, Paint()..color = cap);
    canvas.drawPath(
      capPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.14),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Đốm trên mũ
    final spotPaint = Paint()..color = spot.withValues(alpha: 0.92);
    canvas.drawCircle(Offset(0.30 * w, 0.36 * h), 0.055 * w, spotPaint);
    canvas.drawCircle(Offset(0.52 * w, 0.24 * h), 0.07 * w, spotPaint);
    canvas.drawCircle(Offset(0.72 * w, 0.38 * h), 0.05 * w, spotPaint);
    canvas.drawCircle(Offset(0.46 * w, 0.46 * h), 0.035 * w, spotPaint);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.cap != cap || old.stem != stem || old.spot != spot;
}
