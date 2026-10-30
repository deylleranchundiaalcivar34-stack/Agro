import '../../../../core/network/supabase_service.dart';
import '../models/user_profile.dart';

/// Única puerta de acceso del cliente a perfiles de Agro+.
///
/// Las políticas RLS del proyecto garantizan que solo se pueda consultar y
/// actualizar el perfil propio. Las asignaciones de administrador no pasan por
/// este repositorio.
class ProfileRepository {
  final SupabaseService _supabaseService;

  ProfileRepository({required SupabaseService supabaseService})
      : this._(supabaseService);

  ProfileRepository._(this._supabaseService);

  static const _profileSelect =
      'id_usuario, nombres, apellidos, correo_electronico, '
      'tipos_usuario(nombre_tipo)';

  Future<UserProfile?> getCurrentProfile() async {
    final user = _supabaseService.currentUser;
    if (user == null) return null;

    final data = await _supabaseService.client
        .from('usuarios')
        .select(_profileSelect)
        .eq('id_usuario', user.id)
        .maybeSingle();

    return data == null ? null : UserProfile.fromMap(data);
  }

  Future<UserProfile> updateCurrentRole(String role) async {
    if (role == 'admin') {
      throw StateError('El rol de administrador se asigna fuera de la app.');
    }

    final user = _supabaseService.currentUser;
    if (user == null) throw StateError('No hay una sesión activa.');

    final roleData = await _supabaseService.client
        .from('tipos_usuario')
        .select('id_tipo_usuario')
        .eq('nombre_tipo', role)
        .single();

    final data = await _supabaseService.client
        .from('usuarios')
        .update({'id_tipo_usuario': roleData['id_tipo_usuario']})
        .eq('id_usuario', user.id)
        .select(_profileSelect)
        .single();

    return UserProfile.fromMap(data);
  }
}
