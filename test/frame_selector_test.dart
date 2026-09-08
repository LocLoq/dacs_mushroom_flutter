import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thu/core/services/frame_selector_service.dart';

void main() {
  group('FrameSelectorService tests', () {
    final service = FrameSelectorService.instance;

    test('buildSamplePoints generates 8 distinct distributed sample timestamps', () {
      final points = service.buildSamplePoints(9000, 8);
      expect(points.length, 8);
      expect(points.first, greaterThan(0));
      expect(points.last, lessThan(9000));
      // Sắp xếp tăng dần
      for (int i = 1; i < points.length; i++) {
        expect(points[i], greaterThan(points[i - 1]));
      }
    });

    test('buildSamplePoints handles zero or negative duration safely', () {
      expect(service.buildSamplePoints(0, 8), [0]);
      expect(service.buildSamplePoints(-100, 8), [0]);
    });

    test('scoreFrameQuality scores high contrast gradient image higher than blank image', () {
      // 1. Ảnh đen toàn phần (10x10)
      final blackImg = img.Image(width: 10, height: 10);
      img.fill(blackImg, color: img.ColorRgb8(0, 0, 0));
      final blackBytes = img.encodeJpg(blackImg);
      final blackScore = service.scoreFrameQuality(blackBytes);

      // 2. Ảnh có độ tương phản và biên rõ rệt (checkerboard pattern)
      final patternedImg = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          final isEven = ((x ~/ 10) + (y ~/ 10)) % 2 == 0;
          patternedImg.setPixel(
            x,
            y,
            isEven ? img.ColorRgb8(240, 240, 240) : img.ColorRgb8(15, 15, 15),
          );
        }
      }
      final patternBytes = img.encodeJpg(patternedImg);
      final patternScore = service.scoreFrameQuality(patternBytes);

      expect(patternScore, greaterThan(blackScore));
      expect(patternScore, greaterThan(0.5));
    });
  });
}

