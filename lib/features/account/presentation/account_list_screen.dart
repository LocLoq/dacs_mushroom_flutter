import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_session.dart';
import '../data/account_model.dart';
import 'account_edit_sheet.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key, this.onOpenNavigation});
  final VoidCallback? onOpenNavigation;
  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  final _api = ApiClient();
  List<AccountModel> _accounts = [];
  List<Map<String, dynamic>> _roles = [];
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.fetchProfile();
      final accounts = LocalSession.isAdmin
          ? await _api.fetchAccounts()
          : <AccountModel>[];
      final roles = LocalSession.isAdmin
          ? await _api.fetchRoles()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _profile = profile;
          _accounts = accounts;
          _roles = roles;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _edit(AccountModel account) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AccountEditSheet(
      account: account,
      roles: _roles,
      onSave: (updated, password) async {
        await _api.updateAccount(updated, password: password);
        if (account.id == LocalSession.user?['id'].toString() &&
            (updated.roleId != account.roleId || password != null)) {
          await LocalSession.logout();
        } else {
          await _load();
        }
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: widget.onOpenNavigation == null
          ? null
          : IconButton(
              key: const Key('home-appbar-menu-button'),
              icon: const Icon(Icons.menu_rounded),
              tooltip: tr(
                context,
                vi: 'Mở menu điều hướng',
                en: 'Open navigation menu',
              ),
              onPressed: widget.onOpenNavigation,
            ),
      title: const Text(
        'Quản lý tài khoản',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        IconButton(
          onPressed: LocalSession.logout,
          icon: const Icon(Icons.logout),
          tooltip: 'Đăng xuất',
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      _profile?['full_name']?.toString() ??
                          LocalSession.username,
                    ),
                    subtitle: Text(
                      '${LocalSession.username} · ${LocalSession.role}',
                    ),
                  ),
                ),
                if (!LocalSession.isAdmin)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chỉ Admin được quản trị tài khoản.'),
                  ),
                for (final account in _accounts)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          account.fullName.isEmpty
                              ? '?'
                              : account.fullName.characters.first,
                        ),
                      ),
                      title: Text(
                        account.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${account.username} · ${account.role.name}\n${account.email}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _edit(account),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}
