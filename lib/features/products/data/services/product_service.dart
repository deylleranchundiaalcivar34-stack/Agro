
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../models/product_model.dart';

class ProductService {
  final SupabaseService _supabaseService;

  ProductService({
    required this._supabaseService,
  });

  SupabaseClient get _client => _supabaseService.client;

  // ==========================================
  // 1. CREAR PRODUCTO
  // ==========================================

  Future<ProductModel> createProduct(ProductModel product) async {
    final response = await _client
        .from('productos')
        .insert(product.toJson())
        .select()
        .single();

    return ProductModel.fromJson(response);
  }

  // ==========================================
  // 2. CONSULTAR PRODUCTOS DE UN PRODUCTOR
  // ==========================================

  Future<List<ProductModel>> getProductsByProducer(
    String idProductor,
  ) async {
    final response = await _client
        .from('productos')
        .select('*, fotografias_producto(url_fotografia)')
        .eq('id_productor', idProductor)
        .order('created_at', ascending: false);

    return response.map((json) {
      final data = Map<String, dynamic>.from(json);

      final photos = data['fotografias_producto'] as List? ?? [];

      data['fotografias'] = photos
          .map((photo) => photo['url_fotografia'] as String)
          .toList();

      return ProductModel.fromJson(data);
    }).toList();
  }

  // ==========================================
  // 3. CONSULTAR UN PRODUCTO POR SU ID
  // ==========================================

  Future<ProductModel> getProductById(String idProducto) async {
    final response = await _client
        .from('productos')
        .select('*, fotografias_producto(url_fotografia)')
        .eq('id_producto', idProducto)
        .single();

    final data = Map<String, dynamic>.from(response);

    final photos = data['fotografias_producto'] as List? ?? [];

    data['fotografias'] = photos
        .map((photo) => photo['url_fotografia'] as String)
        .toList();

    return ProductModel.fromJson(data);
  }

  // ==========================================
  // 4. ACTUALIZAR PRODUCTO
  // ==========================================

  Future<ProductModel> updateProduct(ProductModel product) async {
    if (product.idProducto == null) {
      throw Exception('El producto no tiene un identificador.');
    }

    final response = await _client
        .from('productos')
        .update(product.toJson())
        .eq('id_producto', product.idProducto!)
        .select()
        .single();

    return ProductModel.fromJson(response);
  }

  // ==========================================
  // 5. DESACTIVAR PUBLICACIÓN
  // ==========================================

  Future<void> deactivateProduct(String idProducto) async {
    await _client
        .from('productos')
        .update({'estado_publicacion': false})
        .eq('id_producto', idProducto);
  }

  // ==========================================
  // 6. ELIMINAR PRODUCTO
  // ==========================================

  Future<void> deleteProduct(String idProducto) async {
    await _client
        .from('productos')
        .delete()
        .eq('id_producto', idProducto);
  }
}
