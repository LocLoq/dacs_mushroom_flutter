import 'package:flutter/material.dart';

import 'mushroom_glyph.dart';

/// Ảnh đại diện cho một loài nấm. Thứ tự ưu tiên:
///   1. [imageUrl] từ backend (URL đầy đủ hoặc đường dẫn tương đối)
///   2. ảnh đóng gói trong app: assets/mushrooms/<assetKey>.jpg
///   3. hình nấm vẽ sẵn [MushroomGlyph]
/// Bước nào lỗi (mất mạng, thiếu file...) thì tự rơi xuống bước kế tiếp,
/// nên không bao giờ hiện ô ảnh vỡ.
class MushroomPhoto extends StatelessWidget {
  final String? imageUrl;
  final String assetKey;
  final String name;
  final bool poisonous;
  final String? baseUrl;
  final double glyphSize;
  final BoxFit fit;

  const MushroomPhoto({
    super.key,
    required this.assetKey,
    required this.name,
    required this.poisonous,
    this.imageUrl,
    this.baseUrl,
    this.glyphSize = 84,
    this.fit = BoxFit.cover,
  });

  String? _resolveUrl() {
    final u = imageUrl;
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final b = baseUrl;
    if (b == null || b.isEmpty) return null;
    final base = b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    return u.startsWith('/') ? '$base$u' : '$base/$u';
  }

  Widget _glyph() => Center(
        child: MushroomGlyph.forSpecies(name,
            poisonous: poisonous, size: glyphSize),
      );

  Widget _asset() {
    if (assetKey.isEmpty) return _glyph();
    return Image.asset(
      'assets/mushrooms/$assetKey.jpg',
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 600, // giải mã nhỏ lại để tiết kiệm RAM
      errorBuilder: (_, __, ___) => _glyph(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveUrl();
    if (url == null) return _asset();

    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 600,
      // Đang tải: hiện tạm hình nấm vẽ, tải xong thì thay bằng ảnh thật
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _glyph(),
      // Lỗi mạng hoặc 404: thử ảnh trong app, rồi mới đến hình vẽ
      errorBuilder: (_, __, ___) => _asset(),
    );
  }
}
