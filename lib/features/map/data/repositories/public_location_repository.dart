import '../../../../core/network/supabase_service.dart';
import '../models/public_producer_location.dart';

class PublicLocationRepository {
  PublicLocationRepository({required SupabaseService supabaseService})
    : _service = supabaseService;

  final SupabaseService _service;
  static const table = 'ubicaciones_productores_publicas';

  Future<List<PublicProducerLocation>> listPublished() async {
    final rows = await _service.client
        .from(table)
        .select('id_productor,alias_publico,nombre_lugar,latitud,longitud');
    return (rows as List)
        .map(
          (row) => PublicProducerLocation.fromMap(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<PublicProducerLocation?> getMine() async {
    final row = await _service.client
        .from(table)
        .select('id_productor,alias_publico,nombre_lugar,latitud,longitud')
        .eq('id_productor', _requireUser())
        .maybeSingle();
    return row == null ? null : PublicProducerLocation.fromMap(row);
  }

  Future<PublicProducerLocation> saveMine({
    required String alias,
    required String placeName,
    required double latitude,
    required double longitude,
  }) async {
    final location = PublicProducerLocation.manual(
      producerId: _requireUser(),
      alias: alias,
      placeName: placeName,
      latitude: latitude,
      longitude: longitude,
    );
    final row = await _service.client
        .from(table)
        .upsert(location.toMap(), onConflict: 'id_productor')
        .select('id_productor,alias_publico,nombre_lugar,latitud,longitud')
        .single();
    return PublicProducerLocation.fromMap(row);
  }

  Future<void> removeMine() async {
    await _service.client
        .from(table)
        .delete()
        .eq('id_productor', _requireUser());
  }

  String _requireUser() {
    final userId = _service.currentUser?.id;
    if (userId == null) {
      throw StateError('Inicia sesion para publicar tu zona.');
    }
    return userId;
  }
}
