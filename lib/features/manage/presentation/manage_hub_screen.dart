import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/farm_api.dart';
import '../../../core/network/mock_config.dart';
import '../../../core/storage/local_session.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/mushroom_glyph.dart';
import '../../../core/widgets/soft_card.dart';
import '../../audit/audit_log_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../batches/batch_list_screen.dart';
import '../../dashboard/dashboard_section.dart';
import '../../facilities/facility_list_screen.dart';
import '../../public_growth/public_growth_screen.dart';
import '../../reports/reports_screen.dart';
import '../../species/species_list_screen.dart';
import '../../tasks/task_list_screen.dart';
import '../../users/user_list_screen.dart';

/// Không gian làm việc của trại nấm: Tổng quan + lối vào các chức năng theo vai trò.
/// Chức năng không đủ quyền bị ẨN (không chỉ làm mờ).
class ManageHubScreen extends StatefulWidget {
  const ManageHubScreen({super.key});

  @override
  State<ManageHubScreen> createState() => _ManageHubScreenState();
}

class _Tool {
  final IconData icon;
  final String title;
  final String desc;
  final Widget Function() page;

  const _Tool(this.icon, this.title, this.desc, this.page);
}

class _ManageHubScreenState extends State<ManageHubScreen> {
  int _tick = 0; // đổi để tải lại Tổng quan
  bool _retrying = false;

  void _go(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  /// Đăng xuất luôn hỏi xác nhận (specs/S01).
  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ quay về chế độ khách. Nhận diện, từ điển và tra cứu lô vẫn dùng được.',
      ok: 'Đăng xuất',
    );
    if (ok) await LocalSession.clear();
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await FarmApi.instance.confirmProfile();
    if (mounted) setState(() => _retrying = false);
  }

  List<_Tool> _tools() => [
        _Tool(Icons.task_alt_rounded, 'Công việc', 'Giao việc, minh chứng, duyệt', () => const TaskListScreen()),
        _Tool(Icons.eco_rounded, 'Lô nuôi', 'Tiến trình, chăm sóc, thu hoạch', () => const BatchListScreen()),
        _Tool(Icons.spa_rounded, 'Giống nấm', 'Danh mục và ảnh', () => const SpeciesListScreen()),
        _Tool(Icons.factory_rounded, 'Cơ sở', 'Trại nuôi trồng', () => const FacilityListScreen()),
        if (LocalSession.canManage)
          _Tool(Icons.bar_chart_rounded, 'Báo cáo', 'Số liệu và xuất file', () => const ReportsScreen()),
        if (LocalSession.canManage)
          _Tool(Icons.receipt_long_rounded, 'Nhật ký hệ thống', 'Ai làm gì, khi nào', () => const AuditLogScreen()),
        if (LocalSession.isAdmin)
          _Tool(Icons.people_alt_rounded, 'Người dùng', 'Tài khoản và vai trò', () => const UserListScreen()),
      ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder<int>(
        valueListenable: LocalSession.changes,
        builder: (context, _, __) {
          final theme = Theme.of(context);
          final status = LocalSession.status;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _tick++),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text('Quản lý trại nấm', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  status == SessionStatus.signedIn
                      ? 'Xin chào ${LocalSession.displayName} · ${label(roleLabels, LocalSession.role)}'
                      : 'Đăng nhập để quản lý lô, công việc và báo cáo. Nhận diện, từ điển và tra cứu lô vẫn dùng được khi chưa đăng nhập.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<bool>(
                  valueListenable: MockConfig.notifier,
                  builder: (context, on, _) => on
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? AppColors.warning.withValues(alpha: 0.14)
                                : AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(children: [
                            Icon(Icons.science_outlined, color: AppColors.warning, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Đang dùng DỮ LIỆU MẪU: không gọi backend, thay đổi mất khi mở lại app. Tắt ở Cài đặt → API Trại nấm.',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4),
                              ),
                            ),
                          ]),
                        )
                      : const SizedBox.shrink(),
                ),
                if (status == SessionStatus.guest) ..._guest(context),
                if (status == SessionStatus.pending) _pending(context),
                if (status == SessionStatus.signedIn) ..._signedIn(context),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _guest(BuildContext context) => [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            const MushroomGlyph(size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Đăng nhập để quản lý',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onPressed: () => _go(const LoginScreen()),
                  child: const Text('Đăng nhập'),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _toolCard(const _Tool(Icons.qr_code_2_rounded, 'Tra cứu tiến trình lô', 'Nhập mã lô, không cần đăng nhập', _publicPage)),
      ];

  static Widget _publicPage() => const PublicGrowthScreen();

  Widget _pending(BuildContext context) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text('Chưa xác nhận được phiên đăng nhập', style: Theme.of(context).textTheme.titleSmall)),
          ]),
          const SizedBox(height: 8),
          Text('Có thể do mất mạng hoặc máy chủ chưa phản hồi. Dữ liệu nội bộ chưa được hiển thị.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: _retrying ? null : _retry,
                child: _retrying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Thử lại'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: _logout, child: const Text('Đăng xuất'))),
          ]),
        ]),
      );

  List<Widget> _signedIn(BuildContext context) {
    return [
      // Mỗi lần đổi _tick Tổng quan được dựng lại và tải mới.
      DashboardSection(key: ValueKey('dash-$_tick')),
      const SizedBox(height: 22),
      Text('Chức năng', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 3 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final t in [..._tools(), _Tool(Icons.qr_code_2_rounded, 'Tra cứu công khai', 'Xem như khách', _publicPage)])
            SizedBox(width: w, child: _toolCard(t, compact: true)),
        ]);
      }),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Đăng xuất'),
      ),
    ];
  }

  Widget _toolCard(_Tool t, {bool compact = false}) {
    final theme = Theme.of(context);
    return SoftCard(
      onTap: () => _go(t.page()),
      padding: const EdgeInsets.all(16),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(t.icon),
              const SizedBox(height: 14),
              Text(t.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(t.desc, style: theme.textTheme.bodySmall),
            ])
          : Row(children: [
              IconTile(t.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, style: theme.textTheme.titleMedium),
                  Text(t.desc, style: theme.textTheme.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
    );
  }
}
