import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/image_rules.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/soft_card.dart';

/// Nhật ký sinh trưởng + ảnh (specs/S07_GROWTH_PROGRESS.md).
/// Ghi được KHÔNG ảnh hoặc tối đa 5 ảnh mới; PATCH thêm ảnh, không xóa ảnh cũ.
class ProgressTab extends StatefulWidget {
  final int batchId;
  final VoidCallback onChanged;

  const ProgressTab({super.key, required this.batchId, required this.onChanged});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  final _key = GlobalKey<FutureBodyState<List<J>>>();

  String get _base => '/cultivation-batches/${widget.batchId}/growth-progress';

  Future<List<J>> _load() async => (await FarmApi.instance.get(_base)).l('data');

  Future<void> _openForm({J? record}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => GrowthForm(path: record == null ? _base : '$_base/${record.i('id')}', record: record),
    );
    if (ok == true) {
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
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ghi sinh trưởng'),
          ),
        ),
        const SizedBox(height: 10),
        FutureBody<List<J>>(
          key: _key,
          load: _load,
          builder: (ctx, items, _) {
            if (items.isEmpty) return const SizedBox(height: 140, child: EmptyView('Chưa có nhật ký sinh trưởng.'));
            return Column(children: [
              for (final r in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(r.s('stage'), style: theme.textTheme.titleSmall)),
                        Text(fmtDateTime(r.sn('recordedAt')), style: theme.textTheme.bodySmall),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openForm(record: r),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ]),
                      Text(r.s('notes')),
                      if (r.l('images').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 72,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final img in r.l('images'))
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: NetImage(img.sn('imageUrl'), width: 72, height: 72),
                                ),
                            ],
                          ),
                        ),
                      ],
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

/// Form tạo/sửa bản ghi sinh trưởng, có chọn ảnh. Dùng lại khi ghi từ công việc (S17).
class GrowthForm extends StatefulWidget {
  final String path;
  final J? record;

  /// Nhận record server trả về (để chọn làm minh chứng).
  final void Function(J created)? onCreated;

  const GrowthForm({super.key, required this.path, this.record, this.onCreated});

  @override
  State<GrowthForm> createState() => _GrowthFormState();
}

class _GrowthFormState extends State<GrowthForm> {
  late final _stage = TextEditingController(text: widget.record?.s('stage') ?? '');
  late final _notes = TextEditingController(text: widget.record?.s('notes') ?? '');
  late DateTime _at = parseIso(widget.record?.sn('recordedAt')) ?? DateTime.now();
  final List<XFile> _files = [];
  final Map<String, Uint8List> _bytes = {};
  bool _busy = false;
  String? _error;

  bool get _edit => widget.record != null;

  @override
  void dispose() {
    _stage.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final room = 5 - _files.length;
    if (room <= 0) {
      setState(() => _error = 'Tối đa 5 ảnh mới mỗi lần.');
      return;
    }
    final picked = await ImagePicker().pickMultiImage(limit: room < 2 ? 2 : room, imageQuality: 92);
    if (picked.isEmpty) return;
    final all = [..._files, ...picked];
    final err = await validateImages(all, max: 5); // chặn >5 ảnh/sai MIME/>5 MiB trước request
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    for (final f in picked) {
      _bytes[f.path] = await f.readAsBytes();
    }
    setState(() {
      _files
        ..clear()
        ..addAll(all);
      _error = null;
    });
  }

  Future<void> _pickTime() async {
    final d = await showDatePicker(context: context, initialDate: _at, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    setState(() => _at = DateTime(d.year, d.month, d.day, t?.hour ?? _at.hour, t?.minute ?? _at.minute));
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_stage.text.trim().isEmpty || _notes.text.trim().isEmpty) {
      setState(() => _error = 'Giai đoạn và ghi chú là bắt buộc.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await FarmApi.instance.multipart(
        _edit ? 'PATCH' : 'POST',
        widget.path,
        fields: {
          'stage': _stage.text.trim(),
          'notes': _notes.text.trim(),
          'recordedAt': _at.toUtc().toIso8601String(),
        },
        files: _files, // 0 ảnh thì không gửi field file
      );
      final created = r.m('data');
      if (created != null) widget.onCreated?.call(created);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = widget.record?.l('images') ?? [];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(children: [
              Expanded(child: Text(_edit ? 'Sửa nhật ký sinh trưởng' : 'Ghi sinh trưởng', style: theme.textTheme.titleLarge)),
              IconButton(onPressed: _busy ? null : () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(14)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                TextField(controller: _stage, decoration: const InputDecoration(labelText: 'Giai đoạn *', helperText: 'Chuỗi tự do, ví dụ: Ra quả thể')),
                const SizedBox(height: 14),
                TextField(controller: _notes, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Ghi chú *')),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Thời điểm ghi nhận', suffixIcon: Icon(Icons.event_rounded)),
                    child: Text(fmtDateTime(_at.toIso8601String())),
                  ),
                ),
                if (existing.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Ảnh đã lưu (chỉ xem, không bị thay thế)', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final img in existing) NetImage(img.sn('imageUrl'), width: 64, height: 64),
                  ]),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('Ảnh mới (${_files.length}/5)', style: theme.textTheme.titleSmall)),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('Chọn ảnh'),
                  ),
                ]),
                const SizedBox(height: 8),
                // Gỡ ở đây chỉ bỏ ảnh MỚI chưa gửi, không xóa ảnh đã lưu trên server.
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final f in _files)
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _bytes[f.path] == null
                            ? const SizedBox(width: 64, height: 64)
                            : Image.memory(_bytes[f.path]!, width: 64, height: 64, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _files.remove(f);
                            _bytes.remove(f.path);
                          }),
                          child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                        ),
                      ),
                    ]),
                ]),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Hủy'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Lưu'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
