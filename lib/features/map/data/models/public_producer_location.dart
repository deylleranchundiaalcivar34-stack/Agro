class PublicProducerLocation {
  const PublicProducerLocation({
    required this.producerId,
    required this.alias,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.province,
    this.canton,
  });

  final String producerId;
  final String alias;
  final String placeName;
  final double latitude;
  final double longitude;
  final String? province;
  final String? canton;

  factory PublicProducerLocation.manual({
    required String producerId,
    required String alias,
    required String placeName,
    String? province,
    String? canton,
    required double latitude,
    required double longitude,
  }) {
    final cleanAlias = alias.trim();
    final cleanPlace = placeName.trim();
    final cleanProvince = province?.trim();
    final cleanCanton = canton?.trim();
    if (producerId.isEmpty ||
        cleanAlias.isEmpty ||
        cleanPlace.isEmpty ||
        cleanAlias.length > 80 ||
        cleanPlace.length > 120 ||
        (cleanProvince != null &&
            (cleanProvince.isEmpty || cleanProvince.length > 80)) ||
        (cleanCanton != null &&
            (cleanCanton.isEmpty || cleanCanton.length > 100)) ||
        ((cleanProvince == null) != (cleanCanton == null)) ||
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
      province: cleanProvince,
      canton: cleanCanton,
    );
  }

  factory PublicProducerLocation.fromMap(Map<String, dynamic> row) =>
      PublicProducerLocation(
        producerId: row['id_productor'] as String,
        alias: row['alias_publico'] as String,
        placeName: row['nombre_lugar'] as String,
        latitude: (row['latitud'] as num).toDouble(),
        longitude: (row['longitud'] as num).toDouble(),
        province: row['provincia'] as String?,
        canton: row['canton'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'id_productor': producerId,
    'alias_publico': alias,
    'nombre_lugar': placeName,
    'latitud': latitude,
    'longitud': longitude,
    if (province != null) 'provincia': province,
    if (canton != null) 'canton': canton,
  };
}
