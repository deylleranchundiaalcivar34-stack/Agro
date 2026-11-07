// Operaciones de productos con validacion de datos, propiedad y confirmacion de escrituras.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/supabase_service.dart';
import '../models/product_model.dart';
import '../models/product_quantity.dart';
import '../models/product_unit.dart';
import 'product_storage_service.dart';
import '../../../auth/data/repositories/profile_repository.dart';

/// Senala que no se pudo autorizar o confirmar la retirada de una publicacion.
class ProductDeleteException implements Exception {
  const ProductDeleteException();
}

/// Error de edicion con un mensaje apto para mostrar al productor.
class ProductEditException implements Exception {
  const ProductEditException(this.message);
  final String message;
}

/// Encapsula las operaciones de Supabase y la actualizacion opcional de fotografias.
class ProductService {
  final SupabaseService _supabaseService;
  final ProductStorageService _storageService;

  ProductService({
    required this._supabaseService,
    ProductStorageService? storageService,
  }) : _storageService = storageService ?? ProductStorageService();

  SupabaseClient get _client => _supabaseService.client;

  // ==========================================
  // 1. CREAR PRODUCTO
  // ==========================================

  /// Valida unidad y cantidad antes de insertar los campos del producto.
  Future<ProductModel> createProduct(ProductModel product) async {
    if (product.unidadMedida == null) {
      throw const ProductEditException('Selecciona la unidad de medida.');
    }
    if (!product.hasValidQuantity) {
      throw ProductEditException(
        ProductQuantity.validate(
          product.cantidadDisponible.toString(),
          unit: product.unidadMedida,
        )!,
      );
    }
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

  /// Lista los productos de un productor y transforma las relaciones de fotos en URLs.
  Future<List<ProductModel>> getProductsByProducer(String idProductor) async {
    final response = await _client
        .from('productos')
        .select('''
          *,
          fotografias_producto (
            id_fotografia,
            url_fotografia
          )
        ''')
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

  /// Recupera el producto y ordena sus fotografias para mantener una portada estable.
  Future<ProductModel> getProductById(String idProducto) async {
    final response = await _client
        .from('productos')
        .select('''
          *,
          fotografias_producto (
            id_fotografia,
            url_fotografia
          )
        ''')
        .eq('id_producto', idProducto)
        .single();

    final data = Map<String, dynamic>.from(response);

    final photos = data['fotografias_producto'] as List? ?? [];
    photos.sort(
      (a, b) => a['id_fotografia'].toString().compareTo(
        b['id_fotografia'].toString(),
      ),
    );

    data['fotografias'] = photos
        .map((photo) => photo['url_fotografia'] as String)
        .toList();

    return ProductModel.fromJson(data);
  }

  // ==========================================
  // 4. ACTUALIZAR PRODUCTO
  // ==========================================

  /// Edita un producto propio sin alterar su fase y conserva las demas fotografias.
  Future<ProductModel> updateProduct(
    ProductModel product, {
    XFile? image,
  }) async {
    if (product.idProducto == null) {
      throw Exception('El producto no tiene un identificador.');
    }
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) {
      throw const ProductEditException('Inicia sesion como productor.');
    }
    // El perfil persistido y el propietario se comprueban ademas de la sesion.
    final profile = await ProfileRepository(supabaseService: _supabaseService)
        .getCurrentProfile();
    final existing = await getProductById(product.idProducto!);
    if (profile == null ||
        profile.id != userId ||
        profile.role != 'producer' ||
        existing.idProductor != userId ||
        product.idProductor != userId) {
      throw const ProductEditException('Solo puedes editar tus publicaciones.');
    }
    if (product.nombreProducto.trim().length < 3 ||
        !product.hasValidQuantity ||
        !product.precioUnitario.isFinite ||
        product.precioUnitario < 0) {
      throw const ProductEditException(
        'Revisa el nombre, la cantidad y el precio.',
      );
    }
    // Cargar primero la nueva imagen: un fallo conserva todos los datos anteriores.
    final imageUrl = image == null
        ? null
        : await _storageService.subirImagen(image);
    final fields = product.toJson();
    fields['nombre_producto'] = product.nombreProducto.trim();
    // La edicion no convierte una preventa en otra fase de comercializacion.
    fields['id_fase_actual'] = existing.idFaseActual;
    final response = await _client
        .from('productos')
        .update(fields)
        .eq('id_producto', product.idProducto!)
        .eq('id_productor', userId)
        .select()
        .single();

    // Verificar la identidad devuelta antes de asociar una fotografia al registro editado.
    if (response['id_producto'] != product.idProducto ||
        response['id_productor'] != userId) {
      throw const ProductEditException(
        'No se pudo confirmar la actualizacion. Revisa la publicacion antes de reintentar.',
      );
    }
    // La fotografia se asocia despues del producto; un fallo se informa como guardado parcial.
    if (imageUrl != null) {
      try {
        final photos = await _client
            .from('fotografias_producto')
            .select('id_fotografia')
            .eq('id_producto', product.idProducto!);
        photos.sort(
          (a, b) => a['id_fotografia'].toString().compareTo(
            b['id_fotografia'].toString(),
          ),
        );
        if (photos.isEmpty) {
          await _client.from('fotografias_producto').insert({
            'id_producto': product.idProducto!,
            'url_fotografia': imageUrl,
          });
        } else {
          await _client
              .from('fotografias_producto')
              .update({'url_fotografia': imageUrl})
              .eq('id_producto', product.idProducto!)
              .eq('id_fotografia', photos.first['id_fotografia'])
              .select('id_fotografia')
              .single();
        }
      } catch (error, stackTrace) {
        // Conservar el rechazo real de Supabase en desarrollo, sin exponerlo en el formulario.
        if (kDebugMode) {
          debugPrint(
            '[ProductService.updateProduct / fotografias_producto] $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
        throw const ProductEditException(
          'Los datos se guardaron, pero no se pudo confirmar el cambio de fotografia. '
          'La fotografia anterior no se elimino. Revisa la publicacion antes de reintentar.',
        );
      }
    }
    return ProductModel.fromJson(response).copyWith(
      fotografias: [
        ?imageUrl,
        ...existing.fotografias.skip(
          imageUrl != null && existing.fotografias.isNotEmpty ? 1 : 0,
        ),
      ],
    );
  }

  // ==========================================
  // 5. DESACTIVAR PUBLICACION
  // ==========================================

  /// Mantiene la entrada de desactivacion delegando en la misma retirada logica.
  Future<void> deactivateProduct(String idProducto) async {
    await deleteProduct(idProducto);
  }

  /// Actualiza solo cantidad y unidad tras comprobar rol, propietario y respuesta del servidor.
  Future<void> updateQuantity(
    String productId,
    double quantity, {
    ProductUnit? unit,
  }) async {
    final user = _supabaseService.currentUser;
    if (user == null || productId.trim().isEmpty) {
      throw const ProductEditException('Inicia sesion como productor.');
    }
    // El perfil persistido y el propietario se comprueban ademas de la sesion.
    final profile = await ProfileRepository(supabaseService: _supabaseService)
        .getCurrentProfile();
    if (profile == null ||
        profile.id != user.id ||
        profile.role != 'producer') {
      throw const ProductEditException(
        'Solo el productor propietario puede actualizar la cantidad.',
      );
    }
    final existing = await _client
        .from('productos')
        .select('id_producto, id_productor, unidad_medida')
        .eq('id_producto', productId)
        .single();
    if (existing['id_producto'] != productId ||
        existing['id_productor'] != profile.id) {
      throw const ProductEditException(
        'Solo puedes modificar tus publicaciones.',
      );
    }
    // Conservar la unidad existente si no se envia otra; nunca inventarla para NULL.
    final selectedUnit =
        unit ?? ProductUnit.fromValue(existing['unidad_medida']);
    if (selectedUnit == null) {
      throw const ProductEditException('Selecciona la unidad de medida.');
    }
    final error = ProductQuantity.validate(
      quantity.toString(),
      unit: selectedUnit,
    );
    if (error != null) throw ProductEditException(error);
    // La representacion devuelta permite comprobar que la escritura afecto al registro esperado.
    final updated = await _client
        .from('productos')
        .update({
          'cantidad_disponible': quantity,
          'unidad_medida': selectedUnit.value,
        })
        .eq('id_producto', productId)
        .eq('id_productor', profile.id)
        .select('id_producto, id_productor, cantidad_disponible, unidad_medida')
        .single();
    if (updated['id_producto'] != productId ||
        updated['id_productor'] != profile.id ||
        (updated['cantidad_disponible'] as num?)?.toDouble() != quantity ||
        updated['unidad_medida'] != selectedUnit.value) {
      throw const ProductEditException(
        'No se pudo confirmar la cantidad actualizada. Refresca la publicacion.',
      );
    }
  }

  // ==========================================
  // 6. ELIMINAR PRODUCTO
  // ==========================================

  /// Retira del catalogo mediante estado_publicacion=false; no elimina filas ni fotografias.
  Future<void> deleteProduct(String idProducto) =>
      setVisibility(idProducto, false);

  /// Oculta o vuelve a mostrar sin modificar campos del producto ni sus fotografias.
  Future<void> setVisibility(String idProducto, bool visible) async {
    final user = _supabaseService.currentUser;
    if (user == null || idProducto.trim().isEmpty) {
      throw const ProductDeleteException();
    }
    // usuarios.id_usuario corresponde a Auth segun el repositorio de perfiles.
    // Verificar el perfil real y su rol, nunca user_metadata editable.
    // El perfil persistido y el propietario se comprueban ademas de la sesion.
    final profile = await ProfileRepository(supabaseService: _supabaseService)
        .getCurrentProfile();
    if (profile == null ||
        profile.role != 'producer' ||
        profile.id != user.id) {
      throw const ProductDeleteException();
    }
    final existing = await _client
        .from('productos')
        .select('id_producto, id_productor, estado_publicacion')
        .eq('id_producto', idProducto)
        .single();
    if (existing['id_producto'] != idProducto ||
        existing['id_productor'] != profile.id) {
      throw const ProductDeleteException();
    }
    // La representacion devuelta permite comprobar que la escritura afecto al registro esperado.
    final updated = await _client
        .from('productos')
        .update({'estado_publicacion': visible})
        .eq('id_producto', idProducto)
        .eq('id_productor', profile.id)
        .select('id_producto, id_productor, estado_publicacion')
        .single();
    if (updated['id_producto'] != idProducto ||
        updated['id_productor'] != profile.id ||
        updated['estado_publicacion'] != visible) {
      throw const ProductDeleteException();
    }
  }
}
