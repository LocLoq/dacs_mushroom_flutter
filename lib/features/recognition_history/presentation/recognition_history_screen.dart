import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/localization/app_text_scope.dart';
import '../../../core/services/recognition_history_service.dart';
import '../data/history_item.dart';
import 'widgets/history_detail_dialog.dart';

class RecognitionHistoryScreen extends StatefulWidget {
  const RecognitionHistoryScreen({super.key});

  @override
  State<RecognitionHistoryScreen> createState() =>
      _RecognitionHistoryScreenState();
}

class _RecognitionHistoryScreenState extends State<RecognitionHistoryScreen> {
  final _service = RecognitionHistoryService.instance;
  List<RecognitionHistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.reload();
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    await _service.deleteItem(id);
    await _load();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, vi: 'Xóa toàn bộ lịch sử?', en: 'Clear all history?')),
        content: Text(
          tr(
            context,
            vi: 'Hành động này không thể hoàn tác. Bạn có chắc muốn xóa không?',
            en: 'This action cannot be undone. Are you sure?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(context, vi: 'Hủy', en: 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(context, vi: 'Xóa', en: 'Clear')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(context, vi: 'Lịch Sử Nhận Diện', en: 'Recognition History'),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: tr(context, vi: 'Xóa tất cả', en: 'Clear all'),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr(
                          context,
                          vi: 'Chưa có lịch sử nhận diện nào.',
                          en: 'No recognition history recorded yet.',
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final hasPreview = item.previewImagePath != null &&
                          File(item.previewImagePath!).existsSync();

                      Color statusColor = Colors.grey;
                      if (item.isPoisonous == true) {
                        statusColor = Colors.red.shade700;
                      } else if (item.isPoisonous == false) {
                        statusColor = Colors.green.shade700;
                      } else if (item.status == 'failed') {
                        statusColor = Colors.red.shade700;
                      }

                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteItem(item.id),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: hasPreview
                                  ? Image.file(
                                      File(item.previewImagePath!),
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 52,
                                      height: 52,
                                      color: theme.colorScheme.surfaceVariant,
                                      child: const Icon(Icons.image_not_supported_outlined),
                                    ),
                            ),
                            title: Text(
                              item.mushroomName ?? item.prediction ?? tr(context, vi: 'Chưa rõ', en: 'Unknown'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (item.isPoisonous != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.isPoisonous == true
                                              ? tr(context, vi: 'Nấm độc', en: 'Poisonous')
                                              : tr(context, vi: 'An toàn', en: 'Safe'),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    if (item.confidence != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(item.confidence! * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.createdAt.day}/${item.createdAt.month} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => HistoryDetailDialog.show(context, item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

