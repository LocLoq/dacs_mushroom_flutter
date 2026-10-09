import 'package:flutter/material.dart';

import '../core/localization/app_text_scope.dart';
import '../core/widgets/mushroom_glyph.dart';
import '../features/manage/presentation/manage_hub_screen.dart';
import '../features/mushroom_catalog/presentation/mushroom_catalog_screen.dart';
import '../features/recognition/presentation/mushroom_recognition_screen.dart';
import '../features/recognition_history/presentation/history_hub.dart';
import '../features/settings/presentation/first_run_backend_dialog.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'theme/app_colors.dart';

/// Các trang chính. Chỉ số này cũng là giá trị của [HomeScreen.initialIndex].
const int kPageScan = 0;
const int kPageCatalog = 1;
const int kPageHistory = 2;
const int kPageManage = 3;
const int kPageSettings = 4;

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = kPageScan});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _index;
  final Set<int> _visited = {};
  int _historyTick = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
    _visited.add(_index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstRunBackendDialog.checkAndShow(context);
    });
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
      if (i == kPageHistory) _historyTick++; // tải lại lịch sử mỗi lần mở tab
    });
  }

  Widget _page(int i) {
    switch (i) {
      case kPageScan:
        return const MushroomRecognitionScreen();
      case kPageCatalog:
        return const MushroomCatalogScreen();
      case kPageHistory:
        return HistoryHub(key: ValueKey('history-$_historyTick'));
      case kPageManage:
        return const ManageHubScreen();
      default:
        return const SettingsScreen(embedded: true);
    }
  }

  List<_Dest> _destinations(BuildContext context) => [
        _Dest(kPageScan, Icons.center_focus_strong_outlined,
            Icons.center_focus_strong_rounded,
            tr(context, vi: 'Quét', en: 'Scan')),
        _Dest(kPageCatalog, Icons.menu_book_outlined, Icons.menu_book_rounded,
            tr(context, vi: 'Từ điển', en: 'Catalog')),
        _Dest(kPageHistory, Icons.history_rounded, Icons.history_rounded,
            tr(context, vi: 'Lịch sử', en: 'History')),
        _Dest(kPageManage, Icons.grid_view_outlined, Icons.grid_view_rounded,
            tr(context, vi: 'Quản lý', en: 'Manage')),
        _Dest(kPageSettings, Icons.settings_outlined, Icons.settings_rounded,
            tr(context, vi: 'Cài đặt', en: 'Settings')),
      ];

  @override
  Widget build(BuildContext context) {
    final dests = _destinations(context);
    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < 5; i++)
          _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
      ],
    );

    final wide = MediaQuery.of(context).size.width >= 840;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _SideRail(dests: dests, index: _index, onSelect: _select),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: false,
      body: body,
      bottomNavigationBar: _BottomBar(
        // Thứ tự hiển thị: Từ điển, Lịch sử, [Quét], Quản lý, Cài đặt
        left: [dests[1], dests[2]],
        center: dests[0],
        right: [dests[3], dests[4]],
        index: _index,
        onSelect: _select,
      ),
    );
  }
}

class _Dest {
  final int page;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _Dest(this.page, this.icon, this.selectedIcon, this.label);
}

// ─────────────────────────── Thanh điều hướng dưới ───────────────────────────

class _BottomBar extends StatelessWidget {
  final List<_Dest> left;
  final _Dest center;
  final List<_Dest> right;
  final int index;
  final ValueChanged<int> onSelect;

  const _BottomBar({
    required this.left,
    required this.center,
    required this.right,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final centerSelected = index == center.page;

    Widget item(_Dest d) => Expanded(
          child: _NavItem(
            dest: d,
            selected: index == d.page,
            onTap: () => onSelect(d.page),
          ),
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF173F0E).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (final d in left) item(d),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: center.label,
                    child: GestureDetector(
                      onTap: () => onSelect(center.page),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: centerSelected
                                ? AppColors.leaf
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark
                                  .withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.center_focus_strong_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final d in right) item(d),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              selected ? dest.selectedIcon : dest.icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dest.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Thanh bên (màn rộng) ───────────────────────────

class _SideRail extends StatelessWidget {
  final List<_Dest> dests;
  final int index;
  final ValueChanged<int> onSelect;

  const _SideRail({
    required this.dests,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  const MushroomGlyph(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(context, vi: 'Nhận diện nấm', en: 'Mushroom ID'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            for (final d in dests)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: Material(
                  color: index == d.page
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelect(d.page),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            index == d.page ? d.selectedIcon : d.icon,
                            size: 22,
                            color: index == d.page
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            d.label,
                            style: TextStyle(
                              fontWeight: index == d.page
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: index == d.page
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
