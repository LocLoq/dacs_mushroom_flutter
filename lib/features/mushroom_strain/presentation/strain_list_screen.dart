import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../data/strain_model.dart';
import 'strain_form_sheet.dart';

class StrainListScreen extends StatefulWidget {
  const StrainListScreen({super.key});

  @override
  State<StrainListScreen> createState() => _StrainListScreenState();
}

class _StrainListScreenState extends State<StrainListScreen> {
  final _api = ApiClient();
  List<StrainModel> _strains = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // TODO(BACKEND): strain_controller -> strain_repository -> ApiClient.fetchStrains
    final data = await _api.fetchStrains();
    setState(() { _strains = data; _loading = false; });
  }

  void _openForm({StrainModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StrainFormSheet(
        existing: existing,
        onSave: (strain) async {
          // TODO(BACKEND): ApiClient.saveStrain(strain) -> reload list
          await _api.saveStrain(strain);
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giống nấm')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _strains.length,
              itemBuilder: (context, i) {
                final s = _strains[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: AppColors.textSecondary),
                              onPressed: () => _openForm(existing: s),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _paramTag('🌡 ${s.tempMin.toStringAsFixed(0)}–${s.tempMax.toStringAsFixed(0)}°C'),
                            _paramTag('💧 ${s.humidityMin.toStringAsFixed(0)}–${s.humidityMax.toStringAsFixed(0)}%'),
                            _paramTag('🫧 CO₂ ${s.co2Min.toStringAsFixed(0)}–${s.co2Max.toStringAsFixed(0)}ppm'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _paramTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}
