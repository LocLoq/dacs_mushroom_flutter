import 'package:flutter/material.dart';
import '../../../../core/localization/app_text_scope.dart';
import 'result_row.dart';

class ResultPayloadView extends StatelessWidget {
  final Map<String, dynamic> result;

  const ResultPayloadView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prediction = result['prediction']?.toString() ?? 'unknown';
    final rawPred = result['raw_prediction']?.toString() ?? prediction;
    final mushroomName = result['mushroom_name']?.toString() ??
        (prediction != 'unknown' ? prediction : tr(context, vi: 'Không xác định', en: 'Unknown'));

    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidencePct = confidence <= 1.0 ? confidence * 100 : confidence;
    final threshold = (result['confidence_threshold'] as num?)?.toDouble() ?? 0.70;
    final thresholdPct = threshold <= 1.0 ? threshold * 100 : threshold;

    final isPoisonous = _toBool(result['is_poisonous']);
    final isAccepted = _toBool(result['accepted_prediction']) ?? true;
    final reason = result['decision_reason']?.toString() ?? '';
    final inferenceSec = (result['inference_time_seconds'] as num?)?.toDouble();
    final sizeBytes = (result['size_bytes'] as num?)?.toInt();
    final sha256 = result['sha256']?.toString();

    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeLabel;

    if (prediction.toLowerCase() == 'unknown' || isPoisonous == null) {
      badgeColor = Colors.orange.shade700;
      badgeIcon = Icons.help_outline_rounded;
      badgeLabel = tr(context, vi: 'Chưa rõ loài', en: 'Unknown Species');
    } else if (isPoisonous) {
      badgeColor = Colors.red.shade700;
      badgeIcon = Icons.warning_rounded;
      badgeLabel = tr(context, vi: 'CẢNH BÁO: NẤM ĐỘC', en: 'WARNING: POISONOUS');
    } else {
      badgeColor = Colors.green.shade700;
      badgeIcon = Icons.verified_rounded;
      badgeLabel = tr(context, vi: 'NẤM AN TOÀN / ĂN ĐƯỢC', en: 'SAFE / EDIBLE');
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Độc tính
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, color: badgeColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    badgeLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tên nấm & Độ tin cậy
            Text(
              mushroomName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  tr(context, vi: 'Độ tin cậy: ', en: 'Confidence: '),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                ),
                Text(
                  '${confidencePct.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: confidencePct >= thresholdPct
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Thông số chi tiết
            ResultRow(
              label: tr(context, vi: 'Dự đoán gốc', en: 'Raw prediction'),
              value: rawPred,
            ),
            ResultRow(
              label: tr(context, vi: 'Chấp nhận kết quả', en: 'Accepted'),
              value: isAccepted
                  ? tr(context, vi: 'Đạt ngưỡng tin cậy', en: 'Accepted above threshold')
                  : tr(context, vi: 'Dưới ngưỡng tin cậy', en: 'Below confidence threshold'),
              valueStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isAccepted ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            ResultRow(
              label: tr(context, vi: 'Ngưỡng tối thiểu', en: 'Threshold'),
              value: '${thresholdPct.toStringAsFixed(1)}%',
            ),
            if (reason.isNotEmpty)
              ResultRow(
                label: tr(context, vi: 'Lý do quyết định', en: 'Decision reason'),
                value: reason,
              ),
            if (inferenceSec != null)
              ResultRow(
                label: tr(context, vi: 'Thời gian suy luận', en: 'Inference time'),
                value: '${(inferenceSec * 1000).toStringAsFixed(0)} ms',
              ),
            if (sizeBytes != null)
              ResultRow(
                label: tr(context, vi: 'Dung lượng ảnh', en: 'Image size'),
                value: '${(sizeBytes / 1024).toStringAsFixed(1)} KB',
              ),
            if (sha256 != null && sha256.isNotEmpty)
              ResultRow(
                label: 'SHA-256',
                value: sha256.length > 16 ? '${sha256.substring(0, 16)}...' : sha256,
              ),
          ],
        ),
      ),
    );
  }

  bool? _toBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }
}

