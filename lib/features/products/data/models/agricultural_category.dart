class AgriculturalCategory {
  const AgriculturalCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory AgriculturalCategory.fromMap(Map<String, dynamic> map) {
    return AgriculturalCategory(
      id: (map['id_categoria'] as num).toInt(),
      name: map['nombre_categoria'] as String,
    );
  }
}
