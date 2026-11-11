import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/map/data/models/public_producer_location.dart';
import 'package:proyecto_agro/features/map/data/repositories/public_location_repository.dart';
import 'package:proyecto_agro/features/map/presentation/views/map_view.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';

class _EmptyLocations extends PublicLocationRepository {
  _EmptyLocations() : super(supabaseService: SupabaseService());
  @override
  Future<List<PublicProducerLocation>> listPublished() async => [];
}

class _EmptyProducts extends ProductsRepository {
  _EmptyProducts() : super(supabaseService: SupabaseService());
  @override
  Future<List<AgriculturalProduct>> getPublishedProducts() async => [];
}

void main() {
  const zone = PublicProducerLocation(
    producerId: 'p1',
    alias: 'Finca Norte',
    placeName: 'Guano',
    latitude: -1.67,
    longitude: -78.65,
  );
  AgriculturalProduct product(String producerId, {double quantity = 8}) =>
      AgriculturalProduct(
        id: 'product-1',
        producerId: producerId,
        categoryId: 1,
        phaseId: 1,
        name: 'Tomate',
        availableQuantity: quantity,
        unitPrice: 2,
        isPublished: true,
        categoryName: 'Hortalizas',
        phaseName: 'Preventa',
      );

  test('map entries require a voluntary zone and an available product', () {
    expect(ProducerMapEntry.fromData([zone], [product('p2')]), isEmpty);
    expect(
      ProducerMapEntry.fromData([zone], [product('p1', quantity: 0)]),
      isEmpty,
    );
    final entries = ProducerMapEntry.fromData([zone], [product('p1')]);
    expect(entries, hasLength(1));
    expect(entries.single.products.single.id, 'product-1');
  });

  test('radius filtering starts only after location is available', () {
    final entries = ProducerMapEntry.fromData([zone], [product('p1')]);
    expect(ProducerMapEntry.withinRadius(entries, null, 5), hasLength(1));
    expect(
      ProducerMapEntry.withinRadius(entries, const LatLng(-1.67, -78.65), 5),
      hasLength(1),
    );
    expect(
      ProducerMapEntry.withinRadius(entries, const LatLng(-2.2, -78.65), 5),
      isEmpty,
    );
  });

  testWidgets('empty live data shows a clear state without invented markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapView(
          locationRepository: _EmptyLocations(),
          productsRepository: _EmptyProducts(),
          showTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aun no hay productores'), findsOneWidget);
    expect(find.byIcon(Icons.agriculture), findsNothing);
  });
}
