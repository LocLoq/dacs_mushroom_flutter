import 'package:flutter/material.dart';

import '../core/localization/app_text_scope.dart';
import '../core/storage/local_session.dart';
import '../features/account/presentation/account_list_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/cultivation_batch/presentation/batch_list_screen.dart';
import '../features/facility/presentation/facility_list_screen.dart';
import '../features/mushroom_catalog/presentation/mushroom_catalog_screen.dart';
import '../features/mushroom_strain/presentation/strain_list_screen.dart';
import '../features/recognition/presentation/mushroom_recognition_screen.dart';
import '../features/settings/presentation/first_run_backend_dialog.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _compactBreakpoint = 600.0;
  static const _expandedSidebarBreakpoint = 1024.0;
  static const _railWidth = 72.0;
  static const _expandedRailWidth = 220.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _index;
  bool? _sidebarExpandedOverride;
  bool? _wasCompact;

  final List<_NavigationItem> _items = const [
    _NavigationItem(
      Icons.auto_awesome_outlined,
      Icons.auto_awesome,
      'Nhận diện AI',
    ),
    _NavigationItem(Icons.menu_book_outlined, Icons.menu_book, 'Từ điển'),
    _NavigationItem(Icons.factory_outlined, Icons.factory, 'Cơ sở'),
    _NavigationItem(Icons.spa_outlined, Icons.spa, 'Giống nấm'),
    _NavigationItem(Icons.eco_outlined, Icons.eco, 'Lô nuôi trồng'),
    _NavigationItem(Icons.people_outline, Icons.people, 'Tài khoản'),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstRunBackendDialog.checkAndShow(context);
    });
  }

  void _openNavigation() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _selectDestination(int index, {bool closeDrawer = false}) {
    setState(() => _index = index);

    if (closeDrawer && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildBody({VoidCallback? onOpenNavigation}) {
    switch (_index) {
      case 0:
        return MushroomRecognitionScreen(onOpenNavigation: onOpenNavigation);
      case 1:
        return MushroomCatalogScreen(onOpenNavigation: onOpenNavigation);
      case 2:
        return LocalSession.isLoggedIn
            ? FacilityListScreen(onOpenNavigation: onOpenNavigation)
            : _AuthRequiredPlaceholder(
                title: tr(
                  context,
                  vi: 'Quản Lý Cơ Sở Trại Nấm',
                  en: 'Facility Management',
                ),
                description: tr(
                  context,
                  vi: 'Tính năng quản lý cơ sở nuôi trồng chỉ dành cho nhân sự và ban quản lý trại. Vui lòng đăng nhập để tiếp tục.',
                  en: 'Facility management is restricted to authorized personnel. Please login to proceed.',
                ),
                onLoginSuccess: () => setState(() {}),
                onOpenNavigation: onOpenNavigation,
              );
      case 3:
        return LocalSession.isLoggedIn
            ? StrainListScreen(onOpenNavigation: onOpenNavigation)
            : _AuthRequiredPlaceholder(
                title: tr(
                  context,
                  vi: 'Quản Lý Giống Nấm',
                  en: 'Mushroom Strains',
                ),
                description: tr(
                  context,
                  vi: 'Tính năng cấu hình thông số kỹ thuật giống nấm (nhiệt độ, độ ẩm, CO2) yêu cầu quyền quản trị.',
                  en: 'Strain parameter management (temp, humidity, CO2) requires authentication.',
                ),
                onLoginSuccess: () => setState(() {}),
                onOpenNavigation: onOpenNavigation,
              );
      case 4:
        return LocalSession.isLoggedIn
            ? BatchListScreen(onOpenNavigation: onOpenNavigation)
            : _AuthRequiredPlaceholder(
                title: tr(
                  context,
                  vi: 'Quản Lý Lô Nuôi Trồng',
                  en: 'Cultivation Batch Management',
                ),
                description: tr(
                  context,
                  vi: 'Tính năng theo dõi lô nuôi trồng (ủ tơ, ra quả thể, thu hoạch, năng suất) yêu cầu đăng nhập.',
                  en: 'Batch tracking (incubation, fruiting, harvesting, yield) requires authentication.',
                ),
                onLoginSuccess: () => setState(() {}),
                onOpenNavigation: onOpenNavigation,
              );
      case 5:
        return LocalSession.isLoggedIn
            ? AccountListScreen(onOpenNavigation: onOpenNavigation)
            : _AuthRequiredPlaceholder(
                title: tr(
                  context,
                  vi: 'Quản Trị Tài Khoản',
                  en: 'Account Management',
                ),
                description: tr(
                  context,
                  vi: 'Tính năng phân quyền và quản trị nhân sự yêu cầu tài khoản quản lý / admin.',
                  en: 'User administration and role management requires admin/manager privileges.',
                ),
                onLoginSuccess: () => setState(() {}),
                onOpenNavigation: onOpenNavigation,
              );
      default:
        return MushroomRecognitionScreen(onOpenNavigation: onOpenNavigation);
    }
  }

  Widget _buildDrawer(BuildContext context, double screenWidth) {
    final drawerWidth = screenWidth * 0.9 > 300 ? 300.0 : screenWidth * 0.9;
    final theme = Theme.of(context);

    return DrawerTheme(
      data: DrawerTheme.of(context).copyWith(width: drawerWidth),
      child: NavigationDrawer(
        key: const Key('home-navigation-drawer'),
        selectedIndex: _index,
        onDestinationSelected: (index) {
          _selectDestination(index, closeDrawer: true);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
            child: Row(
              children: [
                Icon(Icons.eco_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(
                      context,
                      vi: 'Quản lý & Nhận diện Nấm',
                      en: 'Mushroom Management & AI',
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._items.map(
            (item) => NavigationDrawerDestination(
              icon: Icon(item.unselectedIcon),
              selectedIcon: Icon(item.selectedIcon),
              label: Text(item.label),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail(BuildContext context, bool isExpanded) {
    return NavigationRail(
      selectedIndex: _index,
      extended: isExpanded,
      minWidth: _railWidth,
      minExtendedWidth: _expandedRailWidth,
      labelType: NavigationRailLabelType.none,
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Tooltip(
          message: isExpanded
              ? tr(context, vi: 'Thu gọn menu', en: 'Collapse menu')
              : tr(context, vi: 'Mở rộng menu', en: 'Expand menu'),
          child: IconButton(
            key: const Key('home-rail-toggle'),
            icon: Icon(
              isExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
            ),
            onPressed: () {
              setState(() => _sidebarExpandedOverride = !isExpanded);
            },
          ),
        ),
      ),
      onDestinationSelected: _selectDestination,
      destinations: _items
          .map(
            (item) => NavigationRailDestination(
              icon: Tooltip(
                message: item.label,
                child: Icon(item.unselectedIcon),
              ),
              selectedIcon: Tooltip(
                message: item.label,
                child: Icon(item.selectedIcon),
              ),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < _compactBreakpoint;
    final isExpandedByDefault = screenWidth >= _expandedSidebarBreakpoint;
    final isRailExpanded = _sidebarExpandedOverride ?? isExpandedByDefault;
    final theme = Theme.of(context);

    if (_wasCompact == true && !isCompact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
          Navigator.of(context).pop();
        }
      });
    }
    _wasCompact = isCompact;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.surface,
      drawer: isCompact ? _buildDrawer(context, screenWidth) : null,
      drawerEnableOpenDragGesture: isCompact,
      body: isCompact
          ? _buildBody(onOpenNavigation: _openNavigation)
          : Row(
              children: [
                _buildRail(context, isRailExpanded),
                const VerticalDivider(width: 1),
                Expanded(child: _buildBody()),
              ],
            ),
    );
  }
}

class _NavigationItem {
  final IconData unselectedIcon;
  final IconData selectedIcon;
  final String label;

  const _NavigationItem(this.unselectedIcon, this.selectedIcon, this.label);
}

class _AuthRequiredPlaceholder extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onLoginSuccess;
  final VoidCallback? onOpenNavigation;

  const _AuthRequiredPlaceholder({
    required this.title,
    required this.description,
    required this.onLoginSuccess,
    this.onOpenNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: onOpenNavigation == null
            ? null
            : IconButton(
                key: const Key('home-appbar-menu-button'),
                tooltip: tr(
                  context,
                  vi: 'Mở menu điều hướng',
                  en: 'Open navigation menu',
                ),
                icon: const Icon(Icons.menu_rounded),
                onPressed: onOpenNavigation,
              ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  tr(context, vi: 'Yêu Cầu Đăng Nhập', en: 'Login Required'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.login),
                  label: Text(
                    tr(context, vi: 'Đăng Nhập Ngay', en: 'Login Now'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        )
                        .then((_) => onLoginSuccess());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
