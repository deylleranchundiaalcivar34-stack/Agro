import 'package:flutter/material.dart';

/// Vista de detalle de producto.
/// TODO (Bloque 3): Implementar detalle completo con imágenes, precio y chat.
class ProductDetailView extends StatelessWidget {
  final String productId;

  const ProductDetailView({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del producto')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Producto ID: $productId'),
            const SizedBox(height: 8),
            const Text(
              '🚧 Implementación — Bloque 3',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

