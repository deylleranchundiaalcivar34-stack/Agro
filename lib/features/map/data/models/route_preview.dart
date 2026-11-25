import 'package:latlong2/latlong.dart';

class RoutePreview {
  const RoutePreview({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  double get distanceKilometers => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();

  factory RoutePreview.fromMap(Map<String, dynamic> data) {
    final rawPoints = data['points'];
    final distance = (data['distanceMeters'] as num?)?.toDouble();
    final duration = (data['durationSeconds'] as num?)?.toDouble();
    if (rawPoints is! List ||
        rawPoints.length < 2 ||
        distance == null ||
        !distance.isFinite ||
        distance <= 0 ||
        duration == null ||
        !duration.isFinite ||
        duration <= 0) {
      throw const FormatException('La ruta recibida no es válida.');
    }

    final points = rawPoints
        .map((rawPoint) {
          if (rawPoint is! Map) {
            throw const FormatException(
              'La geometría de la ruta no es válida.',
            );
          }
          final latitude = (rawPoint['latitude'] as num?)?.toDouble();
          final longitude = (rawPoint['longitude'] as num?)?.toDouble();
          if (latitude == null ||
              longitude == null ||
              !latitude.isFinite ||
              !longitude.isFinite ||
              latitude < -90 ||
              latitude > 90 ||
              longitude < -180 ||
              longitude > 180) {
            throw const FormatException(
              'La geometría de la ruta no es válida.',
            );
          }
          return LatLng(latitude, longitude);
        })
        .toList(growable: false);

    return RoutePreview(
      points: points,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }
}
