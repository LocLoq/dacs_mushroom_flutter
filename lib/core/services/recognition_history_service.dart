import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/config/app_constants.dart';
import '../../features/recognition/data/queue_job.dart';
import '../../features/recognition_history/data/history_item.dart';

class RecognitionHistoryService {
  static RecognitionHistoryService? _instance;
  static RecognitionHistoryService get instance =>
      _instance ??= RecognitionHistoryService();

  static const int _kMaxHistoryItems = 200;

  SharedPreferences? _prefs;
  Directory? _mediaDir;
  final List<RecognitionHistoryItem> _items = [];

  List<RecognitionHistoryItem> get items => List.unmodifiable(_items);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (_mediaDir == null) {
      final docDir = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${docDir.path}/recognition_history');
      _mediaDir = Directory('${historyDir.path}/media');
      if (!await _mediaDir!.exists()) {
        await _mediaDir!.create(recursive: true);
      }
    }
    await reload();
  }

  Future<List<RecognitionHistoryItem>> reload() async {
    if (_prefs == null) await init();
    final raw = _prefs!.getString(AppConstants.prefRecognitionHistory);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _items.add(RecognitionHistoryItem.fromJson(item));
          } else if (item is Map) {
            _items.add(RecognitionHistoryItem.fromJson(
                Map<String, dynamic>.from(item)));
          }
        }
      } catch (_) {
        // Safe fallback nếu JSON lỗi cú pháp
      }
    }
    return items;
  }

  Future<void> upsertFromJob(QueueJob job, String backendBaseUrl) async {
    if (_prefs == null) await init();

    final result = job.result;
    final prediction = result?['prediction']?.toString();
    final mushroomName = result?['mushroom_name']?.toString() ??
        (prediction != null ? 'Nấm: $prediction' : null);
    final rawPrediction = result?['raw_prediction']?.toString();
    final confidence = (result?['confidence'] as num?)?.toDouble();
    final isPoisonous = result?['is_poisonous'] == true ||
        result?['is_poisonous'] == 1 ||
        result?['is_poisonous'].toString().toLowerCase() == 'true';
    final decisionReason = result?['decision_reason']?.toString();

    // Copy/save preview bytes to media directory
    final previewPath = await _savePreviewImage(job.jobId, job.previewBytes);
    final sourcePath = await _saveSourceMedia(job.jobId, job.originalMediaPath);

    final newItem = RecognitionHistoryItem(
      id: '${job.jobId}_${job.createdAt.millisecondsSinceEpoch}',
      jobId: job.jobId,
      status: job.status.name,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
      backendBaseUrl: backendBaseUrl,
      mushroomName: mushroomName,
      prediction: prediction,
      rawPrediction: rawPrediction,
      confidence: confidence,
      isPoisonous: result != null ? isPoisonous : null,
      decisionReason: decisionReason,
      previewImagePath: previewPath,
      sourceMediaPath: sourcePath,
      sourceMediaType: job.originalMediaType,
      result: result,
      error: job.error,
    );

    final existingIndex = _items.indexWhere((it) => it.jobId == job.jobId);
    if (existingIndex >= 0) {
      _items[existingIndex] = newItem;
    } else {
      _items.insert(0, newItem);
    }

    if (_items.length > _kMaxHistoryItems) {
      _items.removeRange(_kMaxHistoryItems, _items.length);
    }

    await _persist();
  }

  Future<void> deleteItem(String id) async {
    if (_prefs == null) await init();
    _items.removeWhere((it) => it.id == id || it.jobId == id);
    await _persist();
  }

  Future<void> clear() async {
    if (_prefs == null) await init();
    _items.clear();
    await _prefs!.remove(AppConstants.prefRecognitionHistory);
  }

  Future<void> _persist() async {
    final raw = jsonEncode(_items.map((it) => it.toJson()).toList());
    await _prefs!.setString(AppConstants.prefRecognitionHistory, raw);
  }

  Future<String?> _savePreviewImage(String jobId, Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty || _mediaDir == null) return null;
    try {
      final safeJobId = jobId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file = File('${_mediaDir!.path}/preview_$safeJobId.jpg');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _saveSourceMedia(String jobId, String? origPath) async {
    if (origPath == null || origPath.isEmpty || _mediaDir == null) return null;
    try {
      final origFile = File(origPath);
      if (!await origFile.exists()) return null;

      final safeJobId = jobId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final ext = origPath.split('.').last;
      final target = File('${_mediaDir!.path}/source_$safeJobId.$ext');
      if (!await target.exists()) {
        await origFile.copy(target.path);
      }
      return target.path;
    } catch (_) {
      return origPath;
    }
  }
}

