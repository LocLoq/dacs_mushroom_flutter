import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_chip.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // TODO(BACKEND): gọi facility_controller (Riverpod) -> facility_repository -> ApiClient.fetchFacilities
    // TODO(BACKEND): nếu mất mạng, fallback đọc cache từ hive_service.dart
    final data = await _api.fetchFacilities();
    setState(() { _all = data; _loading = false; });
  }

  List<FacilityModel> get _filtered {
    return _all.where((f) {
      final matchSearch = f.name.toLowerCase().contains(_searchCtrl.text.toLowerCase());
      final matchStatus = _filter == null || f.status == _filter;
      return matchSearch && matchStatus;
    }).toList();
  }

  void _openSelector(FacilityModel f) {
    // tương ứng facility_selector_dialog.dart — chọn cơ sở làm việc hiện tại
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Chuyển sang "${f.name}"?'),
        content: const Text('Toàn bộ dữ liệu Giống nấm / thống kê sẽ chuyển theo cơ sở này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              // TODO(BACKEND): lưu f.id vào SecureStorage/Hive (AppConstants.selectedFacilityKey)
              // và gọi lại API các màn hình khác theo facility mới.
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã chuyển sang ${f.name}')),
              );
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(FacilityStatus s) => switch (s) {
        FacilityStatus.active => AppColors.success,
        FacilityStatus.paused => AppColors.warning,
        FacilityStatus.maintenance => AppColors.danger,
      };

  String _statusLabel(FacilityStatus s) => switch (s) {
        FacilityStatus.active => 'Đang hoạt động',
        FacilityStatus.paused => 'Tạm dừng',
        FacilityStatus.maintenance => 'Bảo trì',
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
                        ...FacilityStatus.values.map((s) => _filterChip(_statusLabel(s), s)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filtered.map((f) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.factory, color: Colors.white),
                          ),
                          title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(f.address, style: const TextStyle(color: AppColors.textSecondary)),
                          ),
                          trailing: StatusChip(text: _statusLabel(f.status), color: _statusColor(f.status)),
                          onTap: () => _openSelector(f),
                        ),
                      )),
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
