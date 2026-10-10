import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thu/core/network/api_client.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/core/services/backend_queue_service.dart';
import 'package:thu/features/cultivation_batch/data/batch_model.dart';

class MemoryTokenStore extends TokenStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(String token, String serverOrigin) async {
    value = {'token': token, 'server': serverOrigin};
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  tearDown(LocalSession.clear);
  test(
    'login verifies /auth/me, persists server affinity, and sends Bearer tokens',
    () async {
      final store = MemoryTokenStore();
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api',
        tokenStore: store,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/login') {
            expect(request.headers.containsKey('Authorization'), isFalse);
            expect(jsonDecode(request.body), {
              'username': 'user',
              'password': 'password',
            });
            return jsonResponse({'token': 'fixture-token'});
          }
          expect(request.headers['Authorization'], 'Bearer fixture-token');
          return jsonResponse({
            'data': {'id': 7, 'username': 'user', 'role': 'admin'},
          });
        }),
      );
      await api.login('user', 'password');
      expect(requests.map((r) => r.url.path), ['/api/login', '/api/auth/me']);
      expect(store.value?['server'], 'http://localhost:8080');
      expect(LocalSession.isAdmin, isTrue);
      expect(LocalSession.tokenFor('http://different-server:8080'), isNull);
    },
  );

  test(
    'all backend pagination pages are loaded without losing records',
    () async {
      final pages = <int>[];
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        client: MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          pages.add(page);
          return jsonResponse({
            'data': [
              {
                'id': page,
                'name': 'Facility ' + page.toString(),
                'address': 'Address',
                'status': 'ACTIVE',
              },
            ],
            'pagination': {
              'currentPage': page,
              'totalPages': 3,
              'totalItems': 3,
              'pageSize': 1,
            },
          });
        }),
      );
      final rows = await api.fetchFacilities();
      expect(rows.map((row) => row.id), ['1', '2', '3']);
      expect(pages, [1, 2, 3]);
    },
  );

  test(
    '403 permission failures preserve sessions; invalid token clears sessions',
    () async {
      final store = MemoryTokenStore();
      await store.write('token', 'http://localhost:8080');
      LocalSession.save('token', {
        'username': 'staff',
        'role': 'staff',
      }, serverOrigin: 'http://localhost:8080');
      var status = 403;
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStore: store,
        client: MockClient(
          (_) async => jsonResponse({
            'code': status == 403 ? 'AUTH_FORBIDDEN' : 'AUTH_INVALID_TOKEN',
            'message': 'Backend error',
          }, status),
        ),
      );
      await expectLater(
        api.fetchAccounts(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.forbidden,
          ),
        ),
      );
      expect(LocalSession.isLoggedIn, isTrue);
      expect(store.value, isNotNull);
      status = 401;
      await expectLater(
        api.fetchProfile(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.unauthorized,
          ),
        ),
      );
      expect(LocalSession.isLoggedIn, isFalse);
      expect(store.value, isNull);
    },
  );

  test(
    'new batches POST numeric IDs and existing batches PUT without relation metadata',
    () async {
      final sent = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        client: MockClient((r) async {
          sent.add(r);
          return jsonResponse({
            'data': {'id': 9},
          });
        }),
      );
      final batch = BatchModel(
        id: '',
        batchCode: 'TEST',
        facilityId: '3',
        facilityName: 'Facility',
        mushroomId: '2',
        mushroomName: 'Species',
        status: BatchStatus.incubation,
        startDate: DateTime(2026, 10, 10),
        bagQuantity: 20,
      );
      await api.saveBatch(batch);
      expect(sent.single.method, 'POST');
      final data = jsonDecode(sent.single.body) as Map;
      expect(data['facilityId'], 3);
      expect(data['mushroomId'], 2);
      expect(data['status'], 'INCUBATION');
      expect(data.containsKey('id'), isFalse);
      expect(data.containsKey('facilityName'), isFalse);
      final existing = BatchModel.fromJson({...data, 'id': 9});
      await api.saveBatch(existing);
      expect(sent.last.method, 'PUT');
      expect(sent.last.url.path, '/api/cultivation-batches/9');
    },
  );

  test(
    'backend validation and non-JSON errors are visible instead of fake success',
    () async {
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        client: MockClient(
          (_) async => jsonResponse({'message': 'Mã lô bị trùng'}, 400),
        ),
      );
      await expectLater(
        api.request('/cultivation-batches', method: 'POST', data: {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Mã lô bị trùng',
          ),
        ),
      );
      final invalid = ApiClient(
        baseUrl: 'http://localhost:8080',
        client: MockClient(
          (_) async => http.Response('<html>error</html>', 502),
        ),
      );
      await expectLater(
        invalid.request('/test'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)),
      );
    },
  );

  test(
    'classifier result maps the actual backend payload and keeps UNKNOWN unresolved',
    () {
      final result = BackendQueueService.adaptResult({
        'name': 'unknown',
        'scientificName': 'Species',
        'rawPrediction': 'Species',
        'accepted': false,
        'edibility': 'UNKNOWN',
        'isPoisonous': false,
        'confidence': 0.4,
        'confidenceThreshold': 0.7,
        'inferenceTimeMs': 300,
        'image': {'format': 'jpeg', 'sizeBytes': 200},
      });
      expect(result['prediction'], 'unknown');
      expect(result['is_poisonous'], isNull);
      expect(result['inference_time_seconds'], 0.3);
      expect(result['size_bytes'], 200);
    },
  );
}
