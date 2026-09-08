import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_text_scope.dart';
import '../../../recognition/presentation/widgets/result_payload_view.dart';
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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.history, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(context, vi: 'Chi Tiết Lịch Sử Quét', en: 'History Detail'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasPreview)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(item.previewImagePath!),
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Job: ${item.jobId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (item.result != null)
                ResultPayloadView(result: item.result!)
              else if (item.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                )
              else
                Text(
                  tr(context, vi: 'Không có dữ liệu kết quả.', en: 'No result data available.'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(context, vi: 'Đóng', en: 'Close')),
        ),
      ],
    );
  }
}
