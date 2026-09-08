import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_text_scope.dart';
import 'result_payload_view.dart';

class ResultPopupDialog extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic> result;
  final Uint8List? previewBytes;

  const ResultPopupDialog({
    super.key,
    required this.jobId,
    required this.result,
    this.previewBytes,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    required Map<String, dynamic> result,
    Uint8List? previewBytes,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ResultPopupDialog(
        jobId: jobId,
        result: result,
        previewBytes: previewBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(context, vi: 'Kết Quả Nhận Diện Nấm', en: 'Recognition Result'),
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
              if (previewBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    previewBytes!,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              ResultPayloadView(result: result),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          vi: 'Lưu ý an toàn: Kết quả AI chỉ mang tính tham khảo khoa học. Tuyệt đối không tự ý ăn hoặc chế biến nấm hoang dã.',
                          en: 'Safety notice: AI results are for reference only. Never consume wild mushrooms based on this prediction.',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
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

