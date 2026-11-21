import '../../../../core/network/supabase_service.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  final SupabaseService _supabaseService;

  ProfileRepository({required SupabaseService supabaseService})
    : this._(supabaseService);

  ProfileRepository._(this._supabaseService);

  static const _profileSelect =
      'id_usuario, nombres, apellidos, correo_electronico, nombre_empresa, '
      'tipos_usuario(nombre_tipo)';

  Future<UserProfile?> getCurrentProfile({bool includeAvatar = false}) async {
    final user = _supabaseService.currentUser;
    if (user == null) return null;

    final data = await _supabaseService.client
        .from('usuarios')
        .select(_profileSelect)
        .eq('id_usuario', user.id)
        .maybeSingle();

    if (data == null) return null;

    String? avatarUrl;
    if (includeAvatar) {
      try {
        final publicProfile = await _supabaseService.client
            .from('perfiles_contacto_publicos')
            .select('avatar_url')
            .eq('id_usuario', user.id)
            .maybeSingle();
        avatarUrl = publicProfile?['avatar_url'] as String?;
      } catch (_) {
        // An optional public avatar must not block a valid account sign-in.
      }
    }
    return UserProfile.fromMap({...data, 'avatar_url': avatarUrl});
  }

  Future<UserProfile> updateCurrentRole(String role) async {
    if (role == 'admin') {
      throw StateError('El rol de administrador se asigna fuera de la app.');
    }

    final user = _supabaseService.currentUser;
    if (user == null) throw StateError('No hay una sesion activa.');

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

  Future<UserProfile> updateCurrentData({
    required String firstName,
    required String lastName,
    required String companyName,
  }) async {
    final user = _supabaseService.currentUser;
    if (user == null) throw StateError('No hay una sesion activa.');

    final data = await _supabaseService.client
        .from('usuarios')
        .update({
          'nombres': firstName.trim(),
          'apellidos': lastName.trim(),
          'nombre_empresa': companyName.trim().isEmpty
              ? null
              : companyName.trim(),
        })
        .eq('id_usuario', user.id)
        .select(_profileSelect)
        .single();

    return UserProfile.fromMap(data);
  }
}
