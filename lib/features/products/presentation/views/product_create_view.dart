import 'package:flutter/material.dart';

/// Formulario de creación de producto.
/// TODO (Bloque 3): Implementar CRUD completo con subida de imagen.
class ProductCreateView extends StatelessWidget {
  const ProductCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo producto')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '🚧 Formulario de producto — Bloque 3',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

