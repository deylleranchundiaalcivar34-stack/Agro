// Unidades comerciales: separa los codigos guardados en Supabase de sus etiquetas visibles.

/// Opciones permitidas en el selector; ninguna se asigna por defecto.
enum ProductUnit {
  kg('kg', 'Kilogramos (kg)', 'kg'),
  lb('lb', 'Libras (libras)', 'libras'),
  unidad('unidad', 'Unidades (unidades)', 'unidades');

  const ProductUnit(this.value, this.label, this.symbol);
  // Codigo persistido, etiqueta del selector y texto usado junto a cantidad y precio.
  final String value;
  final String label;
  final String symbol;

  /// Reconoce codigos y equivalencias conocidas; NULL o valores desconocidos quedan sin unidad.
  static ProductUnit? fromValue(Object? value) => switch (value) {
    'kg' => kg,
    'lb' || 'libras' => lb,
    'unidad' || 'unidades' => unidad,
    _ => null,
  };
}
