import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/soft_card.dart';

/// Thu hoạch (specs/S06_HARVESTS.md). Sản lượng ≥ 0 (cho phép 0), không sửa/xóa.
List<FieldDef> harvestFields() => const [
      FieldDef('totalYieldKg', 'Sản lượng (kg)', FieldType.number, required: true, min: 0),
      FieldDef('qualityGrade', 'Chất lượng', FieldType.text, helper: 'Chuỗi tự do, ví dụ: Loại A'),
      FieldDef('harvestedAt', 'Thời điểm thu hoạch', FieldType.dateTime),
      FieldDef('notes', 'Ghi chú', FieldType.multiline),
      FieldDef('finalizeBatch', 'Hoàn thành lô sau lần thu hoạch này', FieldType.check,
          helper: 'Server sẽ chuyển lô sang Hoàn thành và ghi ngày kết thúc.'),
    ];

class HarvestTab extends StatefulWidget {
  final int batchId;
  final VoidCallback onChanged;

  const HarvestTab({super.key, required this.batchId, required this.onChanged});

  @override
  State<HarvestTab> createState() => _HarvestTabState();
}

class _HarvestTabState extends State<HarvestTab> {
  final _key = GlobalKey<FutureBodyState<List<J>>>();

  Future<List<J>> _load() async =>
      (await FarmApi.instance.get('/cultivation-batches/${widget.batchId}/harvests')).l('data');

  Future<void> _add() async {
    final ok = await showFormSheet(
      context,
      title: 'Ghi thu hoạch',
      fields: harvestFields(),
      initial: {'harvestedAt': DateTime.now(), 'finalizeBatch': false},
      onSubmit: (b) async {
        if (b['finalizeBatch'] == true) {
          final yes = await confirmDialog(context,
              title: 'Hoàn thành lô?',
              message: 'Lô sẽ chuyển sang Hoàn thành sau khi ghi lần thu hoạch này.');
          if (!yes) throw const ApiException(0, 'Bạn chưa xác nhận hoàn thành lô.');
        }
        await FarmApi.instance.post('/cultivation-batches/${widget.batchId}/harvests', b);
      },
    );
    if (ok) {
      _key.currentState?.reload();
      widget.onChanged(); // tải lại lô (trạng thái do server quyết định) và tài chính nếu đã mở
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
            label: const Text('Ghi thu hoạch'),
          ),
        ),
        const SizedBox(height: 10),
        FutureBody<List<J>>(
          key: _key,
          load: _load,
          builder: (ctx, items, _) {
            if (items.isEmpty) return const SizedBox(height: 140, child: EmptyView('Chưa có lần thu hoạch nào.'));
            // Tổng cộng toàn bộ mảng server trả về — chỉ là thông tin thu hoạch của lô, không phải doanh thu.
            final total = items.fold<double>(0, (a, e) => a + (e.d('totalYieldKg') ?? 0));
            return Column(children: [
              SoftCard(
                color: theme.colorScheme.primaryContainer,
                child: Row(children: [
                  const Icon(Icons.scale_rounded),
                  const SizedBox(width: 10),
                  Text('Tổng thu hoạch', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Text(kg(total), style: theme.textTheme.titleMedium),
                ]),
              ),
              const SizedBox(height: 10),
              for (final h in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(kg(h.d('totalYieldKg')), style: theme.textTheme.titleSmall)),
                        Text(fmtDateTime(h.sn('harvestedAt')), style: theme.textTheme.bodySmall),
                      ]),
                      if (h.sn('qualityGrade') != null) Text('Chất lượng: ${h.s('qualityGrade')}', style: theme.textTheme.bodySmall),
                      if (h.sn('notes') != null) ...[const SizedBox(height: 4), Text(h.s('notes'))],
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
