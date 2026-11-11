import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/features/map/data/models/public_producer_location.dart';

void main() {
  test('published point is rounded to an approximate zone', () {
    final point = PublicProducerLocation.manual(
      producerId: 'producer-1',
      alias: 'Finca Norte',
      placeName: 'Guano',
      latitude: -1.67452,
      longitude: -78.65249,
    );
    expect(point.latitude, -1.67);
    expect(point.longitude, -78.65);
  });

  test('manual location requires a name and valid coordinates', () {
    expect(
      () => PublicProducerLocation.manual(
        producerId: 'producer-1',
        alias: ' ',
        placeName: 'Guano',
        latitude: -1,
        longitude: -78,
      ),
      throwsArgumentError,
    );
    expect(
      () => PublicProducerLocation.manual(
        producerId: 'producer-1',
        alias: 'Finca',
        placeName: 'Guano',
        latitude: 91,
        longitude: -78,
      ),
      throwsArgumentError,
    );
  });
}
