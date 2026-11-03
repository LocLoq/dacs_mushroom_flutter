import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_text_scope.dart';
import '../../../../core/widgets/mushroom_glyph.dart';
import 'result_payload_view.dart';
import 'result_row.dart';

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
              _Header(previewBytes: previewBytes),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResultPayloadView(result: result),
                    const SizedBox(height: 10),
                    const ResultSafetyNotice(),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr(context, vi: 'Xong', en: 'Done')),
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

class _Header extends StatelessWidget {
  final Uint8List? previewBytes;

  const _Header({this.previewBytes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (previewBytes != null)
            Image.memory(previewBytes!, fit: BoxFit.cover)
          else
            Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: const Center(child: MushroomGlyph(size: 96)),
            ),
          // Lớp tối dần ở đáy để chữ/nhãn nổi lên
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000), Color(0x8C000000)],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    tr(context, vi: 'Kết quả từ AI', en: 'AI result'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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
    );
  }
}
