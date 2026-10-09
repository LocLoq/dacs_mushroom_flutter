import 'dart:typed_data';
import 'job_status.dart';

class QueueJob {
  final String jobId;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? result;
  final String? error;
  final Uint8List? previewBytes;
  final String? originalMediaPath;
  final String? originalMediaType;
  final Map<String, dynamic> imageInfo;

  const QueueJob({
    required this.jobId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.result,
    this.error,
    this.previewBytes,
    this.originalMediaPath,
    this.originalMediaType,
    this.imageInfo = const {},
  });

  QueueJob copyWith({
    String? jobId,
    JobStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? result,
    String? error,
    Uint8List? previewBytes,
    String? originalMediaPath,
    String? originalMediaType,
    Map<String, dynamic>? imageInfo,
  }) {
    return QueueJob(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      result: result ?? this.result,
      error: error ?? this.error,
      previewBytes: previewBytes ?? this.previewBytes,
      originalMediaPath: originalMediaPath ?? this.originalMediaPath,
      originalMediaType: originalMediaType ?? this.originalMediaType,
      imageInfo: imageInfo ?? this.imageInfo,
    );
  }
}

