import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/agricultural_category.dart';
import '../../data/models/agricultural_product.dart';
import '../../data/repositories/products_repository.dart';
import '../../data/services/product_storage_service.dart';

enum ProductsStatus { idle, loading, ready, error }

class ProductsViewModel extends ChangeNotifier {
  ProductsViewModel({required this._productsRepository});

  final ProductsRepository _productsRepository;

  ProductsStatus _catalogueStatus = ProductsStatus.idle;
  List<AgriculturalProduct> _products = const [];
  List<AgriculturalCategory> _categories = const [];
  String? _errorMessage;
  String? _publicationWarning;
  bool _isSubmitting = false;

  ProductsStatus get catalogueStatus => _catalogueStatus;
  List<AgriculturalProduct> get products => _products;
  List<AgriculturalCategory> get categories => _categories;
  String? get errorMessage => _errorMessage;
  String? get publicationWarning => _publicationWarning;
  bool get isSubmitting => _isSubmitting;

  Future<void> loadCatalogue({bool force = false}) async {
    if (_catalogueStatus == ProductsStatus.loading ||
        (!force && _catalogueStatus == ProductsStatus.ready)) {
      return;
    }
    _catalogueStatus = ProductsStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _productsRepository.getPublishedProducts(),
        _productsRepository.getCategories(),
      ]);
      _products = results[0] as List<AgriculturalProduct>;
      _categories = results[1] as List<AgriculturalCategory>;
      _catalogueStatus = ProductsStatus.ready;
    } catch (_) {
      _catalogueStatus = ProductsStatus.error;
      _errorMessage = 'No pudimos cargar el catálogo. Revisa tu conexión.';
    }
    notifyListeners();
  }

  Future<bool> createPreorderProduct({
    required String name,
    XFile? image,
    required int categoryId,
    required double quantity,
    required double price,
    DateTime? estimatedHarvestDate,
  }) async {
    if (_isSubmitting) return false;
    _publicationWarning = null;
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
        estimatedHarvestDate: estimatedHarvestDate,
      );
      await loadCatalogue(force: true);
      return true;
    } on ProductUploadException catch (error) {
      _errorMessage = error.message;
      return false;
    } on ProductPublicationException catch (error) {
      if (error.productId != null) {
        await loadCatalogue(force: true);
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

  Future<AgriculturalProduct?> getProduct(String productId) {
    return _productsRepository.getProduct(productId);
  }

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
