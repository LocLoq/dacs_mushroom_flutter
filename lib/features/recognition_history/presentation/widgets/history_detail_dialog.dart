import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_text_scope.dart';
import '../../../../core/widgets/mushroom_glyph.dart';
import '../../../recognition/presentation/widgets/result_payload_view.dart';
import '../../../recognition/presentation/widgets/result_row.dart';
import '../../data/history_item.dart';

class HistoryDetailDialog extends StatelessWidget {
  final RecognitionHistoryItem item;

  const HistoryDetailDialog({super.key, required this.item});

  static Future<void> show(BuildContext context, RecognitionHistoryItem item) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => HistoryDetailDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPreview = item.previewImagePath != null &&
        File(item.previewImagePath!).existsSync();
    String two(int n) => n.toString().padLeft(2, '0');
    final t = item.createdAt;
    final when =
        '${two(t.day)}/${two(t.month)}/${t.year} · ${two(t.hour)}:${two(t.minute)}';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 210,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasPreview)
                      Image.file(File(item.previewImagePath!), fit: BoxFit.cover)
                    else
                      Container(
                        decoration:
                            const BoxDecoration(gradient: AppColors.heroGradient),
                        child: const Center(child: MushroomGlyph(size: 88)),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Job ${item.jobId.length > 10 ? '${item.jobId.substring(0, 8)}…' : item.jobId}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(when, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (item.result != null) ...[
                      ResultPayloadView(result: item.result!),
                      const SizedBox(height: 10),
                      const ResultSafetyNotice(),
                    ] else if (item.error != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          item.error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      )
                    else
                      Text(
                        tr(context,
                            vi: 'Không có dữ liệu kết quả.',
                            en: 'No result data available.'),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr(context, vi: 'Đóng', en: 'Close')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
