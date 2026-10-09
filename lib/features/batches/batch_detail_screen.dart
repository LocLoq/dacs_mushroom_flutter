import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/storage/local_session.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';
import '../gallery/entity_gallery.dart';
import '../public_growth/public_growth_screen.dart';
import 'batch_list_screen.dart';
import 'care_tab.dart';
import 'finance_tab.dart';
import 'harvest_tab.dart';
import 'progress_tab.dart';

/// Chi tiết lô + tab (specs/S04_BATCH_DETAIL.md).
class BatchDetailScreen extends StatefulWidget {
  final int batchId;

  const BatchDetailScreen({super.key, required this.batchId});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

const _stages = ['PREPARATION', 'INCUBATION', 'FRUITING', 'HARVESTING', 'COMPLETED'];

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  final _api = FarmApi.instance;
  final _bodyKey = GlobalKey<FutureBodyState<J>>();
  final _financeTick = ValueNotifier<int>(0);
  String _tab = 'progress';
  final Set<String> _visited = {'progress'};

  @override
  void dispose() {
    _financeTick.dispose();
    super.dispose();
  }

  Future<J> _load() async =>
      (await _api.get('/cultivation-batches/${widget.batchId}')).m('data') ?? {};

  void _reloadBatch() => _bodyKey.currentState?.reload();

  /// Ghi chăm sóc/sinh trưởng/thu hoạch -> tải lại lô (và tài chính nếu đã mở).
  void _onRecordChanged({bool harvest = false}) {
    _reloadBatch();
    if (harvest && _visited.contains('finance')) _financeTick.value++;
  }

  Future<void> _edit(J d) async {
    final ok = await showFormSheet(
      context,
      title: 'Sửa lô',
      fields: batchFields(),
      initial: d,
      initialPicks: {
        'facilityId': [{'id': d.m('facility')?.i('id'), 'label': d.m('facility')?.s('name') ?? ''}],
        'mushroomId': [{'id': d.m('mushroom')?.i('id'), 'label': d.m('mushroom')?.s('commonName') ?? ''}],
      },
      isEdit: true,
      onSubmit: (b) => _api.put('/cultivation-batches/${widget.batchId}', b),
    );
    if (ok) _reloadBatch();
  }

  Future<void> _delete(J d) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa lô ${d.s('batchCode')}?',
      message: 'Các bản ghi liên quan (chăm sóc, thu hoạch, ảnh, tài chính…) có thể bị xóa cùng. Không hoàn tác.',
      ok: 'Xóa lô',
      danger: true,
    );
    if (!ok) return;
    try {
      await _api.delete('/cultivation-batches/${widget.batchId}');
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = LocalSession.canManage;
    final tabs = <String, String>{
      'progress': 'Tiến trình',
      'care': 'Chăm sóc',
      'harvest': 'Thu hoạch',
      'gallery': 'Ảnh',
      if (canManage) 'finance': 'Tài chính', // staff không thấy tab và không gọi API tài chính
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết lô'),
        actions: [IconButton(onPressed: _reloadBatch, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: FutureBody<J>(
        key: _bodyKey,
        load: _load,
        builder: (ctx, d, reload) {
          final theme = Theme.of(ctx);
          final st = d.sn('status');
          final idx = _stages.indexOf(st ?? '');
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Text(d.s('batchCode'), style: theme.textTheme.headlineSmall),
              Text('${d.m('mushroom')?.s('commonName') ?? '—'} · ${d.m('facility')?.s('name') ?? '—'}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => _edit(d),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa lô'),
                ),
                if (canManage)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => _delete(d),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Xóa lô'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => PublicGrowthScreen(initialCode: d.s('batchCode')))),
                  icon: const Icon(Icons.public_rounded, size: 18),
                  label: const Text('Trang công khai'),
                ),
              ]),
              const SizedBox(height: 14),
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Trạng thái', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    StatusChip(text: label(batchStatusLabels, st), color: statusColor(st)),
                  ]),
                  const SizedBox(height: 12),
                  if (st == 'FAILED')
                    Text('Lô này đã được ghi nhận là thất bại.', style: theme.textTheme.bodySmall)
                  else
                    // Chip giai đoạn chỉ là thông tin, không phải nút đổi trạng thái.
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (var i = 0; i < _stages.length; i++)
                        Chip(
                          label: Text(batchStatusLabels[_stages[i]]!),
                          backgroundColor: i <= idx ? theme.colorScheme.primaryContainer : null,
                          side: BorderSide(color: i == idx ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                        ),
                    ]),
                  const SizedBox(height: 8),
                  InfoRow('Ngày bắt đầu', fmtDate(d.sn('startDate'))),
                  InfoRow('Dự kiến thu hoạch', fmtDate(d.sn('expectedHarvestDate'))),
                  InfoRow('Ngày kết thúc', fmtDate(d.sn('endDate'))),
                  InfoRow('Số bịch', d.i('bagQuantity')?.toString()),
                  InfoRow('Giá thể', d.sn('substrateType')),
                  InfoRow('Nguồn giống', d.sn('spawnSource')),
                  InfoRow('Tỷ lệ lỗi', d.d('defectRate') == null ? null : '${d.d('defectRate')}%'),
                  InfoRow('Sản lượng thực tế', d.d('actualYieldKg') == null ? null : kg(d.d('actualYieldKg'))),
                  InfoRow('Ghi chú', d.sn('notes')),
                ]),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final e in tabs.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _tab == e.key,
                    onSelected: (_) => setState(() {
                      _tab = e.key;
                      _visited.add(e.key); // lazy load lần đầu mở, giữ nội dung đã tải
                    }),
                  ),
              ]),
              const SizedBox(height: 14),
              // Offstage giữ State của tab đã mở nên không tải lại khi chuyển qua lại.
              if (_visited.contains('progress'))
                Offstage(
                  offstage: _tab != 'progress',
                  child: ProgressTab(key: const ValueKey('progress'), batchId: widget.batchId, onChanged: _onRecordChanged),
                ),
              if (_visited.contains('care'))
                Offstage(
                  offstage: _tab != 'care',
                  child: CareTab(key: const ValueKey('care'), batchId: widget.batchId, onChanged: _onRecordChanged),
                ),
              if (_visited.contains('harvest'))
                Offstage(
                  offstage: _tab != 'harvest',
                  child: HarvestTab(
                      key: const ValueKey('harvest'),
                      batchId: widget.batchId,
                      onChanged: () => _onRecordChanged(harvest: true)),
                ),
              if (_visited.contains('gallery'))
                Offstage(
                  offstage: _tab != 'gallery',
                  child: EntityGallery(
                    key: const ValueKey('gallery'),
                    resource: 'cultivation-batches',
                    parentId: widget.batchId,
                    canEdit: canManage,
                    onChanged: _reloadBatch,
                  ),
                ),
              if (canManage && _visited.contains('finance'))
                Offstage(
                  offstage: _tab != 'finance',
                  child: FinanceTab(key: const ValueKey('finance'), batchId: widget.batchId, refresh: _financeTick),
                ),
            ],
          );
        },
      ),
    );
  }
}
