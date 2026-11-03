import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/soft_card.dart';

/// Nhật ký chăm sóc (specs/S05_CARE_LOGS.md). Không có sửa/xóa.
List<FieldDef> careFields() => const [
      FieldDef('actionType', 'Loại hành động', FieldType.text, required: true, maxLen: 255, helper: 'Chuỗi tự do, ví dụ: Tưới nước'),
      FieldDef('notes', 'Nội dung', FieldType.multiline, required: true),
      FieldDef('recordedAt', 'Thời điểm ghi nhận', FieldType.dateTime),
    ];

class CareTab extends StatefulWidget {
  final int batchId;
  final VoidCallback onChanged;

  const CareTab({super.key, required this.batchId, required this.onChanged});

  @override
  State<CareTab> createState() => _CareTabState();
}

class _CareTabState extends State<CareTab> {
  final _key = GlobalKey<FutureBodyState<List<J>>>();

  Future<List<J>> _load() async =>
      (await FarmApi.instance.get('/cultivation-batches/${widget.batchId}/care-logs')).l('data');

  Future<void> _add() async {
    final ok = await showFormSheet(
      context,
      title: 'Ghi chăm sóc',
      fields: careFields(),
      initial: {'recordedAt': DateTime.now()},
      onSubmit: (b) => FarmApi.instance.post('/cultivation-batches/${widget.batchId}/care-logs', b),
    );
    if (ok) {
      _key.currentState?.reload();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ghi chăm sóc'),
          ),
        ),
        const SizedBox(height: 10),
        FutureBody<List<J>>(
          key: _key,
          load: _load,
          builder: (ctx, items, _) {
            if (items.isEmpty) return const SizedBox(height: 140, child: EmptyView('Chưa có nhật ký chăm sóc.'));
            return Column(children: [
              for (final c in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.water_drop_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(careActionLabel(c.s('actionType')), style: theme.textTheme.titleSmall)),
                        Text(fmtDateTime(c.sn('recordedAt')), style: theme.textTheme.bodySmall),
                      ]),
                      const SizedBox(height: 6),
                      Text(c.s('notes'), style: theme.textTheme.bodyMedium),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}
