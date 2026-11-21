class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String companyName;
  final String? avatarUrl;

  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.companyName = '',
    this.avatarUrl,
  });

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? role,
    String? companyName,
    String? avatarUrl,
  }) => UserProfile(
    id: id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    role: role ?? this.role,
    companyName: companyName ?? this.companyName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email.split('@').first : name;
  }

  String get initial => fullName.isEmpty ? 'A' : fullName[0].toUpperCase();

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final roleData = map['tipos_usuario'];
    final role = roleData is Map<String, dynamic>
        ? roleData['nombre_tipo'] as String?
        : null;

    return UserProfile(
      id: map['id_usuario'] as String,
      firstName: map['nombres'] as String? ?? '',
      lastName: map['apellidos'] as String? ?? '',
      email: map['correo_electronico'] as String? ?? '',
      role: role ?? 'buyer',
      companyName: map['nombre_empresa'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
