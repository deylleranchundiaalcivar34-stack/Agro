// Categorias agricolas: transforma los identificadores y nombres recibidos de Supabase.

/// Categoria disponible para clasificar publicaciones y filtrar el catalogo.
class AgriculturalCategory {
  const AgriculturalCategory({required this.id, required this.name});

  final int id;
  final String name;

  /// Lee una fila de categorias_agricolas conservando su identificador numerico.
  factory AgriculturalCategory.fromMap(Map<String, dynamic> map) {
    return AgriculturalCategory(
      id: (map['id_categoria'] as num).toInt(),
      name: map['nombre_categoria'] as String,
    );
  }
}
