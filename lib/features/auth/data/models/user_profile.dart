/// Perfil de dominio que complementa la sesión de Supabase Auth.
///
/// El UUID siempre corresponde a `auth.users.id`; los permisos se obtienen
/// desde PostgreSQL/RLS, no desde `user_metadata` editable por el cliente.
class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;

  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

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
    );
  }
}
