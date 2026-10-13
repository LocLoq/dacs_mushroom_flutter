import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:thu/core/network/api_client.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/services/backend_queue_service.dart';
import 'package:thu/core/services/recognition_queue_store.dart';
import 'package:thu/features/recognition/data/job_status.dart';
import 'package:thu/features/recognition/data/prepared_frame.dart';
import 'package:thu/features/recognition/data/queue_job.dart';
import 'package:thu/features/recognition/presentation/widgets/job_result_card.dart';

class TestSocket extends io.Socket {
  TestSocket({this.autoConnect = true})
    : super(
        io.io('http://localhost:8080', <String, dynamic>{
          'autoConnect': false,
          'forceNew': true,
        }).io,
        '/',
        {},
      );

  final bool autoConnect;
  final subscriptions = <String>[];

  @override
  io.Socket connect() {
    if (autoConnect) serverConnect();
    return this;
  }

  void serverConnect() {
    connected = true;
    emitEvent(['connect', null]);
  }

  void serverDisconnect() {
    connected = false;
    emitEvent(['disconnect', 'Network lost']);
  }

  void receive(String event, Map<String, dynamic> payload) =>
      emitEvent([event, payload]);

  @override
  void emit(String event, [dynamic data]) {
    if (event == 'subscribe_job') subscriptions.add(data as String);
  }

  @override
  void dispose() {
    connected = false;
    super.dispose();
  }
}

PreparedFrame frame() => PreparedFrame(
  bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
  sourcePath: 'fixture.jpg',
  sourceLabel: 'Photo',
  mediaType: 'image',
  qualityScore: 1,
);

http.Response accepted([String id = 'job-1']) => http.Response(
  jsonEncode({'jobId': id, 'status': 'QUEUED'}),
  202,
  headers: {'content-type': 'application/json'},
);

BackendQueueService service(TestSocket socket, http.Client client) {
  final queue = BackendQueueService.withDependencies(
    initialBaseUrl: 'http://localhost:8080',
    apiClient: ApiClient(client: client),
    socketFactory: (_, _) => socket,
    historyWriter: (_, _) async {},
  );
  addTearDown(queue.dispose);
  return queue;
}

// Drain asynchronous event delivery and preference writes.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MockConfig.set(false);
  });

  test(
    '202 saves the job before subscription and restores it after app restart',
    () async {
      final store = RecognitionQueueStore();
      final socket = TestSocket(autoConnect: false);
      var uploads = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET')
          return http.Response(
            jsonEncode({
              'data': {'status': 'QUEUED'},
            }),
            200,
          );
        uploads++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/mushroom-classifier/classify');
        return accepted();
      });
      final queue = service(socket, client);
      expect(await queue.enqueue(frame()), 'job-1');
      expect(socket.subscriptions, isEmpty);
      final saved = await store.load(queue.backendBaseUrl);
      expect(saved.single.jobId, 'job-1');
      expect(saved.single.previewBytes, isNull);
      expect(saved.single.originalMediaPath, 'fixture.jpg');
      queue.dispose();

      final nextSocket = TestSocket();
      final restored = service(nextSocket, client);
      await restored.connect();
      expect(restored.jobs.single.jobId, 'job-1');
      expect(nextSocket.subscriptions, ['job-1']);
      expect(uploads, 1);
    },
  );

  test(
    'refresh reads status from the API, debounces duplicates and reconnects',
    () async {
      final socket = TestSocket();
      var reads = 0;
      var state = <String, dynamic>{'status': 'QUEUED'};
      final queue = service(
        socket,
        MockClient((request) async {
          if (request.method == 'POST') return accepted();
          reads++;
          expect(request.url.path, '/api/mushroom-classifier/jobs/job-1');
          return http.Response(jsonEncode({'data': state}), 200);
        }),
      );
      await queue.enqueue(frame());
      await flush();
      state = {'status': 'PROCESSING'};
      for (var i = 0; i < 3; i++) {
        socket.receive('refresh', {
          'resource': 'classifier-job',
          'id': 'job-1',
        });
      }
      final before = reads;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(reads, before + 1);
      expect(queue.jobs.single.status, JobStatus.processing);
      state = {
        'status': 'QUEUED',
        'nextRetryAt': DateTime.now()
            .add(const Duration(seconds: 5))
            .toIso8601String(),
      };
      await queue.fetchJob('job-1');
      expect(queue.jobs.single.status, JobStatus.retrying);
      socket.subscriptions.clear();
      socket.serverDisconnect();
      socket.serverConnect();
      await flush();
      expect(socket.subscriptions, ['job-1']);
      expect(queue.jobs.single.status, JobStatus.retrying);
    },
  );

  for (final status in ['SUCCEEDED', 'FAILED']) {
    test(
      '$status snapshot finalizes the job and cannot regress from delayed refresh',
      () async {
        final socket = TestSocket();
        var state = <String, dynamic>{'status': 'QUEUED'};
        final queue = service(
          socket,
          MockClient(
            (request) async => request.method == 'POST'
                ? accepted()
                : http.Response(jsonEncode({'data': state}), 200),
          ),
        );
        await queue.enqueue(frame());
        await flush();
        final resultEvent = queue.events.firstWhere(
          (event) => event.event == 'job.result',
        );
        state = {
          'status': status,
          if (status == 'SUCCEEDED')
            'result': {'name': 'Mushroom', 'confidence': 0.9},
          if (status == 'FAILED') 'message': 'Retries exhausted',
        };
        socket.receive('refresh', {
          'resource': 'classifier-job',
          'id': 'job-1',
        });
        expect(
          (await resultEvent).data['status'],
          status == 'SUCCEEDED' ? 'completed' : 'failed',
        );
        expect(queue.jobs.single.status.isPending, isFalse);
        expect(
          queue.jobs.single.result?['mushroom_name'],
          status == 'SUCCEEDED' ? 'Mushroom' : null,
        );
        state = {'status': 'PROCESSING'};
        await queue.fetchJob('job-1');
        expect(queue.jobs.single.status.isPending, isFalse);
        await flush();
        expect(
          await RecognitionQueueStore().load(queue.backendBaseUrl),
          isEmpty,
        );
      },
    );
  }

  test(
    'a disconnected socket polls the pending job API after five seconds',
    () async {
      final socket = TestSocket(autoConnect: false);
      var reads = 0;
      final queue = service(
        socket,
        MockClient((request) async {
          if (request.method == 'POST') return accepted();
          reads++;
          return http.Response(
            jsonEncode({
              'data': {
                'status': 'SUCCEEDED',
                'result': {'name': 'Mushroom'},
              },
            }),
            200,
          );
        }),
      );
      await queue.enqueue(frame());
      await Future<void>.delayed(const Duration(milliseconds: 5100));
      expect(reads, 1);
      expect(queue.jobs.single.status, JobStatus.completed);
    },
  );

  test(
    'refresh arriving during a snapshot read triggers another API read',
    () async {
      final socket = TestSocket();
      final firstRead = Completer<http.Response>();
      var reads = 0;
      final queue = service(
        socket,
        MockClient((request) async {
          if (request.method == 'POST') return accepted();
          if (++reads == 1) return firstRead.future;
          return http.Response(
            jsonEncode({
              'data': {
                'status': 'SUCCEEDED',
                'result': {'name': 'Latest result'},
              },
            }),
            200,
          );
        }),
      );
      await queue.enqueue(frame());
      await flush();
      final resultEvent = queue.events.firstWhere(
        (event) => event.event == 'job.result',
      );
      socket.receive('refresh', {'resource': 'classifier-job', 'id': 'job-1'});
      await Future<void>.delayed(const Duration(milliseconds: 350));
      firstRead.complete(
        http.Response(
          jsonEncode({
            'data': {'status': 'PROCESSING'},
          }),
          200,
        ),
      );
      expect((await resultEvent).data['status'], 'completed');
      expect(reads, 2);
      expect(queue.jobs.single.result?['mushroom_name'], 'Latest result');
    },
  );

  test(
    'pending IDs are isolated by backend and available when switching back',
    () async {
      final queue = service(TestSocket(), MockClient((_) async => accepted()));
      await queue.enqueue(frame());
      await queue.connect('http://other-server:8080');
      expect(queue.jobs, isEmpty);
      await queue.connect('http://localhost:8080');
      expect(queue.jobs.single.jobId, 'job-1');
    },
  );

  for (final status in [429, 503]) {
    test(
      '$status honors Retry-After and never resends automatically',
      () async {
        var uploads = 0;
        final queue = service(
          TestSocket(),
          MockClient((_) async {
            uploads++;
            return http.Response(
              'temporarily unavailable',
              status,
              headers: {'retry-after': '60'},
            );
          }),
        );
        await expectLater(
          queue.enqueue(frame()),
          throwsA(
            isA<ApiException>().having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 60),
            ),
          ),
        );
        expect(queue.uploadRetryRemaining.inSeconds, inInclusiveRange(58, 60));
        expect(queue.isUploading, isFalse);
        await expectLater(
          queue.enqueue(frame()),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              status,
            ),
          ),
        );
        await queue.connect();
        expect(uploads, 1);
        expect(queue.jobs, isEmpty);
      },
    );
  }

  test('429 without a valid Retry-After uses a 30 second cooldown', () async {
    final queue = service(
      TestSocket(),
      MockClient((_) async => http.Response('{}', 429)),
    );
    await expectLater(queue.enqueue(frame()), throwsA(isA<ApiException>()));
    expect(queue.uploadRetryRemaining.inSeconds, inInclusiveRange(28, 30));
  });

  test('503 without Retry-After allows an explicit manual retry', () async {
    var uploads = 0;
    final queue = service(
      TestSocket(),
      MockClient((_) async {
        uploads++;
        return uploads == 1 ? http.Response('{}', 503) : accepted();
      }),
    );
    await expectLater(queue.enqueue(frame()), throwsA(isA<ApiException>()));
    await flush();
    expect(uploads, 1);
    expect(queue.uploadRetryRemaining, Duration.zero);
    expect(await queue.enqueue(frame()), 'job-1');
    expect(uploads, 2);
  });

  test(
    'network failure before 202 neither creates a job nor automatically reuploads',
    () async {
      var uploads = 0;
      final queue = service(
        TestSocket(),
        MockClient((_) async {
          uploads++;
          throw http.ClientException('Network lost before response');
        }),
      );
      await expectLater(
        queue.enqueue(frame()),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.network,
          ),
        ),
      );
      await queue.reconnect(queue.backendBaseUrl);
      expect(uploads, 1);
      expect(queue.jobs, isEmpty);
      expect(queue.isUploading, isFalse);
    },
  );

  test('a concurrent submit does not start another upload', () async {
    final response = Completer<http.Response>();
    final requestSent = Completer<void>();
    var uploads = 0;
    final queue = service(
      TestSocket(),
      MockClient((_) {
        uploads++;
        requestSent.complete();
        return response.future;
      }),
    );
    final firstUpload = queue.enqueue(frame());
    await requestSent.future;
    await expectLater(queue.enqueue(frame()), throwsA(isA<ApiException>()));
    expect(uploads, 1);
    response.complete(accepted());
    await firstUpload;
  });

  testWidgets('retrying appears as waiting to retry on the result card', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobResultCard(
            job: QueueJob(
              jobId: 'job-1',
              status: JobStatus.retrying,
              createdAt: now,
              updatedAt: now,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Đang chờ thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
