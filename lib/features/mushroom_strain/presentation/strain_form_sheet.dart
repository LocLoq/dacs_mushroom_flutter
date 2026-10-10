import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/strain_model.dart';

class StrainFormSheet extends StatefulWidget {
  const StrainFormSheet({super.key, this.existing, required this.onSave});
  final StrainModel? existing;
  final Future<void> Function(StrainModel) onSave;
  @override
  State<StrainFormSheet> createState() => _StrainFormSheetState();
}

class _StrainFormSheetState extends State<StrainFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _scientific = TextEditingController(
    text: widget.existing?.scientificName ?? '',
  );
  late final _family = TextEditingController(
    text: widget.existing?.family ?? '',
  );
  late final _genus = TextEditingController(text: widget.existing?.genus ?? '');
  late final _habitat = TextEditingController(
    text: widget.existing?.habitat ?? '',
  );
  late String _edibility = widget.existing?.edibilityStatus ?? 'EDIBLE';
  late String? _difficulty = widget.existing?.cultivationDifficulty;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _scientific, _family, _genus, _habitat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final strain = StrainModel(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      scientificName: _scientific.text.trim(),
      family: _family.text.trim(),
      genus: _genus.text.trim(),
      edibilityStatus: _edibility,
      habitat: _habitat.text.trim().isEmpty ? null : _habitat.text.trim(),
      cultivationDifficulty: _difficulty,
      imageUrl: widget.existing?.imageUrl,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(strain);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? 'Thêm giống nấm'
                  : 'Chỉnh sửa giống nấm',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final entry in {
              _name: 'Tên giống nấm',
              _scientific: 'Tên khoa học',
              _family: 'Họ',
              _genus: 'Chi',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: entry.key,
                  decoration: InputDecoration(labelText: entry.value),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Bắt buộc' : null,
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _edibility,
              decoration: const InputDecoration(labelText: 'Khả năng ăn được'),
              items: const [
                DropdownMenuItem(value: 'CHOICE', child: Text('Ăn ngon')),
                DropdownMenuItem(value: 'EDIBLE', child: Text('Ăn được')),
                DropdownMenuItem(
                  value: 'INEDIBLE',
                  child: Text('Không ăn được'),
                ),
                DropdownMenuItem(value: 'POISONOUS', child: Text('Có độc')),
                DropdownMenuItem(
                  value: 'DEADLY',
                  child: Text('Độc chết người'),
                ),
              ],
              onChanged: (value) => setState(() => _edibility = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Độ khó nuôi trồng'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Chưa xác định')),
                DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
                DropdownMenuItem(value: 'MEDIUM', child: Text('Trung bình')),
                DropdownMenuItem(value: 'HARD', child: Text('Khó')),
                DropdownMenuItem(
                  value: 'UNCULTIVABLE',
                  child: Text('Không thể nuôi trồng'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _difficulty = value == '' ? null : value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _habitat,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Môi trường sống'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Đang lưu' : 'Lưu'),
            ),
          ],
        ),
      ),
    ),
  );
}
