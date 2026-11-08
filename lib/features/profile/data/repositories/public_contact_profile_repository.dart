import '../../../../core/network/supabase_service.dart';
import '../models/public_contact_profile.dart';

class PublicContactProfileRepository {
  PublicContactProfileRepository({required SupabaseService supabaseService})
    : _service = supabaseService;

  final SupabaseService _service;

  static const _columns =
      'id_usuario,nombre_publico,avatar_url,telefono_whatsapp,whatsapp_visible';

  String get _userId {
    final id = _service.currentUser?.id;
    if (id == null) throw StateError('Inicia sesion para editar tu perfil.');
    return id;
  }

  Future<PublicContactProfile?> getMine() async {
    final row = await _service.client
        .from('perfiles_contacto_publicos')
        .select(_columns)
        .eq('id_usuario', _userId)
        .maybeSingle();
    return row == null ? null : PublicContactProfile.fromMap(row);
  }

  Future<Map<String, PublicContactProfile>> getMany(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _service.client
        .from('perfiles_contacto_publicos')
        .select(_columns)
        .inFilter('id_usuario', ids);
    return {
      for (final row in rows as List)
        (row['id_usuario'] as String): PublicContactProfile.fromMap(
          row as Map<String, dynamic>,
        ),
    };
  }

  Future<PublicContactProfile> saveMine({
    required String displayName,
    required String? avatarUrl,
    required bool whatsappVisible,
    required String whatsappPhone,
  }) async {
    final cleanName = displayName.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw ArgumentError(
        'El nombre publico debe tener entre 1 y 80 caracteres.',
      );
    }

    final cleanAvatarUrl = avatarUrl?.trim();
    final parsedAvatarUrl = cleanAvatarUrl == null || cleanAvatarUrl.isEmpty
        ? null
        : Uri.tryParse(cleanAvatarUrl);
    if (cleanAvatarUrl != null &&
        cleanAvatarUrl.isNotEmpty &&
        (parsedAvatarUrl == null ||
            parsedAvatarUrl.scheme != 'https' ||
            parsedAvatarUrl.host.isEmpty)) {
      throw ArgumentError('La foto debe tener una direccion HTTPS valida.');
    }

    final normalizedPhone = whatsappVisible
        ? whatsappPhone.replaceAll(RegExp(r'[\s()\-]'), '')
        : null;
    if (whatsappVisible &&
        (normalizedPhone == null ||
            !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(normalizedPhone))) {
      throw ArgumentError(
        'Escribe el numero en formato internacional, por ejemplo +593...',
      );
    }

    final row = await _service.client
        .from('perfiles_contacto_publicos')
        .upsert({
          'id_usuario': _userId,
          'nombre_publico': cleanName,
          'avatar_url': parsedAvatarUrl?.toString(),
          'telefono_whatsapp': normalizedPhone,
          'whatsapp_visible': whatsappVisible,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'id_usuario')
        .select(_columns)
        .single();
    return PublicContactProfile.fromMap(row);
  }
}
