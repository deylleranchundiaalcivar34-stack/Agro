import '../../../../core/network/supabase_service.dart';
import '../models/profile_notification.dart';

class ProfileNotificationsRepository {
  ProfileNotificationsRepository({required this._supabaseService});

  final SupabaseService _supabaseService;

  Future<List<ProfileNotification>> listMine() async {
    final user = _supabaseService.currentUser;
    if (user == null) return const [];

    final rows = await _supabaseService.client
        .from('alertas_notificaciones')
        .select('id_notificacion,titulo,mensaje_cuerpo,leida')
        .eq('id_usuario_receptor', user.id);

    return rows
        .map((row) => ProfileNotification.fromMap(row))
        .toList(growable: false);
  }

  Future<void> markAsRead(String notificationId) async {
    final user = _supabaseService.currentUser;
    if (user == null) throw StateError('No hay una sesion activa.');

    await _supabaseService.client
        .from('alertas_notificaciones')
        .update({'leida': true})
        .eq('id_notificacion', notificationId)
        .eq('id_usuario_receptor', user.id);
  }
}
