import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/backend_queue_service.dart';
import '../../../core/storage/local_session.dart';
import '../../../core/network/mock_config.dart';
import '../../auth/presentation/login_screen.dart';
import '../../../core/widgets/mushroom_glyph.dart';
import '../../../core/widgets/mushroom_photo.dart';
import '../data/catalog_model.dart';

class MushroomCatalogScreen extends StatefulWidget {
  const MushroomCatalogScreen({super.key});

  @override
  State<MushroomCatalogScreen> createState() => _MushroomCatalogScreenState();
}

class _MushroomCatalogScreenState extends State<MushroomCatalogScreen> {
  final _api = ApiClient();
  final _searchCtrl = TextEditingController();

  MushroomCatalogResponse? _catalog;
  bool _loading = true;
  String? _error;
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
    setState(() { _loading=true; _error=null; });
    if (!LocalSession.isLoggedIn && !MockConfig.enabled) { setState(() { _loading=false; _error='Đăng nhập để xem danh mục giống nấm trên máy chủ.'; }); return; }
    try { final result=await _api.fetchMushroomCatalog(); if(mounted) setState(() => _catalog=result); }
    catch(error) { if(mounted) setState(() => _error=error.toString()); }
    finally { if(mounted) setState(() => _loading=false); }
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
          (_filterType == 'safe' && ['CHOICE','EDIBLE'].contains(m.edibilityStatus)) ||
          (_filterType == 'poisonous' && m.isPoisonous);

      return matchQuery && matchFilter;
    }).toList();
  }

  Color _tone(BuildContext context, bool poison) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (poison) return dark ? const Color(0xFFFF8A80) : AppColors.danger;
    return dark ? AppColors.leaf : AppColors.primary;
  }

  Color _toneSoft(BuildContext context, bool poison) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (poison) {
      return dark
          ? const Color(0xFFFF8A80).withValues(alpha: 0.14)
          : AppColors.dangerSoft;
    }
    return Theme.of(context).colorScheme.primaryContainer;
  }

  void _showMushroomDetail(MushroomCatalogItem item) {
    final theme = Theme.of(context);
    final poison = item.isPoisonous;
    final tone = _tone(context, poison);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 190,
                color: _toneSoft(context, poison),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MushroomPhoto(
                        imageUrl: item.imageUrl,
                        assetKey: item.assetKey,
                        name: item.name,
                        poisonous: poison,
                        baseUrl: BackendQueueService.instance.backendBaseUrl,
                        glyphSize: 130,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      item.scientificName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _toneSoft(context, poison),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            poison
                                ? Icons.warning_amber_rounded
                                : Icons.verified_rounded,
                            color: tone,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              poison
                                  ? tr(context,
                                      vi: 'Loài nấm có độc tố nguy hiểm',
                                      en: 'Dangerous poisonous species')
                                  : tr(context,
                                      vi: 'Thông tin phân loại theo danh mục',
                                      en: 'Safe / edible species'),
                              style: TextStyle(
                                color: tone,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      poison
                          ? tr(
                              context,
                              vi: 'Loài nấm này chứa độc tố có thể gây ngộ độc tiêu hóa, tổn thương gan thận hoặc tử vong. Tuyệt đối không tiêu thụ.',
                              en: 'This species contains toxins that can cause severe poisoning or death. Never consume it.',
                            )
                          : tr(
                              context,
                              vi: 'Xem khả năng ăn được theo thông tin phân loại của loài.',
                              en: 'An edible mushroom, commonly used as food and widely cultivated.',
                            ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(tr(context, vi: 'Đóng', en: 'Close')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = (_filterType ?? 'all') == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterType = value),
        labelStyle: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return SafeArea(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Padding(padding:const EdgeInsets.all(24),child:Text(_error!,textAlign:TextAlign.center)),
      FilledButton(onPressed:() async {
        if(!LocalSession.isLoggedIn) { await Navigator.push(context,MaterialPageRoute(builder:(_) => const LoginScreen())); }
        if(mounted) await _loadCatalog();
      },child:Text(LocalSession.isLoggedIn ? 'Thử lại' : 'Đăng nhập')),
    ])));
    final theme = Theme.of(context);
    final list = _filteredList;
    final c = _catalog;

    return SafeArea(
      bottom: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCatalog,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(context,
                                        vi: 'Từ điển nấm', en: 'Mushroom catalog'),
                                    style: theme.textTheme.headlineMedium,
                                  ),
                                  if (c != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      tr(
                                        context,
                                        vi: '${c.total} loài · ${c.safeCount} ăn được · ${c.poisonousCount} có độc',
                                        en: '${c.total} species · ${c.safeCount} edible · ${c.poisonousCount} poisonous',
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: tr(context, vi: 'Làm mới', en: 'Refresh'),
                              onPressed: _loadCatalog,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: tr(
                              context,
                              vi: 'Tìm theo tên hoặc tên khoa học',
                              en: 'Search by common or scientific name',
                            ),
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _chip(
                                tr(context, vi: 'Tất cả', en: 'All'),
                                'all',
                              ),
                              _chip(
                                tr(context, vi: 'Ăn được', en: 'Edible'),
                                'safe',
                              ),
                              _chip(
                                tr(context, vi: 'Nấm độc', en: 'Poisonous'),
                                'poisonous',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ]),
                    ),
                  ),
                  if (list.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const MushroomGlyph(size: 72),
                              const SizedBox(height: 12),
                              Text(
                                tr(
                                  context,
                                  vi: 'Không có loài nào khớp. Thử từ khoá khác.',
                                  en: 'No matching species. Try another keyword.',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 230,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final m = list[i];
                            return _SpeciesCard(
                              item: m,
                              tone: _tone(context, m.isPoisonous),
                              toneSoft: _toneSoft(context, m.isPoisonous),
                              onTap: () => _showMushroomDetail(m),
                            );
                          },
                          childCount: list.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final MushroomCatalogItem item;
  final Color tone;
  final Color toneSoft;
  final VoidCallback onTap;

  const _SpeciesCard({
    required this.item,
    required this.tone,
    required this.toneSoft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final poison = item.isPoisonous;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  color: toneSoft,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MushroomPhoto(
                          imageUrl: item.imageUrl,
                          assetKey: item.assetKey,
                          name: item.name,
                          poisonous: poison,
                          baseUrl: BackendQueueService.instance.backendBaseUrl,
                          glyphSize: 84,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: tone,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                poison
                                    ? Icons.warning_rounded
                                    : Icons.check_rounded,
                                size: 12,
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.darkBg
                                    : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                poison
                                    ? tr(context, vi: 'Có độc', en: 'Poisonous')
                                    : item.edibilityLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: theme.brightness == Brightness.dark
                                      ? AppColors.darkBg
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(height: 1.25),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
