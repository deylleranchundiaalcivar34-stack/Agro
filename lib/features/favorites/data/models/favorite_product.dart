import '../../../products/data/models/agricultural_product.dart';

/// Una publicacion guardada; puede no estar disponible si fue retirada.
class FavoriteProduct {
  const FavoriteProduct({
    required this.productId,
    required this.createdAt,
    this.product,
  });

  final String productId;
  final DateTime createdAt;
  final AgriculturalProduct? product;
}
