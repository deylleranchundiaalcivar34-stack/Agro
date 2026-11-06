// Modelo de lectura del catálogo y detalle, con categoría, fase y fotografías relacionadas.

import 'product_quantity.dart';
import 'product_unit.dart';

/// Datos de una publicación y textos de presentación compartidos por las vistas.
class AgriculturalProduct {
  // La creación existente identifica esta fase por nombre, nunca por un ID fijo.
  bool get isPresale => phaseName.trim().toLowerCase() == 'preventa';
  String get quantityLabel =>
      isPresale ? 'Cantidad anunciada' : 'Cantidad disponible';
  String get formattedQuantity => ProductQuantity.format(availableQuantity);

  /// Presenta la cantidad sin inventar unidades para registros históricos con NULL.
  String get quantityWithUnit => unit == null
      ? '$formattedQuantity (unidad sin registrar)'
      : '$formattedQuantity ${unit!.symbol}';

  /// Corresponde a productos.unidad_medida; NULL no implica una unidad por defecto.
  final ProductUnit? unit;

  /// Añade la unidad al precio solo cuando está registrada.
  String get priceWithUnit =>
      '\$${unitPrice.toStringAsFixed(2)}${unit == null ? '' : '/${unit!.symbol}'}';

  /// Formatea la fecha de cosecha como día/mes/año cuando está disponible.
  String? get harvestLabel {
    final date = estimatedHarvestDate;
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  const AgriculturalProduct({
    this.unit,
    required this.id,
    required this.producerId,
    required this.categoryId,
    required this.phaseId,
    required this.name,
    required this.availableQuantity,
    required this.unitPrice,
    required this.isPublished,
    required this.categoryName,
    required this.phaseName,
    this.estimatedHarvestDate,
    this.imagenUrl,
    this.fotografias = const [],
  });

  // Datos de identificación, relaciones y valores mostrados en la publicación.
  final String? imagenUrl;
  final List<String> fotografias;
  final String id;
  final String producerId;
  final int categoryId;
  final int phaseId;
  final String name;
  final double availableQuantity;
  final double unitPrice;
  final bool isPublished;
  String get visibilityLabel => isPublished ? 'Visible' : 'Oculto';

  /// Refleja un cambio confirmado de visibilidad sin perder datos ni fotografías locales.
  AgriculturalProduct withVisibility(bool visible) => AgriculturalProduct(
    unit: unit,
    id: id,
    producerId: producerId,
    categoryId: categoryId,
    phaseId: phaseId,
    name: name,
    availableQuantity: availableQuantity,
    unitPrice: unitPrice,
    isPublished: visible,
    categoryName: categoryName,
    phaseName: phaseName,
    estimatedHarvestDate: estimatedHarvestDate,
    imagenUrl: imagenUrl,
    fotografias: fotografias,
  );
  final String categoryName;
  final String phaseName;
  final DateTime? estimatedHarvestDate;

  /// Actualiza el estado local con la cantidad confirmada y conserva los demás datos.
  AgriculturalProduct withQuantity(double quantity, {ProductUnit? unit}) =>
      AgriculturalProduct(
        unit: unit ?? this.unit,
        id: id,
        producerId: producerId,
        categoryId: categoryId,
        phaseId: phaseId,
        name: name,
        availableQuantity: quantity,
        unitPrice: unitPrice,
        isPublished: isPublished,
        categoryName: categoryName,
        phaseName: phaseName,
        estimatedHarvestDate: estimatedHarvestDate,
        imagenUrl: imagenUrl,
        fotografias: fotografias,
      );

  /// Convierte la respuesta de productos y sus relaciones en el modelo de lectura.
  factory AgriculturalProduct.fromMap(Map<String, dynamic> map) {
    final fotos = List<dynamic>.from(
      map['fotografias_producto'] as List? ?? [],
    );
    // Orden estable para elegir la misma fotografía principal en cada lectura.
    fotos.sort(
      (a, b) => a['id_fotografia'].toString().compareTo(
        b['id_fotografia'].toString(),
      ),
    );
    final String? imagenUrl = fotos.isNotEmpty
        ? fotos.first['url_fotografia'] as String?
        : null;
    // Los alias categoria y fase corresponden a la selección del repositorio.
    final category = map['categoria'] as Map<String, dynamic>?;
    final phase = map['fase'] as Map<String, dynamic>?;
    return AgriculturalProduct(
      unit: ProductUnit.fromValue(map['unidad_medida']),
      imagenUrl: imagenUrl,
      fotografias: fotos
          .map((photo) => photo['url_fotografia'])
          .whereType<String>()
          .toList(),
      id: map['id_producto'] as String,
      producerId: map['id_productor'] as String,
      categoryId: (map['id_categoria'] as num).toInt(),
      phaseId: (map['id_fase_actual'] as num).toInt(),
      name: map['nombre_producto'] as String,
      availableQuantity: (map['cantidad_disponible'] as num).toDouble(),
      unitPrice: (map['precio_unitario'] as num).toDouble(),
      isPublished: map['estado_publicacion'] as bool? ?? false,
      categoryName: category?['nombre_categoria'] as String? ?? 'Sin categoría',
      phaseName: phase?['nombre_fase'] as String? ?? 'Sin fase',
      estimatedHarvestDate: map['fecha_estimada_cosecha'] == null
          ? null
          : DateTime.tryParse(map['fecha_estimada_cosecha'] as String),
    );
  }
}
