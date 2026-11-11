// Modelo usado por el servicio para crear y editar los campos persistidos de un producto.

import 'product_quantity.dart';
import 'product_unit.dart';

/// Representacion de escritura y edicion; las fotografias se guardan por separado.
class ProductModel {
  /// Exige una unidad explicita y aplica las reglas de cantidad antes de escribir.
  bool get hasValidQuantity =>
      unidadMedida != null &&
      ProductQuantity.isValid(cantidadDisponible, unit: unidadMedida);
  // Datos persistidos; la unidad nullable permite leer publicaciones anteriores.
  final ProductUnit? unidadMedida;
  final String? idProducto;
  final String idProductor;
  final int idCategoria;
  final int idFaseActual;
  final String nombreProducto;
  final double cantidadDisponible;
  final double precioUnitario;
  final DateTime? fechaEstimadaCosecha;
  final bool estadoPublicacion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // URLs de las fotografias almacenadas en Cloudinary
  final List<String> fotografias;

  /// Usa la primera URL como portada sin crear una imagen ficticia.
  String? get imagenUrl => fotografias.isEmpty ? null : fotografias.first;

  const ProductModel({
    this.unidadMedida,
    this.idProducto,
    required this.idProductor,
    required this.idCategoria,
    required this.idFaseActual,
    required this.nombreProducto,
    required this.cantidadDisponible,
    required this.precioUnitario,
    this.fechaEstimadaCosecha,
    this.estadoPublicacion = true,
    this.createdAt,
    this.updatedAt,
    this.fotografias = const [],
  });

  // Convertir los datos de Supabase en un objeto Dart
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      unidadMedida: ProductUnit.fromValue(json['unidad_medida']),
      idProducto: json['id_producto']?.toString(),
      idProductor: json['id_productor'].toString(),
      idCategoria: (json['id_categoria'] as num).toInt(),
      idFaseActual: (json['id_fase_actual'] as num).toInt(),
      nombreProducto: json['nombre_producto'] as String,
      cantidadDisponible: (json['cantidad_disponible'] as num).toDouble(),
      precioUnitario: (json['precio_unitario'] as num).toDouble(),
      fechaEstimadaCosecha: json['fecha_estimada_cosecha'] != null
          ? DateTime.parse(json['fecha_estimada_cosecha'].toString())
          : null,
      estadoPublicacion: json['estado_publicacion'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      fotografias: json['fotografias'] != null
          ? List<String>.from(json['fotografias'])
          : const [],
    );
  }

  // Convertir el objeto Dart en JSON para Supabase
  // La escritura omite ID, marcas de tiempo y fotografias; la cosecha se envia sin hora.
  Map<String, dynamic> toJson() {
    return {
      'id_productor': idProductor,
      'id_categoria': idCategoria,
      'id_fase_actual': idFaseActual,
      'nombre_producto': nombreProducto,
      'cantidad_disponible': cantidadDisponible,
      'unidad_medida': unidadMedida?.value,
      'precio_unitario': precioUnitario,
      'fecha_estimada_cosecha': fechaEstimadaCosecha
          ?.toIso8601String()
          .split('T')
          .first,
      'estado_publicacion': estadoPublicacion,
    };
  }

  // Crear una copia modificando solamente los campos necesarios
  // Los argumentos nulos conservan el valor actual; clearHarvestDate permite quitar la cosecha.
  ProductModel copyWith({
    ProductUnit? unidadMedida,
    String? idProducto,
    String? idProductor,
    int? idCategoria,
    int? idFaseActual,
    String? nombreProducto,
    double? cantidadDisponible,
    double? precioUnitario,
    DateTime? fechaEstimadaCosecha,
    bool clearHarvestDate = false,
    bool? estadoPublicacion,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? fotografias,
  }) {
    return ProductModel(
      unidadMedida: unidadMedida ?? this.unidadMedida,
      idProducto: idProducto ?? this.idProducto,
      idProductor: idProductor ?? this.idProductor,
      idCategoria: idCategoria ?? this.idCategoria,
      idFaseActual: idFaseActual ?? this.idFaseActual,
      nombreProducto: nombreProducto ?? this.nombreProducto,
      cantidadDisponible: cantidadDisponible ?? this.cantidadDisponible,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      fechaEstimadaCosecha: clearHarvestDate
          ? null
          : fechaEstimadaCosecha ?? this.fechaEstimadaCosecha,
      estadoPublicacion: estadoPublicacion ?? this.estadoPublicacion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fotografias: fotografias ?? this.fotografias,
    );
  }
}
