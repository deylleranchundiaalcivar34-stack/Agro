import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../../../products/data/models/agricultural_product.dart';
import '../models/favorite_product.dart';

/// Persistencia privada por usuario para publicaciones guardadas.
class FavoritesRepository {
  FavoritesRepository({required this._supabaseService});

  final SupabaseService _supabaseService;
  String? get currentUserId => _supabaseService.currentUser?.id;
  Stream<AuthState> get authStateChanges => _supabaseService.authStateChanges;

  static const _productSelect = '''
    id_producto, id_productor, id_categoria, id_fase_actual,
    nombre_producto, cantidad_disponible, precio_unitario,
    fecha_estimada_cosecha, estado_publicacion, unidad_medida,
    categoria:categorias_agricolas(nombre_categoria),
    fase:fases_comercializacion(nombre_fase),
    fotografias_producto(id_fotografia, url_fotografia)
  ''';

  Future<List<FavoriteProduct>> getFavorites() async {
    final userId = currentUserId;
    if (userId == null) return const [];

    final rows = await _supabaseService.client
        .from('productos_favoritos')
        .select(
          'id_producto, created_at, '
          'producto:productos!productos_favoritos_id_producto_fkey($_productSelect)',
        )
        .eq('id_usuario', userId)
        .order('created_at', ascending: false);

    return (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final nested = map['producto'];
      return FavoriteProduct(
        productId: map['id_producto'] as String,
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        product: nested is Map<String, dynamic>
            ? AgriculturalProduct.fromMap(nested)
            : null,
      );
    }).toList();
  }

  Future<void> add(String productId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('Inicia sesión para guardar favoritos.');
    }
    await _supabaseService.client
        .from('productos_favoritos')
        .upsert(
          {'id_usuario': userId, 'id_producto': productId},
          onConflict: 'id_usuario,id_producto',
          ignoreDuplicates: true,
        );
  }

  Future<void> remove(String productId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('Inicia sesión para gestionar favoritos.');
    }
    await _supabaseService.client
        .from('productos_favoritos')
        .delete()
        .eq('id_usuario', userId)
        .eq('id_producto', productId);
  }
}
