// Validación y formato de cantidades compartidos por creación, edición y servicios.

import 'product_unit.dart';

/// Reglas del esquema actual: numeric(10,2) con CHECK cantidad_disponible > 0.
class ProductQuantity {
  // numeric(10,2) permite ocho dígitos enteros y hasta dos decimales.
  static const double maximum = 99999999.99;

  /// Acepta coma o punto, exige cantidad positiva y evita redondear entradas inválidas.
  static String? validate(String? input, {ProductUnit? unit}) {
    final text = (input ?? '').trim().replaceAll(',', '.');
    if (text.isEmpty) return 'Ingresa la cantidad.';
    if (!RegExp(r'^(?:\d+(?:\.\d{1,2})?|\.\d{1,2})$').hasMatch(text)) {
      return 'Usa un número mayor a 0 con un máximo de 2 decimales.';
    }
    final value = double.tryParse(text);
    // Los productos contados por unidad no admiten cantidades fraccionarias.
    if (unit == ProductUnit.unidad &&
        (value == null || value != value.truncateToDouble())) {
      return 'Para unidades ingresa un número entero positivo.';
    }
    if (value == null || !value.isFinite || value <= 0 || value > maximum) {
      return 'La cantidad debe estar entre 0,01 y 99.999.999,99.';
    }
    return null;
  }

  /// Reutiliza las mismas reglas al validar cantidades que ya son numéricas.
  static bool isValid(double value, {ProductUnit? unit}) =>
      validate(value.toString(), unit: unit) == null;
  /// Convierte una entrada validada; lanza FormatException si incumple las reglas.
  static double parse(String input) {
    final error = validate(input);
    if (error != null) throw FormatException(error);
    return double.parse(input.trim().replaceAll(',', '.'));
  }

  /// Muestra coma decimal y elimina los ceros decimales innecesarios.
  static String format(double value) => value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
}
