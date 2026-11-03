import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/soft_card.dart';
import '../batches/care_tab.dart';
import '../batches/harvest_tab.dart';
import '../batches/progress_tab.dart';
import 'task_list_screen.dart';

/// Chọn và ghi minh chứng cho công việc (specs/S17 §3). Chỉ người nhận việc mở được.
class EvidenceSheet extends StatefulWidget {
  final J task;

  const EvidenceSheet({super.key, required this.task});

  @override
  State<EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends State<EvidenceSheet> {
  final _api = FarmApi.instance;
  final _listKey = GlobalKey<PagedListViewState>();
  final _notes = TextEditingController();
  String? _type; // null = tất cả
  // Giữ lựa chọn qua trang/bộ lọc, khoá "TYPE:recordId" nên không trùng cặp.
  final Map<String, J> _sel = {};
  bool _busy = false;
  String? _error;

  String get _taskPath => '/dashboard/tasks/${widget.task.s('id')}';

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String _k(String type, Object? id) => '$type:$id';

  /// Task chưa gắn lô thì phải chọn lô cho hành động ghi mới (không gắn lại batchId của task).
  Future<int?> _ensureBatch() async {
    final fixed = widget.task.i('batchId');
    if (fixed != null) return fixed;
    final r = await pickOneFrom(context, batchPicker());
    if (r == null || r.isEmpty) return null;
    return r.first['id'] as int?;
  }

  void _autoSelect(String type, J? created) {
    final id = created?.i('id'); // dùng record server trả về, không đoán từ thứ tự list
    if (id == null) return;
    setState(() => _sel[_k(type, id)] = {'type': type, 'recordId': id, 'record': created});
    _listKey.currentState?.load();
  }

  Future<void> _recordCare() async {
    final bid = await _ensureBatch();
    if (bid == null || !mounted) return;
    J? created;
    await showFormSheet(
      context,
      title: 'Ghi chăm sóc',
      fields: careFields(),
      initial: {'recordedAt': DateTime.now()},
      onSubmit: (b) async => created = (await _api.post('/cultivation-batches/$bid/care-logs', b)).m('data'),
    );
    _autoSelect('CARE_LOG', created);
  }

  Future<void> _recordHarvest() async {
    final bid = await _ensureBatch();
    if (bid == null || !mounted) return;
    J? created;
    await showFormSheet(
      context,
      title: 'Ghi thu hoạch',
      fields: harvestFields(),
      initial: {'harvestedAt': DateTime.now(), 'finalizeBatch': false},
      onSubmit: (b) async => created = (await _api.post('/cultivation-batches/$bid/harvests', b)).m('data'),
    );
    _autoSelect('HARVEST', created);
  }

  Future<void> _recordGrowth() async {
    final bid = await _ensureBatch();
    if (bid == null || !mounted) return;
    J? created;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => GrowthForm(path: '/cultivation-batches/$bid/growth-progress', onCreated: (r) => created = r),
    );
    _autoSelect('GROWTH_PROGRESS', created);
  }

  Future<void> _submit() async {
    if (_busy) return; // chống nhấn đôi
    final notes = _notes.text.trim();
    if (_sel.isEmpty) return setState(() => _error = 'Chọn ít nhất 1 minh chứng.');
    if (_sel.length > 20) return setState(() => _error = 'Tối đa 20 minh chứng.');
    if (notes.length > 10000) return setState(() => _error = 'Ghi chú tối đa 10.000 ký tự.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Chỉ gửi type + recordId, không gửi record/snapshot/ảnh.
      await _api.post('$_taskPath/submissions', {
        'evidence': [for (final c in _sel.values) {'type': c['type'], 'recordId': c['recordId']}],
        if (notes.isNotEmpty) 'notes': notes,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        toast(context, 'Trạng thái công việc đã thay đổi. Đã tải lại.', error: true);
        Navigator.pop(context, true); // màn cha tải lại, không tự gửi lại
      } else {
        setState(() => _error = e.message); // giữ lựa chọn
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _summary(String type, J r) {
    switch (type) {
      case 'CARE_LOG':
        return '${careActionLabel(r.s('actionType'))}: ${r.s('notes')}';
      case 'GROWTH_PROGRESS':
        return '${r.s('stage')}: ${r.s('notes')}';
      case 'HARVEST':
        return '${kg(r.d('totalYieldKg'))}${r.sn('qualityGrade') == null ? '' : ' · ${r.s('qualityGrade')}'}';
    }
    return '';
  }

  String? _time(String type, J r) =>
      r.sn('recordedAt') ?? r.sn('harvestedAt') ?? r.sn('createdAt');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = <String?, String>{null: 'Tất cả', ...evidenceTypeLabels};
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(children: [
              Expanded(child: Text('Gửi minh chứng', style: theme.textTheme.titleLarge)),
              IconButton(onPressed: _busy ? null : () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              ActionChip(avatar: const Icon(Icons.water_drop_outlined, size: 16), label: const Text('Ghi chăm sóc'), onPressed: _recordCare),
              ActionChip(avatar: const Icon(Icons.eco_outlined, size: 16), label: const Text('Ghi sinh trưởng'), onPressed: _recordGrowth),
              ActionChip(avatar: const Icon(Icons.scale_outlined, size: 16), label: const Text('Ghi thu hoạch'), onPressed: _recordHarvest),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final e in filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(e.value), selected: _type == e.key, onSelected: (_) => setState(() => _type = e.key)),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: PagedListView(
              key: _listKey,
              deps: [_type],
              emptyText: 'Chưa có hành động nào của bạn để chọn. Dùng các nút ghi ở trên.',
              fetch: (p, s) async => PageData.from(await _api.get('$_taskPath/evidence-candidates',
                  query: {'page': p, 'limit': 10, 'type': _type})),
              itemBuilder: (ctx, c, _) {
                final type = c.s('type');
                final r = c.m('record') ?? {};
                final key = _k(type, c.i('recordId'));
                final on = _sel.containsKey(key);
                return SoftCard(
                  color: on ? theme.colorScheme.primaryContainer : null,
                  padding: const EdgeInsets.all(12),
                  onTap: () => setState(() {
                    if (on) {
                      _sel.remove(key);
                    } else if (_sel.length < 20) {
                      _sel[key] = c;
                    } else {
                      _error = 'Tối đa 20 minh chứng.';
                    }
                  }),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: on ? theme.colorScheme.primary : null),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label(evidenceTypeLabels, type), style: theme.textTheme.labelMedium),
                        Text(_summary(type, r), maxLines: 3, overflow: TextOverflow.ellipsis),
                        Text('${fmtDateTime(_time(type, r))}${r.i('batchId') == null ? '' : ' · Lô #${r.i('batchId')}'}',
                            style: theme.textTheme.bodySmall),
                        if (r.l('images').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, children: [for (final i in r.l('images')) NetImage(i.sn('imageUrl'), width: 44, height: 44, zoomable: false)]),
                        ],
                      ]),
                    ),
                  ]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text('Gửi minh chứng (${_sel.length}/20)'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
