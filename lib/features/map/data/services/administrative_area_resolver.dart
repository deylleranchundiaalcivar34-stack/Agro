import 'dart:convert';

import 'package:flutter/services.dart';

class AdministrativeAreaMatch {
  const AdministrativeAreaMatch({
    required this.provinceCode,
    required this.cantonCode,
  });

  final String provinceCode;
  final String cantonCode;
}

/// Finds the canton containing an approximate map point using local polygons.
/// The boundary asset is loaded and decoded only on the first map tap.
class AdministrativeAreaResolver {
  static const _assetPath = 'assets/data/ecuador_canton_boundaries.json';
  static const _coordinateScale = 100000;

  Future<List<_BoundaryFeature>>? _cachedBoundaries;

  Future<AdministrativeAreaMatch?> resolve({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final point = _Point(
      longitude: (longitude * _coordinateScale).round(),
      latitude: (latitude * _coordinateScale).round(),
    );
    final features = await (_cachedBoundaries ??= _loadBoundaries());
    for (final feature in features) {
      for (final polygon in feature.polygons) {
        if (!polygon.containsBounds(point)) continue;
        if (polygon.contains(point)) {
          return AdministrativeAreaMatch(
            provinceCode: feature.provinceCode,
            cantonCode: feature.cantonCode,
          );
        }
      }
    }
    return null;
  }

  Future<List<_BoundaryFeature>> _loadBoundaries() async {
    final decoded = jsonDecode(await rootBundle.loadString(_assetPath));
    if (decoded is! Map<String, dynamic> ||
        decoded['coordinate_scale'] != _coordinateScale ||
        decoded['features'] is! List) {
      throw const FormatException('Invalid Ecuador canton boundary data.');
    }

    final features = (decoded['features'] as List)
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Invalid canton boundary feature.');
          }
          final cantonCode = _requiredCode(value, 'code');
          final provinceCode = _requiredCode(value, 'province_code');
          final polygonsValue = value['polygons'];
          if (polygonsValue is! List || polygonsValue.isEmpty) {
            throw const FormatException('Canton has no boundary polygons.');
          }
          return _BoundaryFeature(
            provinceCode: provinceCode,
            cantonCode: cantonCode,
            polygons: List.unmodifiable(
              polygonsValue.map((polygon) {
                if (polygon is! Map<String, dynamic>) {
                  throw const FormatException('Invalid canton polygon.');
                }
                return _BoundaryPolygon.fromMap(polygon);
              }),
            ),
          );
        })
        .toList(growable: false);

    if (features.length != 223) {
      throw const FormatException('Incomplete Ecuador canton boundaries.');
    }
    return List.unmodifiable(features);
  }
}

class _BoundaryFeature {
  const _BoundaryFeature({
    required this.provinceCode,
    required this.cantonCode,
    required this.polygons,
  });

  final String provinceCode;
  final String cantonCode;
  final List<_BoundaryPolygon> polygons;
}

class _BoundaryPolygon {
  const _BoundaryPolygon({required this.bounds, required this.rings});

  final List<int> bounds;
  final List<List<_Point>> rings;

  factory _BoundaryPolygon.fromMap(Map<String, dynamic> map) {
    final boundsValue = map['bbox'];
    final ringsValue = map['rings'];
    if (boundsValue is! List ||
        boundsValue.length != 4 ||
        boundsValue.any((value) => value is! int) ||
        ringsValue is! List ||
        ringsValue.isEmpty) {
      throw const FormatException('Invalid canton polygon structure.');
    }
    final rings = ringsValue
        .map((value) {
          if (value is! List || value.length < 8 || value.length.isOdd) {
            throw const FormatException(
              'Invalid encoded canton boundary ring.',
            );
          }
          final points = <_Point>[];
          var longitude = value[0] as int;
          var latitude = value[1] as int;
          points.add(_Point(longitude: longitude, latitude: latitude));
          for (var index = 2; index < value.length; index += 2) {
            longitude += value[index] as int;
            latitude += value[index + 1] as int;
            points.add(_Point(longitude: longitude, latitude: latitude));
          }
          return List<_Point>.unmodifiable(points);
        })
        .toList(growable: false);

    return _BoundaryPolygon(
      bounds: List<int>.unmodifiable(boundsValue.cast<int>()),
      rings: List<List<_Point>>.unmodifiable(rings),
    );
  }

  bool containsBounds(_Point point) =>
      point.longitude >= bounds[0] &&
      point.latitude >= bounds[1] &&
      point.longitude <= bounds[2] &&
      point.latitude <= bounds[3];

  bool contains(_Point point) {
    if (!_pointInRing(point, rings.first)) return false;
    for (final hole in rings.skip(1)) {
      if (_pointInRing(point, hole)) return false;
    }
    return true;
  }
}

class _Point {
  const _Point({required this.longitude, required this.latitude});

  final int longitude;
  final int latitude;
}

bool _pointInRing(_Point point, List<_Point> ring) {
  var inside = false;
  for (
    var index = 0, previous = ring.length - 1;
    index < ring.length;
    previous = index++
  ) {
    final currentPoint = ring[index];
    final previousPoint = ring[previous];
    final crossesLatitude =
        (currentPoint.latitude > point.latitude) !=
        (previousPoint.latitude > point.latitude);
    if (!crossesLatitude) continue;
    final crossingLongitude =
        currentPoint.longitude +
        (point.latitude - currentPoint.latitude) *
            (previousPoint.longitude - currentPoint.longitude) /
            (previousPoint.latitude - currentPoint.latitude);
    if (point.longitude < crossingLongitude) inside = !inside;
  }
  return inside;
}

String _requiredCode(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.startsWith('EC')) return value;
  throw FormatException('Missing administrative code $key.');
}
