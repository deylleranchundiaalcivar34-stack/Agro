import '../../../../core/network/supabase_service.dart';
import '../models/profile_order.dart';

class ProfileOrdersRepository {
  ProfileOrdersRepository({required this._supabaseService});

  final SupabaseService _supabaseService;

  Future<List<ProfileOrder>> listMine() async {
    final user = _supabaseService.currentUser;
    if (user == null) return const [];

    final rows = await _supabaseService.client
        .from('pedidos')
        .select(
          'id_pedido,id_comprador,id_productor,monto_total,estado_pedido,'
          'detalles_pedido(id_detalle,cantidad_solicitada,productos(nombre_producto))',
        )
        .or('id_comprador.eq.${user.id},id_productor.eq.${user.id}');

    return rows.map((row) => ProfileOrder.fromMap(row)).toList(growable: false);
  }
}
