import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/storage/local_session.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';
import '../facilities/facility_list_screen.dart';
import 'batch_detail_screen.dart';

/// Danh sách và tạo lô (specs/S03_BATCH_LIST.md).
class BatchListScreen extends StatefulWidget {
  /// Từ chip trạng thái ở Tổng quan.
  final String? initialStatus;

  const BatchListScreen({super.key, this.initialStatus});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

/// Form dùng chung tạo/sửa lô.
List<FieldDef> batchFields() => [
      const FieldDef('batchCode', 'Mã lô', FieldType.text, required: true, maxLen: 191),
      FieldDef('facilityId', 'Cơ sở', FieldType.pickOne, required: true, picker: facilityPicker()),
      FieldDef('mushroomId', 'Giống nấm', FieldType.pickOne, required: true, picker: speciesPicker()),
      const FieldDef('status', 'Trạng thái', FieldType.choice, required: true, options: batchStatusLabels),
      const FieldDef('startDate', 'Ngày bắt đầu', FieldType.date, required: true),
      const FieldDef('expectedHarvestDate', 'Dự kiến thu hoạch', FieldType.date, nullable: true),
      const FieldDef('endDate', 'Ngày kết thúc', FieldType.date, nullable: true),
      const FieldDef('substrateType', 'Loại giá thể', FieldType.text, nullable: true),
      const FieldDef('spawnSource', 'Nguồn giống', FieldType.text, nullable: true),
      const FieldDef('bagQuantity', 'Số bịch', FieldType.integer, nullable: true, min: 0),
      const FieldDef('defectRate', 'Tỷ lệ lỗi (%)', FieldType.number, nullable: true, min: 0, max: 100),
      const FieldDef('notes', 'Ghi chú', FieldType.multiline, nullable: true),
    ];

class _BatchListScreenState extends State<BatchListScreen> {
  final _api = FarmApi.instance;
  final _key = GlobalKey<PagedListViewState>();
  String? _status;
  J? _facility; // {id,label}
  J? _species;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  Future<void> _create() async {
    final ok = await showFormSheet(
      context,
      title: 'Tạo lô nuôi',
      fields: batchFields(),
      initial: {'status': 'PREPARATION', 'startDate': DateTime.now()},
      onSubmit: (b) => _api.post('/cultivation-batches', b),
    );
    if (ok) _key.currentState?.load(); // lỗi thì giữ form, không dựng dòng tạm
  }

  Future<void> _pick(PickerSource src, bool facility) async {
    final res = await showModalBottomSheet<List<J>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _SinglePick(source: src),
    );
    if (res == null) return;
    setState(() {
      final v = res.isEmpty ? null : res.first;
      facility ? _facility = v : _species = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManage = LocalSession.canManage;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lô nuôi trồng')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('Tạo lô'))
          : null,
      body: PagedListView(
        key: _key,
        searchHint: 'Tìm theo mã lô',
        emptyText: 'Chưa có lô nào khớp bộ lọc.',
        deps: [_status, _facility?['id'], _species?['id']],
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: const Text('Tất cả'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
                  ),
                  for (final e in batchStatusLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _status == e.key,
                        onSelected: (_) => setState(() => _status = e.key),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                ActionChip(
                  avatar: const Icon(Icons.factory_rounded, size: 16),
                  label: Text(_facility == null ? 'Cơ sở: tất cả' : _facility!.s('label')),
                  onPressed: () => _pick(facilityPicker(), true),
                ),
                ActionChip(
                  avatar: const Icon(Icons.spa_rounded, size: 16),
                  label: Text(_species == null ? 'Giống: tất cả' : _species!.s('label')),
                  onPressed: () => _pick(speciesPicker(), false),
                ),
              ]),
              Text('', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        fetch: (p, s) async => PageData.from(await _api.get('/cultivation-batches', query: {
          'page': p,
          'limit': 10,
          'search': s,
          'status': _status,
          'facilityId': _facility?['id'],
          'mushroomId': _species?['id'],
        })),
        itemBuilder: (ctx, b, reload) {
          final st = b.sn('status');
          return SoftCard(
            padding: const EdgeInsets.all(12),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batchId: b.i('id')!)));
              reload();
            },
            child: Row(
              children: [
                NetImage(b.sn('coverImageUrl'), width: 64, height: 64, zoomable: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.s('batchCode'), style: theme.textTheme.titleSmall),
                      Text('${b.m('mushroom')?.s('commonName') ?? '—'} · ${b.m('facility')?.s('name') ?? '—'}',
                          style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        StatusChip(text: label(batchStatusLabels, st), color: statusColor(st)),
                        Text('${fmtDate(b.sn('startDate'))} · ${b.i('imageCount') ?? 0} ảnh', style: theme.textTheme.bodySmall),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SinglePick extends StatelessWidget {
  final PickerSource source;

  const _SinglePick({required this.source});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(children: [
              Expanded(child: Text(source.title, style: Theme.of(context).textTheme.titleLarge)),
              TextButton(onPressed: () => Navigator.pop(context, <J>[]), child: const Text('Bỏ lọc')),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Expanded(
            child: PagedListView(
              searchHint: 'Tìm kiếm',
              fetch: source.fetch,
              itemBuilder: (ctx, item, _) => SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => Navigator.pop(context, [<String, dynamic>{'id': item['id'], 'label': source.label(item)}]),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(source.label(item), style: Theme.of(ctx).textTheme.titleSmall),
                      if (source.subtitle != null) Text(source.subtitle!(item), style: Theme.of(ctx).textTheme.bodySmall),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
