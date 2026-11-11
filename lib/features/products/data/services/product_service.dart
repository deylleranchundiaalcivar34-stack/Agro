// Operaciones de productos con validación de datos, propiedad y confirmación de escrituras.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/supabase_service.dart';
import '../models/product_model.dart';
import '../models/product_quantity.dart';
import '../models/product_unit.dart';
import 'product_storage_service.dart';
import '../../../auth/data/repositories/profile_repository.dart';

/// Señala que no se pudo autorizar o confirmar la retirada de una publicación.
class ProductDeleteException implements Exception {
  const ProductDeleteException();
}

class ProductPermanentDeleteException implements Exception {
  const ProductPermanentDeleteException(this.message);
  final String message;
}

/// Error de edición con un mensaje apto para mostrar al productor.
class ProductEditException implements Exception {
  const ProductEditException(this.message);
  final String message;
}

/// Fallo de transición que puede mostrarse sin exponer detalles internos de SQL.
class ProductPhaseException implements Exception {
  const ProductPhaseException(this.message);
  final String message;
}

/// Encapsula las operaciones de Supabase y la actualización opcional de fotografías.
class ProductService {
  final SupabaseService _supabaseService;
  final ProductStorageService _storageService;

  ProductService({
    required this._supabaseService,
    ProductStorageService? storageService,
  }) : _storageService = storageService ?? ProductStorageService();

  SupabaseClient get _client => _supabaseService.client;

  /// Avanza exclusivamente de Preventa a Venta directa mediante una RPC atómica.
  /// Nunca sustituirla por UPDATE + INSERT: ambos deben confirmar o revertir juntos.
  Future<int> transitionToDirectSale(
    String productId, {
    required double quantity,
    required double price,
    required ProductUnit unit,
  }) => _transitionCommercialPhase(
    productId,
    quantity: quantity,
    price: price,
    unit: unit,
    alternative: false,
  );

  /// Destina una cantidad de Venta directa a Canales alternativos sin cambiar la unidad.
  Future<int> transitionToAlternativeChannels(
    String productId, {
    required double quantity,
    required double price,
    required ProductUnit unit,
  }) => _transitionCommercialPhase(
    productId,
    quantity: quantity,
    price: price,
    unit: unit,
    alternative: true,
  );

  // Ambas transiciones comparten autorización y confirmación, con RPC independientes.
  Future<int> _transitionCommercialPhase(
    String productId, {
    required double quantity,
    required double price,
    required ProductUnit unit,
    required bool alternative,
  }) async {
    final sourcePhase = alternative ? 'Venta directa' : 'Preventa';
    final targetPhase = alternative ? 'Canales alternativos' : 'Venta directa';
    final rpcName = alternative
        ? 'agro_pasar_a_canales_alternativos'
        : 'agro_pasar_a_venta_directa';
    final user = _supabaseService.currentUser;
    if (user == null || productId.trim().isEmpty) {
      throw const ProductPhaseException('Inicia sesión como productor.');
    }
    // Cantidad y precio mantienen las reglas compartidas; la unidad no se convierte.
    final quantityError = ProductQuantity.validate(
      quantity.toString(),
      unit: unit,
    );
    if (quantityError != null) throw ProductPhaseException(quantityError);
    if (!price.isFinite || price < 0) {
      throw const ProductPhaseException(
        'Ingresa un precio válido, mayor o igual a cero.',
      );
    }
    // Identifica la operación fallida sin registrar sesión ni parámetros de la petición.
    var diagnosticStage = 'lectura del perfil';
    try {
      final profile = await ProfileRepository(supabaseService: _supabaseService)
          .getCurrentProfile();
      if (profile?.id != user.id || profile?.role != 'producer') {
        throw const ProductPhaseException(
          'Solo el productor propietario puede cambiar la fase.',
        );
      }
      diagnosticStage = 'lectura del producto';
      final existing = await _client
          .from('productos')
          .select(
            'id_producto, id_productor, id_fase_actual, unidad_medida, estado_publicacion, cantidad_disponible',
          )
          .eq('id_producto', productId)
          .single();
      if (existing['id_producto'] != productId ||
          existing['id_productor'] != user.id) {
        throw const ProductPhaseException(
          'Solo puedes cambiar la fase de tus publicaciones.',
        );
      }
      if (existing['unidad_medida'] != unit.value) {
        throw const ProductPhaseException(
          'Revisa la unidad actual antes de cambiar de fase.',
        );
      }
      // Releer existencias; la RPC vuelve a comprobarlas dentro del bloqueo.
      if (alternative) {
        final available = existing['cantidad_disponible'];
        if (available is! num || !available.isFinite || quantity > available) {
          throw const ProductPhaseException(
            'La cantidad destinada no puede superar la disponible. Actualiza el detalle.',
          );
        }
      }
      // Resolver los IDs reales por nombre; no asumir su numeración en Supabase.
      diagnosticStage = 'lectura de la fase $sourcePhase';
      final presale = await _client
          .from('fases_comercializacion')
          .select('id_fase')
          .ilike('nombre_fase', sourcePhase)
          .single();
      diagnosticStage = 'lectura de la fase $targetPhase';
      final direct = await _client
          .from('fases_comercializacion')
          .select('id_fase')
          .ilike('nombre_fase', targetPhase)
          .single();
      if (existing['id_fase_actual'] != presale['id_fase'] ||
          presale['id_fase'] == direct['id_fase']) {
        throw ProductPhaseException(
          'El producto ya no está en $sourcePhase. Actualiza el detalle.',
        );
      }
      if (_supabaseService.currentUser?.id != user.id) {
        throw const ProductPhaseException(
          'La sesión cambió. Vuelve a abrir el producto.',
        );
      }
      // PostgreSQL vuelve a validar propietario y fase bajo bloqueo de la fila.
      diagnosticStage = 'llamada a $rpcName';
      final result = await _client.rpc(
        rpcName,
        params: {
          'p_id_producto': productId,
          'p_cantidad': quantity,
          'p_precio': price,
          'p_unidad': unit.value,
          'p_fase_esperada': presale['id_fase'],
          if (alternative) 'p_confirmado': true else 'p_disponible': true,
        },
      );
      // Mostrar solo los campos incompatibles, sin volcar la respuesta ni sus valores.
      if (kDebugMode) {
        if (result is! Map) {
          debugPrint(
            '[ProductService.$rpcName] RPC completada; '
            'validación de respuesta fallida: se esperaba un objeto Map.',
          );
        } else {
          final expected = <String, Object?>{
            'id_producto': productId,
            'id_productor': user.id,
            'id_fase_actual': direct['id_fase'],
            'fase_anterior': presale['id_fase'],
            'historial_registrado': true,
            'cantidad_disponible': quantity,
            'precio_unitario': price,
            'unidad_medida': unit.value,
            'estado_publicacion': existing['estado_publicacion'],
          };
          final mismatches = <String>[];
          for (final entry in expected.entries) {
            final received = result[entry.key];
            final numeric =
                entry.key == 'cantidad_disponible' ||
                entry.key == 'precio_unitario';
            final matches = numeric
                ? received is num && received.toDouble() == entry.value
                : received == entry.value;
            if (!matches) mismatches.add(entry.key);
          }
          if (mismatches.isNotEmpty) {
            debugPrint(
              '[ProductService.$rpcName] RPC completada; '
              'validación de respuesta fallida. Campos que no coinciden: '
              '${mismatches.join(', ')}.',
            );
          }
        }
      }
      if (result is! Map ||
          result['id_producto'] != productId ||
          result['id_productor'] != user.id ||
          result['id_fase_actual'] != direct['id_fase'] ||
          result['fase_anterior'] != presale['id_fase'] ||
          result['historial_registrado'] != true ||
          (result['cantidad_disponible'] as num?)?.toDouble() != quantity ||
          (result['precio_unitario'] as num?)?.toDouble() != price ||
          result['unidad_medida'] != unit.value ||
          result['estado_publicacion'] != existing['estado_publicacion']) {
        throw const ProductPhaseException(
          'No se pudo confirmar el cambio y su historial. Actualiza el producto antes de reintentar.',
        );
      }
      return (direct['id_fase'] as num).toInt();
    } on PostgrestException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ProductService.$rpcName] PostgrestException '
          'durante $diagnosticStage; no se completó la validación de respuesta. '
          'code=${error.code}; message=${error.message}; '
          'details=${error.details}; hint=${error.hint}',
        );
      }
      if (error.code == 'PGRST202' || error.code == '42883') {
        if (alternative) {
          throw const ProductPhaseException(
            'El paso a Canales alternativos aún no está habilitado en Supabase. Falta instalar y verificar su RPC.',
          );
        }
        throw const ProductPhaseException(
          'La transición aún no está habilitada en Supabase. Falta instalar y verificar la operación transaccional.',
        );
      }
      throw const ProductPhaseException(
        'Supabase no confirmó la transición. Revisa permisos, fase e historial y actualiza el producto antes de reintentar.',
      );
    }
  }

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

  /// Recupera el producto y ordena sus fotografías para mantener una portada estable.
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

  /// Edita un producto propio sin alterar su fase y conserva las demás fotografías.
  Future<ProductModel> updateProduct(
    ProductModel product, {
    XFile? image,
  }) async {
    if (product.idProducto == null) {
      throw Exception('El producto no tiene un identificador.');
    }
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) {
      throw const ProductEditException('Inicia sesión como productor.');
    }
    // El perfil persistido y el propietario se comprueban además de la sesión.
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
    // La fase solo se cambia por RPC; el PATCH normal tampoco reasigna propietario.
    fields.remove('id_fase_actual');
    fields.remove('id_productor');
    final response = await _client
        .from('productos')
        .update(fields)
        .eq('id_producto', product.idProducto!)
        .eq('id_productor', userId)
        .select()
        .single();

    // Verificar la identidad devuelta antes de asociar una fotografía al registro editado.
    if (response['id_producto'] != product.idProducto ||
        response['id_productor'] != userId) {
      throw const ProductEditException(
        'No se pudo confirmar la actualización. Revisa la publicación antes de reintentar.',
      );
    }
    // La fotografía se asocia después del producto; un fallo se informa como guardado parcial.
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
          'Los datos se guardaron, pero no se pudo confirmar el cambio de fotografía. '
          'La fotografía anterior no se eliminó. Revisa la publicación antes de reintentar.',
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
  // 5. DESACTIVAR PUBLICACIÓN
  // ==========================================

  /// Mantiene la entrada de desactivación delegando en la misma retirada lógica.
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
      throw const ProductEditException('Inicia sesión como productor.');
    }
    // El perfil persistido y el propietario se comprueban además de la sesión.
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
    // Conservar la unidad existente si no se envía otra; nunca inventarla para NULL.
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
    // La representación devuelta permite comprobar que la escritura afectó al registro esperado.
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
        'No se pudo confirmar la cantidad actualizada. Refresca la publicación.',
      );
    }
  }

  // ==========================================
  // 6. ELIMINAR PRODUCTO
  // ==========================================

  /// El trigger instalado protege las cascadas; RLS se aplica a la sesión actual.
  Future<void> permanentlyDeleteProduct(String productId, String name) async {
    const unconfirmed = ProductPermanentDeleteException(
      'No se pudo confirmar la eliminación. Revisa la publicación antes de reintentar. Puedes utilizar «Ocultar producto».',
    );
    final user = _supabaseService.currentUser;
    if (user == null || productId.trim().isEmpty || name.trim().isEmpty) {
      throw unconfirmed;
    }
    try {
      final profile = await ProfileRepository(supabaseService: _supabaseService)
          .getCurrentProfile();
      if (profile == null ||
          profile.id != user.id ||
          profile.role != 'producer') {
        throw unconfirmed;
      }
      final existing = await _client
          .from('productos')
          .select('id_producto, id_productor, nombre_producto')
          .eq('id_producto', productId)
          .single();
      if (existing['id_productor'] != user.id ||
          existing['id_producto'] != productId ||
          (existing['nombre_producto'] as String?)?.trim() != name.trim() ||
          _supabaseService.currentUser?.id != user.id) {
        throw unconfirmed;
      }
      // RETURNING evita anunciar éxito cuando RLS no permite eliminar ninguna fila.
      final deleted = await _client
          .from('productos')
          .delete()
          .eq('id_producto', productId)
          .eq('id_productor', user.id)
          .eq('nombre_producto', existing['nombre_producto'])
          .select('id_producto, id_productor');
      if (deleted.length != 1 ||
          deleted.single['id_producto'] != productId ||
          deleted.single['id_productor'] != user.id) {
        throw unconfirmed;
      }
    } on PostgrestException catch (error) {
      if (error.code == 'P0001' ||
          error.code == '23503' ||
          error.code == '23514') {
        throw const ProductPermanentDeleteException(
          'Supabase bloqueó la eliminación por actividad comercial o historial protegido. Puedes utilizar «Ocultar producto» para conservar la información.',
        );
      }
      throw unconfirmed;
    }
  }

  /// Retira del catálogo mediante estado_publicacion=false; no elimina filas ni fotografías.
  Future<void> deleteProduct(String idProducto) =>
      setVisibility(idProducto, false);

  /// Oculta o vuelve a mostrar sin modificar campos del producto ni sus fotografías.
  Future<void> setVisibility(String idProducto, bool visible) async {
    final user = _supabaseService.currentUser;
    if (user == null || idProducto.trim().isEmpty) {
      throw const ProductDeleteException();
    }
    // usuarios.id_usuario corresponde a Auth según el repositorio de perfiles.
    // Verificar el perfil real y su rol, nunca user_metadata editable.
    // El perfil persistido y el propietario se comprueban además de la sesión.
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
    // La representación devuelta permite comprobar que la escritura afectó al registro esperado.
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
