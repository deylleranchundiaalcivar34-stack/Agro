import '../../../../core/network/supabase_service.dart';
import '../models/contact_request.dart';

class ContactRequestsRepository {
  ContactRequestsRepository({required SupabaseService supabaseService})
    : _service = supabaseService;

  final SupabaseService _service;

  String get currentUserId =>
      _service.currentUser?.id ??
      (throw StateError('Inicia sesion para continuar.'));

  static const _select =
      'id_solicitud,id_producto,id_comprador,cantidad_solicitada,'
      'mensaje_inicial,estado_solicitud,id_chat,created_at,'
      'producto:productos!solicitudes_contacto_id_producto_fkey(nombre_producto,unidad_medida)';

  Future<ContactRequest> create({
    required String productId,
    required double quantity,
    required String initialMessage,
  }) async {
    final row = await _service.client
        .from('solicitudes_contacto')
        .insert({
          'id_producto': productId,
          'id_comprador': currentUserId,
          'cantidad_solicitada': quantity,
          'mensaje_inicial': initialMessage.trim(),
        })
        .select(_select)
        .single();
    return ContactRequest.fromMap(row);
  }

  Future<List<ContactRequest>> listMine() async {
    final rows = await _service.client
        .from('solicitudes_contacto')
        .select(_select)
        .order('created_at', ascending: false);
    final requestRows = (rows as List).cast<Map<String, dynamic>>();
    if (requestRows.isEmpty) return const [];

    final buyerIds = requestRows
        .map((row) => row['id_comprador'] as String?)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final buyerRows = buyerIds.isEmpty
        ? const <dynamic>[]
        : await _service.client
              .from('perfiles_contacto_publicos')
              .select('id_usuario,nombre_publico')
              .inFilter('id_usuario', buyerIds);
    final buyerNames = {
      for (final row in buyerRows)
        row['id_usuario'] as String: row['nombre_publico'] as String?,
    };

    return requestRows
        .map(
          (row) => ContactRequest.fromMap({
            ...row,
            'comprador': {'nombre_publico': buyerNames[row['id_comprador']]},
          }),
        )
        .toList(growable: false);
  }

  Future<String?> respond({
    required String requestId,
    required bool accept,
  }) async {
    final result = await _service.client.rpc(
      'respond_to_contact_request',
      params: {'p_solicitud': requestId, 'p_aceptar': accept},
    );
    return result as String?;
  }
}
