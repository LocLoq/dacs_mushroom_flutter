import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_text_scope.dart';
import 'result_row.dart';

/// Hiển thị kết quả nhận diện: kết luận (độc / an toàn / chưa rõ) + độ tin cậy,
/// còn thông số kỹ thuật được gấp gọn bên dưới.
class ResultPayloadView extends StatelessWidget {
  final Map<String, dynamic> result;

  const ResultPayloadView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if(result['demo'] == true) return const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('KẾT QUẢ MẪU\nChỉ minh họa giao diện. Ảnh này chưa được AI phân tích.')));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final prediction = result['prediction']?.toString() ?? 'unknown';
    final rawPred = result['raw_prediction']?.toString() ?? prediction;
    final mushroomName = result['mushroom_name']?.toString() ??
        (prediction != 'unknown'
            ? prediction
            : tr(context, vi: 'Không xác định', en: 'Unknown'));

    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidencePct = confidence <= 1.0 ? confidence * 100 : confidence;
    final threshold =
        (result['confidence_threshold'] as num?)?.toDouble() ?? 0.70;
    final thresholdPct = threshold <= 1.0 ? threshold * 100 : threshold;

    final isPoisonous = _toBool(result['is_poisonous']);
    final isAccepted = _toBool(result['accepted_prediction']) ?? true;
    final reason = result['decision_reason']?.toString() ?? '';
    final inferenceSec = (result['inference_time_seconds'] as num?)?.toDouble();
    final sizeBytes = (result['size_bytes'] as num?)?.toInt();
    final sha256 = result['sha256']?.toString();

    // Chế độ demo: khi không kết nối được máy chủ AI, dịch vụ hàng đợi tự sinh kết quả
    // ngẫu nhiên (sha256 = simulated_offline_hash). Tuyệt đối không hiện như kết luận thật.
    final simulated = sha256 == 'simulated_offline_hash' || reason.contains('Simulation');

    final Color tone;
    final Color toneSoft;
    final IconData icon;
    final String label;

    if (simulated) {
      tone = AppColors.warning;
      toneSoft = isDark ? tone.withValues(alpha: 0.16) : AppColors.warningSoft;
      icon = Icons.science_outlined;
      label = tr(context, vi: 'KẾT QUẢ GIẢ LẬP (demo)', en: 'SIMULATED RESULT (demo)');
    } else if (prediction.toLowerCase() == 'unknown' || isPoisonous == null) {
      tone = AppColors.warning;
      toneSoft = isDark ? tone.withValues(alpha: 0.16) : AppColors.warningSoft;
      icon = Icons.help_outline_rounded;
      label = tr(context, vi: 'Chưa rõ loài', en: 'Unknown species');
    } else if (isPoisonous) {
      tone = isDark ? const Color(0xFFFF8A80) : AppColors.danger;
      toneSoft = isDark ? tone.withValues(alpha: 0.16) : AppColors.dangerSoft;
      icon = Icons.warning_rounded;
      label = tr(context, vi: 'Cảnh báo: nấm độc', en: 'Warning: poisonous');
    } else {
      tone = isDark ? AppColors.leaf : AppColors.primary;
      toneSoft = isDark ? tone.withValues(alpha: 0.16) : AppColors.mint;
      icon = Icons.verified_rounded;
      label = tr(context, vi: 'Nấm an toàn / ăn được', en: 'Safe / edible');
    }

    final ringValue = (confidencePct / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: toneSoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tone,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon,
                        color: isDark ? AppColors.darkBg : Colors.white,
                        size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: tone,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mushroomName,
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 62,
                    height: 62,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: ringValue,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            color: confidencePct >= thresholdPct
                                ? tone
                                : AppColors.warning,
                            backgroundColor: tone.withValues(alpha: 0.18),
                          ),
                        ),
                        Text(
                          '${confidencePct.round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isAccepted
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: isAccepted ? tone : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isAccepted
                          ? tr(
                              context,
                              vi: 'Độ tin cậy đạt ngưỡng ${thresholdPct.toStringAsFixed(0)}%',
                              en: 'Confidence meets the ${thresholdPct.toStringAsFixed(0)}% threshold',
                            )
                          : tr(
                              context,
                              vi: 'Độ tin cậy dưới ngưỡng ${thresholdPct.toStringAsFixed(0)}%, hãy chụp lại rõ hơn',
                              en: 'Confidence is below the ${thresholdPct.toStringAsFixed(0)}% threshold, try a clearer photo',
                            ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (simulated)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              tr(
                context,
                vi: 'Không kết nối được máy chủ AI nên đây là dữ liệu mẫu ngẫu nhiên, KHÔNG phải nhận diện thật. Không dùng để quyết định ăn nấm.',
                en: 'The AI server was unreachable, so this is random sample data, NOT a real identification. Never use it to decide whether to eat a mushroom.',
              ),
              style: const TextStyle(fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w700, color: AppColors.danger),
            ),
          ),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              tr(context, vi: 'Chi tiết kỹ thuật', en: 'Technical details'),
              style: theme.textTheme.titleSmall,
            ),
            children: [
              ResultRow(
                label: tr(context, vi: 'Dự đoán gốc', en: 'Raw prediction'),
                value: rawPred,
              ),
              ResultRow(
                label: tr(context, vi: 'Ngưỡng tối thiểu', en: 'Threshold'),
                value: '${thresholdPct.toStringAsFixed(1)}%',
              ),
              ResultRow(
                label: tr(context, vi: 'Độ tin cậy', en: 'Confidence'),
                value: '${confidencePct.toStringAsFixed(2)}%',
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
                  value: sha256.length > 16 ? '${sha256.substring(0, 16)}…' : sha256,
                ),
            ],
          ),
        ),
      ],
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
