import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../app/config/app_constants.dart';
import '../../features/recognition/data/job_status.dart';
import '../../features/recognition/data/prepared_frame.dart';
import '../../features/recognition/data/queue_event.dart';
import '../../features/recognition/data/queue_job.dart';
import '../network/api_client.dart';
import '../network/mock_config.dart';
import 'recognition_history_service.dart';

class BackendQueueService {
  static BackendQueueService? _instance;
  static BackendQueueService get instance =>
      _instance ??= BackendQueueService();
  BackendQueueService([String? initialBaseUrl]) {
    _backendBaseUrl = normalizeBaseUrl(
      initialBaseUrl ?? AppConstants.kDefaultBackendBaseUrl,
    );
  }
  late String _backendBaseUrl;
  final _jobs = <String, QueueJob>{};
  final _events = StreamController<QueueEvent>.broadcast();
  io.Socket? _socket;
  bool get isWebSocketConnected => _socket?.connected ?? false;
  String get backendBaseUrl => _backendBaseUrl;
  Stream<QueueEvent> get events => _events.stream;
  List<QueueJob> get jobs =>
      _jobs.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  static String normalizeBaseUrl(String raw) =>
      ApiConfig.fromInput(raw).serverOrigin.toString();

  void updateBackendBaseUrl(String value) {
    final normalized = normalizeBaseUrl(value);
    if (normalized == _backendBaseUrl) return;
    _socket?.dispose();
    _socket = null;
    _jobs.clear();
    _backendBaseUrl = normalized;
  }

  Future<void> connect([String? baseUrl]) async {
    if (MockConfig.enabled) {
      _emit('ws.mock', {'message': 'Đang dùng dữ liệu mẫu.'});
      return;
    }
    if (baseUrl != null) updateBackendBaseUrl(baseUrl);
    if (_socket != null) {
      if (!isWebSocketConnected) _socket!.connect();
      return;
    }
    final socket = io.io(
      _backendBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) {
      _emit('ws.connected', {'url': _backendBaseUrl});
      for (final job in _jobs.values.where(
        (job) =>
            job.status == JobStatus.queued ||
            job.status == JobStatus.processing,
      )) {
        socket.emit('subscribe_job', job.jobId);
      }
    });
    socket.onDisconnect(
      (_) => _emit('ws.closed', {'reason': 'Connection closed'}),
    );
    socket.onConnectError(
      (_) => _emit('ws.error', {
        'message': 'Không kết nối được máy chủ. Đang thử lại.',
      }),
    );
    for (final event in ['processing', 'finished', 'failed']) {
      socket.on(event, _handleEvent);
    }
    socket.connect();
  }

  Future<void> reconnect(String baseUrl) async {
    await disconnect();
    await connect(baseUrl);
  }

  Future<void> reconnectWithTimeout(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await disconnect();
    updateBackendBaseUrl(baseUrl);
    final connected = Completer<void>();
    final subscription = events.listen((event) {
      if (event.event == 'ws.connected' && !connected.isCompleted)
        connected.complete();
    });
    try {
      await connect();
      await connected.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    _emit('ws.closed', {'reason': 'Manual disconnect'});
  }

  void sendPing() {
    unawaited(_checkServer());
  }

  Future<void> _checkServer() async {
    try {
      await ApiClient().request(
        '/test',
        baseUrl: _backendBaseUrl,
        auth: RequestAuth.none,
      );
      _emit('pong', {'message': 'Máy chủ đang hoạt động'});
    } catch (error) {
      _emit('ws.error', {'message': error.toString()});
    }
  }

  Future<String> enqueue(PreparedFrame frame) async {
    final bytes = frame.bytes;
    if (bytes.lengthInBytes > 5 * 1024 * 1024)
      throw const ApiException(
        'Ảnh tối đa 5 MB.',
        kind: ApiErrorKind.validation,
      );
    final type = bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8
        ? 'jpeg'
        : bytes.length > 8 &&
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4e &&
              bytes[3] == 0x47
        ? 'png'
        : bytes.length > 12 &&
              bytes[0] == 0x52 &&
              bytes[1] == 0x49 &&
              bytes[8] == 0x57 &&
              bytes[9] == 0x45
        ? 'webp'
        : null;
    if (type == null)
      throw const ApiException(
        'Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP.',
        kind: ApiErrorKind.validation,
      );
    if (MockConfig.enabled) {
      final now = DateTime.now();
      final jobId = 'mock-' + now.microsecondsSinceEpoch.toString();
      _jobs[jobId] = QueueJob(
        jobId: jobId,
        status: JobStatus.completed,
        createdAt: now,
        updatedAt: now,
        previewBytes: frame.bytes,
        originalMediaPath: frame.sourcePath,
        originalMediaType: frame.mediaType,
        result: {
          'demo': true,
          'mushroom_name': 'Kết quả mẫu',
          'prediction': 'unknown',
          'is_poisonous': null,
          'decision_reason': 'Chỉ minh họa giao diện, không phân tích ảnh.',
        },
      );
      _emit('job.result', {
        'job_id': jobId,
        'status': 'completed',
        'result': _jobs[jobId]!.result,
      });
      unawaited(_saveHistory(_jobs[jobId]!));
      return jobId;
    }
    final cfg = ApiConfig.fromInput(_backendBaseUrl);
    final request = http.MultipartRequest(
      'POST',
      cfg.endpoint('/mushroom-classifier/classify'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'upload.' + (type == 'jpeg' ? 'jpg' : type),
        contentType: MediaType('image', type),
      ),
    );
    final data = await ApiClient().send(
      request,
      auth: RequestAuth.optional,
      serverOrigin: _backendBaseUrl,
    );
    final jobId = data['jobId'] as String;
    final now = DateTime.now();
    _jobs[jobId] = QueueJob(
      jobId: jobId,
      status: JobStatus.fromString(data['status'] as String?),
      createdAt: now,
      updatedAt: now,
      previewBytes: bytes,
      originalMediaPath: frame.sourcePath,
      originalMediaType: frame.mediaType,
      imageInfo: {
        'source': frame.sourceLabel,
        'quality_score': frame.qualityScore,
        'selected_frame_ms': frame.selectedFrameMs,
        'size_bytes': bytes.lengthInBytes,
      },
    );
    _emit('job.status', {'job_id': jobId, 'status': _jobs[jobId]!.status.name});
    await connect();
    _socket?.emit('subscribe_job', jobId);
    return jobId;
  }

  void clearSessionJobs() {
    _jobs.clear();
    _emit('session.reset', {});
  }

  Future<void> fetchJob(String jobId) async {
    await connect();
    _socket?.emit('subscribe_job', jobId);
  }

  static Map<String, dynamic> adaptResult(Map<String, dynamic> raw) {
    final image = raw['image'] as Map? ?? {};
    return {
      ...raw,
      'prediction': raw['name'] == 'unknown'
          ? 'unknown'
          : raw['scientificName'] ?? raw['name'],
      'mushroom_name': raw['name'],
      'raw_prediction': raw['rawPrediction'],
      'confidence_threshold': raw['confidenceThreshold'],
      'accepted_prediction': raw['accepted'],
      'is_poisonous': raw['edibility'] == 'UNKNOWN' ? null : raw['isPoisonous'],
      'image_type': image['format'],
      'size_bytes': image['sizeBytes'],
      'sha256': image['sha256'],
      'inference_time_seconds': raw['inferenceTimeMs'] is num
          ? (raw['inferenceTimeMs'] as num) / 1000
          : null,
    };
  }

  void _handleEvent(dynamic payload) {
    if (payload is! Map) return;
    final data = Map<String, dynamic>.from(payload);
    final jobId = data['jobId']?.toString();
    if (jobId == null) return;
    final status = JobStatus.fromString(data['status']?.toString());
    final result = data['result'] is Map
        ? adaptResult(Map<String, dynamic>.from(data['result'] as Map))
        : null;
    final error = status == JobStatus.failed
        ? data['message']?.toString()
        : null;
    final now = DateTime.now();
    final job =
        _jobs[jobId]?.copyWith(
          status: status,
          updatedAt: now,
          result: result,
          error: error,
        ) ??
        QueueJob(
          jobId: jobId,
          status: status,
          createdAt: now,
          updatedAt: now,
          result: result,
          error: error,
        );
    _jobs[jobId] = job;
    _emit('job.status', {'job_id': jobId, 'status': status.name});
    if (status == JobStatus.completed || status == JobStatus.failed) {
      _emit('job.result', {
        'job_id': jobId,
        'status': status.name,
        'result': result,
        'error': error,
      });
      unawaited(_saveHistory(job));
    }
  }

  Future<void> _saveHistory(QueueJob job) async {
    try {
      await RecognitionHistoryService.instance.upsertFromJob(
        job,
        _backendBaseUrl,
      );
    } catch (_) {
      _emit('history.error', {
        'message': 'Không lưu được lịch sử trên thiết bị.',
      });
    }
  }

  void _emit(String event, Map<String, dynamic> data) {
    if (!_events.isClosed)
      _events.add(
        QueueEvent(event: event, timestamp: DateTime.now(), data: data),
      );
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    unawaited(_events.close());
  }
}
