import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/map/data/models/public_producer_location.dart';
import 'package:proyecto_agro/features/map/data/repositories/public_location_repository.dart';
import 'package:proyecto_agro/features/map/presentation/views/public_location_edit_view.dart';

class _FakeLocationRepository extends PublicLocationRepository {
  _FakeLocationRepository() : super(supabaseService: SupabaseService());
  int saves = 0;
  @override
  Future<PublicProducerLocation?> getMine() async => null;
  @override
  Future<PublicProducerLocation> saveMine({
    required String alias,
    required String placeName,
    required double latitude,
    required double longitude,
  }) async {
    saves++;
    return PublicProducerLocation.manual(
      producerId: 'p',
      alias: alias,
      placeName: placeName,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<void> removeMine() async {}
}

void main() {
  testWidgets(
    'public zone requires deliberate point selection before publish',
    (tester) async {
      final repository = _FakeLocationRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicLocationEditView(
            repository: repository,
            showTiles: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Publicar zona'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Publicar zona'),
      );
      expect(button.onPressed, isNull);
      expect(repository.saves, 0);
    },
  );
}
