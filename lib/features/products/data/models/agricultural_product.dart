class AgriculturalProduct {
  const AgriculturalProduct({
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
  });

  final String id;
  final String producerId;
  final int categoryId;
  final int phaseId;
  final String name;
  final double availableQuantity;
  final double unitPrice;
  final bool isPublished;
  final String categoryName;
  final String phaseName;
  final DateTime? estimatedHarvestDate;

  factory AgriculturalProduct.fromMap(Map<String, dynamic> map) {
    final category = map['categoria'] as Map<String, dynamic>?;
    final phase = map['fase'] as Map<String, dynamic>?;
    return AgriculturalProduct(
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
