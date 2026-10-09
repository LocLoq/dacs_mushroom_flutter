import 'package:flutter/material.dart';

import '../network/api_config.dart';

/// Ảnh từ server: ghép origin cho /uploads/..., có placeholder khi lỗi/rỗng,
/// bấm để phóng to.
class NetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final bool zoomable;

  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 14,
    this.zoomable = true,
  });

  Widget _placeholder(BuildContext context, {bool broken = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.primaryContainer,
      child: Icon(
        broken ? Icons.broken_image_outlined : Icons.image_outlined,
        color: scheme.primary.withValues(alpha: 0.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = ApiConfig.media(url);
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: full == null
          ? _placeholder(context)
          : Image.network(
              full,
              width: width,
              height: height,
              fit: fit,
              cacheWidth: 800,
              loadingBuilder: (c, w, p) => p == null ? w : _placeholder(context),
              errorBuilder: (c, e, s) => _placeholder(context, broken: true),
            ),
    );
    if (!zoomable || full == null) return child;
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  full,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  color: Colors.white,
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}
