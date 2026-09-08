class RecognitionHistoryItem {
  final String id;
  final String jobId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String backendBaseUrl;
  final String? mushroomName;
  final String? prediction;
  final String? rawPrediction;
  final double? confidence;
  final bool? isPoisonous;
  final String? decisionReason;
  final String? previewImagePath;
  final String? sourceMediaPath;
  final String? sourceMediaType;
  final Map<String, dynamic>? result;
  final String? error;

  const RecognitionHistoryItem({
    required this.id,
    required this.jobId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.backendBaseUrl,
    this.mushroomName,
    this.prediction,
    this.rawPrediction,
    this.confidence,
    this.isPoisonous,
    this.decisionReason,
    this.previewImagePath,
    this.sourceMediaPath,
    this.sourceMediaType,
    this.result,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'backend_base_url': backendBaseUrl,
      'mushroom_name': mushroomName,
      'prediction': prediction,
      'raw_prediction': rawPrediction,
      'confidence': confidence,
      'is_poisonous': isPoisonous,
      'decision_reason': decisionReason,
      'preview_image_path': previewImagePath,
      'source_media_path': sourceMediaPath,
      'source_media_type': sourceMediaType,
      'result': result,
      'error': error,
    };
  }

  factory RecognitionHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    bool? parseBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return null;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return RecognitionHistoryItem(
      id: (json['id'] ?? json['job_id'] ?? '').toString(),
      jobId: (json['job_id'] ?? '').toString(),
      status: (json['status'] ?? 'queued').toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      backendBaseUrl: (json['backend_base_url'] ?? '').toString(),
      mushroomName: json['mushroom_name'] as String?,
      prediction: json['prediction'] as String?,
      rawPrediction: json['raw_prediction'] as String?,
      confidence: parseDouble(json['confidence']),
      isPoisonous: parseBool(json['is_poisonous']),
      decisionReason: json['decision_reason'] as String?,
      previewImagePath: json['preview_image_path'] as String?,
      sourceMediaPath: json['source_media_path'] as String?,
      sourceMediaType: json['source_media_type'] as String?,
      result: json['result'] is Map<String, dynamic>
          ? json['result'] as Map<String, dynamic>
          : (json['result'] is Map ? Map<String, dynamic>.from(json['result'] as Map) : null),
      error: json['error'] as String?,
    );
  }
}

