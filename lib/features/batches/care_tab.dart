import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/image_rules.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/soft_card.dart';

const careActionOptions = {
  'WATERING': 'Tưới nước',
  'FERTILIZING': 'Bón bổ sung',
  'CLEANING': 'Vệ sinh',
  'VENTILATION': 'Thông gió',
  'PEST_CONTROL': 'Kiểm tra sâu bệnh',
};
List<FieldDef> careFields() => const [
  FieldDef(
    'actionType',
    'Loại hành động',
    FieldType.text,
    required: true,
    maxLen: 255,
  ),
  FieldDef('notes', 'Nội dung', FieldType.multiline, required: true),
  FieldDef('recordedAt', 'Thời điểm ghi nhận', FieldType.dateTime),
];

class CareTab extends StatefulWidget {
  const CareTab({super.key, required this.batchId, required this.onChanged});
  final int batchId;
  final VoidCallback onChanged;
  @override
  State<CareTab> createState() => _CareTabState();
}

class _CareTabState extends State<CareTab> {
  final _key = GlobalKey<FutureBodyState<List<J>>>();
  Future<List<J>> _load() async => (await FarmApi.instance.get(
    '/cultivation-batches/${widget.batchId}/care-logs',
  )).l('data');
  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) =>
          CareForm(path: '/cultivation-batches/${widget.batchId}/care-logs'),
    );
    if (ok == true) {
      _key.currentState?.reload();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Ghi chăm sóc'),
        ),
      ),
      const SizedBox(height: 10),
      FutureBody<List<J>>(
        key: _key,
        load: _load,
        refreshResources: const ['care-logs'],
        refreshId: widget.batchId,
        builder: (context, items, _) => items.isEmpty
            ? const EmptyView('Chưa có nhật ký chăm sóc.')
            : Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              careActionLabel(item.s('actionType')),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(fmtDateTime(item.sn('recordedAt'))),
                            const SizedBox(height: 6),
                            Text(item.s('notes')),
                            if (item.l('images').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final image in item.l('images'))
                                      NetImage(
                                        image.sn('imageUrl'),
                                        width: 72,
                                        height: 72,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ],
  );
}

class CareForm extends StatefulWidget {
  const CareForm({super.key, required this.path, this.onCreated});
  final String path;
  final void Function(J record)? onCreated;
  @override
  State<CareForm> createState() => _CareFormState();
}

class _CareFormState extends State<CareForm> {
  final _form = GlobalKey<FormState>();
  final _custom = TextEditingController();
  final _notes = TextEditingController();
  String _action = 'WATERING';
  DateTime _at = DateTime.now();
  final List<XFile> _files = [];
  final Map<String, Uint8List> _previews = {};
  bool _busy = false;
  bool _picking = false;
  String? _error;
  @override
  void dispose() {
    _custom.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(bool camera) async {
    if (_busy || _picking) return;
    if (_files.length >= 5) {
      setState(() => _error = 'Tối đa 5 ảnh.');
      return;
    }
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final rawPicked = camera
          ? [
              await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 92,
              ),
            ].whereType<XFile>().toList()
          : await picker.pickMultiImage(imageQuality: 92);
      if (!mounted) return;
      final picked = rawPicked
          .where(
            (file) => !_files.any((existing) => existing.path == file.path),
          )
          .toList();
      final error = await validateImages([..._files, ...picked], max: 5);
      if (!mounted) return;
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      final previews = <String, Uint8List>{};
      for (final file in picked) {
        previews[file.path] = await file.readAsBytes();
      }
      if (mounted)
        setState(() {
          _files.addAll(picked);
          _previews.addAll(previews);
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Không thể chọn ảnh. Kiểm tra quyền camera/thư viện.',
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickTime() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time != null && mounted)
      setState(
        () => _at = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
  }

  Future<void> _save() async {
    if (_busy || _picking || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await FarmApi.instance.multipart(
        'POST',
        widget.path,
        fields: {
          'actionType': _action == 'CUSTOM' ? _custom.text.trim() : _action,
          'notes': _notes.text.trim(),
          'recordedAt': _at.toUtc().toIso8601String(),
        },
        files: _files,
      );
      if (!mounted) return;
      final record = response.m('data');
      if (record != null) widget.onCreated?.call(record);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ghi chăm sóc',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _action,
                decoration: const InputDecoration(labelText: 'Hành động'),
                items: [
                  for (final entry in {
                    ...careActionOptions,
                    'CUSTOM': 'Tự nhập',
                  }.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _action = value!),
              ),
              if (_action == 'CUSTOM')
                TextFormField(
                  controller: _custom,
                  enabled: !_busy,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Hành động tự nhập',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập hành động'
                      : null,
                ),
              TextFormField(
                controller: _notes,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Nội dung'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập nội dung chăm sóc'
                    : null,
              ),
              TextButton.icon(
                onPressed: _busy ? null : _pickTime,
                icon: const Icon(Icons.schedule),
                label: Text(fmtDateTime(_at.toIso8601String())),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy || _picking ? null : () => _pick(false),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _picking ? null : () => _pick(true),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                ],
              ),
              const Text(
                'Ảnh không bắt buộc. Tối đa 5 ảnh JPEG/PNG/WebP, mỗi ảnh 5 MB.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final file in _files)
                    Stack(
                      children: [
                        Image.memory(
                          _previews[file.path]!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _files.remove(file);
                                    _previews.remove(file.path);
                                  }),
                            icon: const Icon(Icons.cancel),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || _picking ? null : _save,
                child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
