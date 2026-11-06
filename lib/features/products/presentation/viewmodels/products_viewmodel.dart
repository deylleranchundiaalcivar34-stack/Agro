// Estado compartido del módulo: catálogo, publicaciones, edición e intereses de compradores.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/agricultural_category.dart';
import '../../data/models/agricultural_product.dart';
import '../../data/models/product_unit.dart';
import '../../data/repositories/products_repository.dart';
import '../../data/services/product_storage_service.dart';
import '../../data/services/product_service.dart';

/// Estados que el catálogo traduce en carga, resultados, vacío o error.
enum ProductsStatus { idle, loading, ready, error }

/// Coordina el repositorio y notifica a las vistas sin realizar consultas desde los widgets.
class ProductsViewModel extends ChangeNotifier {
  ProductsViewModel({required this._productsRepository});

  final ProductsRepository _productsRepository;

  // Datos en memoria, mensajes y bloqueos utilizados por las pantallas del módulo.
  ProductsStatus _catalogueStatus = ProductsStatus.idle;
  List<AgriculturalProduct> _products = const [];
  List<AgriculturalCategory> _categories = const [];
  String? _errorMessage;
  String? _publicationWarning;
  bool _isSubmitting = false;
  bool _publicationRequiresReview = false;
  ProductUploadException? _lastUploadError;
  Completer<void>? _catalogueLoad;

  // Lectura del estado público; las operaciones inferiores controlan sus actualizaciones.
  ProductsStatus get catalogueStatus => _catalogueStatus;
  List<AgriculturalProduct> get products => _products;
  List<AgriculturalCategory> get categories => _categories;
  String? get errorMessage => _errorMessage;
  String? get publicationWarning => _publicationWarning;
  bool get isSubmitting => _isSubmitting;
  bool get publicationRequiresReview => _publicationRequiresReview;
  ProductUploadException? get lastUploadError => _lastUploadError;

  // La lista privada se vincula a la sesión para no mostrar publicaciones de una cuenta anterior.
  List<AgriculturalProduct> _myProducts = const [];
  ProductsStatus _myStatus = ProductsStatus.idle;
  String? _myOwnerId;
  String? _myError;
  String? _visibilityWarning;
  Completer<void>? _myLoad;
  String? _myLoadingOwner;
  List<AgriculturalProduct> get myProducts =>
      _myOwnerId == _productsRepository.currentUserId ? _myProducts : const [];
  ProductsStatus get myStatus => _myOwnerId == _productsRepository.currentUserId
      ? _myStatus
      : ProductsStatus.idle;
  String? get myError =>
      _myOwnerId == _productsRepository.currentUserId ? _myError : null;
  String? get visibilityWarning => _visibilityWarning;

  /// Carga privada con control de solicitudes simultáneas y de cambios de sesión.
  Future<void> loadMyPublications({bool force = false}) async {
    final owner = _productsRepository.currentUserId;
    if (_myLoad != null && _myLoadingOwner == owner) {
      await _myLoad!.future;
      if (force) await loadMyPublications(force: true);
      return;
    }
    if (_myOwnerId != owner) {
      _myProducts = const [];
      _myOwnerId = owner;
      _myStatus = ProductsStatus.idle;
    }
    if (!force && _myStatus == ProductsStatus.ready) return;
    final completion = Completer<void>();
    _myLoad = completion;
    _myLoadingOwner = owner;
    _myStatus = ProductsStatus.loading;
    _myError = null;
    notifyListeners();
    try {
      final rows = await _productsRepository.getMyProducts();
      if (_productsRepository.currentUserId == owner && _myOwnerId == owner) {
        _myProducts = rows;
        _myStatus = ProductsStatus.ready;
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ProductsViewModel.getMyProducts] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (_myOwnerId == owner) {
        _myStatus = ProductsStatus.error;
        _myError =
            'No pudimos cargar tus publicaciones. Intenta actualizar de nuevo.';
      }
    } finally {
      if (identical(_myLoad, completion)) _myLoad = null;
      completion.complete();
      notifyListeners();
    }
  }

  /// Conservar la separación entre el catálogo público y la lista del propietario.
  Future<void> _refreshLists() async {
    await loadCatalogue(force: true);
    if (_myOwnerId != null) await loadMyPublications(force: true);
  }

  /// Registra qué consulta o mapeo falló y su traza, únicamente durante el desarrollo.
  Future<T> _catalogueOperation<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ProductsCatalogue] $operation: $error');
        debugPrintStack(
          label: '[ProductsCatalogue] $operation',
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  /// Reutiliza la carga en curso y permite forzar un refresco explícito.
  Future<void> loadCatalogue({bool force = false}) async {
    if (_catalogueStatus == ProductsStatus.loading) {
      await _catalogueLoad?.future;
      if (force) await loadCatalogue(force: true);
      return;
    }
    if (!force && _catalogueStatus == ProductsStatus.ready) {
      return;
    }
    final completion = Completer<void>();
    _catalogueLoad = completion;
    _catalogueStatus = ProductsStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      // Productos y categorías se consultan en paralelo y se aplican si ambas cargas terminan bien.
      final results = await Future.wait([
        _catalogueOperation(
          'getPublishedProducts / productos y relaciones',
          _productsRepository.getPublishedProducts,
        ),
        _catalogueOperation(
          'getCategories / categorias_agricolas',
          _productsRepository.getCategories,
        ),
      ]);
      _products = results[0] as List<AgriculturalProduct>;
      _categories = results[1] as List<AgriculturalCategory>;
      _catalogueStatus = ProductsStatus.ready;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ProductsCatalogue] loadCatalogue falló: $error');
      }
      _catalogueStatus = ProductsStatus.error;
      _errorMessage =
          'No pudimos cargar el catálogo. Intenta actualizarlo de nuevo.';
    }
    completion.complete();
    notifyListeners();
  }

  /// Publica una preventa y distingue fallos de subida, creación incierta y guardado parcial.
  Future<bool> createPreorderProduct({
    required String name,
    XFile? image,
    required int categoryId,
    required double quantity,
    required double price,
    ProductUnit? unit,
    DateTime? estimatedHarvestDate,
  }) async {
    // Evita doble envío y nuevos intentos cuando una escritura requiere revisión manual.
    if (_isSubmitting || _publicationRequiresReview) return false;
    _publicationWarning = null;
    _lastUploadError = null;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _productsRepository.createPreorderProduct(
        name: name,
        image: image,
        categoryId: categoryId,
        quantity: quantity,
        price: price,
        unit: unit,
        estimatedHarvestDate: estimatedHarvestDate,
      );
      await _refreshLists();
      if (_catalogueStatus == ProductsStatus.error) {
        _publicationWarning = 'La preventa se guardó, pero no se pudo actualizar el catálogo. Recarga tus publicaciones; no vuelvas a publicarla.';
      }
      return true;
    } on ProductUploadException catch (error) {
      _lastUploadError = error;
      _errorMessage = error.message;
      return false;
    } on ProductPublicationException catch (error) {
      _publicationRequiresReview = error.requiresReview;
      // El producto ya existe: devolver éxito con advertencia evita que el formulario lo duplique.
      if (error.productId != null) {
        await _refreshLists();
        _publicationWarning = error.message;
        return true;
      }
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'No se pudo publicar la preventa. Intenta de nuevo.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Obtiene el detalle actualizado sin reemplazar toda la lista del catálogo.
  Future<AgriculturalProduct?> getProduct(String productId) {
    return _productsRepository.getProduct(productId);
  }

  /// Compatibilidad con llamadas anteriores: siempre es ocultación lógica, nunca borrado.
  Future<bool> deleteProduct(String productId) =>
      setVisibility(productId, false);

  /// Cambia únicamente la visibilidad y mantiene sincronizadas las dos listas.
  Future<bool> setVisibility(String productId, bool visible) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    _visibilityWarning = null;
    notifyListeners();
    try {
      await _productsRepository.setVisibility(productId, visible);
      final known = [
        ..._products,
        ...myProducts,
      ].where((p) => p.id == productId).firstOrNull;
      _products = _products.where((p) => p.id != productId).toList();
      if (visible && known != null) {
        _products = [..._products, known.withVisibility(true)];
      }
      _myProducts = _myProducts
          .map((p) => p.id == productId ? p.withVisibility(visible) : p)
          .toList();
      notifyListeners();
      await _refreshLists();
      if (_catalogueStatus == ProductsStatus.error ||
          _myStatus == ProductsStatus.error) {
        _visibilityWarning = 'El producto se actualizó, pero no se pudieron refrescar todas las listas. Intenta actualizarlas.';
      }
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ProductsViewModel.setVisibility] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _errorMessage = 'No se pudo confirmar el cambio de visibilidad. Revisa tus publicaciones antes de reintentar.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Aplica la cantidad confirmada localmente aunque falle el refresco posterior.
  Future<bool> updateQuantity(
    String productId,
    double quantity, {
    ProductUnit? unit,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _productsRepository.updateQuantity(productId, quantity, unit: unit);
      _products = _products
          .map(
            (product) => product.id == productId
                ? product.withQuantity(quantity, unit: unit)
                : product,
          )
          .toList();
      notifyListeners();
      await _refreshLists();
      return true;
    } on ProductEditException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'No se pudo actualizar la cantidad. Intenta nuevamente.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Guarda cambios completos y vuelve a consultar el catálogo para mostrar datos actuales.
  Future<bool> updateProduct({
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
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _lastUploadError = null;
    _errorMessage = null;
    notifyListeners();
    try {
      await _productsRepository.updateProduct(
        productId: productId,
        name: name,
        categoryId: categoryId,
        quantity: quantity,
        price: price,
        unit: unit,
        isPublished: isPublished,
        harvest: harvest,
        image: image,
      );
      await _refreshLists();
      return true;
    } on ProductEditException catch (error) {
      await _refreshLists();
      _errorMessage = error.message;
      return false;
    } on ProductUploadException catch (error) {
      _lastUploadError = error;
      _errorMessage = error.message;
      return false;
    } catch (error, stackTrace) {
      // El diagnóstico real ayuda a revisar permisos o conectividad sin mostrar datos internos.
      if (kDebugMode) {
        debugPrint('[ProductsViewModel.updateProduct] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _errorMessage = 'No se pudo confirmar la actualización. Revisa la publicación antes de reintentar.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Registra la cantidad proyectada por el comprador y comunica el resultado a la vista.
  Future<bool> registerInterest({
    required String productId,
    required double quantity,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _productsRepository.registerInterest(
        productId: productId,
        quantity: quantity,
      );
      return true;
    } catch (_) {
      _errorMessage = 'No se pudo registrar tu interés. Intenta de nuevo.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
