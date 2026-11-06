// Acceso a datos del catálogo y coordinación del alta de preventas con fotografía.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../models/agricultural_category.dart';
import '../models/agricultural_product.dart';
import '../models/product_quantity.dart';
import '../models/product_unit.dart';

import 'package:image_picker/image_picker.dart';

import '../services/product_storage_service.dart';
import '../services/product_service.dart';
import '../../../auth/data/repositories/profile_repository.dart';

/// Distingue errores de validación, creación incierta y guardado parcial de fotografías.
class ProductPublicationException implements Exception {
  const ProductPublicationException(
    this.message, {
    this.productId,
    this.requiresReview = false,
  });
  final String message;
  // Un ID conocido indica que el producto ya se creó; requiresReview bloquea reintentos inciertos.
  final String? productId;
  final bool requiresReview;
}

/// Fuente de datos para el catálogo de preventas y los intereses de compradores.
/// Las vistas delegan sus operaciones; no consultan Supabase directamente.
class ProductsRepository {
  ProductsRepository({
    required this._supabaseService,
    ProductStorageService? storageService,
  }) : _storageService = storageService ?? ProductStorageService();

  final SupabaseService _supabaseService;
  final ProductStorageService _storageService;
  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Lista privada del productor: no filtrar estado para incluir visibles y ocultos.
  Future<List<AgriculturalProduct>> getMyProducts() async {
    final userId = _requireUserId();
    final profile = await ProfileRepository(supabaseService: _supabaseService)
        .getCurrentProfile();
    if (profile == null || profile.id != userId || profile.role != 'producer') {
      throw const ProductEditException('Esta sección es para productores.');
    }
    final rows = await _withOptionalUnit(
      (select) async => await _supabaseService.client
          .from('productos')
          .select(select)
          .eq('id_productor', userId)
          .order('created_at', ascending: false),
    );
    return rows.map((row) => AgriculturalProduct.fromMap(row)).toList();
  }

  /// La misma comprobación de rol y propiedad protege ambos cambios de visibilidad.
  Future<void> setVisibility(String productId, bool visible) =>
      ProductService(supabaseService: _supabaseService)
          .setVisibility(productId, visible);

  // Campos y alias comunes del catálogo y detalle; las fotografías son una relación hija.
  static const _productSelect = '''
    id_producto, id_productor, id_categoria, id_fase_actual,
    nombre_producto, cantidad_disponible, precio_unitario,
    fecha_estimada_cosecha, estado_publicacion,
    categoria:categorias_agricolas(nombre_categoria),
    fase:fases_comercializacion(nombre_fase),
    fotografias_producto(id_fotografia, url_fotografia)
  ''';

  // La unidad es opcional para lectura mientras el esquema remoto no la tenga.
  // No ocultar errores de otras columnas, relaciones ni permisos.
  Future<T> _withOptionalUnit<T>(
    Future<T> Function(String select) query,
  ) async {
    try {
      return await query('unidad_medida, $_productSelect');
    } on PostgrestException catch (error) {
      var code = error.code;
      var message = error.message;
      // maybeSingle del SDK puede envolver un error con su estado HTTP y JSON.
      if (code == '400') {
        try {
          final body = jsonDecode(message);
          if (body is Map &&
              body['code'] is String &&
              body['message'] is String) {
            code = body['code'] as String;
            message = body['message'] as String;
          }
        } on FormatException {
          // No es un error JSON estructurado; propagar la excepción original.
        }
      }
      if (code != '42703' || !message.contains('productos.unidad_medida')) {
        rethrow;
      }
      if (kDebugMode) {
        debugPrint(
          '[ProductsRepository] productos.unidad_medida no existe (42703). '
          'Se consulta sin unidad; no se modifica el esquema.',
        );
      }
      return await query(_productSelect);
    }
  }

  /// Carga las categorías ordenadas que utilizan los filtros y formularios.
  Future<List<AgriculturalCategory>> getCategories() async {
    final rows = await _supabaseService.client
        .from('categorias_agricolas')
        .select()
        .order('nombre_categoria');
    return (rows as List)
        .map((row) => AgriculturalCategory.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Consulta publicaciones activas, sus relaciones y el orden de creación descendente.
  Future<List<AgriculturalProduct>> getPublishedProducts() async {
    final rows = await _withOptionalUnit(
      (select) async => await _supabaseService.client
          .from('productos')
          .select(select)
          .eq('estado_publicacion', true)
          .order('created_at', ascending: false),
    );
    return (rows as List)
        .map((row) => AgriculturalProduct.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Busca un lote por ID; una publicación inactiva solo se devuelve a su propietario.
  Future<AgriculturalProduct?> getProduct(String productId) async {
    final row = await _withOptionalUnit(
      (select) async => await _supabaseService.client
          .from('productos')
          .select(select)
          .eq('id_producto', productId)
          .maybeSingle(),
    );
    if (row == null) return null;
    if (row['estado_publicacion'] != true &&
        row['id_productor'] != _supabaseService.currentUser?.id) {
      return null;
    }
    return AgriculturalProduct.fromMap(row);
  }

  /// Delega la retirada lógica en el servicio que comprueba sesión, rol y propiedad.
  Future<void> deleteProduct(String productId) =>
      ProductService(supabaseService: _supabaseService)
          .deleteProduct(productId);

  /// Guarda cantidad y unidad sin modificar el resto de la publicación.
  Future<void> updateQuantity(
    String productId,
    double quantity, {
    ProductUnit? unit,
  }) =>
      ProductService(supabaseService: _supabaseService)
          .updateQuantity(productId, quantity, unit: unit);

  /// Recupera el modelo actual y delega una edición que conserva su fase comercial.
  Future<void> updateProduct({
    required String productId,
    required String name,
    required int categoryId,
    required double quantity,
    required double price,
    ProductUnit? unit,
    required bool isPublished,
    DateTime? harvest,
    XFile? image,
  }) async {
    // Rechazar accesos directos sin sesión o sin unidad antes de consultar el producto.
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) {
      throw const ProductEditException('Inicia sesión como productor.');
    }
    if (unit == null) {
      throw const ProductEditException('Selecciona la unidad de medida.');
    }
    final service = ProductService(
      supabaseService: _supabaseService,
      storageService: _storageService,
    );
    final current = await service.getProductById(productId);
    if (current.idProductor != userId) {
      throw const ProductEditException('Solo puedes editar tus publicaciones.');
    }
    await service.updateProduct(
      current.copyWith(
        nombreProducto: name,
        idCategoria: categoryId,
        cantidadDisponible: quantity,
        unidadMedida: unit,
        precioUnitario: price,
        estadoPublicacion: isPublished,
        fechaEstimadaCosecha: harvest,
        clearHarvestDate: harvest == null,
      ),
      image: image,
    );
  }

  /// Valida, resuelve la fase Preventa, sube la imagen y registra producto y URL en ese orden.
  Future<void> createPreorderProduct({
    required String name,
    required int categoryId,
    required double quantity,
    required double price,
    ProductUnit? unit,
    DateTime? estimatedHarvestDate,
    XFile? image,
  }) async {
    final userId = _requireUserId();
    if (name.trim().length < 3 || !price.isFinite || price < 0) {
      throw const ProductPublicationException(
        'Revisa el nombre y el precio del producto.',
      );
    }
    if (unit == null) {
      throw const ProductPublicationException(
        'Selecciona la unidad de medida.',
      );
    }
    final quantityError = ProductQuantity.validate(
      quantity.toString(),
      unit: unit,
    );
    if (quantityError != null) throw ProductPublicationException(quantityError);

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

    // Estas operaciones no forman una transacción conjunta con Cloudinary.
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
            'unidad_medida': unit.value,
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
        requiresReview: true,
      );
    }

    // Si falla esta segunda escritura, el ID permite advertir que el producto ya existe.
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

  /// Crea o actualiza el interés del mismo comprador y producto, sin descontar existencias.
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

  /// Impide realizar operaciones de escritura cuando ya no hay una sesión disponible.
  String _requireUserId() {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) throw StateError('La sesión ya no está disponible.');
    return userId;
  }
}
