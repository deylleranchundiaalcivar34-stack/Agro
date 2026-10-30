import '../../../../core/network/supabase_service.dart';
import '../models/agricultural_category.dart';
import '../models/agricultural_product.dart';

/// Source of truth for the Phase 0 catalogue and buyer pre-order interest.
/// Views do not communicate with Supabase directly.
class ProductsRepository {
  ProductsRepository({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  static const _productSelect = '''
    id_producto, id_productor, id_categoria, id_fase_actual,
    nombre_producto, cantidad_disponible, precio_unitario,
    fecha_estimada_cosecha, estado_publicacion,
    categoria:categorias_agricolas(nombre_categoria),
    fase:fases_comercializacion(nombre_fase)
  ''';

  Future<List<AgriculturalCategory>> getCategories() async {
    final rows = await _supabaseService.client
        .from('categorias_agricolas')
        .select()
        .order('nombre_categoria');
    return (rows as List)
        .map((row) => AgriculturalCategory.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AgriculturalProduct>> getPublishedProducts() async {
    final rows = await _supabaseService.client
        .from('productos')
        .select(_productSelect)
        .eq('estado_publicacion', true)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => AgriculturalProduct.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<AgriculturalProduct?> getProduct(String productId) async {
    final row = await _supabaseService.client
        .from('productos')
        .select(_productSelect)
        .eq('id_producto', productId)
        .maybeSingle();
    if (row == null) return null;
    return AgriculturalProduct.fromMap(row);
  }

  Future<void> createPreorderProduct({
    required String name,
    required int categoryId,
    required double quantity,
    required double price,
    DateTime? estimatedHarvestDate,
  }) async {
    final userId = _requireUserId();
    final phase = await _supabaseService.client
        .from('fases_comercializacion')
        .select('id_fase')
        .eq('nombre_fase', 'Preventa')
        .single();

    await _supabaseService.client.from('productos').insert({
      'id_productor': userId,
      'id_categoria': categoryId,
      'id_fase_actual': phase['id_fase'],
      'nombre_producto': name.trim(),
      'cantidad_disponible': quantity,
      'precio_unitario': price,
      'fecha_estimada_cosecha': estimatedHarvestDate
          ?.toIso8601String()
          .split('T')
          .first,
      'estado_publicacion': true,
    });
  }

  Future<void> registerInterest({
    required String productId,
    required double quantity,
  }) async {
    final userId = _requireUserId();
    await _supabaseService.client.from('intereses_preventa').upsert({
      'id_producto': productId,
      'id_comprador': userId,
      'cantidad_proyectada': quantity,
    }, onConflict: 'id_producto,id_comprador');
  }

  String _requireUserId() {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) throw StateError('La sesión ya no está disponible.');
    return userId;
  }
}
