import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../facility/data/facility_model.dart';
import '../../mushroom_strain/data/strain_model.dart';
import '../data/batch_model.dart';

class BatchFormSheet extends StatefulWidget {
  final BatchModel? existing;
  final List<FacilityModel> facilities;
  final List<StrainModel> strains;
  final Future<void> Function(BatchModel) onSave;

  const BatchFormSheet({
    super.key,
    this.existing,
    required this.facilities,
    required this.strains,
    required this.onSave,
  });

  @override
  State<BatchFormSheet> createState() => _BatchFormSheetState();
}

class _BatchFormSheetState extends State<BatchFormSheet> {
  late final _codeCtrl = TextEditingController(text: widget.existing?.batchCode ?? '');
  late final _substrateCtrl = TextEditingController(text: widget.existing?.substrateType ?? '');
  late final _spawnCtrl = TextEditingController(text: widget.existing?.spawnSource ?? '');
  late final _bagQtyCtrl = TextEditingController(text: widget.existing?.bagQuantity?.toString() ?? '');
  late final _yieldCtrl = TextEditingController(text: widget.existing?.actualYieldKg?.toString() ?? '');
  late final _defectCtrl = TextEditingController(text: widget.existing?.defectRate?.toString() ?? '');
  late final _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');

  String? _facilityId;
  String? _mushroomId;
  BatchStatus _status = BatchStatus.preparation;
  DateTime _startDate = DateTime.now();
  DateTime? _expectedHarvestDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _facilityId = e?.facilityId ?? (widget.facilities.isNotEmpty ? widget.facilities.first.id : null);
    _mushroomId = e?.mushroomId ?? (widget.strains.isNotEmpty ? widget.strains.first.id : null);
    _status = e?.status ?? BatchStatus.preparation;
    _startDate = e?.startDate ?? DateTime.now();
    _expectedHarvestDate = e?.expectedHarvestDate;
    _endDate = e?.endDate;
  }

  String _fmt(DateTime? d) => d == null
      ? 'Chưa chọn'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) onPicked(picked);
  }

  String _statusLabel(BatchStatus s) => switch (s) {
        BatchStatus.preparation => 'Chuẩn bị cơ chất/trại',
        BatchStatus.incubation => 'Ủ tơ',
        BatchStatus.fruiting => 'Ra quả thể',
        BatchStatus.harvesting => 'Đang thu hoạch',
        BatchStatus.completed => 'Đã hoàn tất',
        BatchStatus.failed => 'Bị hỏng/nhiễm bệnh',
      };

  Future<void> _submit() async {
    if (_codeCtrl.text.trim().isEmpty || _facilityId == null || _mushroomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã lô, chọn cơ sở và giống nấm')),
      );
      return;
    }
    setState(() => _saving = true);
    final facility = widget.facilities.firstWhere((f) => f.id == _facilityId);
    final strain = widget.strains.firstWhere((s) => s.id == _mushroomId);
    final batch = BatchModel(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      batchCode: _codeCtrl.text.trim(),
      facilityId: facility.id,
      facilityName: facility.name,
      mushroomId: strain.id,
      mushroomName: strain.name,
      status: _status,
      substrateType: _substrateCtrl.text.trim().isEmpty ? null : _substrateCtrl.text.trim(),
      spawnSource: _spawnCtrl.text.trim().isEmpty ? null : _spawnCtrl.text.trim(),
      bagQuantity: int.tryParse(_bagQtyCtrl.text),
      startDate: _startDate,
      expectedHarvestDate: _expectedHarvestDate,
      endDate: _endDate,
      actualYieldKg: double.tryParse(_yieldCtrl.text),
      defectRate: double.tryParse(_defectCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    // TODO(BACKEND): validate batchCode unique, startDate <= expectedHarvestDate <= endDate, v.v.
    await widget.onSave(batch);
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
            Text(
              widget.existing == null ? 'Thêm lô nuôi trồng' : 'Chỉnh sửa lô nuôi trồng',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CustomTextField(label: 'Mã lô (batch_code)', controller: _codeCtrl),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _facilityId,
              decoration: const InputDecoration(labelText: 'Cơ sở sản xuất'),
              items: widget.facilities
                  .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name)))
                  .toList(),
              onChanged: (v) => setState(() => _facilityId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _mushroomId,
              decoration: const InputDecoration(labelText: 'Giống nấm'),
              items: widget.strains
                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _mushroomId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BatchStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: BatchStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CustomTextField(label: 'Loại cơ chất', controller: _substrateCtrl)),
              const SizedBox(width: 10),
              Expanded(child: CustomTextField(label: 'Nguồn giống', controller: _spawnCtrl)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CustomTextField(label: 'Số lượng bịch phôi', controller: _bagQtyCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: CustomTextField(label: 'Sản lượng thực tế (kg)', controller: _yieldCtrl, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            CustomTextField(label: 'Tỷ lệ hao hụt (%)', controller: _defectCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _dateRow('Ngày bắt đầu', _startDate, (d) => setState(() => _startDate = d)),
            const SizedBox(height: 10),
            _dateRow('Dự kiến thu hoạch', _expectedHarvestDate, (d) => setState(() => _expectedHarvestDate = d)),
            const SizedBox(height: 10),
            _dateRow('Ngày kết thúc/dọn trại', _endDate, (d) => setState(() => _endDate = d)),
            const SizedBox(height: 12),
            CustomTextField(label: 'Ghi chú', controller: _notesCtrl),
            const SizedBox(height: 20),
            CustomButton(label: 'Lưu', onPressed: _submit, loading: _saving, icon: Icons.save),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () => _pickDate(initial: value, onPicked: onPicked),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
        ),
        child: Text(_fmt(value)),
      ),
    );
  }
}
