import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/storage/local_session.dart';
import '../data/strain_model.dart';
import 'strain_form_sheet.dart';

class StrainListScreen extends StatefulWidget {
  final VoidCallback? onOpenNavigation;

  const StrainListScreen({super.key, this.onOpenNavigation});

  @override
  State<StrainListScreen> createState() => _StrainListScreenState();
}

class _StrainListScreenState extends State<StrainListScreen> {
  final _api = ApiClient();
  List<StrainModel> _strains = [];
  bool _loading = true;
  String? _error;

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
      final data = await _api.fetchStrains();
      if (mounted) setState(() => _strains = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm({StrainModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StrainFormSheet(
        existing: existing,
        onSave: (strain) async {
          // TODO(BACKEND): ApiClient.saveStrain(strain) -> reload list
          await _api.saveStrain(strain);
          if (context.mounted) Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenNavigation == null
            ? null
            : IconButton(
                key: const Key('home-appbar-menu-button'),
                tooltip: tr(
                  context,
                  vi: 'Mở menu điều hướng',
                  en: 'Open navigation menu',
                ),
                icon: const Icon(Icons.menu_rounded),
                onPressed: widget.onOpenNavigation,
              ),
        title: const Text(
          'Giống nấm',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      floatingActionButton: !LocalSession.canManage
          ? null
          : FloatingActionButton(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ApiErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
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
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (LocalSession.canManage)
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => _openForm(existing: s),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _paramTag(s.scientificName),
                              _paramTag('Họ: ' + s.family),
                              _paramTag(s.edibilityStatus),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _paramTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}
