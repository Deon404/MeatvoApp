class UserModel {
  final int id;
  final String phone;
  final String role;
  final String? name;

  const UserModel({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      name: json['name']?.toString(),
    );
  }
}
