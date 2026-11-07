// Campos reutilizables de cantidad y unidad para crear, editar o actualizar existencias.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/product_quantity.dart';
import '../../data/models/product_unit.dart';

/// Rechaza entradas con letras completas: pegar «5kg» no se convierte en «5».
class ProductQuantityInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => RegExp(r'^\d*(?:[.,]\d*)?$').hasMatch(newValue.text)
      ? newValue
      : oldValue;
}

/// Agrupa cantidad positiva y seleccion obligatoria de unidad con disposicion adaptable.
class ProductQuantityFields extends StatelessWidget {
  const ProductQuantityFields({
    super.key,
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
    this.label = 'Cantidad disponible',
    this.enabled = true,
  });
  final TextEditingController controller;
  final ProductUnit? unit;
  final ValueChanged<ProductUnit?> onUnitChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // El teclado facilita numeros; el validador aplica limites, decimales y enteros por unidad.
    final quantity = TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(
        decimal: unit != ProductUnit.unidad,
      ),
      inputFormatters: [ProductQuantityInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: '5',
        helperText: unit == ProductUnit.unidad
            ? 'Solo enteros positivos'
            : 'Maximo 2 decimales',
      ),
      validator: (value) => ProductQuantity.validate(value, unit: unit),
    );
    // No asignar una unidad ficticia cuando un producto antiguo tiene NULL.
    final selector = DropdownButtonFormField<ProductUnit>(
      key: ValueKey(unit),
      initialValue: unit,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Unidad de medida',
        helperText: 'Selecciona una opcion',
      ),
      items: ProductUnit.values
          .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
          .toList(),
      onChanged: enabled ? onUnitChanged : null,
      validator: (value) =>
          value == null ? 'Selecciona la unidad de medida.' : null,
    );
    // Mostrar los campos juntos con espacio suficiente o apilarlos en pantallas estrechas.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: quantity),
              const SizedBox(width: 16),
              Expanded(child: selector),
            ],
          );
        }
        return Column(
          children: [quantity, const SizedBox(height: 16), selector],
        );
      },
    );
  }
}
