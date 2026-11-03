import 'dart:io';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/services/recognition_history_service.dart';
import '../../../core/widgets/mushroom_glyph.dart';
import '../../../core/widgets/soft_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/history_item.dart';
import 'widgets/history_detail_dialog.dart';

class RecognitionHistoryScreen extends StatefulWidget {
  /// true khi hiển thị như một tab của Home (không có nút quay lại).
  final bool embedded;

  const RecognitionHistoryScreen({super.key, this.embedded = false});

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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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

  String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} · ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(widget.embedded ? 20 : 8, 12, 12, 8),
              child: Row(
                children: [
                  if (!widget.embedded)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, vi: 'Lịch sử nhận diện', en: 'History'),
                          style: theme.textTheme.headlineMedium,
                        ),
                        if (_items.isNotEmpty)
                          Text(
                            tr(
                              context,
                              vi: '${_items.length} lượt quét gần nhất · vuốt sang trái để xoá',
                              en: '${_items.length} recent scans · swipe left to delete',
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (_items.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      tooltip: tr(context, vi: 'Xoá tất cả', en: 'Clear all'),
                      onPressed: _clearAll,
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const MushroomGlyph(size: 80),
                                const SizedBox(height: 14),
                                Text(
                                  tr(context,
                                      vi: 'Chưa có lượt nhận diện nào',
                                      en: 'No scans yet'),
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tr(
                                    context,
                                    vi: 'Các ảnh bạn đã quét sẽ được lưu ở đây để xem lại.',
                                    en: 'Photos you scan will be saved here for later.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Dismissible(
                                  key: Key(item.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.delete_rounded,
                                        color: Colors.white),
                                  ),
                                  onDismissed: (_) => _deleteItem(item.id),
                                  child: _HistoryTile(
                                    item: item,
                                    time: _fmt(item.createdAt),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final RecognitionHistoryItem item;
  final String time;

  const _HistoryTile({required this.item, required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPreview = item.previewImagePath != null &&
        File(item.previewImagePath!).existsSync();

    Color? statusColor;
    String? statusText;
    if (item.status == 'failed') {
      statusColor = AppColors.danger;
      statusText = tr(context, vi: 'Thất bại', en: 'Failed');
    } else if (item.isPoisonous == true) {
      statusColor = AppColors.danger;
      statusText = tr(context, vi: 'Nấm độc', en: 'Poisonous');
    } else if (item.isPoisonous == false) {
      statusColor = AppColors.success;
      statusText = tr(context, vi: 'An toàn', en: 'Safe');
    }

    return SoftCard(
      padding: const EdgeInsets.all(12),
      onTap: () => HistoryDetailDialog.show(context, item),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: hasPreview
                ? Image.file(
                    File(item.previewImagePath!),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.image_not_supported_outlined,
                        color: theme.colorScheme.primary),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.mushroomName ??
                      item.prediction ??
                      tr(context, vi: 'Chưa rõ', en: 'Unknown'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (statusColor != null && statusText != null)
                      StatusChip(text: statusText, color: statusColor),
                    if (item.confidence != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${(item.confidence! * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(time, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
