import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../facility/data/facility_model.dart';
import '../../mushroom_strain/data/strain_model.dart';
import '../data/batch_model.dart';
import 'batch_form_sheet.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  final _api = ApiClient();
  final _searchCtrl = TextEditingController();
  List<BatchModel> _all = [];
  List<FacilityModel> _facilities = [];
  List<StrainModel> _strains = [];
  BatchStatus? _filter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // TODO(BACKEND): batch_controller (Riverpod) -> batch_repository -> ApiClient.fetchBatches
    // GET {baseUrl}/cultivation-batches/?search=&status=&facility_id=
    final results = await Future.wait([
      _api.fetchBatches(),
      _api.fetchFacilities(),
      _api.fetchStrains(),
    ]);
    setState(() {
      _all = results[0] as List<BatchModel>;
      _facilities = results[1] as List<FacilityModel>;
      _strains = results[2] as List<StrainModel>;
      _loading = false;
    });
  }

  List<BatchModel> get _filtered {
    return _all.where((b) {
      final q = _searchCtrl.text.toLowerCase();
      final matchSearch = b.batchCode.toLowerCase().contains(q) ||
          b.facilityName.toLowerCase().contains(q) ||
          b.mushroomName.toLowerCase().contains(q);
      final matchStatus = _filter == null || b.status == _filter;
      return matchSearch && matchStatus;
    }).toList();
  }

  void _openForm({BatchModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => BatchFormSheet(
        existing: existing,
        facilities: _facilities,
        strains: _strains,
        onSave: (batch) async {
          // TODO(BACKEND): POST/PUT {baseUrl}/cultivation-batches/ hoặc /{id}/
          await _api.saveBatch(batch);
          if (context.mounted) Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  Color _statusColor(BatchStatus s) => switch (s) {
        BatchStatus.preparation => AppColors.textSecondary,
        BatchStatus.incubation => AppColors.warning,
        BatchStatus.fruiting => AppColors.primary,
        BatchStatus.harvesting => AppColors.success,
        BatchStatus.completed => AppColors.primaryDark,
        BatchStatus.failed => AppColors.danger,
      };

  String _statusLabel(BatchStatus s) => switch (s) {
        BatchStatus.preparation => 'Chuẩn bị',
        BatchStatus.incubation => 'Ủ tơ',
        BatchStatus.fruiting => 'Ra quả thể',
        BatchStatus.harvesting => 'Thu hoạch',
        BatchStatus.completed => 'Hoàn tất',
        BatchStatus.failed => 'Thất bại',
      };

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lô nuôi trồng')),
      floatingActionButton: FloatingActionButton(
        onPressed: (_facilities.isEmpty || _strains.isEmpty) ? null : () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load, // TODO(BACKEND): pull-to-refresh gọi lại API
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo mã lô, cơ sở, giống nấm...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip('Tất cả', null),
                        ...BatchStatus.values.map((s) => _filterChip(_statusLabel(s), s)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: Text('Không có lô nào phù hợp', style: TextStyle(color: AppColors.textSecondary))),
                    ),
                  ..._filtered.map((b) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(b.batchCode,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(b.status).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _statusColor(b.status).withOpacity(0.4)),
                                    ),
                                    child: Text(_statusLabel(b.status),
                                        style: TextStyle(color: _statusColor(b.status), fontWeight: FontWeight.w600, fontSize: 12)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: AppColors.textSecondary),
                                    onPressed: () => _openForm(existing: b),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${b.facilityName} · ${b.mushroomName}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: [
                                  if (b.bagQuantity != null) _tag('📦 ${b.bagQuantity} bịch'),
                                  _tag('🗓 BD: ${_fmtDate(b.startDate)}'),
                                  if (b.expectedHarvestDate != null) _tag('🌾 DK: ${_fmtDate(b.expectedHarvestDate)}'),
                                  if (b.actualYieldKg != null) _tag('⚖️ ${b.actualYieldKg} kg'),
                                  if (b.defectRate != null) _tag('⚠️ Hao hụt ${b.defectRate}%'),
                                ],
                              ),
                              if (b.notes != null && b.notes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(b.notes!, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                              ],
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  Widget _filterChip(String label, BatchStatus? value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppColors.primary.withOpacity(0.15),
      ),
    );
  }
}
