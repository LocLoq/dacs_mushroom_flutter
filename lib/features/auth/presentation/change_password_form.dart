import 'package:flutter/material.dart';

import '../../../core/network/farm_api.dart';
import '../../../core/storage/local_session.dart';

/// Shown in the management tab until the server accepts a new password.
class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({super.key});

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final current = _current.text;
    final next = _next.text;
    final error = current.isEmpty || next.isEmpty
        ? 'Vui lòng nhập mật khẩu hiện tại và mật khẩu mới.'
        : next == current
        ? 'Mật khẩu mới phải khác mật khẩu hiện tại.'
        : next != _confirm.text
        ? 'Xác nhận mật khẩu không khớp.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FarmApi.instance.changePassword(current, next);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AutofillGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Đổi mật khẩu để tiếp tục',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Quản trị viên yêu cầu bạn đổi mật khẩu trước khi sử dụng chức năng quản lý.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _current,
          enabled: !_busy,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _next,
          enabled: !_busy,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirm,
          enabled: !_busy,
          obscureText: _obscure,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hiện mật khẩu'),
          value: !_obscure,
          onChanged: _busy
              ? null
              : (value) => setState(() => _obscure = !(value ?? false)),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Đang lưu…' : 'Đổi mật khẩu'),
        ),
        TextButton(
          onPressed: _busy ? null : LocalSession.logout,
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
  );
}
