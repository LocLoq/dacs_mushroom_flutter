import 'package:flutter/material.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../data/strain_model.dart';

class StrainFormSheet extends StatefulWidget {
  final StrainModel? existing;
  final Future<void> Function(StrainModel) onSave;

  const StrainFormSheet({super.key, this.existing, required this.onSave});

  @override
  State<StrainFormSheet> createState() => _StrainFormSheetState();
}

class _StrainFormSheetState extends State<StrainFormSheet> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _tempMinCtrl = TextEditingController(text: widget.existing?.tempMin.toString() ?? '');
  late final _tempMaxCtrl = TextEditingController(text: widget.existing?.tempMax.toString() ?? '');
  late final _humMinCtrl = TextEditingController(text: widget.existing?.humidityMin.toString() ?? '');
  late final _humMaxCtrl = TextEditingController(text: widget.existing?.humidityMax.toString() ?? '');
  late final _co2MinCtrl = TextEditingController(text: widget.existing?.co2Min.toString() ?? '');
  late final _co2MaxCtrl = TextEditingController(text: widget.existing?.co2Max.toString() ?? '');
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    final strain = StrainModel(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text,
      tempMin: double.tryParse(_tempMinCtrl.text) ?? 0,
      tempMax: double.tryParse(_tempMaxCtrl.text) ?? 0,
      humidityMin: double.tryParse(_humMinCtrl.text) ?? 0,
      humidityMax: double.tryParse(_humMaxCtrl.text) ?? 0,
      co2Min: double.tryParse(_co2MinCtrl.text) ?? 0,
      co2Max: double.tryParse(_co2MaxCtrl.text) ?? 0,
    );
    // TODO(BACKEND): validate dữ liệu trước khi gửi (min < max, số dương, v.v.)
    await widget.onSave(strain);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Thêm giống nấm' : 'Chỉnh sửa giống nấm',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            CustomTextField(label: 'Tên giống nấm', controller: _nameCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CustomTextField(label: 'Nhiệt độ min (°C)', controller: _tempMinCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: CustomTextField(label: 'Nhiệt độ max (°C)', controller: _tempMaxCtrl, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CustomTextField(label: 'Độ ẩm min (%)', controller: _humMinCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: CustomTextField(label: 'Độ ẩm max (%)', controller: _humMaxCtrl, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CustomTextField(label: 'CO₂ min (ppm)', controller: _co2MinCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: CustomTextField(label: 'CO₂ max (ppm)', controller: _co2MaxCtrl, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 20),
            CustomButton(label: 'Lưu', onPressed: _submit, loading: _saving, icon: Icons.save),
          ],
        ),
      ),
    );
  }
}
