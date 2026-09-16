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
  late int _index;
  bool _isSidebarVisible = true;

  final List<_SidebarItem> _items = const [
    _SidebarItem(
      Icons.auto_awesome_outlined,
      Icons.auto_awesome,
      'Nhận diện AI',
    ),
    _SidebarItem(Icons.menu_book_outlined, Icons.menu_book, 'Từ điển'),
    _SidebarItem(Icons.factory_outlined, Icons.factory, 'Cơ sở'),
    _SidebarItem(Icons.spa_outlined, Icons.spa, 'Giống nấm'),
    _SidebarItem(Icons.eco_outlined, Icons.eco, 'Lô nuôi trồng'),
    _SidebarItem(Icons.people_outline, Icons.people, 'Tài khoản'),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstRunBackendDialog.checkAndShow(context);
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  Widget _buildBody() {
    switch (_index) {
      case 0:
        return const MushroomRecognitionScreen();
      case 1:
        return const MushroomCatalogScreen();
      case 2:
        return LocalSession.isLoggedIn
            ? const FacilityListScreen()
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
              );
      case 3:
        return LocalSession.isLoggedIn
            ? const StrainListScreen()
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
              );
      case 4:
        return LocalSession.isLoggedIn
            ? const BatchListScreen()
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
              );
      case 5:
        return LocalSession.isLoggedIn
            ? const AccountListScreen()
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
              );
      default:
        return const MushroomRecognitionScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: _isSidebarVisible ? 220 : 78,
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.8),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _isSidebarVisible
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: _toggleSidebar,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary,
                                              theme.colorScheme.tertiary,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.menu_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'thu',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {},
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.notifications_none_rounded,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: _toggleSidebar,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.tertiary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.menu_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final selected = index == _index;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: selected
                                  ? theme.colorScheme.primaryContainer
                                  : Colors.transparent,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() {
                                  _index = index;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? item.selectedIcon
                                          : item.unselectedIcon,
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    if (_isSidebarVisible) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: selected
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData unselectedIcon;
  final IconData selectedIcon;
  final String label;

  const _SidebarItem(this.unselectedIcon, this.selectedIcon, this.label);
}

class _AuthRequiredPlaceholder extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onLoginSuccess;

  const _AuthRequiredPlaceholder({
    required this.title,
    required this.description,
    required this.onLoginSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
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
