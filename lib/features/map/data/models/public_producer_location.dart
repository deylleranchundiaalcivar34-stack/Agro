class PublicProducerLocation {
  const PublicProducerLocation({
    required this.producerId,
    required this.alias,
    required this.placeName,
    required this.latitude,
    required this.longitude,
  });

  final String producerId;
  final String alias;
  final String placeName;
  final double latitude;
  final double longitude;

  factory PublicProducerLocation.manual({
    required String producerId,
    required String alias,
    required String placeName,
    required double latitude,
    required double longitude,
  }) {
    final cleanAlias = alias.trim();
    final cleanPlace = placeName.trim();
    if (producerId.isEmpty ||
        cleanAlias.isEmpty ||
        cleanPlace.isEmpty ||
        cleanAlias.length > 80 ||
        cleanPlace.length > 120 ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw ArgumentError('Ingresa un alias, un lugar y un punto validos.');
    }
    return PublicProducerLocation(
      producerId: producerId,
      alias: cleanAlias,
      placeName: cleanPlace,
      latitude: (latitude * 100).roundToDouble() / 100,
      longitude: (longitude * 100).roundToDouble() / 100,
    );
  }

  factory PublicProducerLocation.fromMap(Map<String, dynamic> row) =>
      PublicProducerLocation(
        producerId: row['id_productor'] as String,
        alias: row['alias_publico'] as String,
        placeName: row['nombre_lugar'] as String,
        latitude: (row['latitud'] as num).toDouble(),
        longitude: (row['longitud'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
    'id_productor': producerId,
    'alias_publico': alias,
    'nombre_lugar': placeName,
    'latitud': latitude,
    'longitud': longitude,
  };
}
