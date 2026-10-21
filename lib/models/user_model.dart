class UserModel {
  static const String roleAdmin = 'admin';
  static const String roleStaff = 'staff';

  final String uid;
  final String name;
  final String email;
  final String role;
  final bool active;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  bool get isAdmin => role == roleAdmin;
  bool get isStaff => role == roleStaff;

  String get roleLabel => isAdmin ? 'Admin' : 'Staff';

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      role: ((map['role'] as String?) ?? '').trim().toLowerCase(),
      active: (map['active'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'email': email,
      'role': role,
      'active': active,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? role,
    bool? active,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
    );
  }
}
