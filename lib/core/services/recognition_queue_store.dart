import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/recognition/data/queue_job.dart';

class RecognitionQueueStore {
  Future<void> _writes = Future.value();

  String _key(String origin) => 'recognition_pending_v1_$origin';

  Future<List<QueueJob>> load(String origin) async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(origin));
    if (raw == null) return [];
    final rows = jsonDecode(raw) as List;
    return rows
        .map(
          (row) =>
              QueueJob.fromPendingJson(Map<String, dynamic>.from(row as Map)),
        )
        .where((job) => job.jobId.isNotEmpty && job.status.isPending)
        .toList();
  }

  Future<void> save(String origin, Iterable<QueueJob> jobs) {
    final raw = jsonEncode(
      jobs
          .where((job) => job.status.isPending)
          .map((job) => job.toPendingJson())
          .toList(),
    );
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key(origin), raw)) {
        throw StateError('Unable to save pending recognition jobs');
      }
    });
    // A failed write must not prevent later snapshots from being saved.
    _writes = write.catchError((Object _) {});
    return write;
  }
}
