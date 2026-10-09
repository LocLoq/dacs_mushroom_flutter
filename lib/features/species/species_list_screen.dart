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

/// Danh sách giống nấm (specs/S08_MUSHROOM_SPECIES.md).
class SpeciesListScreen extends StatefulWidget {
  const SpeciesListScreen({super.key});

  @override
  State<SpeciesListScreen> createState() => _SpeciesListScreenState();
}

const speciesFields = <FieldDef>[
  FieldDef('commonName', 'Tên thường gọi', FieldType.text, required: true, maxLen: 255),
  FieldDef('scientificName', 'Tên khoa học', FieldType.text, required: true, maxLen: 255),
  FieldDef('family', 'Họ', FieldType.text, required: true),
  FieldDef('genus', 'Chi', FieldType.text, required: true),
  FieldDef('edibilityStatus', 'Khả năng ăn', FieldType.choice, required: true, options: edibilityLabels),
  FieldDef('cultivationDifficulty', 'Độ khó nuôi', FieldType.choice, nullable: true, options: difficultyLabels),
  FieldDef('ecologyType', 'Kiểu sinh thái', FieldType.choice, nullable: true, options: ecologyLabels),
  FieldDef('otherNames', 'Tên gọi khác', FieldType.text, nullable: true),
  FieldDef('habitat', 'Môi trường sống', FieldType.multiline, nullable: true),
  FieldDef('fruitingSeason', 'Mùa ra quả thể', FieldType.text, nullable: true),
  FieldDef('capDescription', 'Mô tả mũ nấm', FieldType.multiline, nullable: true),
  FieldDef('gillsDescription', 'Mô tả phiến nấm', FieldType.multiline, nullable: true),
  FieldDef('stemDescription', 'Mô tả thân nấm', FieldType.multiline, nullable: true),
  FieldDef('sporePrintColor', 'Màu bào tử', FieldType.text, nullable: true),
  FieldDef('bruisingBehavior', 'Phản ứng khi dập', FieldType.text, nullable: true),
  FieldDef('toxicitySymptoms', 'Triệu chứng ngộ độc', FieldType.multiline, nullable: true),
  FieldDef('medicinalProperties', 'Dược tính', FieldType.multiline, nullable: true),
];

class _SpeciesListScreenState extends State<SpeciesListScreen> {
  final _api = FarmApi.instance;
  final _key = GlobalKey<PagedListViewState>();

  Future<void> _create() async {
    final ok = await showFormSheet(
      context,
      title: 'Thêm giống nấm',
      fields: speciesFields,
      onSubmit: (b) => _api.post('/mushroom-species', b),
    );
    if (ok) _key.currentState?.load();
  }

  Future<void> _edit(J detail) async {
    final ok = await showFormSheet(
      context,
      title: 'Sửa giống nấm',
      fields: speciesFields,
      initial: detail,
      isEdit: true,
      onSubmit: (b) => _api.put('/mushroom-species/${detail.i('id')}', b),
    );
    if (ok) _key.currentState?.load();
  }

  Future<void> _delete(J item) async {
    final ok = await confirmDialog(context,
        title: 'Xóa giống nấm?',
        message: 'Xóa "${item.s('commonName')}". Hành động không hoàn tác.',
        ok: 'Xóa',
        danger: true);
    if (!ok) return;
    try {
      await _api.delete('/mushroom-species/${item.i('id')}');
      if (mounted) toast(context, 'Đã xóa');
      _key.currentState?.load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true); // lỗi: không tự loại dòng
    }
  }

  void _openDetail(J row) {
    showDetailSheet(context, (ctx) => _SpeciesDetail(
          id: row.i('id')!,
          onEdit: (d) {
            Navigator.pop(ctx);
            _edit(d);
          },
          onDelete: (d) {
            Navigator.pop(ctx);
            _delete(d);
          },
          onGalleryChanged: () => _key.currentState?.load(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = LocalSession.canManage;
    return Scaffold(
      appBar: AppBar(title: const Text('Giống nấm')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm giống'),
            )
          : null,
      body: PagedListView(
        key: _key,
        searchHint: 'Tìm tên, tên khoa học, họ, chi…',
        emptyText: 'Chưa có giống nấm nào.',
        fetch: (p, s) async => PageData.from(
            await _api.get('/mushroom-species', query: {'page': p, 'limit': 10, 'search': s})),
        itemBuilder: (ctx, it, _) {
          // Ảnh list dùng coverImageUrl, dự phòng imageUrl cũ.
          final cover = it.sn('coverImageUrl') ?? it.sn('imageUrl');
          return SoftCard(
            padding: const EdgeInsets.all(12),
            onTap: () => _openDetail(it),
            child: Row(
              children: [
                NetImage(cover, width: 64, height: 64, zoomable: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.s('commonName'), style: Theme.of(ctx).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(it.s('scientificName'),
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        StatusChip(text: label(edibilityLabels, it.sn('edibilityStatus')), color: statusColor(it.sn('edibilityStatus'))),
                        if (it.sn('cultivationDifficulty') != null)
                          Text('Nuôi: ${label(difficultyLabels, it.sn('cultivationDifficulty'))} · ${it.i('imageCount') ?? 0} ảnh',
                              style: Theme.of(ctx).textTheme.bodySmall),
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

class _SpeciesDetail extends StatelessWidget {
  final int id;
  final void Function(J detail) onEdit;
  final void Function(J detail) onDelete;
  final VoidCallback onGalleryChanged;

  const _SpeciesDetail({
    required this.id,
    required this.onEdit,
    required this.onDelete,
    required this.onGalleryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canManage = LocalSession.canManage;
    // GET chi tiết từ server, không dùng dòng danh sách làm toàn bộ detail.
    return FutureBody<J>(
      load: () async => (await FarmApi.instance.get('/mushroom-species/$id')).m('data') ?? {},
      builder: (ctx, d, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(d.s('commonName'), style: Theme.of(ctx).textTheme.headlineSmall),
          Text(d.s('scientificName'),
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            StatusChip(text: label(edibilityLabels, d.sn('edibilityStatus')), color: statusColor(d.sn('edibilityStatus'))),
          ]),
          const SizedBox(height: 8),
          InfoRow('Họ / Chi', '${d.s('family')} / ${d.s('genus')}'),
          InfoRow('Tên gọi khác', d.sn('otherNames')),
          InfoRow('Độ khó nuôi', label(difficultyLabels, d.sn('cultivationDifficulty'))),
          InfoRow('Kiểu sinh thái', label(ecologyLabels, d.sn('ecologyType'))),
          InfoRow('Môi trường sống', d.sn('habitat')),
          InfoRow('Mùa ra quả thể', d.sn('fruitingSeason')),
          InfoRow('Mũ nấm', d.sn('capDescription')),
          InfoRow('Phiến nấm', d.sn('gillsDescription')),
          InfoRow('Thân nấm', d.sn('stemDescription')),
          InfoRow('Màu bào tử', d.sn('sporePrintColor')),
          InfoRow('Phản ứng khi dập', d.sn('bruisingBehavior')),
          InfoRow('Triệu chứng ngộ độc', d.sn('toxicitySymptoms')),
          InfoRow('Dược tính', d.sn('medicinalProperties')),
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
            resource: 'mushroom-species',
            parentId: id,
            canEdit: canManage,
            onChanged: () {
              reload();
              onGalleryChanged();
            },
          ),
        ],
      ),
    );
  }
}
