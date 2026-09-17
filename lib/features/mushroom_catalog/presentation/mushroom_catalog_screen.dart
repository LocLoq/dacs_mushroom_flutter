import 'package:flutter/material.dart';

import '../../../core/localization/app_text_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/backend_queue_service.dart';
import '../data/catalog_model.dart';

class MushroomCatalogScreen extends StatefulWidget {
  final VoidCallback? onOpenNavigation;

  const MushroomCatalogScreen({super.key, this.onOpenNavigation});

  @override
  State<MushroomCatalogScreen> createState() => _MushroomCatalogScreenState();
}

class _MushroomCatalogScreenState extends State<MushroomCatalogScreen> {
  final _api = ApiClient();
  final _searchCtrl = TextEditingController();

  MushroomCatalogResponse? _catalog;
  bool _loading = true;
  String? _filterType; // 'all', 'safe', 'poisonous'

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _loading = true);
    final baseUrl = BackendQueueService.instance.backendBaseUrl;
    final res = await _api.fetchMushroomCatalog(baseUrl);
    if (mounted) {
      setState(() {
        _catalog = res;
        _loading = false;
      });
    }
  }

  List<MushroomCatalogItem> get _filteredList {
    if (_catalog == null) return [];
    final query = _searchCtrl.text.toLowerCase().trim();

    return _catalog!.mushrooms.where((m) {
      final matchQuery = query.isEmpty ||
          m.name.toLowerCase().contains(query) ||
          m.scientificName.toLowerCase().contains(query);

      final matchFilter = _filterType == null ||
          _filterType == 'all' ||
          (_filterType == 'safe' && !m.isPoisonous) ||
          (_filterType == 'poisonous' && m.isPoisonous);

      return matchQuery && matchFilter;
    }).toList();
  }

  void _showMushroomDetail(MushroomCatalogItem item) {
    final theme = Theme.of(context);
    final isPoison = item.isPoisonous;
    final color = isPoison ? Colors.red.shade700 : Colors.green.shade700;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPoison ? Icons.dangerous_rounded : Icons.spa_rounded,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item.scientificName,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    isPoison ? Icons.warning_amber_rounded : Icons.verified_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPoison
                        ? tr(context, vi: 'Loài nấm có độc tố nguy hiểm', en: 'Dangerous poisonous species')
                        : tr(context, vi: 'Loài nấm an toàn / ăn được', en: 'Safe / Edible species'),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPoison
                  ? tr(
                      context,
                      vi: 'Cảnh báo: Loài nấm này chứa độc tố có thể gây ngộ độc tiêu hóa, tổn thương gan thận hoặc tử vong. Tuyệt đối không tiêu thụ.',
                      en: 'Warning: This species contains dangerous toxins that can cause severe poisoning or death. Never consume.',
                    )
                  : tr(
                      context,
                      vi: 'Thông tin: Loài nấm ăn được, thường được sử dụng làm thực phẩm hoặc nuôi trồng phổ biến trong nông nghiệp.',
                      en: 'Info: Edible mushroom, commonly cultivated in agriculture and used as food.',
                    ),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr(context, vi: 'Đóng', en: 'Close')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        title: Text(
          tr(context, vi: 'Từ Điển & Danh Mục Nấm', en: 'Mushroom Catalog'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: tr(context, vi: 'Làm mới', en: 'Refresh'),
            onPressed: _loadCatalog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCatalog,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Thẻ thống kê tổng quan
                  if (_catalog != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: tr(context, vi: 'Tổng số loài', en: 'Total'),
                            value: '${_catalog!.total}',
                            icon: Icons.list_alt_rounded,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: tr(context, vi: 'Ăn được', en: 'Safe'),
                            value: '${_catalog!.safeCount}',
                            icon: Icons.check_circle_outline,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: tr(context, vi: 'Nấm độc', en: 'Poisonous'),
                            value: '${_catalog!.poisonousCount}',
                            icon: Icons.warning_amber_rounded,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Ô tìm kiếm
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: tr(
                        context,
                        vi: 'Tìm theo tên thông dụng hoặc tên khoa học...',
                        en: 'Search by common or scientific name...',
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(tr(context, vi: 'Tất cả', en: 'All')),
                          selected: _filterType == null || _filterType == 'all',
                          onSelected: (_) => setState(() => _filterType = 'all'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(tr(context, vi: 'Nấm ăn được', en: 'Safe')),
                          selected: _filterType == 'safe',
                          onSelected: (_) => setState(() => _filterType = 'safe'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(tr(context, vi: 'Nấm độc', en: 'Poisonous')),
                          selected: _filterType == 'poisonous',
                          onSelected: (_) => setState(() => _filterType = 'poisonous'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Danh sách
                  if (_filteredList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Text(
                          tr(
                            context,
                            vi: 'Không tìm thấy loài nấm nào phù hợp.',
                            en: 'No matching mushroom species found.',
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._filteredList.map((m) {
                      final isPoison = m.isPoisonous;
                      final badgeColor =
                          isPoison ? Colors.red.shade700 : Colors.green.shade700;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: badgeColor.withOpacity(0.15),
                            child: Icon(
                              isPoison
                                  ? Icons.warning_rounded
                                  : Icons.spa_rounded,
                              color: badgeColor,
                            ),
                          ),
                          title: Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            m.scientificName,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPoison
                                  ? tr(context, vi: 'Có độc', en: 'Poisonous')
                                  : tr(context, vi: 'An toàn', en: 'Safe'),
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          onTap: () => _showMushroomDetail(m),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
