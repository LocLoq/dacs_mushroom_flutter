import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/farm_api.dart';
import '../../core/utils/image_rules.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/net_image.dart';

/// Gallery dùng chung cho cơ sở / giống nấm / lô (specs/S19_ENTITY_GALLERY.md).
/// [resource]: production-facilities | mushroom-species | cultivation-batches.
/// Chỉ gọi API khi widget này được mở (không gọi cho từng dòng danh sách).
class EntityGallery extends StatefulWidget {
  final String resource;
  final int parentId;
  final bool canEdit; // manager/admin
  final VoidCallback? onChanged; // để màn cha tải lại cover/count

  const EntityGallery({
    super.key,
    required this.resource,
    required this.parentId,
    required this.canEdit,
    this.onChanged,
  });

  @override
  State<EntityGallery> createState() => _EntityGalleryState();
}

class _EntityGalleryState extends State<EntityGallery> {
  final _api = FarmApi.instance;
  PageData _data = PageData.empty;
  int _page = 1;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String get _base => '/${widget.resource}/${widget.parentId}/images';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.get(_base, query: {'page': _page, 'limit': 10});
      if (!mounted) return;
      setState(() {
        _data = PageData.from(r);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _afterMutation() async {
    _page = 1; // reload gallery trang 1, rồi báo màn cha tải lại cover/count
    await _load();
    widget.onChanged?.call();
  }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) toast(context, okMsg);
      await _afterMutation();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final files = await ImagePicker().pickMultiImage(limit: 5, imageQuality: 92);
    if (files.isEmpty || !mounted) return;
    final err = await validateImages(files, min: 1, max: 5);
    if (err != null) {
      if (mounted) toast(context, err, error: true);
      return;
    }
    if (!mounted) return;
    final caption = await _askCaption(title: 'Chú thích chung (tuỳ chọn)', initial: '');
    if (caption == null) return;
    await _run(() async {
      await _api.multipart('POST', _base,
          files: files, fields: caption.isEmpty ? {} : {'caption': caption});
    }, 'Đã tải ${files.length} ảnh');
  }

  Future<String?> _askCaption({required String title, required String initial}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Chú thích (tối đa 500 ký tự)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
  }

  Future<void> _editCaption(J img) async {
    final c = await _askCaption(title: 'Chú thích ảnh', initial: img.s('caption'));
    if (c == null) return;
    // Xoá chú thích phải gửi null.
    await _run(() => _api.patch('$_base/${img.i('id')}', {'caption': c.isEmpty ? null : c}), 'Đã cập nhật chú thích');
  }

  Future<void> _setCover(J img) =>
      _run(() => _api.patch('$_base/${img.i('id')}', {'isCover': true}), 'Đã đặt ảnh bìa');

  Future<void> _delete(J img) async {
    final ok = await confirmDialog(context,
        title: 'Xóa ảnh?', message: 'Ảnh sẽ bị xóa khỏi thư viện.', ok: 'Xóa', danger: true);
    if (!ok) return;
    await _run(() => _api.delete('$_base/${img.i('id')}'), 'Đã xóa ảnh');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Thư viện ảnh (${_data.totalItems})', style: theme.textTheme.titleMedium)),
            if (widget.canEdit)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _busy ? null : _upload,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Tải ảnh'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading && _data.items.isEmpty)
          const SizedBox(height: 120, child: LoadingView())
        else if (_error != null && _data.items.isEmpty)
          SizedBox(height: 160, child: ErrorView(message: _error!, onRetry: _load))
        else if (_data.items.isEmpty)
          Container(
            height: 110,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Chưa có ảnh nào'),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: _data.items.length,
            itemBuilder: (c, i) {
              final img = _data.items[i];
              final cover = img['isCover'] == true;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cover ? AppColors.leaf : theme.colorScheme.outlineVariant, width: cover ? 2 : 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            NetImage(img.sn('imageUrl'), radius: 0),
                            if (cover)
                              Positioned(
                                left: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.leaf, borderRadius: BorderRadius.circular(10)),
                                  child: const Text('Ảnh bìa',
                                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            if (widget.canEdit)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: PopupMenuButton<String>(
                                  enabled: !_busy,
                                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, shadows: [Shadow(blurRadius: 6)]),
                                  onSelected: (v) {
                                    if (v == 'cap') _editCaption(img);
                                    if (v == 'cover') _setCover(img);
                                    if (v == 'del') _delete(img);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'cap', child: Text('Sửa chú thích')),
                                    if (!cover) const PopupMenuItem(value: 'cover', child: Text('Đặt làm ảnh bìa')),
                                    const PopupMenuItem(value: 'del', child: Text('Xóa ảnh')),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          img.sn('caption') ?? img.s('originalName'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (_data.totalPages > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: (_loading || _page <= 1) ? null : () { _page--; _load(); },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('Trang $_page/${_data.totalPages}', style: theme.textTheme.bodySmall),
              IconButton(
                onPressed: (_loading || _page >= _data.totalPages) ? null : () { _page++; _load(); },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
      ],
    );
  }
}
