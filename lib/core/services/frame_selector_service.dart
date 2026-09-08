import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../features/recognition/data/prepared_frame.dart';

class FrameSelectorService {
  static FrameSelectorService? _instance;
  static FrameSelectorService get instance => _instance ??= FrameSelectorService();

  Future<PreparedFrame> prepareFromImage(File file) async {
    final bytes = await file.readAsBytes();
    final score = scoreFrameQuality(bytes);
    return PreparedFrame(
      bytes: bytes,
      sourcePath: file.path,
      sourceLabel: 'Ảnh tĩnh',
      mediaType: 'image',
      qualityScore: score,
    );
  }

  Future<PreparedFrame> prepareFromVideo(File file) async {
    final totalMs = await _probeDuration(file.path);
    final samplePoints = buildSamplePoints(totalMs, 8);

    Uint8List? bestBytes;
    double bestScore = -1.0;
    int? bestMs;

    for (final ms in samplePoints) {
      try {
        final data = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          quality: 95,
          maxWidth: 720,
          timeMs: ms,
        );
        if (data != null && data.isNotEmpty) {
          final score = scoreFrameQuality(data);
          if (score > bestScore) {
            bestScore = score;
            bestBytes = data;
            bestMs = ms;
          }
        }
      } catch (_) {
        // Tiếp tục thử các mốc khác nếu 1 mốc gặp lỗi
      }
    }

    if (bestBytes == null || bestBytes.isEmpty) {
      throw Exception('Không lấy được frame hợp lệ từ video.');
    }

    return PreparedFrame(
      bytes: bestBytes,
      sourcePath: file.path,
      sourceLabel: 'Video (frame tối ưu)',
      mediaType: 'video',
      qualityScore: math.max(0.0, bestScore),
      selectedFrameMs: bestMs,
    );
  }

  Future<int> _probeDuration(String path) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } catch (_) {
      return 0;
    } finally {
      await controller?.dispose();
    }
  }

  List<int> buildSamplePoints(int totalMs, [int sampleCount = 8]) {
    if (totalMs <= 0) return [0];
    final safeEnd = math.max(1, totalMs - 1);
    final step = safeEnd / (sampleCount + 1);
    final points = <int>[];
    for (int i = 1; i <= sampleCount; i++) {
      points.add((step * i).round());
    }
    return points;
  }

  double scoreFrameQuality(Uint8List bytes) {
    try {
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return 0.0;

      if (decoded.width > 320) {
        decoded = img.copyResize(decoded, width: 320);
      }

      final width = decoded.width;
      final height = decoded.height;
      if (width < 3 || height < 3) return 0.0;

      final lumaGrid = List.generate(
        height,
        (_) => Float32List(width),
        growable: false,
      );

      double sumLuma = 0.0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = decoded.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          lumaGrid[y][x] = lum;
          sumLuma += lum;
        }
      }

      final avgLuma = sumLuma / (width * height);

      double sumGradient = 0.0;
      int interiorCount = 0;
      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          final gx = lumaGrid[y][x + 1] - lumaGrid[y][x - 1];
          final gy = lumaGrid[y + 1][x] - lumaGrid[y - 1][x];
          sumGradient += math.sqrt(gx * gx + gy * gy);
          interiorCount++;
        }
      }

      final avgGradient = interiorCount > 0 ? sumGradient / interiorCount : 0.0;
      final sharpnessScore = (avgGradient / 60.0).clamp(0.0, 1.0);
      final exposureScore = (1.0 - ((avgLuma - 128.0).abs() / 128.0)).clamp(0.0, 1.0);

      final totalScore = 0.8 * sharpnessScore + 0.2 * exposureScore;
      return totalScore.clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }
}

