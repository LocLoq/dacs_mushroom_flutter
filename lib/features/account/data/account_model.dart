enum AccountRole { admin, manager, staff }

class AccountModel {
  final String id;
  final String fullName;
  final AccountRole role;
  final String assignedFacility;
  bool isActive;
  bool mustChangePassword; // true = lần đăng nhập tới bắt buộc đổi mật khẩu

  AccountModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.assignedFacility,
    required this.isActive,
    this.mustChangePassword = false,
  });
}

// ------ Mock data (thay bằng dữ liệu thật từ ApiClient) ------
final mockAccounts = [
  AccountModel(id: '1', fullName: 'Nguyễn Văn A', role: AccountRole.admin, assignedFacility: 'Trại Đơn Dương', isActive: true),
  AccountModel(id: '2', fullName: 'Trần Thị B', role: AccountRole.manager, assignedFacility: 'Trại Đức Trọng', isActive: true),
  AccountModel(id: '3', fullName: 'Lê Văn C', role: AccountRole.staff, assignedFacility: 'Trại Lạc Dương', isActive: false),
];
