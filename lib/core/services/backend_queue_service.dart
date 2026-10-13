import 'workflow_refresh_service.dart';
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
import 'recognition_queue_store.dart';

class BackendQueueService {
  static BackendQueueService? _instance;
  static BackendQueueService get instance =>
      _instance ??= BackendQueueService();
  BackendQueueService([String? initialBaseUrl])
    : this.withDependencies(initialBaseUrl: initialBaseUrl);

  BackendQueueService.withDependencies({
    String? initialBaseUrl,
    ApiClient? apiClient,
    io.Socket Function(String, Map<String, dynamic>)? socketFactory,
    Future<void> Function(QueueJob, String)? historyWriter,
  }) : _api = apiClient ?? ApiClient(),
       _socketFactory = socketFactory ?? io.io,
       _historyWriter = historyWriter {
    _backendBaseUrl = normalizeBaseUrl(
      initialBaseUrl ?? AppConstants.kDefaultBackendBaseUrl,
    );
  }
  late String _backendBaseUrl;
  final ApiClient _api;
  final io.Socket Function(String, Map<String, dynamic>) _socketFactory;
  final Future<void> Function(QueueJob, String)? _historyWriter;
  final _pendingStore = RecognitionQueueStore();
  Future<void>? _restoreFuture;
  int _connectionRevision = 0;
  bool _isUploading = false;
  bool get isUploading => _isUploading;
  DateTime? _uploadRetryAt;
  int? _uploadRetryStatus;
  Duration get uploadRetryRemaining {
    final remaining =
        _uploadRetryAt?.difference(DateTime.now()) ?? Duration.zero;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  final _jobs = <String, QueueJob>{};
  final _events = StreamController<QueueEvent>.broadcast();
  io.Socket? _socket;
  Timer? _pollTimer;
  final Map<String, Timer> _refreshTimers = {};
  final Map<String, Future<void>> _fetching = {};
  final Set<String> _refetchRequested = {};
  StreamSubscription<RefreshSignal>? _refreshSub;
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
    _connectionRevision++;
    _pollTimer?.cancel();
    for (final timer in _refreshTimers.values) {
      timer.cancel();
    }
    _refreshTimers.clear();
    _jobs.clear();
    _restoreFuture = null;
    _uploadRetryAt = null;
    _uploadRetryStatus = null;
    _backendBaseUrl = normalized;
  }

  Future<void> connect([String? baseUrl]) async {
    if (MockConfig.enabled) {
      _emit('ws.mock', {'message': 'Đang dùng dữ liệu mẫu.'});
      return;
    }
    if (baseUrl != null) updateBackendBaseUrl(baseUrl);
    final revision = _connectionRevision;
    await (_restoreFuture ??= _restoreJobs());
    if (revision != _connectionRevision || _events.isClosed) return;
    if (_socket != null) {
      if (!isWebSocketConnected) _socket!.connect();
      return;
    }
    final socket = _socketFactory(
      _backendBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
            .setExtraHeaders({'Accept': 'application/json', 'X-Tunnel-Skip-AntiPhishing-Page': 'true'})
          .enableForceNew()
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    _refreshSub ??= WorkflowRefreshService.instance.events.listen((signal) {
      if (signal.resource == '*') {
        for (final job
            in _jobs.values.where((job) => job.status.isPending).toList()) {
          unawaited(fetchJob(job.jobId));
        }
      }
    });
    socket.onConnect((_) {
      _emit('ws.connected', {'url': _backendBaseUrl});
      _updatePolling();
      for (final job in _jobs.values.where((job) => job.status.isPending)) {
        socket.emit('subscribe_job', job.jobId);
        unawaited(fetchJob(job.jobId));
      }
    });
    socket.onDisconnect((_) {
      _emit('ws.closed', {'reason': 'Connection closed'});
      _updatePolling();
    });
    socket.onConnectError(
      (_) => _emit('ws.error', {
        'message': 'Không kết nối được máy chủ. Đang thử lại.',
      }),
    );
    socket.on('refresh', (payload) {
      if (payload is! Map || payload['resource'] != 'classifier-job') return;
      final id = payload['id']?.toString();
      if (id == null || !_jobs.containsKey(id)) return;
      _refreshTimers.remove(id)?.cancel();
      _refreshTimers[id] = Timer(const Duration(milliseconds: 300), () {
        _refreshTimers.remove(id);
        unawaited(fetchJob(id));
      });
    });
    socket.connect();
    _updatePolling();
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
      if (event.event == 'ws.connected' && !connected.isCompleted) {
        connected.complete();
      }
    });
    try {
      await connect();
      await connected.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> disconnect() async {
    _connectionRevision++;
    _pollTimer?.cancel();
    for (final timer in _refreshTimers.values) {
      timer.cancel();
    }
    _refreshTimers.clear();
    _refreshSub?.cancel();
    _refreshSub = null;
    _socket?.dispose();
    _socket = null;
    _emit('ws.closed', {'reason': 'Manual disconnect'});
  }

  void sendPing() {
    unawaited(_checkServer());
  }

  Future<void> _checkServer() async {
    try {
      await _api.request(
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
    if (_isUploading) {
      throw const ApiException(
        'Đang gửi ảnh. Vui lòng chờ phản hồi.',
        kind: ApiErrorKind.validation,
      );
    }
    final retryRemaining = uploadRetryRemaining;
    if (retryRemaining > Duration.zero) {
      throw ApiException(
        'Vui lòng chờ trước khi gửi lại.',
        statusCode: _uploadRetryStatus,
        retryAfter: retryRemaining,
        kind: _uploadRetryStatus == 503
            ? ApiErrorKind.server
            : ApiErrorKind.validation,
      );
    }
    _isUploading = true;
    _emit('upload.status', {'uploading': true});
    try {
      return await _enqueue(frame);
    } finally {
      _isUploading = false;
      _emit('upload.status', {'uploading': false});
    }
  }

  Future<String> _enqueue(PreparedFrame frame) async {
    final bytes = frame.bytes;
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw const ApiException(
        'Ảnh tối đa 5 MB.',
        kind: ApiErrorKind.validation,
      );
    }
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
    if (type == null) {
      throw const ApiException(
        'Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP.',
        kind: ApiErrorKind.validation,
      );
    }
    if (MockConfig.enabled) {
      final now = DateTime.now();
      final jobId = 'mock-${now.microsecondsSinceEpoch}';
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
    final origin = _backendBaseUrl;
    await (_restoreFuture ??= _restoreJobs());
    if (origin != _backendBaseUrl) {
      throw const ApiException(
        'Máy chủ đã thay đổi. Vui lòng gửi lại.',
        kind: ApiErrorKind.validation,
      );
    }
    final cfg = ApiConfig.fromInput(origin);
    final request = http.MultipartRequest(
      'POST',
      cfg.endpoint('/mushroom-classifier/classify'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'upload.${type == 'jpeg' ? 'jpg' : type}',
        contentType: MediaType('image', type),
      ),
    );
    late Map<String, dynamic> data;
    try {
      data = await _api.send(
        request,
        auth: RequestAuth.optional,
        serverOrigin: origin,
      );
    } on ApiException catch (error) {
      if (origin == _backendBaseUrl &&
          (error.statusCode == 429 || error.statusCode == 503)) {
        final delay =
            error.retryAfter ??
            (error.statusCode == 429
                ? const Duration(seconds: 30)
                : Duration.zero);
        _uploadRetryAt = DateTime.now().add(delay);
        _uploadRetryStatus = error.statusCode;
      }
      rethrow;
    }
    final jobId = data['jobId'];
    if (jobId is! String || jobId.trim().isEmpty) {
      throw const ApiException(
        'Máy chủ không trả về mã nhận diện.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    final now = DateTime.now();
    final job = QueueJob(
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
    if (origin != _backendBaseUrl) {
      // The upload was accepted by the previous server; retain its ID there.
      try {
        final pending = await _pendingStore.load(origin);
        await _pendingStore.save(origin, [
          ...pending.where((j) => j.jobId != jobId),
          job,
        ]);
      } catch (_) {
        _emitStorageError();
      }
      return jobId;
    }
    _jobs[jobId] = job;
    await _persistJobs();
    _emit('job.status', {'job_id': jobId, 'status': job.status.name});
    _updatePolling();
    try {
      if (isWebSocketConnected) {
        _socket!.emit('subscribe_job', jobId);
      } else {
        await connect();
      }
    } catch (_) {
      // The HTTP request has already been accepted; do not suggest reuploading.
      _emit('ws.error', {
        'message': 'Đã nhận ảnh. Kết nối lại để nhận kết quả.',
      });
    }
    return jobId;
  }

  void clearSessionJobs() {
    _jobs.clear();
    unawaited(_persistJobs());
    _emit('session.reset', {});
  }

  void _updatePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!isWebSocketConnected &&
        _jobs.values.any((job) => job.status.isPending) &&
        !_events.isClosed) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        for (final job
            in _jobs.values.where((job) => job.status.isPending).toList()) {
          unawaited(fetchJob(job.jobId));
        }
      });
    }
  }

  Future<void> fetchJob(String jobId) {
    if (!_jobs.containsKey(jobId) || !_jobs[jobId]!.status.isPending)
      return Future.value();
    final revision = _connectionRevision;
    final key = '$revision:$jobId';
    final pending = _fetching[key];
    if (pending != null) {
      _refetchRequested.add(key);
      return pending;
    }
    final future = _fetchJobApi(jobId).whenComplete(() {
      _fetching.remove(key);
      if (_refetchRequested.remove(key) &&
          revision == _connectionRevision &&
          !_events.isClosed) {
        unawaited(fetchJob(jobId));
      }
    });
    _fetching[key] = future;
    return future;
  }

  Future<void> _fetchJobApi(String jobId) async {
    final revision = _connectionRevision;
    try {
      final response = await _api.request(
        '/mushroom-classifier/jobs/$jobId',
        baseUrl: _backendBaseUrl,
        auth: RequestAuth.none,
      );
      if (revision != _connectionRevision ||
          _events.isClosed ||
          !_jobs.containsKey(jobId))
        return;
      final raw = response['data'];
      if (raw is! Map || raw['status'] is! String) return;
      final data = Map<String, dynamic>.from(raw)..['jobId'] = jobId;
      _handleEvent(
        data['status'] == 'QUEUED' && data['nextRetryAt'] != null
            ? 'retrying'
            : 'snapshot',
        data,
      );
      _updatePolling();
    } catch (_) {
      _emit('job.refresh_error', {
        'job_id': jobId,
        'message': 'Chưa tải được trạng thái nhận diện. Sẽ thử lại.',
      });
    }
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

  void _handleEvent(String event, dynamic payload) {
    if (payload is! Map) return;
    final data = Map<String, dynamic>.from(payload);
    final jobId = data['jobId']?.toString();
    if (jobId == null || !_jobs.containsKey(jobId)) return;
    final status = event == 'retrying'
        ? JobStatus.retrying
        : event == 'finished'
        ? JobStatus.completed
        : event == 'failed'
        ? JobStatus.failed
        : JobStatus.fromString(data['status']?.toString() ?? 'PROCESSING');
    // Ignore delayed progress events once a terminal result has arrived.
    if (!_jobs[jobId]!.status.isPending && status.isPending) return;
    final result = data['result'] is Map
        ? adaptResult(Map<String, dynamic>.from(data['result'] as Map))
        : null;
    final error = status == JobStatus.failed
        ? data['message']?.toString()
        : null;
    final now = DateTime.now();
    final job = _jobs[jobId]!.copyWith(
      status: status,
      updatedAt: now,
      result: result,
      error: error,
    );
    _jobs[jobId] = job;
    unawaited(_persistJobs());
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
      if (_historyWriter != null) {
        await _historyWriter(job, _backendBaseUrl);
        return;
      }
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

  Future<void> _restoreJobs() async {
    final origin = _backendBaseUrl;
    try {
      final pending = await _pendingStore.load(origin);
      if (origin != _backendBaseUrl || _events.isClosed) return;
      for (final job in pending) {
        _jobs.putIfAbsent(job.jobId, () => job);
      }
      _emit('session.restored', {'pending_jobs': pending.length});
    } catch (_) {
      _emitStorageError();
    }
  }

  Future<void> _persistJobs() async {
    try {
      await _pendingStore.save(_backendBaseUrl, _jobs.values);
    } catch (_) {
      // A local storage failure must not turn an accepted upload into a retry.
      _emitStorageError();
    }
  }

  void _emitStorageError() => _emit('queue.storage_error', {
    'message':
        'Không lưu được mã nhận diện trên thiết bị. Giữ ứng dụng mở để tiếp tục nhận kết quả.',
  });

  void _emit(String event, Map<String, dynamic> data) {
    if (!_events.isClosed) {
      _events.add(
        QueueEvent(event: event, timestamp: DateTime.now(), data: data),
      );
    }
  }

  void dispose() {
    _connectionRevision++;
    _pollTimer?.cancel();
    for (final timer in _refreshTimers.values) {
      timer.cancel();
    }
    _refreshTimers.clear();
    _refreshSub?.cancel();
    _refreshSub = null;
    _socket?.dispose();
    _socket = null;
    unawaited(_events.close());
  }
}
