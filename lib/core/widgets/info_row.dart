import 'package:flutter/material.dart';

/// Một dòng "nhãn : giá trị" dùng trong màn chi tiết.
class InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = (value == null || value!.isEmpty) ? '—' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Mở nội dung chi tiết trong bottom sheet cao ~90%.
Future<T?> showDetailSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.9, child: builder(ctx)),
  );
}
