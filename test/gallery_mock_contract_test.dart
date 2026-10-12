import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/core/network/api_client.dart' show ApiClient;
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/storage/local_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalSession.clear();
    MockConfig.notifier.value = true;
  });
  tearDown(() {
    LocalSession.clear();
    MockConfig.notifier.value = false;
  });

  test(
    'mock galleries match public projection, private visibility and patch permissions',
    () async {
      final api = FarmApi();
      await api.login('manager', 'manager123');
      final file = XFile.fromData(Uint8List.fromList([1]), name: 'test.png');
      for (final resource in [
        'mushroom-species',
        'production-facilities',
        'cultivation-batches',
      ]) {
        final path = '/$resource/1/images';
        final privateResponse = await api.multipart(
          'POST',
          path,
          files: [file],
          fields: {'isPublic': 'false'},
        );
        final publicResponse = await api.multipart(
          'POST',
          path,
          files: [file],
          fields: {'isPublic': 'true'},
        );
        final privateId = (privateResponse['data'] as List).first['id'];
        final publicId = (publicResponse['data'] as List).first['id'];
        final visible = (await api.get(path, public: true))['data'] as List;
        expect(visible.length, 1);
        expect((visible.first as Map).keys.toSet(), {
          'id',
          'imageUrl',
          'caption',
          'isCover',
        });
        final full = (await api.get(path))['data'] as List;
        expect(full.length, 2);
        expect(
          (full.first as Map).keys,
          containsAll([
            'isPublic',
            'uploadedByUserId',
            'createdAt',
            'originalName',
          ]),
        );
        await api.patch('$path/$privateId', {'isPublic': true});
        expect(
          ((await api.get(path, public: true))['pagination']
              as Map)['totalItems'],
          2,
        );
        if (resource == 'mushroom-species') {
          final catalog = await ApiClient().fetchMushroomCatalog();
          expect(catalog.mushrooms.first.imageUrl, isNotNull);
        }
        await api.login('staff', 'staff123');
        await expectLater(
          api.patch('$path/$publicId', {'isPublic': false}),
          throwsA(
            isA<ApiException>().having((error) => error.status, 'status', 403),
          ),
        );
        await api.login('manager', 'manager123');
        await api.delete('$path/$privateId');
        await api.delete('$path/$publicId');
      }
    },
  );

  test('mock resolves an exact encoded QR code and requires login', () async {
    final api = FarmApi();
    await api.login('manager', 'manager123');
    const code = 'LO / Đà Lạt #01?%';
    final created = await api.post('/cultivation-batches', {
      'batchCode': code,
      'facilityId': 1,
      'mushroomId': 2,
      'status': 'FRUITING',
      'startDate': '2026-10-11',
    });
    final id = (created['data'] as Map)['id'];
    await api.login('staff', 'staff123');
    expect(
      (await api.get(
        '/cultivation-batches/by-code/${Uri.encodeComponent(code)}',
      ))['data'],
      {'id': id, 'batchCode': code},
    );
    await expectLater(
      api.get('/cultivation-batches/by-code/LO'),
      throwsA(
        isA<ApiException>().having((error) => error.status, 'status', 404),
      ),
    );
    await api.login('manager', 'manager123');
    for (final reserved in ['images', 'expenses']) {
      final reservedBatch = await api.post('/cultivation-batches', {
        'batchCode': reserved,
        'facilityId': 1,
        'mushroomId': 2,
        'status': 'FRUITING',
        'startDate': '2026-10-11',
      });
      final reservedId = (reservedBatch['data'] as Map)['id'];
      await api.login('staff', 'staff123');
      expect(
        (await api.get('/cultivation-batches/by-code/$reserved'))['data'],
        {'id': reservedId, 'batchCode': reserved},
      );
      await api.login('manager', 'manager123');
      await api.delete('/cultivation-batches/$reservedId');
    }
    await api.delete('/cultivation-batches/$id');
    LocalSession.clear();
    await expectLater(
      api.get('/cultivation-batches/by-code/${Uri.encodeComponent(code)}'),
      throwsA(
        isA<ApiException>().having((error) => error.status, 'status', 401),
      ),
    );
  });
}
