import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';

/// Quản lý người dùng — chỉ admin (specs/S14_USERS.md).
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _api = FarmApi.instance;
  final _key = GlobalKey<PagedListViewState>();

  /// Mỗi lần mở form đều GET roles trước — KHÔNG hardcode role_id.
  Future<Map<String, String>?> _roles() async {
    try {
      final r = (await _api.get('/admin/roles')).l('data');
      return {for (final x in r) x.i('id').toString(): label(roleLabels, x.sn('name'))};
    } on ApiException catch (e) {
      if (!mounted) return null;
      final retry = await confirmDialog(context,
          title: 'Không tải được danh sách vai trò', message: e.message, ok: 'Thử lại');
      return retry ? _roles() : null; // không thay bằng ID giả
    }
  }

  Future<void> _create() async {
    final roles = await _roles();
    if (roles == null || !mounted) return;
    final ok = await showFormSheet(
      context,
      title: 'Thêm người dùng',
      fields: [
        const FieldDef('username', 'Tên đăng nhập', FieldType.text, required: true, maxLen: 191),
        const FieldDef('password', 'Mật khẩu', FieldType.password, required: true),
        const FieldDef('full_name', 'Họ và tên', FieldType.text, required: true),
        const FieldDef('phone_number', 'Số điện thoại', FieldType.text, required: true),
        const FieldDef('email', 'Email', FieldType.text, required: true),
        FieldDef('role_id', 'Vai trò', FieldType.choice, required: true, options: roles),
      ],
      onSubmit: (b) => _api.post('/admin/users', {...b, 'role_id': int.parse(b['role_id'].toString())}),
    );
    if (ok) _key.currentState?.load();
  }

  Future<void> _edit(J u) async {
    final roles = await _roles();
    if (roles == null || !mounted) return;
    final oldRole = u.i('role_id');
    final ok = await showFormSheet(
      context,
      title: 'Sửa ${u.s('username')}', // username bị khoá, không gửi
      fields: [
        const FieldDef('full_name', 'Họ và tên', FieldType.text, required: true),
        // Chỉ mở sửa khi dòng có field tương ứng.
        if (u.containsKey('phone_number')) const FieldDef('phone_number', 'Số điện thoại', FieldType.text),
        if (u.containsKey('email')) const FieldDef('email', 'Email', FieldType.text),
        const FieldDef('password', 'Mật khẩu mới', FieldType.password, helper: 'Để trống nếu không đổi'),
        FieldDef('role_id', 'Vai trò', FieldType.choice, options: roles),
      ],
      initial: {...u, 'password': '', 'role_id': oldRole?.toString()},
      isEdit: true,
      onSubmit: (b) async {
        final body = {...b};
        // Backend bỏ qua liên hệ rỗng (không xoá được) nên không hứa xoá.
        // role_id/password làm tăng phiên bản token -> chỉ gửi role_id khi thật sự đổi.
        final newRole = int.tryParse((body['role_id'] ?? '').toString());
        if (newRole == null || newRole == oldRole) {
          body.remove('role_id');
        } else {
          body['role_id'] = newRole;
        }
        await _api.put('/admin/users/${u.i('id')}', body);
      },
    );
    if (ok) _key.currentState?.load();
  }

  Future<void> _delete(J u) async {
    final yes = await confirmDialog(context,
        title: 'Xóa người dùng?', message: 'Xóa tài khoản "${u.s('username')}". Không hoàn tác.', ok: 'Xóa', danger: true);
    if (!yes) return;
    try {
      await _api.delete('/admin/users/${u.i('id')}');
      if (mounted) toast(context, 'Đã xóa');
      _key.currentState?.load(); // chỉ refresh sau khi server thành công
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Người dùng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Thêm'),
      ),
      body: PagedListView(
        key: _key,
        searchHint: 'Tìm tên đăng nhập, họ tên',
        emptyText: 'Chưa có người dùng nào.',
        fetch: (p, s) async => PageData.from(await _api.get('/admin/users', query: {'page': p, 'limit': 10, 'search': s})),
        itemBuilder: (ctx, u, _) {
          final role = u.m('role')?.sn('name'); // admin/users.role là object
          return SoftCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(_initial(u.s('full_name').isEmpty ? u.s('username') : u.s('full_name'))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.s('full_name').isEmpty ? u.s('username') : u.s('full_name'), style: theme.textTheme.titleSmall),
                  Text('@${u.s('username')}${u.sn('email') == null ? '' : ' · ${u.s('email')}'}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  StatusChip(text: label(roleLabels, role), color: role == 'admin' ? Colors.deepPurple : statusColor(null)),
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? _edit(u) : _delete(u),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'del', child: Text('Xóa')),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }
}

String _initial(String s) => s.isEmpty ? '?' : s.substring(0, 1).toUpperCase();
