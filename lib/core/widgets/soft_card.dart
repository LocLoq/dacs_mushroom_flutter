import 'package:flutter/material.dart';

/// Thẻ bo tròn dùng chung: viền mảnh + bóng rất nhẹ.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final Border? border;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 20,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: r,
        border: border ?? Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173F0E).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Tiêu đề mục (vd: "Hàng đợi nhận diện") kèm phần phụ bên phải.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Ô icon vuông bo tròn nền mint.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  const IconTile(
    this.icon, {
    super.key,
    this.color,
    this.background,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? scheme.primary),
    );
  }
}
