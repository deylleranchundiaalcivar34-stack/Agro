import '../../../../core/network/supabase_service.dart';
import '../models/ecuador_mobile_phone.dart';

class PrivateContactProfileRepository {
  PrivateContactProfileRepository({required SupabaseService supabaseService})
    : _service = supabaseService;

  final SupabaseService _service;

  String get _userId {
    final id = _service.currentUser?.id;
    if (id == null) throw StateError('Inicia sesión para editar tus datos.');
    return id;
  }

  Future<String?> getMine() async {
    final row = await _service.client
        .from('perfiles_contacto_privados')
        .select('telefono_celular')
        .eq('id_usuario', _userId)
        .maybeSingle();
    return row?['telefono_celular'] as String?;
  }

  Future<void> saveMine({required String? phone}) async {
    final cleanedPhone = phone?.trim();
    final normalizedPhone = cleanedPhone == null || cleanedPhone.isEmpty
        ? null
        : cleanedPhone;
    if (normalizedPhone != null &&
        !EcuadorMobilePhone.internationalPattern.hasMatch(normalizedPhone)) {
      throw ArgumentError(
        'El celular debe estar en formato +593 seguido de 9 dígitos.',
      );
    }

    await _service.client.from('perfiles_contacto_privados').upsert({
      'id_usuario': _userId,
      'telefono_celular': normalizedPhone,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id_usuario');
  }
}
