import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/account_model.dart';
import 'account_edit_sheet.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

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

  Future<void> _toggleLock(AccountModel a) async {
    // TODO(BACKEND): ApiClient.toggleAccountLock(a.id) -> PATCH is_active
    await _api.toggleAccountLock(a.id);
    setState(() => a.isActive = !a.isActive);
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
          setState(() {
            _accounts[_accounts.indexOf(a)] = AccountModel(
              id: a.id,
              fullName: a.fullName,
              role: role,
              assignedFacility: facility,
              isActive: a.isActive,
            );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý tài khoản')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _accounts.length,
              itemBuilder: (context, i) {
                final a = _accounts[i];
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: AppColors.textSecondary),
                          tooltip: 'Sửa vai trò / mật khẩu',
                          onPressed: () => _openEditSheet(a),
                        ),
                        Switch(
                          value: a.isActive,
                          activeColor: AppColors.primary,
                          onChanged: (_) => _toggleLock(a),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
