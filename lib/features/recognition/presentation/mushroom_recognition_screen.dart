import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_text_scope.dart';
import '../../../core/services/backend_queue_service.dart';
import '../../../core/services/frame_selector_service.dart';
import '../data/prepared_frame.dart';
import '../data/queue_event.dart';
import 'widgets/job_result_card.dart';
import 'widgets/result_popup_dialog.dart';
import '../../recognition_history/presentation/recognition_history_screen.dart';
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
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWsConnected = _queue.isWebSocketConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(context, vi: 'Nhận Diện Nấm AI', en: 'AI Mushroom Recognition'),
        ),
        actions: [
          IconButton(
            tooltip: tr(context, vi: 'Lịch sử nhận diện', en: 'History'),
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecognitionHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: tr(context, vi: 'Cài đặt kết nối', en: 'Settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thẻ trạng thái kết nối
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isWsConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isWsConnected
                              ? tr(context, vi: 'WebSocket Đang Kết Nối', en: 'WebSocket Connected')
                              : tr(context, vi: 'WebSocket Đang Ngắt', en: 'WebSocket Disconnected'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isWsConnected ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        Text(
                          _queue.backendBaseUrl,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: Text(tr(context, vi: 'Đổi IP', en: 'Change')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bộ chọn phương tiện (3 buttons)
          Text(
            tr(context, vi: 'Chọn phương thức nhập ảnh:', en: 'Select input method:'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MediaActionButton(
                  icon: Icons.photo_library_outlined,
                  label: tr(context, vi: 'Thư viện', en: 'Gallery'),
                  onTap: _isPreparing ? null : () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MediaActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: tr(context, vi: 'Chụp ảnh', en: 'Camera'),
                  onTap: _isPreparing ? null : () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MediaActionButton(
                  icon: Icons.videocam_outlined,
                  label: tr(context, vi: 'Quay video', en: 'Video'),
                  onTap: _isPreparing ? null : _pickVideo,
                ),
              ),
            ],
          ),

          if (_isPreparing) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_prepareError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _prepareError!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
              ),
            ),
          ],

          // Khung xem trước & Chấm điểm Frame
          if (_preparedFrame != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr(context, vi: 'Ảnh đã sẵn sàng', en: 'Ready for Analysis'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => _preparedFrame = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _preparedFrame!.bytes,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _preparedFrame!.sourceLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(_preparedFrame!.bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Điểm chất lượng
                    Row(
                      children: [
                        Text(
                          tr(context, vi: 'Điểm chất lượng: ', en: 'Quality score: '),
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '${(_preparedFrame!.qualityScore * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _preparedFrame!.qualityScore >= 0.5
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isUploading ? null : _submitJob,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        tr(context, vi: 'Phân Tích Bằng AI', en: 'Analyze with AI'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Danh sách công việc trong hàng đợi
          const SizedBox(height: 24),
          Text(
            tr(context, vi: 'Hàng đợi nhận diện (${_queue.jobs.length})', en: 'Recognition Queue (${_queue.jobs.length})'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          if (_queue.jobs.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        context,
                        vi: 'Chưa có ảnh nào được gửi nhận diện trong phiên này.',
                        en: 'No jobs in queue yet for this session.',
                      ),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._queue.jobs.map((job) => JobResultCard(job: job)),

          // Event log
          if (_recentEvents.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              tr(context, vi: 'Sự kiện WebSocket gần đây', en: 'Recent WebSocket Events'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _recentEvents.take(5).map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      '• [${e.event}] ${e.data}',
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
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
        ],
      ),
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MediaActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
