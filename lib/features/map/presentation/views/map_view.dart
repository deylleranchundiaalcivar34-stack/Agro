import 'package:flutter/material.dart';

/// Vista del mapa con geolocalización de productores.
/// TODO (Bloque 4): Implementar flutter_map + geolocator + PostGIS queries.
class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de productores')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '🚧 Mapa con flutter_map — Bloque 4',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

