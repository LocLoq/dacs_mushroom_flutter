import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/account_model.dart';

class AccountEditSheet extends StatefulWidget {
  const AccountEditSheet({
    super.key,
    required this.account,
    required this.roles,
    required this.onSave,
  });
  final AccountModel account;
  final List<Map<String, dynamic>> roles;
  final Future<void> Function(AccountModel, String?) onSave;
  @override
  State<AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends State<AccountEditSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.account.fullName);
  late final _phone = TextEditingController(text: widget.account.phoneNumber);
  late final _email = TextEditingController(text: widget.account.email);
  final _password = TextEditingController(),
      _confirmation = TextEditingController();
  late int _roleId = widget.account.roleId;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final role =
        widget.roles.firstWhere((row) => row['id'] == _roleId)['name']
            as String;
    final account = AccountModel(
      id: widget.account.id,
      username: widget.account.username,
      fullName: _name.text.trim(),
      phoneNumber: _phone.text.trim(),
      email: _email.text.trim(),
      roleId: _roleId,
      role: AccountRole.values.byName(role),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        account,
        _password.text.isEmpty ? null : _password.text,
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chỉnh sửa ${widget.account.username}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final entry in {
              _name: 'Họ tên',
              _phone: 'Số điện thoại',
              _email: 'Email',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: entry.key,
                  decoration: InputDecoration(labelText: entry.value),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Bắt buộc' : null,
                ),
              ),
            DropdownButtonFormField<int>(
              initialValue: widget.roles.any((row) => row['id'] == _roleId)
                  ? _roleId
                  : null,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: widget.roles
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as int,
                      child: Text(row['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _roleId = value!),
              validator: (value) =>
                  value == null ? 'Vui lòng chọn vai trò.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (để trống nếu giữ nguyên)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
              validator: (value) => value != _password.text
                  ? 'Mật khẩu xác nhận không khớp.'
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Đang lưu' : 'Lưu'),
            ),
          ],
        ),
      ),
    ),
  );
}
