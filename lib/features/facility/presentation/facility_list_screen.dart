import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/api_error_view.dart';
import '../data/facility_model.dart';

// + facility_selector_dialog.dart (gộp trong hàm _openSelector bên dưới)

class FacilityListScreen extends StatefulWidget {
  final VoidCallback? onOpenNavigation;

  const FacilityListScreen({super.key, this.onOpenNavigation});

  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

class _FacilityListScreenState extends State<FacilityListScreen> {
  final _api = ApiClient();
  final _searchCtrl = TextEditingController();
  List<FacilityModel> _all = [];
  FacilityStatus? _filter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchFacilities();
      if (mounted) setState(() => _all = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FacilityModel> get _filtered {
    return _all.where((f) {
      final matchSearch = f.name.toLowerCase().contains(
        _searchCtrl.text.toLowerCase(),
      );
      final matchStatus = _filter == null || f.status == _filter;
      return matchSearch && matchStatus;
    }).toList();
  }

  void _openSelector(FacilityModel facility) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(facility.name),
        content: Text(facility.address + ' · ' + _statusLabel(facility.status)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(FacilityStatus s) => switch (s) {
    FacilityStatus.active => AppColors.success,
    FacilityStatus.suspended => AppColors.warning,
    FacilityStatus.closed => AppColors.danger,
  };

  String _statusLabel(FacilityStatus s) => switch (s) {
    FacilityStatus.active => 'Đang hoạt động',
    FacilityStatus.suspended => 'Tạm dừng',
    FacilityStatus.closed => 'Đã đóng cửa',
  };

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
          'Cơ sở sản xuất',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ApiErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load, // TODO(BACKEND): pull-to-refresh gọi lại API
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm cơ sở...',
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
                        ...FacilityStatus.values.map(
                          (s) => _filterChip(_statusLabel(s), s),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filtered.map(
                    (f) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.factory, color: Colors.white),
                        ),
                        title: Text(
                          f.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            f.address,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        trailing: StatusChip(
                          text: _statusLabel(f.status),
                          color: _statusColor(f.status),
                        ),
                        onTap: () => _openSelector(f),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _filterChip(String label, FacilityStatus? value) {
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
