import 'dart:convert';

import 'package:flutter/services.dart';

class EcuadorProvince {
  const EcuadorProvince({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.cantons,
  });

  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final List<EcuadorCanton> cantons;

  factory EcuadorProvince.fromMap(Map<String, dynamic> map) => EcuadorProvince(
    code: _requiredString(map, 'code'),
    name: _requiredString(map, 'name'),
    latitude: _coordinate(map, 'latitude', -90, 90),
    longitude: _coordinate(map, 'longitude', -180, 180),
    cantons: List.unmodifiable(
      _requiredList(map, 'cantons').map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Cantón inválido en el catálogo.');
        }
        return EcuadorCanton.fromMap(value);
      }).toList()..sort(_byName),
    ),
  );
}

class EcuadorCanton {
  const EcuadorCanton({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String code;
  final String name;
  final double latitude;
  final double longitude;

  factory EcuadorCanton.fromMap(Map<String, dynamic> map) => EcuadorCanton(
    code: _requiredString(map, 'code'),
    name: _requiredString(map, 'name'),
    latitude: _coordinate(map, 'latitude', -90, 90),
    longitude: _coordinate(map, 'longitude', -180, 180),
  );
}

class EcuadorAdministrativeCatalog {
  EcuadorAdministrativeCatalog._();

  static const _assetPath = 'assets/data/ecuador_administrative_divisions.json';
  static Future<List<EcuadorProvince>>? _cached;

  static Future<List<EcuadorProvince>> load() => _cached ??= _load();

  static Future<List<EcuadorProvince>> _load() async {
    final decoded = jsonDecode(await rootBundle.loadString(_assetPath));
    if (decoded is! Map<String, dynamic> || decoded['provinces'] is! List) {
      throw const FormatException('Catálogo de ubicaciones inválido.');
    }
    final provinces = (decoded['provinces'] as List).map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Provincia inválida en el catálogo.');
      }
      return EcuadorProvince.fromMap(value);
    }).toList()..sort(_byName);
    if (provinces.length != 24 ||
        provinces.any((province) => province.cantons.isEmpty)) {
      throw const FormatException(
        'El catálogo administrativo está incompleto.',
      );
    }
    return List.unmodifiable(provinces);
  }
}

List<dynamic> _requiredList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List || value.isEmpty) {
    throw FormatException('Falta la lista $key en el catálogo.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('Falta el texto $key en el catálogo.');
}

double _coordinate(
  Map<String, dynamic> map,
  String key,
  double minimum,
  double maximum,
) {
  final value = map[key];
  if (value is num && value.isFinite && value >= minimum && value <= maximum) {
    return value.toDouble();
  }
  throw FormatException('Coordenada $key inválida en el catálogo.');
}

int _byName(dynamic first, dynamic second) => (first.name as String)
    .toLowerCase()
    .compareTo((second.name as String).toLowerCase());
