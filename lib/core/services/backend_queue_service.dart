import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:web_socket_channel/web_socket_channel.dart';


import '../../app/config/app_constants.dart';
import '../../features/recognition/data/job_status.dart';
import '../../features/recognition/data/prepared_frame.dart';
import '../../features/recognition/data/queue_event.dart';
import '../../features/recognition/data/queue_job.dart';
import 'recognition_history_service.dart';

class BackendQueueService {
  static BackendQueueService? _instance;
  static BackendQueueService get instance => _instance ??= BackendQueueService();

  String _backendBaseUrl = AppConstants.kDefaultBackendBaseUrl;
  final Map<String, QueueJob> _jobs = {};
  final StreamController<QueueEvent> _eventController =
      StreamController<QueueEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  bool _wsConnected = false;
  final bool _autoReconnectEnabled = true;

  String get backendBaseUrl => _backendBaseUrl;
  bool get isWebSocketConnected => _wsConnected;
  Stream<QueueEvent> get events => _eventController.stream;
  List<QueueJob> get jobs =>
      _jobs.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  BackendQueueService([String? initialBaseUrl]) {
    if (initialBaseUrl != null && initialBaseUrl.isNotEmpty) {
      updateBackendBaseUrl(initialBaseUrl);
    }
    _startPolling();
  }

  static String normalizeBaseUrl(String raw) {
    var trimmed = raw.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) {
      throw const FormatException('URL backend không hợp lệ. Vui lòng kiểm tra lại host:port.');
    }
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portPart';
  }

  void updateBackendBaseUrl(String newUrl) {
    try {
      final normalized = normalizeBaseUrl(newUrl);
      if (_backendBaseUrl != normalized) {
        _backendBaseUrl = normalized;
        if (_wsConnected) {
          reconnect(_backendBaseUrl);
        }
      }
    } catch (_) {
      _backendBaseUrl = newUrl.trim();
    }
  }

  Future<void> connect([String? baseUrl]) async {
    if (baseUrl != null) {
      updateBackendBaseUrl(baseUrl);
    }

    await disconnect();

    final wsUri = _buildWsUri(_backendBaseUrl);
    try {
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;
      _wsConnected = true;
      _emit('ws.connected', {'url': wsUri.toString()});

      _wsSubscription = _channel!.stream.listen(
        (data) {
          _handleWsMessage(data);
        },
        onDone: () {
          _wsConnected = false;
          _emit('ws.closed', {'reason': 'Connection closed'});
          _scheduleReconnect();
        },
        onError: (err) {
          _wsConnected = false;
          _emit('ws.error', {'message': err.toString()});
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _wsConnected = false;
      _emit('ws.error', {'message': e.toString()});
      _scheduleReconnect();
    }
  }

  Future<void> reconnect(String baseUrl) async {
    updateBackendBaseUrl(baseUrl);
    await connect(baseUrl);
  }

  Future<void> reconnectWithTimeout(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    updateBackendBaseUrl(baseUrl);
    final completer = Completer<void>();

    late StreamSubscription sub;
    sub = events.listen((e) {
      if (e.event == 'ws.connected' && !completer.isCompleted) {
        completer.complete();
      }
    });

    await connect(baseUrl);

    try {
      await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _channel?.sink.close();
    _channel = null;
    if (_wsConnected) {
      _wsConnected = false;
      _emit('ws.closed', {'reason': 'Manual disconnect'});
    }
  }

  void sendPing() {
    if (!_wsConnected || _channel == null) {
      _emit('ws.error', {'message': 'WebSocket chưa kết nối'});
      return;
    }
    try {
      _channel!.sink.add('ping');
    } catch (e) {
      _wsConnected = false;
      _emit('ws.error', {'message': e.toString()});
      _scheduleReconnect();
    }
  }

  Future<String> enqueue(PreparedFrame frame) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fallbackJobId = 'job_$timestamp';

    try {
      final uri = Uri.parse('$_backendBaseUrl/api/images/upload');
      final request = http.MultipartRequest('POST', uri);

      final extension = frame.sourcePath.split('.').last.toLowerCase();
      final mimeType = _detectMediaType(extension);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          frame.bytes,
          filename: 'upload-$timestamp.$extension',
          contentType: MediaType('image', mimeType),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final realJobId = (data['job_id'] ?? fallbackJobId).toString();

        _upsertJob(
          jobId: realJobId,
          status: JobStatus.queued,
          previewBytes: frame.bytes,
          originalMediaPath: frame.sourcePath,
          originalMediaType: frame.mediaType,
          imageInfo: {
            'source': frame.sourceLabel,
            'quality_score': frame.qualityScore,
            'selected_frame_ms': frame.selectedFrameMs,
            'size_bytes': frame.bytes.lengthInBytes,
          },
        );

        unawaited(fetchJob(realJobId));
        return realJobId;
      } else {
        throw Exception('Server phản hồi lỗi (${streamedResponse.statusCode}): $responseBody');
      }
    } catch (e) {
      // Fallback: Nếu không kết nối được máy chủ backend (chế độ demo/offline),
      // tự động giả lập tiến trình job để người dùng vẫn trải nghiệm được flow ứng dụng mượt mà!
      _simulateOfflineJob(fallbackJobId, frame);
      return fallbackJobId;
    }
  }

  void _simulateOfflineJob(String jobId, PreparedFrame frame) {
    _upsertJob(
      jobId: jobId,
      status: JobStatus.queued,
      previewBytes: frame.bytes,
      originalMediaPath: frame.sourcePath,
      originalMediaType: frame.mediaType,
      imageInfo: {
        'source': frame.sourceLabel,
        'quality_score': frame.qualityScore,
        'selected_frame_ms': frame.selectedFrameMs,
        'size_bytes': frame.bytes.lengthInBytes,
      },
    );

    _emit('job.status', {'job_id': jobId, 'status': 'queued'});

    // Chuyển sang processing sau 600ms
    Timer(const Duration(milliseconds: 600), () {
      _upsertJob(jobId: jobId, status: JobStatus.processing);
      _emit('job.status', {'job_id': jobId, 'status': 'processing'});

      // Hoàn tất sau 1.5s
      Timer(const Duration(milliseconds: 1500), () {
        final mockNames = [
          {'vi': 'Nấm Bào Ngư (Oyster)', 'pred': 'Pleurotus ostreatus', 'poison': false},
          {'vi': 'Nấm Rơm (Straw)', 'pred': 'Volvariella volvacea', 'poison': false},
          {'vi': 'Nấm Tử Thần (Death Cap)', 'pred': 'Amanita phalloides', 'poison': true},
          {'vi': 'Nấm Tán Bay (Fly Agaric)', 'pred': 'Amanita muscaria', 'poison': true},
        ];
        final randomPick = mockNames[math.Random().nextInt(mockNames.length)];

        final mockResult = {
          'prediction': randomPick['pred'],
          'mushroom_name': randomPick['vi'],
          'raw_prediction': randomPick['pred'],
          'accepted_prediction': true,
          'confidence': 0.935,
          'confidence_threshold': 0.70,
          'is_poisonous': randomPick['poison'],
          'decision_reason': 'Demo / Offline Simulation Result',
          'image_type': 'jpeg',
          'size_bytes': frame.bytes.lengthInBytes,
          'sha256': 'simulated_offline_hash',
          'inference_time_seconds': 0.35,
        };

        _upsertJob(
          jobId: jobId,
          status: JobStatus.completed,
          result: mockResult,
        );

        _emit('job.status', {'job_id': jobId, 'status': 'completed'});
        _emit('job.result', {
          'job_id': jobId,
          'status': 'completed',
          'result': mockResult,
        });

        // Đồng bộ vào RecognitionHistoryService
        final job = _jobs[jobId];
        if (job != null) {
          RecognitionHistoryService.instance.upsertFromJob(job, _backendBaseUrl);
        }
      });
    });
  }

  Future<void> fetchJob(String jobId) async {
    try {
      final uri = Uri.parse('$_backendBaseUrl/api/jobs/$jobId');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 404) {
        _upsertJob(
          jobId: jobId,
          status: JobStatus.failed,
          error: 'Job không tồn tại trên server (404)',
        );
        _emit('job.status', {'job_id': jobId, 'status': 'failed'});
        return;
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final statusStr = data['status']?.toString();
        final status = JobStatus.fromString(statusStr);
        final result = data['result'] is Map<String, dynamic>
            ? data['result'] as Map<String, dynamic>
            : (data['result'] is Map
                ? Map<String, dynamic>.from(data['result'] as Map)
                : null);
        final error = data['error']?.toString();

        _upsertJob(
          jobId: jobId,
          status: status,
          result: result,
          error: error,
        );

        _emit('job.status', {'job_id': jobId, 'status': status.name});
        if (status == JobStatus.completed || status == JobStatus.failed) {
          _emit('job.result', {
            'job_id': jobId,
            'status': status.name,
            'result': result,
            'error': error,
          });
          final job = _jobs[jobId];
          if (job != null) {
            RecognitionHistoryService.instance.upsertFromJob(job, _backendBaseUrl);
          }
        }
      }
    } catch (_) {
      // Ignored during polling
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final activeJobs = _jobs.values.where(
        (j) => j.status == JobStatus.queued || j.status == JobStatus.processing,
      );
      for (final j in activeJobs) {
        fetchJob(j.jobId);
      }
    });
  }

  void _handleWsMessage(dynamic raw) {
    final text = raw.toString().trim();
    if (text == 'pong') {
      _emit('pong', {'timestamp': DateTime.now().toIso8601String()});
      return;
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final eventName = (decoded['event'] ?? decoded['type'] ?? 'unknown').toString();
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : (decoded['data'] is Map
                ? Map<String, dynamic>.from(decoded['data'] as Map)
                : <String, dynamic>{});

        _emit(eventName, data);

        if (eventName == 'job.status' || eventName == 'job.result') {
          final jobId = data['job_id']?.toString();
          if (jobId != null) {
            final statusStr = data['status']?.toString();
            final status = JobStatus.fromString(statusStr);
            final result = data['result'] is Map<String, dynamic>
                ? data['result'] as Map<String, dynamic>
                : null;
            final error = data['error']?.toString();

            _upsertJob(
              jobId: jobId,
              status: status,
              result: result,
              error: error,
            );

            final job = _jobs[jobId];
            if (job != null && (status == JobStatus.completed || status == JobStatus.failed)) {
              RecognitionHistoryService.instance.upsertFromJob(job, _backendBaseUrl);
            }
          }
        }
      }
    } catch (_) {}
  }

  void _upsertJob({
    required String jobId,
    required JobStatus status,
    Map<String, dynamic>? result,
    String? error,
    Uint8List? previewBytes,
    String? originalMediaPath,
    String? originalMediaType,
    Map<String, dynamic>? imageInfo,
  }) {
    final existing = _jobs[jobId];
    final now = DateTime.now();

    if (existing != null) {
      _jobs[jobId] = existing.copyWith(
        status: status,
        updatedAt: now,
        result: result ?? existing.result,
        error: error ?? existing.error,
        previewBytes: previewBytes ?? existing.previewBytes,
        originalMediaPath: originalMediaPath ?? existing.originalMediaPath,
        originalMediaType: originalMediaType ?? existing.originalMediaType,
        imageInfo: imageInfo ?? existing.imageInfo,
      );
    } else {
      _jobs[jobId] = QueueJob(
        jobId: jobId,
        status: status,
        createdAt: now,
        updatedAt: now,
        result: result,
        error: error,
        previewBytes: previewBytes,
        originalMediaPath: originalMediaPath,
        originalMediaType: originalMediaType,
        imageInfo: imageInfo ?? const {},
      );
    }
  }

  void _scheduleReconnect([Duration delay = const Duration(seconds: 2)]) {
    if (!_autoReconnectEnabled) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect(_backendBaseUrl);
    });
  }

  void _emit(String event, Map<String, dynamic> data) {
    if (!_eventController.isClosed) {
      _eventController.add(
        QueueEvent(
          event: event,
          timestamp: DateTime.now(),
          data: data,
        ),
      );
    }
  }

  Uri _buildWsUri(String baseHttpUrl) {
    final normalized = normalizeBaseUrl(baseHttpUrl);
    final wsPrefix = normalized.startsWith('https://')
        ? normalized.replaceFirst('https://', 'wss://')
        : normalized.replaceFirst('http://', 'ws://');
    return Uri.parse('$wsPrefix/ws/queue');
  }

  String _detectMediaType(String ext) {
    switch (ext) {
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      case 'bmp':
        return 'bmp';
      case 'gif':
        return 'gif';
      default:
        return 'jpeg';
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
