import 'package:flutter_test/flutter_test.dart';
import 'package:thu/features/mushroom_catalog/data/catalog_model.dart';
import 'package:thu/features/recognition_history/data/history_item.dart';

void main() {
  group('Models Serialization tests', () {
    test('RecognitionHistoryItem parses JSON safely', () {
      final json = {
        'id': 'job_123_test',
        'job_id': 'job_123',
        'status': 'completed',
        'created_at': '2026-09-08T07:30:00.000Z',
        'updated_at': '2026-09-08T07:30:02.000Z',
        'backend_base_url': 'http://10.0.2.2:8000',
        'mushroom_name': 'Nấm Bào Ngư',
        'prediction': 'Pleurotus ostreatus',
        'raw_prediction': 'Pleurotus ostreatus',
        'confidence': 0.952,
        'is_poisonous': false,
        'decision_reason': 'High confidence above threshold',
        'result': {
          'prediction': 'Pleurotus ostreatus',
          'confidence': 0.952,
          'is_poisonous': false,
        },
      };

      final item = RecognitionHistoryItem.fromJson(json);
      expect(item.id, 'job_123_test');
      expect(item.jobId, 'job_123');
      expect(item.status, 'completed');
      expect(item.mushroomName, 'Nấm Bào Ngư');
      expect(item.confidence, 0.952);
      expect(item.isPoisonous, false);

      final reEncoded = item.toJson();
      expect(reEncoded['job_id'], 'job_123');
      expect(reEncoded['confidence'], 0.952);
      expect(reEncoded['is_poisonous'], false);
    });

    test('MushroomCatalogResponse parses catalog properly', () {
      final json = {
        'source': 'test_dataset',
        'total': 2,
        'poisonous_count': 1,
        'safe_count': 1,
        'mushrooms': [
          {
            'name': 'Nấm Rơm',
            'scientific_name': 'Volvariella volvacea',
            'is_poisonous': false,
          },
          {
            'name': 'Nấm Tử Thần',
            'scientific_name': 'Amanita phalloides',
            'is_poisonous': true,
          }
        ],
      };

      final response = MushroomCatalogResponse.fromJson(json);
      expect(response.source, 'test_dataset');
      expect(response.total, 2);
      expect(response.poisonousCount, 1);
      expect(response.safeCount, 1);
      expect(response.mushrooms.length, 2);
      expect(response.mushrooms.first.isPoisonous, false);
      expect(response.mushrooms.last.isPoisonous, true);
    });

    test('MushroomCatalogItem: assetKey và image_url cho ảnh đại diện', () {
      final item = MushroomCatalogItem.fromJson({
        'name': 'Mộc Nhĩ',
        'scientific_name': 'Auricularia auricula-judae',
        'is_poisonous': false,
        'image_url': '/media/mushrooms/moc-nhi.jpg',
      });
      expect(item.assetKey, 'auricularia_auricula_judae');
      expect(item.imageUrl, '/media/mushrooms/moc-nhi.jpg');
      expect(item.toJson()['image_url'], '/media/mushrooms/moc-nhi.jpg');

      final noImage = MushroomCatalogItem.fromJson({'name': 'Nấm Rơm', 'is_poisonous': false});
      expect(noImage.imageUrl, isNull);
      expect(noImage.toJson().containsKey('image_url'), isFalse);
    });
  });
}
