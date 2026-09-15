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

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstRunBackendDialog.checkAndShow(context);
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
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _isSidebarVisible ? 160 : 52,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: _isSidebarVisible
                        ? 'Ẩn thanh bên'
                        : 'Hiện thanh bên',
                    icon: Icon(
                      _isSidebarVisible
                          ? Icons.keyboard_double_arrow_left
                          : Icons.keyboard_double_arrow_right,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSidebarVisible = !_isSidebarVisible;
                      });
                    },
                  ),
                ),
                if (_isSidebarVisible)
                  Expanded(
                    child: NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (index) {
                        setState(() {
                          _index = index;
                        });
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.auto_awesome_outlined),
                          selectedIcon: Icon(Icons.auto_awesome),
                          label: Text('Nhận diện AI'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.menu_book_outlined),
                          selectedIcon: Icon(Icons.menu_book),
                          label: Text('Từ điển'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.factory_outlined),
                          selectedIcon: Icon(Icons.factory),
                          label: Text('Cơ sở'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.spa_outlined),
                          selectedIcon: Icon(Icons.spa),
                          label: Text('Giống nấm'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.eco_outlined),
                          selectedIcon: Icon(Icons.eco),
                          label: Text('Lô nuôi trồng'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline),
                          selectedIcon: Icon(Icons.people),
                          label: Text('Tài khoản'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
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

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
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
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      )
                      .then((_) => onLoginSuccess());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
