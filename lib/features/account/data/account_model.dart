enum AccountRole { admin, manager, staff }

class AccountModel {
  final String id, username, fullName, phoneNumber, email;
  final AccountRole role;
  final int roleId;
  const AccountModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.roleId,
    required this.phoneNumber,
    required this.email,
  });
  factory AccountModel.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    return AccountModel(
      id: json['id'].toString(),
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      email: json['email'] as String,
      roleId: (json['role_id'] as num?)?.toInt() ?? 0,
      role: AccountRole.values.byName(
        (role is Map ? role['name'] : role).toString(),
      ),
    );
  }
}
