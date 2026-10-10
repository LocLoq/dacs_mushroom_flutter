import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:thu/core/network/api_client.dart' hide ApiException;
import 'package:thu/core/network/farm_api.dart';
import 'api_client_test.dart' show MemoryTokenStore, jsonResponse;

void main() {
  test(
    'restored UI uses real transport paths and preserves response envelopes',
    () async {
      final requests = <String>[];
      final client = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStore: MemoryTokenStore(),
        client: MockClient((request) async {
          requests.add(request.method + ' ' + request.url.path);
          if (request.method == 'POST')
            expect(jsonDecode(request.body), {
              'stage': 'FRUITING',
              'notes': 'Kiểm thử',
            });
          return jsonResponse({
            'data': [
              {'id': 8},
            ],
            'pagination': {'currentPage': 1, 'totalPages': 3},
          });
        }),
      );
      final api = FarmApi(client: client);
      final response = await api.get(
        '/cultivation-batches',
        query: {'page': 1},
      );
      expect(response['pagination']['totalPages'], 3);
      await api.post('/cultivation-batches/8/growth-progress', {
        'stage': 'FRUITING',
        'notes': 'Kiểm thử',
      });
      expect(requests, [
        'GET /api/cultivation-batches',
        'POST /api/cultivation-batches/8/growth-progress',
      ]);
    },
  );
  test(
    'backend errors reach the restored UI with HTTP status and code intact',
    () async {
      final api = FarmApi(
        client: ApiClient(
          baseUrl: 'http://localhost:8080',
          client: MockClient(
            (_) async => jsonResponse({
              'code': 'STATE_CONFLICT',
              'message': 'Trạng thái đã thay đổi',
            }, 409),
          ),
        ),
      );
      await expectLater(
        api.patch('/dashboard/tasks/8', {'status': 'IN_PROGRESS'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isConflict, 'conflict', true)
              .having((e) => e.code, 'code', 'STATE_CONFLICT'),
        ),
      );
    },
  );
}
