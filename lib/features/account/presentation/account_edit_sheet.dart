import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../data/account_model.dart';

// Gồm 2 khối tách biệt trong cùng 1 BottomSheet:
//  1) Đổi vai trò (role) + cơ sở phụ trách -> gọi onSaveRole
//  2) Đặt mật khẩu mới (KHÔNG hiển thị mật khẩu cũ, vì backend không bao giờ
//     trả plaintext password về — chỉ có thể "set" mật khẩu mới, không "xem")

class AccountEditSheet extends StatefulWidget {
  final AccountModel account;
  final Future<void> Function(AccountRole role, String facility) onSaveRole;
  final Future<void> Function(String newPassword, bool mustChangePassword) onSavePassword;

  const AccountEditSheet({
    super.key,
    required this.account,
    required this.onSaveRole,
    required this.onSavePassword,
  });

  @override
  State<AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends State<AccountEditSheet> {
  late AccountRole _role = widget.account.role;
  late final _facilityCtrl = TextEditingController(text: widget.account.assignedFacility);

  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _savingRole = false;
  bool _savingPassword = false;
  String? _passwordError;
  late bool _mustChangePassword = widget.account.mustChangePassword;

  String _roleLabel(AccountRole r) => switch (r) {
        AccountRole.admin => 'Admin',
        AccountRole.manager => 'Manager',
        AccountRole.staff => 'Staff',
      };

  Future<void> _submitRole() async {
    setState(() => _savingRole = true);
    try {
      await widget.onSaveRole(_role, _facilityCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật vai trò')),
      );
    } finally {
      if (mounted) setState(() => _savingRole = false);
    }
  }

  Future<void> _submitPassword() async {
    // TODO(BACKEND): áp policy mật khẩu thật của bạn (độ dài, ký tự đặc biệt...)
    // ở cả đây (UX) và ở Django serializer (bảo mật — không tin client).
    if (_newPassCtrl.text.length < 6) {
      setState(() => _passwordError = 'Mật khẩu phải từ 6 ký tự trở lên');
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _passwordError = 'Mật khẩu xác nhận không khớp');
      return;
    }
    setState(() { _passwordError = null; _savingPassword = true; });
    try {
      await widget.onSavePassword(_newPassCtrl.text, _mustChangePassword);
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đặt mật khẩu mới')),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(widget.account.fullName.characters.first,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.account.fullName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 32),

            // ---- Khối 1: Vai trò + cơ sở phụ trách ----
            const Text('Vai trò & phân công', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: AccountRole.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 12),
            CustomTextField(label: 'Cơ sở phụ trách', controller: _facilityCtrl),
            const SizedBox(height: 14),
            CustomButton(
              label: 'Lưu vai trò',
              onPressed: _submitRole,
              loading: _savingRole,
              icon: Icons.badge_outlined,
            ),

            const Divider(height: 36),

            // ---- Khối 2: Đặt mật khẩu mới ----
            const Text('Đặt lại mật khẩu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
              'Vì lý do bảo mật, hệ thống không hiển thị mật khẩu hiện tại — bạn chỉ có thể đặt mật khẩu mới.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Mật khẩu mới',
              controller: _newPassCtrl,
              obscure: _obscureNew,
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Xác nhận mật khẩu mới',
              controller: _confirmPassCtrl,
              obscure: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            if (_passwordError != null) ...[
              const SizedBox(height: 8),
              Text(_passwordError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            CustomButton(
              label: 'Cập nhật mật khẩu',
              onPressed: _submitPassword,
              loading: _savingPassword,
              icon: Icons.lock_reset,
            ),

            // ---- Checkbox: buộc đổi mật khẩu lần đăng nhập tới ----
            // Đặt ở cuối cùng, dưới nút "Cập nhật mật khẩu": vẫn dùng chung biến _mustChangePassword
            // và vẫn được gửi kèm trong _submitPassword() phía trên, chỉ đổi VỊ TRÍ hiển thị.
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _mustChangePassword,
              onChanged: (v) => setState(() => _mustChangePassword = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Buộc đổi mật khẩu lần đăng nhập tiếp theo'),
            ),
          ],
        ),
      ),
    );
  }
}
