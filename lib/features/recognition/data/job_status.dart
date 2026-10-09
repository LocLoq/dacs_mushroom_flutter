import 'package:flutter/material.dart';

enum JobStatus {
  queued,
  processing,
  completed,
  failed;

  String get label {
    switch (this) {
      case JobStatus.queued:
        return 'Đang chờ';
      case JobStatus.processing:
        return 'Đang xử lý';
      case JobStatus.completed:
        return 'Hoàn thành';
      case JobStatus.failed:
        return 'Thất bại';
    }
  }

  String get labelEn {
    switch (this) {
      case JobStatus.queued:
        return 'Queued';
      case JobStatus.processing:
        return 'Processing';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.failed:
        return 'Failed';
    }
  }

  Color get color {
    switch (this) {
      case JobStatus.queued:
        return Colors.amber.shade800;
      case JobStatus.processing:
        return Colors.blue.shade700;
      case JobStatus.completed:
        return Colors.green.shade700;
      case JobStatus.failed:
        return Colors.red.shade700;
    }
  }

  IconData get icon {
    switch (this) {
      case JobStatus.queued:
        return Icons.hourglass_top_rounded;
      case JobStatus.processing:
        return Icons.sync_rounded;
      case JobStatus.completed:
        return Icons.check_circle_rounded;
      case JobStatus.failed:
        return Icons.error_rounded;
    }
  }

  static JobStatus fromString(String? val) {
    if (val == null) return JobStatus.queued;
    switch (val.toLowerCase().trim()) {
      case 'processing':
      case 'running':
        return JobStatus.processing;
      case 'completed':
      case 'success':
      case 'done':
        return JobStatus.completed;
      case 'failed':
      case 'error':
        return JobStatus.failed;
      default:
        return JobStatus.queued;
    }
  }
}

