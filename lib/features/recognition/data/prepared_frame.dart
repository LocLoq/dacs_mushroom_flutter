import 'dart:typed_data';

class PreparedFrame {
  final Uint8List bytes;
  final String sourcePath;
  final String sourceLabel;
  final String mediaType; // 'image' | 'video'
  final double qualityScore; // 0.0 -> 1.0
  final int? selectedFrameMs;

  const PreparedFrame({
    required this.bytes,
    required this.sourcePath,
    required this.sourceLabel,
    required this.mediaType,
    required this.qualityScore,
    this.selectedFrameMs,
  });
}

