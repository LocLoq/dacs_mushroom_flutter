import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/storage/local_session.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';
import '../gallery/entity_gallery.dart';

/// Cơ sở sản xuất (specs/S09_FACILITIES.md).
class FacilityListScreen extends StatefulWidget {
  const FacilityListScreen({super.key});

  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

/// Nguồn chọn giống nấm dùng chung (picker nhiều giống, picker lô...).
PickerSource speciesPicker() => PickerSource(
      title: 'Chọn giống nấm',
      fetch: (p, s) async => PageData.from(
          await FarmApi.instance.get('/mushroom-species', query: {'page': p, 'limit': 10, 'search': s})),
      label: (i) => i.s('commonName'),
      subtitle: (i) => i.s('scientificName'),
    );

PickerSource facilityPicker() => PickerSource(
      title: 'Chọn cơ sở',
      fetch: (p, s) async => PageData.from(
          await FarmApi.instance.get('/production-facilities', query: {'page': p, 'limit': 10, 'search': s})),
      label: (i) => i.s('name'),
      subtitle: (i) => i.s('province'),
    );

List<FieldDef> _facilityFields() => [
      const FieldDef('name', 'Tên cơ sở', FieldType.text, required: true, maxLen: 255),
      const FieldDef('address', 'Địa chỉ', FieldType.text, required: true),
      const FieldDef('province', 'Tỉnh/Thành', FieldType.text, nullable: true),
      const FieldDef('facilityType', 'Loại hình', FieldType.choice, required: true, options: facilityTypeLabels),
      const FieldDef('status', 'Trạng thái', FieldType.choice, required: true, options: facilityStatusLabels),
      const FieldDef('taxCode', 'Mã số thuế', FieldType.text, nullable: true),
      const FieldDef('contactPhone', 'Điện thoại liên hệ', FieldType.text, nullable: true),
      const FieldDef('contactEmail', 'Email liên hệ', FieldType.text, nullable: true),
      const FieldDef('capacityTonsPerYear', 'Công suất (tấn/năm)', FieldType.number, nullable: true, min: 0),
      const FieldDef('totalAreaSqm', 'Diện tích (m²)', FieldType.number, nullable: true, min: 0),
      const FieldDef('certifications', 'Chứng nhận', FieldType.text, nullable: true),
      FieldDef('mushrooms', 'Giống nấm nuôi', FieldType.pickMany, picker: speciesPicker()),
    ];

class _FacilityListScreenState extends State<FacilityListScreen> {
  final _api = FarmApi.instance;
  final _key = GlobalKey<PagedListViewState>();

  Future<void> _create() async {
    final ok = await showFormSheet(
      context,
      title: 'Thêm cơ sở',
      fields: _facilityFields(),
      initial: const {'status': 'ACTIVE'},
      onSubmit: (b) => _api.post('/production-facilities', b),
    );
    if (ok) _key.currentState?.load();
  }

  Future<void> _edit(J d) async {
    final picks = d.l('mushrooms').map((m) => <String, dynamic>{'id': m.i('id'), 'label': m.s('commonName')}).toList();
    final ok = await showFormSheet(
      context,
      title: 'Sửa cơ sở',
      fields: _facilityFields(),
      initial: d,
      initialPicks: {'mushrooms': picks},
      isEdit: true,
      onSubmit: (b) => _api.put('/production-facilities/${d.i('id')}', b),
    );
    if (ok) _key.currentState?.load();
  }

  Future<void> _delete(J d) async {
    final ok = await confirmDialog(context,
        title: 'Xóa cơ sở?', message: 'Xóa "${d.s('name')}". Hành động không hoàn tác.', ok: 'Xóa', danger: true);
    if (!ok) return;
    try {
      await _api.delete('/production-facilities/${d.i('id')}');
      if (mounted) toast(context, 'Đã xóa');
      _key.currentState?.load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = LocalSession.canManage;
    return Scaffold(
      appBar: AppBar(title: const Text('Cơ sở sản xuất')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('Thêm cơ sở'))
          : null,
      body: PagedListView(
        key: _key,
        searchHint: 'Tìm tên, địa chỉ, tỉnh, mã thuế…',
        emptyText: 'Chưa có cơ sở nào.',
        fetch: (p, s) async => PageData.from(
            await _api.get('/production-facilities', query: {'page': p, 'limit': 10, 'search': s})),
        itemBuilder: (ctx, it, _) => SoftCard(
          padding: const EdgeInsets.all(12),
          onTap: () => showDetailSheet(
            context,
            (sheet) => _FacilityDetail(
              id: it.i('id')!,
              onEdit: (d) { Navigator.pop(sheet); _edit(d); },
              onDelete: (d) { Navigator.pop(sheet); _delete(d); },
              onGalleryChanged: () => _key.currentState?.load(),
            ),
          ),
          child: Row(
            children: [
              NetImage(it.sn('coverImageUrl'), width: 64, height: 64, zoomable: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.s('name'), style: Theme.of(ctx).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${it.sn('province') ?? '—'} · ${label(facilityTypeLabels, it.sn('facilityType'))} · ${it.i('imageCount') ?? 0} ảnh',
                        style: Theme.of(ctx).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    StatusChip(text: label(facilityStatusLabels, it.sn('status')), color: statusColor(it.sn('status'))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacilityDetail extends StatelessWidget {
  final int id;
  final void Function(J) onEdit;
  final void Function(J) onDelete;
  final VoidCallback onGalleryChanged;

  const _FacilityDetail({required this.id, required this.onEdit, required this.onDelete, required this.onGalleryChanged});

  @override
  Widget build(BuildContext context) {
    final canManage = LocalSession.canManage;
    return FutureBody<J>(
      load: () async => (await FarmApi.instance.get('/production-facilities/$id')).m('data') ?? {},
      builder: (ctx, d, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(d.s('name'), style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 8),
          StatusChip(text: label(facilityStatusLabels, d.sn('status')), color: statusColor(d.sn('status'))),
          const SizedBox(height: 8),
          InfoRow('Loại hình', label(facilityTypeLabels, d.sn('facilityType'))),
          InfoRow('Địa chỉ', d.sn('address')),
          InfoRow('Tỉnh/Thành', d.sn('province')),
          InfoRow('Mã số thuế', d.sn('taxCode')),
          InfoRow('Điện thoại', d.sn('contactPhone')),
          InfoRow('Email', d.sn('contactEmail')),
          InfoRow('Công suất', d.d('capacityTonsPerYear') == null ? null : '${d.d('capacityTonsPerYear')} tấn/năm'),
          InfoRow('Diện tích', d.d('totalAreaSqm') == null ? null : '${d.d('totalAreaSqm')} m²'),
          InfoRow('Chứng nhận', d.sn('certifications')),
          const SizedBox(height: 8),
          Text('Giống nấm liên kết', style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 6),
          d.l('mushrooms').isEmpty
              ? Text('Chưa liên kết giống nào.', style: Theme.of(ctx).textTheme.bodySmall)
              : Wrap(spacing: 6, runSpacing: 4, children: [for (final m in d.l('mushrooms')) Chip(label: Text(m.s('commonName')))]),
          if (canManage) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => onEdit(d), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Sửa'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => onDelete(d), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('Xóa'))),
            ]),
          ],
          const SizedBox(height: 20),
          EntityGallery(
            resource: 'production-facilities',
            parentId: id,
            canEdit: canManage,
            onChanged: () { reload(); onGalleryChanged(); },
          ),
        ],
      ),
    );
  }
}
