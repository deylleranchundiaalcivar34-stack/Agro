import '../../../../core/network/supabase_service.dart';
import '../models/agricultural_category.dart';
import '../models/agricultural_product.dart';

import 'package:image_picker/image_picker.dart';

import '../services/product_storage_service.dart';

class ProductPublicationException implements Exception {
  const ProductPublicationException(this.message, {this.productId});
  final String message;
  final String? productId;
}

/// Source of truth for the Phase 0 catalogue and buyer pre-order interest.
/// Views do not communicate with Supabase directly.
class ProductsRepository {
  ProductsRepository({
    required this._supabaseService,
    ProductStorageService? storageService,
  }) : _storageService = storageService ?? ProductStorageService();

  final SupabaseService _supabaseService;
  final ProductStorageService _storageService;

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
    XFile? image,
  }) async {
    final userId = _requireUserId();

    // Identificar la fase de preventa.
    final phase = await _supabaseService.client
        .from('fases_comercializacion')
        .select('id_fase')
        .eq('nombre_fase', 'Preventa')
        .single();

    // Subir la fotografía a Cloudinary, si se seleccionó una.
    String? imageUrl;

    if (image != null) {
      try {
        imageUrl = await _storageService.subirImagen(image);
      } on ProductUploadException {
        rethrow;
      } catch (_) {
        throw const ProductUploadException(
          'No se pudo subir la fotografía. Revisa tu conexión e intenta de nuevo.',
        );
      }
    }

    // Registrar el producto y recuperar su identificador.
    late String productId;
    try {
      final product = await _supabaseService.client
          .from('productos')
          .insert({
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
          })
          .select('id_producto')
          .single();

      productId = product['id_producto'].toString();
    } catch (_) {
      throw const ProductPublicationException(
        'No se pudo confirmar la creación del producto. Revisa tus publicaciones antes de reintentar.',
      );
    }

    // Asociar la fotografía al producto en Supabase.
    if (imageUrl != null) {
      try {
        await _supabaseService.client.from('fotografias_producto').insert({
          'id_producto': productId,
          'url_fotografia': imageUrl,
        });
      } catch (_) {
        throw ProductPublicationException(
          'El producto se guardó, pero no se pudo confirmar la asociación de la fotografía. '
          'Revisa la publicación antes de reintentar.',
          productId: productId,
        );
      }
    }
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
