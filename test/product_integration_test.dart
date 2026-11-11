import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';

void main() {
  test('catalog product uses the first stored photo as its cover', () {
    final product = AgriculturalProduct.fromMap({
      'id_producto': 'product-1',
      'id_productor': 'producer-1',
      'id_categoria': 1,
      'id_fase_actual': 1,
      'nombre_producto': 'Tomate',
      'cantidad_disponible': 10,
      'precio_unitario': 2,
      'estado_publicacion': true,
      'unidad_medida': 'kg',
      'categoria': {'nombre_categoria': 'Hortalizas'},
      'fase': {'nombre_fase': 'Preventa'},
      'fotografias_producto': [
        {
          'id_fotografia': 'photo-b',
          'url_fotografia': 'https://example.com/back.jpg',
        },
        {
          'id_fotografia': 'photo-a',
          'url_fotografia': 'https://example.com/cover.jpg',
        },
      ],
    });

    expect(product.imagenUrl, 'https://example.com/cover.jpg');
  });
}
