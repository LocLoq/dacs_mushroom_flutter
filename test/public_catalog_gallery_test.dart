import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:thu/core/network/api_client.dart' hide ApiException;
import 'package:thu/core/network/farm_api.dart';
import 'package:thu/core/network/mock_config.dart';
import 'package:thu/core/storage/local_session.dart';
import 'package:thu/core/widgets/net_image.dart';
import 'package:thu/features/gallery/entity_gallery.dart';
import 'package:thu/features/mushroom_catalog/data/catalog_model.dart';
import 'package:thu/features/mushroom_catalog/presentation/mushroom_catalog_screen.dart';
import 'package:thu/features/mushroom_catalog/presentation/public_species_detail_screen.dart';
import 'api_client_test.dart' show MemoryTokenStore, jsonResponse;

class _Picker extends ImagePickerPlatform {
  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => [
    XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'test.png',
      path: 'test.png',
      mimeType: 'image/png',
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    LocalSession.clear();
    MockConfig.notifier.value = false;
    ApiConfig.useServer('http://gallery.test');
  });
  tearDown(LocalSession.clear);
  ApiClient client(http.Client transport) => ApiClient(
    client: transport,
    baseUrl: 'http://gallery.test',
    tokenStore: MemoryTokenStore(),
  );
  void manager() => LocalSession.save('manager-token', {
    'id': 1,
    'username': 'manager',
    'role': 'manager',
  }, serverOrigin: 'http://gallery.test');

  test(
    'catalog is public across pages even with an old token; parses IDs, covers and edibility',
    () async {
      manager();
      var requests = 0;
      final api = client(
        MockClient((request) async {
          expect(request.headers['Authorization'], isNull);
          final page = int.parse(request.url.queryParameters['page']!);
          requests++;
          return jsonResponse({
            'data': [
              {
                'id': page,
                'commonName': 'Nấm $page',
                'scientificName': 'Species $page',
                'edibilityStatus': page == 1 ? 'EDIBLE' : 'DEADLY',
                'coverImageUrl': page == 1
                    ? '/uploads/gallery/cover.png'
                    : null,
                'imageUrl': '/legacy.png',
              },
            ],
            'pagination': {'totalPages': 2},
          });
        }),
      );
      final catalog = await api.fetchMushroomCatalog();
      expect(requests, 2);
      expect(catalog.mushrooms.map((item) => item.id), [1, 2]);
      expect(catalog.mushrooms.map((item) => item.imageUrl), [
        '/uploads/gallery/cover.png',
        '/legacy.png',
      ]);
      expect(catalog.safeCount, 1);
      expect(catalog.poisonousCount, 1);
      expect(LocalSession.isLoggedIn, isTrue);
      expect(
        MushroomCatalogItem.fromJson({
          'id': 8,
          'commonName': 'Fallback',
          'coverImageUrl': '',
          'imageUrl': '/fallback.jpg',
        }).imageUrl,
        '/fallback.jpg',
      );
    },
  );

  testWidgets('guest catalog renders data instead of requiring login', (
    tester,
  ) async {
    final api = client(
      MockClient(
        (request) async => jsonResponse({
          'data': [
            {
              'id': 4,
              'commonName': 'Nấm thử nghiệm',
              'scientificName': 'Test species',
              'edibilityStatus': 'EDIBLE',
            },
          ],
          'pagination': {'totalPages': 1},
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MushroomCatalogScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Nấm thử nghiệm'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'public species detail and gallery omit tokens and admin controls',
    (tester) async {
      manager();
      final requests = <String>[];
      final api = FarmApi(
        client: client(
          MockClient((request) async {
            requests.add(request.url.path);
            expect(request.headers['Authorization'], isNull);
            return request.url.path.endsWith('/images')
                ? jsonResponse({
                    'data': [
                      {
                        'id': 1,
                        'imageUrl': '',
                        'caption': 'Ảnh công khai',
                        'isCover': true,
                      },
                    ],
                    'pagination': {'totalPages': 1, 'totalItems': 1},
                  })
                : jsonResponse({
                    'data': {
                      'id': 4,
                      'commonName': 'Nấm thử',
                      'scientificName': 'Test',
                      'edibilityStatus': 'EDIBLE',
                    },
                  });
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: PublicSpeciesDetailScreen(speciesId: 4, api: api)),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(
        requests,
        containsAll([
          '/api/mushroom-species/4',
          '/api/mushroom-species/4/images',
        ]),
      );
      expect(find.text('Tải ảnh'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'anonymous four-field gallery shows public status without metadata or edit actions',
    (tester) async {
      final api = FarmApi(
        client: client(
          MockClient((request) async {
            expect(request.headers['Authorization'], isNull);
            return jsonResponse({
              'data': [
                {
                  'id': 1,
                  'imageUrl': '',
                  'caption': 'Ảnh khách',
                  'isCover': true,
                },
              ],
              'pagination': {'totalPages': 1, 'totalItems': 1},
            });
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntityGallery(
              resource: 'mushroom-species',
              parentId: 1,
              canEdit: true,
              api: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Công khai'), findsOneWidget);
      expect(find.text('Riêng tư'), findsNothing);
      expect(find.text('Tải ảnh'), findsNothing);
    },
  );

  for (final resource in [
    'mushroom-species',
    'production-facilities',
    'cultivation-batches',
  ]) {
    testWidgets(
      '$resource upload uses the correct public default and multipart value',
      (tester) async {
        manager();
        final previousPicker = ImagePickerPlatform.instance;
        ImagePickerPlatform.instance = _Picker();
        addTearDown(() => ImagePickerPlatform.instance = previousPicker);
        String? uploaded;
        final api = FarmApi(
          client: client(
            MockClient((request) async {
              if (request.method == 'POST')
                uploaded = utf8.decode(request.bodyBytes, allowMalformed: true);
              return jsonResponse({
                'data': [],
                'pagination': {'totalPages': 0, 'totalItems': 0},
              });
            }),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EntityGallery(
                resource: resource,
                parentId: 1,
                canEdit: true,
                api: api,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('Tải ảnh'));
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        final expected = resource == 'mushroom-species';
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          expected,
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('Lưu'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(uploaded, contains('name="isPublic"\r\n\r\n$expected'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'manager edits public visibility as JSON boolean; logout removes management controls',
    (tester) async {
      manager();
      var isPublic = false;
      final api = FarmApi(
        client: client(
          MockClient((request) async {
            if (request.method == 'PATCH') {
              final body = jsonDecode(request.body) as Map;
              expect(body['isPublic'], isTrue);
              isPublic = body['isPublic'] as bool;
            }
            return jsonResponse({
              'data': [
                {
                  'id': 1,
                  'imageUrl': '',
                  'caption': 'Ảnh',
                  'originalName': 'private.png',
                  'isCover': true,
                  'isPublic': isPublic,
                },
              ],
              'pagination': {'totalPages': 1, 'totalItems': 1},
            });
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntityGallery(
              resource: 'mushroom-species',
              parentId: 1,
              canEdit: true,
              api: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riêng tư'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sửa ảnh / Công khai'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Công khai'), findsOneWidget);
      LocalSession.clear();
      await tester.pumpAndSettle();
      expect(find.text('Tải ảnh'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    },
  );

  testWidgets(
    'private image fetch sends a token and discards its pixels after logout',
    (tester) async {
      manager();
      final headers = <String?>[];
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGNUWODAwMDAxAAGAAwKAQTFBdYUAAAAAElFTkSuQmCC',
      );
      final transport = MockClient((request) async {
        headers.add(request.headers['Authorization']);
        return request.headers['Authorization'] == null
            ? http.Response('', 404)
            : http.Response.bytes(
                png,
                200,
                headers: {'content-type': 'image/png'},
              );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: NetImage('/uploads/gallery/private.png', client: transport),
        ),
      );
      await tester.pumpAndSettle();
      expect(headers, ['Bearer manager-token']);
      expect(find.byType(Image), findsOneWidget);
      LocalSession.clear();
      await tester.pumpAndSettle();
      expect(headers, ['Bearer manager-token', null]);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
