import 'package:flutter/material.dart';

import '../../../app/home_screen.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_session.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/account_model.dart';
import 'account_edit_sheet.dart';

class AccountListScreen extends StatefulWidget {
  final VoidCallback? onOpenNavigation;

  const AccountListScreen({super.key, this.onOpenNavigation});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  final _api = ApiClient();
  List<AccountModel> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // TODO(BACKEND): account_controller -> user_repository -> ApiClient.fetchAccounts
    // Chỉ Admin/Manager mới được gọi API này — kiểm tra role ở backend (permission_classes)
    final data = await _api.fetchAccounts();
    setState(() { _accounts = data; _loading = false; });
  }

  void _openEditSheet(AccountModel a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AccountEditSheet(
        account: a,
        onSaveRole: (role, facility) async {
          // TODO(BACKEND): ApiClient.updateAccountRole(a.id, role, facility)
          await _api.updateAccountRole(a.id, role, facility);
          final idx = _accounts.indexOf(a);
          setState(() {
            if (idx != -1) {
              _accounts[idx] = AccountModel(
                id: a.id,
                fullName: a.fullName,
                role: role,
                assignedFacility: facility,
                isActive: a.isActive,
              );
            }
          });
        },
        onSavePassword: (newPassword, mustChangePassword) async {
          // TODO(BACKEND): ApiClient.setAccountPassword(a.id, newPassword, mustChangePassword: ...)
          await _api.setAccountPassword(a.id, newPassword, mustChangePassword: mustChangePassword);
          setState(() => a.mustChangePassword = mustChangePassword);
        },
      ),
    );
  }

  AccountRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AccountRole.admin;
      case 'manager':
        return AccountRole.manager;
      default:
        return AccountRole.staff;
    }
  }

  void _openEditSelfSheet() {
    // TODO(BACKEND): lấy đầy đủ thông tin tài khoản hiện tại (id, cơ sở phụ trách) từ API profile thay vì LocalSession
    final self = AccountModel(
      id: '',
      fullName: LocalSession.username.isEmpty ? 'Tài khoản của tôi' : LocalSession.username,
      role: _parseRole(LocalSession.role),
      assignedFacility: '',
      isActive: true,
    );
    _openEditSheet(self);
  }

  Color _roleColor(AccountRole r) => switch (r) {
        AccountRole.admin => AppColors.danger,
        AccountRole.manager => AppColors.primary,
        AccountRole.staff => AppColors.textSecondary,
      };

  String _roleLabel(AccountRole r) => switch (r) {
        AccountRole.admin => 'Admin',
        AccountRole.manager => 'Manager',
        AccountRole.staff => 'Staff',
      };

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // TODO(BACKEND): gọi API /auth/logout (thu hồi refresh token) trước khi clear session, nếu backend hỗ trợ.
    LocalSession.clear();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đăng xuất thành công')),
    );

    // Quay về HomeScreen ở trạng thái chưa đăng nhập (reset toàn bộ ngăn xếp điều hướng)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
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
          'Quản lý tài khoản',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _accounts.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: AppColors.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: const Icon(Icons.person, color: AppColors.primary),
                      ),
                      title: Text(
                        LocalSession.username.isEmpty ? 'Tài khoản của tôi' : LocalSession.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(LocalSession.role, style: const TextStyle(color: AppColors.textSecondary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Sửa vai trò / mật khẩu',
                        onPressed: _openEditSelfSheet,
                      ),
                    ),
                  );
                }

                final a = _accounts[i - 1];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: _roleColor(a.role).withOpacity(0.15),
                      child: Text(a.fullName.characters.first,
                          style: TextStyle(color: _roleColor(a.role), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(a.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6, runSpacing: 6,
                        children: [
                          StatusChip(text: _roleLabel(a.role), color: _roleColor(a.role)),
                          Text('· ${a.assignedFacility}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          if (a.mustChangePassword)
                            const StatusChip(text: 'Chờ đổi mật khẩu', color: AppColors.warning),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: AppColors.textSecondary),
                      tooltip: 'Sửa vai trò / mật khẩu',
                      onPressed: () => _openEditSheet(a),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
