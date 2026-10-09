import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/services/backend_queue_service.dart';
import '../../../core/services/frame_selector_service.dart';
import '../../../core/widgets/mushroom_glyph.dart';
import '../../../core/widgets/soft_card.dart';
import '../data/job_status.dart';
import '../data/prepared_frame.dart';
import '../data/queue_event.dart';
import 'widgets/job_result_card.dart';
import 'widgets/result_popup_dialog.dart';
import '../../settings/presentation/settings_screen.dart';

class MushroomRecognitionScreen extends StatefulWidget {
  const MushroomRecognitionScreen({super.key});

  @override
  State<MushroomRecognitionScreen> createState() =>
      _MushroomRecognitionScreenState();
}

class _MushroomRecognitionScreenState extends State<MushroomRecognitionScreen> {
  final _picker = ImagePicker();
  final _queue = BackendQueueService.instance;
  final _frameSelector = FrameSelectorService.instance;

  PreparedFrame? _preparedFrame;
  bool _isPreparing = false;
  String? _prepareError;
  bool _isUploading = false;

  final Set<String> _shownResultDialogJobs = {};
  final Set<String> _popupEligibleJobIds = {};
  final List<QueueEvent> _recentEvents = [];
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _eventSubscription = _queue.events.listen(_onQueueEvent);
    if (!_queue.isWebSocketConnected) {
      _queue.connect();
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _onQueueEvent(QueueEvent event) {
    if (!mounted) return;

    setState(() {
      _recentEvents.insert(0, event);
      if (_recentEvents.length > 10) {
        _recentEvents.removeLast();
      }
    });

    if (event.event == 'job.result') {
      final jobId = event.data['job_id']?.toString();
      final statusStr = event.data['status']?.toString();
      final result = event.data['result'] is Map<String, dynamic>
          ? event.data['result'] as Map<String, dynamic>
          : null;

      if (jobId != null &&
          statusStr == 'completed' &&
          result != null &&
          _popupEligibleJobIds.contains(jobId) &&
          !_shownResultDialogJobs.contains(jobId)) {
        _shownResultDialogJobs.add(jobId);
        final matchingJob = _queue.jobs.where((j) => j.jobId == jobId).firstOrNull;
        ResultPopupDialog.show(
          context,
          jobId: jobId,
          result: result,
          previewBytes: matchingJob?.previewBytes,
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isPreparing = true;
      _prepareError = null;
    });

    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        setState(() => _isPreparing = false);
        return;
      }

      final frame = await _frameSelector.prepareFromImage(File(picked.path));
      setState(() {
        _preparedFrame = frame;
        _isPreparing = false;
      });
    } catch (e) {
      setState(() {
        _isPreparing = false;
        _prepareError = e.toString();
      });
    }
  }

  Future<void> _pickVideo() async {
    setState(() {
      _isPreparing = true;
      _prepareError = null;
    });

    try {
      final picked = await _picker.pickVideo(source: ImageSource.camera);
      if (picked == null) {
        setState(() => _isPreparing = false);
        return;
      }

      final frame = await _frameSelector.prepareFromVideo(File(picked.path));
      setState(() {
        _preparedFrame = frame;
        _isPreparing = false;
      });
    } catch (e) {
      setState(() {
        _isPreparing = false;
        _prepareError = e.toString();
      });
    }
  }

  Future<void> _submitJob() async {
    if (_preparedFrame == null || _isUploading) return;

    setState(() => _isUploading = true);
    try {
      final jobId = await _queue.enqueue(_preparedFrame!);
      _popupEligibleJobIds.add(jobId);
      setState(() {
        _isUploading = false;
        _preparedFrame = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                vi: 'Đã đưa ảnh vào hàng đợi phân tích (Job ID: $jobId)',
                en: 'Job enqueued for AI analysis (Job ID: $jobId)',
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWsConnected = _queue.isWebSocketConnected;
    final jobs = _queue.jobs;
    final doneCount = jobs.where((j) => j.status == JobStatus.completed).length;
    final busyCount = jobs
        .where((j) =>
            j.status == JobStatus.queued || j.status == JobStatus.processing)
        .length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // ── Tiêu đề + trạng thái kết nối ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, vi: 'Nhận diện nấm', en: 'Mushroom ID'),
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(
                        context,
                        vi: 'Chụp ảnh hoặc quay video, AI sẽ cho biết loài nấm.',
                        en: 'Take a photo or video and let the AI name the species.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ConnectionPill(
                connected: isWsConnected,
                url: _queue.backendBaseUrl,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Hero: 3 cách nhập ảnh ──
          _HeroCard(
            busy: _isPreparing,
            onCamera: () => _pickImage(ImageSource.camera),
            onGallery: () => _pickImage(ImageSource.gallery),
            onVideo: _pickVideo,
          ),
          const SizedBox(height: 14),

          // ── Thống kê phiên ──
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.hourglass_top_rounded,
                  value: '$busyCount',
                  label: tr(context, vi: 'Đang chờ', en: 'In queue'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.check_circle_rounded,
                  value: '$doneCount',
                  label: tr(context, vi: 'Hoàn tất', en: 'Done'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.layers_rounded,
                  value: '${jobs.length}',
                  label: tr(context, vi: 'Tổng phiên này', en: 'This session'),
                ),
              ),
            ],
          ),

          if (_isPreparing) ...[
            const SizedBox(height: 16),
            SoftCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        vi: 'Đang xử lý và chấm điểm độ sắc nét khung hình...',
                        en: 'Processing and scoring frame quality...',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_prepareError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _prepareError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Ảnh đã chuẩn bị ──
          if (_preparedFrame != null) ...[
            const SizedBox(height: 16),
            _PreparedCard(
              frame: _preparedFrame!,
              uploading: _isUploading,
              onClose: () => setState(() => _preparedFrame = null),
              onSubmit: _submitJob,
            ),
          ],

          // ── Hàng đợi ──
          const SizedBox(height: 12),
          SectionTitle(
            tr(context, vi: 'Kết quả gần đây', en: 'Recent results'),
            trailing: jobs.isEmpty
                ? null
                : Text('${jobs.length}', style: theme.textTheme.bodySmall),
          ),
          if (jobs.isEmpty)
            SoftCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const MushroomGlyph(size: 64),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      context,
                      vi: 'Chưa có ảnh nào được nhận diện',
                      en: 'Nothing recognised yet',
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      vi: 'Mẹo: chụp đủ sáng, thấy rõ cả mũ và thân nấm, nền đơn giản.',
                      en: 'Tip: use good light, show the cap and stem, keep the background plain.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            ...jobs.map((job) => JobResultCard(job: job)),

          // ── Nhật ký sự kiện (gấp gọn) ──
          if (_recentEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  tr(context, vi: 'Nhật ký kết nối', en: 'Connection log'),
                  style: theme.textTheme.titleSmall,
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1A0B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _recentEvents.take(5).map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• [${e.event}] ${e.data}',
                            style: const TextStyle(
                              color: Color(0xFFA6E36B),
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Thành phần giao diện ─────────────────────────────

class _ConnectionPill extends StatelessWidget {
  final bool connected;
  final String url;
  final VoidCallback onTap;

  const _ConnectionPill({
    required this.connected,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = connected ? AppColors.success : AppColors.danger;
    return Tooltip(
      message: url,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  connected
                      ? tr(context, vi: 'Trực tuyến', en: 'Online')
                      : tr(context, vi: 'Ngoại tuyến', en: 'Offline'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onVideo;

  const _HeroCard({
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        context,
                        vi: 'Đây là nấm gì?',
                        en: 'What mushroom is this?',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        context,
                        vi: 'Biết ngay loài nấm và có độc hay không.',
                        en: 'Get the species and whether it is poisonous.',
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const MushroomGlyph(size: 92),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: FilledButton.icon(
                  onPressed: busy ? null : onCamera,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                    minimumSize: const Size(0, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.photo_camera_rounded, size: 20),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tr(context, vi: 'Chụp ảnh', en: 'Camera')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _GhostButton(
                  icon: Icons.photo_library_outlined,
                  label: tr(context, vi: 'Thư viện', en: 'Gallery'),
                  onTap: busy ? null : onGallery,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _GhostButton(
                  icon: Icons.videocam_outlined,
                  label: tr(context, vi: 'Video', en: 'Video'),
                  onTap: busy ? null : onVideo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _GhostButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 19),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PreparedCard extends StatelessWidget {
  final PreparedFrame frame;
  final bool uploading;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  const _PreparedCard({
    required this.frame,
    required this.uploading,
    required this.onClose,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final good = frame.qualityScore >= 0.5;
    final qColor = good ? AppColors.success : AppColors.warning;

    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  frame.bytes,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: onClose,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${frame.sourceLabel} · ${(frame.bytes.lengthInBytes / 1024).toStringAsFixed(0)} KB',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, vi: 'Chất lượng ảnh', en: 'Image quality'),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${(frame.qualityScore * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: qColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: frame.qualityScore.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: qColor,
                  ),
                ),
                if (!good) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      vi: 'Ảnh hơi mờ hoặc thiếu sáng, kết quả có thể kém chính xác.',
                      en: 'The photo looks blurry or dark; the result may be less accurate.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: uploading ? null : onSubmit,
                  icon: uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: Text(
                    tr(context, vi: 'Phân tích bằng AI', en: 'Analyze with AI'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
