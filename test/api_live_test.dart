import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:thu/core/network/api_client.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/core/network/farm_api.dart' show FarmApi;
import 'package:thu/features/account/data/account_model.dart';
import 'package:thu/features/cultivation_batch/data/batch_model.dart';
import 'package:thu/features/mushroom_strain/data/strain_model.dart';
import 'api_client_test.dart' show MemoryTokenStore;

void main() {
  const live = bool.fromEnvironment('LIVE_API_TEST');
  const url = String.fromEnvironment(
    'LIVE_API_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
  const username = String.fromEnvironment(
    'LIVE_API_USERNAME',
    defaultValue: 'demo_admin',
  );
  const password = String.fromEnvironment(
    'LIVE_API_PASSWORD',
    defaultValue: 'Demo@12345',
  );
  test(
    'real backend: typed reads, CRUD, permission errors, multipart upload and Socket.IO',
    () async {
      final api = ApiClient(baseUrl: url, tokenStore: MemoryTokenStore());
      final tag =
          'flutter_api_test_' +
          DateTime.now().microsecondsSinceEpoch.toString();
      final cleanup = <String>[];
      try {
        await api.login(username, password);
        expect(LocalSession.isAdmin, isTrue);
        expect(await api.fetchFacilities(), isNotEmpty);
        expect(await api.fetchStrains(), isNotEmpty);
        expect(await api.fetchBatches(), isNotEmpty);
        expect(await api.fetchAccounts(), isNotEmpty);
        expect((await api.fetchMushroomCatalog()).mushrooms, isNotEmpty);
        final farm = FarmApi(client: api);
        for (final endpoint in [
          '/dashboard/tasks',
          '/dashboard/task-assignees',
          '/reports/overview',
          '/reports/cultivation',
          '/reports/classifier',
          '/reports/audit',
          '/reports/financial',
          '/admin/audit-logs',
          '/mushroom-classifier/history',
        ]) {
          final response = await farm.get(
            endpoint,
            query: {'page': 1, 'limit': 2},
          );
          expect(response.containsKey('data'), isTrue, reason: endpoint);
        }
        final export = await farm.download(
          '/reports/overview/export',
          query: {'format': 'csv'},
        );
        expect(export.bytes, isNotEmpty);
        expect(export.contentType, contains('csv'));
        final roles = await api.fetchRoles();
        final staffRole =
            roles.firstWhere((role) => role['name'] == 'staff')['id'] as int;

        final species = StrainModel(
          id: '',
          name: tag,
          scientificName: tag,
          family: 'Testaceae',
          genus: 'Test',
          edibilityStatus: 'INEDIBLE',
        );
        final createdSpecies = await api.request(
          '/mushroom-species',
          method: 'POST',
          data: species.toJson(),
        );
        final speciesId = createdSpecies['data']['id'].toString();
        cleanup.insert(0, '/mushroom-species/' + speciesId);
        await api.saveStrain(
          StrainModel(
            id: speciesId,
            name: tag + '_updated',
            scientificName: tag,
            family: 'Testaceae',
            genus: 'Test',
            edibilityStatus: 'INEDIBLE',
          ),
        );
        expect(
          (await api.request(
            '/mushroom-species/' + speciesId,
          ))['data']['commonName'],
          tag + '_updated',
        );

        final facility = await api.request(
          '/production-facilities',
          method: 'POST',
          data: {
            'name': tag,
            'address': 'API test',
            'facilityType': 'HOUSEHOLD',
          },
        );
        final facilityId = facility['data']['id'].toString();
        cleanup.insert(0, '/production-facilities/' + facilityId);
        final batch = BatchModel(
          id: '',
          batchCode: tag,
          facilityId: facilityId,
          facilityName: tag,
          mushroomId: speciesId,
          mushroomName: tag,
          status: BatchStatus.preparation,
          startDate: DateTime.now(),
          bagQuantity: 3,
        );
        await api.saveBatch(batch);
        final batchRows = await api.fetchRawList(
          '/cultivation-batches',
          query: {'search': tag},
        );
        final batchId = batchRows.single['id'].toString();
        cleanup.insert(0, '/cultivation-batches/' + batchId);
        await api.saveBatch(
          BatchModel.fromJson({...batchRows.single, 'status': 'INCUBATION'}),
        );
        expect(
          (await api.request(
            '/cultivation-batches/' + batchId,
          ))['data']['status'],
          'INCUBATION',
        );
        await expectLater(
          api.saveBatch(batch),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'duplicate code',
              400,
            ),
          ),
        );

        final newUser = await api.request(
          '/admin/users',
          method: 'POST',
          data: {
            'username': tag,
            'password': 'ApiTest@12345',
            'full_name': 'API test',
            'phone_number': '0900000000',
            'email': tag + '@example.test',
            'role_id': staffRole,
          },
        );
        final userId = newUser['data']['id'].toString();
        cleanup.insert(0, '/admin/users/' + userId);
        await api.updateAccount(
          AccountModel(
            id: userId,
            username: tag,
            fullName: 'Updated API test',
            role: AccountRole.staff,
            roleId: staffRole,
            phoneNumber: '0900000001',
            email: tag + '@example.test',
          ),
          password: 'ApiTest@54321',
        );
        final staffApi = ApiClient(
          baseUrl: url,
          tokenStore: MemoryTokenStore(),
        );
        await staffApi.login(tag, 'ApiTest@54321');
        await expectLater(
          staffApi.fetchAccounts(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'staff permission',
              403,
            ),
          ),
        );
        expect(LocalSession.isLoggedIn, isTrue);
        await api.login(username, password);

        for (final path in ['care-logs', 'growth-progress', 'harvests']) {
          expect(
            (await api.request(
              '/cultivation-batches/' + batchId + '/' + path,
            ))['data'],
            isA<List>(),
          );
        }
        await api.request(
          '/cultivation-batches/' + batchId + '/care-logs',
          method: 'POST',
          data: {'actionType': 'API test', 'notes': 'Test request'},
        );
        await api.request(
          '/cultivation-batches/' + batchId + '/growth-progress',
          method: 'POST',
          data: {'stage': 'API test', 'notes': 'Test request'},
        );
        await api.request(
          '/cultivation-batches/' + batchId + '/harvests',
          method: 'POST',
          data: {
            'totalYieldKg': 1,
            'qualityGrade': 'TEST',
            'finalizeBatch': false,
          },
        );
        final public = await api.request(
          '/public/cultivation-batches/' +
              Uri.encodeComponent(tag) +
              '/growth-progress/current',
          auth: RequestAuth.none,
        );
        expect(public['data']['currentProgress']['stage'], 'API test');

        final cfg = await api.config();
        final upload = http.MultipartRequest(
          'POST',
          cfg.endpoint('/mushroom-classifier/classify'),
        );
        final image = img.Image(width: 128, height: 128);
        img.fill(image, color: img.ColorRgb8(90, 70, 50));
        upload.files.add(
          http.MultipartFile.fromBytes(
            'image',
            img.encodeJpg(image),
            filename: 'api-test.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
        final queued = await api.send(
          upload,
          auth: RequestAuth.optional,
          serverOrigin: cfg.serverOrigin.toString(),
        );
        expect(queued['status'], 'QUEUED');
        final result = Completer<Map>();
        final socket = io.io(
          cfg.serverOrigin.toString(),
          io.OptionBuilder()
              .setTransports(['websocket'])
              .enableForceNew()
              .disableAutoConnect()
              .build(),
        );
        try {
          socket.onConnect(
            (_) => socket.emit('subscribe_job', queued['jobId']),
          );
          socket.on('finished', (data) {
            if (!result.isCompleted) result.complete(data as Map);
          });
          socket.on('failed', (data) {
            if (!result.isCompleted)
              result.completeError(
                StateError((data as Map)['message'].toString()),
              );
          });
          socket.connect();
          final completed = await result.future.timeout(
            const Duration(seconds: 120),
          );
          expect(completed['jobId'], queued['jobId']);
          expect(completed['result']['confidence'], isA<num>());
        } finally {
          socket.dispose();
        }
      } finally {
        // Re-authenticate after staff permission checks before removing test records.
        if (cleanup.isNotEmpty) await api.login(username, password);
        final failures = <String>[];
        for (final path in cleanup) {
          try {
            await api.request(path, method: 'DELETE');
          } catch (error) {
            failures.add(path + ': ' + error.toString());
          }
        }
        LocalSession.clear();
        expect(
          failures,
          isEmpty,
          reason: 'Temporary API test records must be removed.',
        );
      }
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
