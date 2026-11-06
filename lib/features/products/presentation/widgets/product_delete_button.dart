// Confirmación de retirada lógica de publicaciones, disponible solo para el productor propietario.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/agricultural_product.dart';
import '../viewmodels/products_viewmodel.dart';

/// Botón de gestión que solicita confirmación y avisa a la vista tras una retirada exitosa.
class ProductDeleteButton extends StatefulWidget {
  const ProductDeleteButton({
    super.key,
    required this.product,
    required this.onDeleted,
  });
  final AgriculturalProduct product;
  final VoidCallback onDeleted;

  @override
  State<ProductDeleteButton> createState() => _ProductDeleteButtonState();
}

class _ProductDeleteButtonState extends State<ProductDeleteButton> {
  // Evita abrir más de un diálogo de confirmación al pulsar repetidamente.
  bool _confirming = false;

  /// Confirma la intención, revalida la sesión y delega la desactivación en el ViewModel.
  Future<void> _confirm() async {
    final vm = context.read<ProductsViewModel>();
    if (_confirming || vm.isSubmitting) return;
    final visible = !widget.product.isPublished;
    setState(() => _confirming = true);
    try {
      final confirmed = visible
          ? true
          : await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: const Text('Ocultar producto'),
                content: const Text(
                  '¿Deseas ocultar este producto? Dejará de aparecer en el catálogo, pero conservarás su información',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Ocultar producto'),
                  ),
                ],
              ),
            );
      if (!mounted || confirmed != true) return;
      // Volver a comprobar propietario y rol después de esperar la decisión del diálogo.
      final auth = context.read<AuthViewModel>();
      if (auth.selectedRole != UserRole.producer ||
          auth.currentUser?.id != widget.product.producerId) {
        return;
      }
      final ok = await vm.setVisibility(widget.product.id, visible);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? AppColors.primary : AppColors.error,
          content: Text(
            ok
                ? vm.visibilityWarning ??
                      (visible
                          ? 'Producto visible nuevamente'
                          : 'Producto ocultado correctamente')
                : vm.errorMessage ??
                      'No se pudo cambiar la visibilidad del producto.',
          ),
        ),
      );
      if (ok) widget.onDeleted();
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final vm = context.watch<ProductsViewModel>();
    if (auth.selectedRole != UserRole.producer ||
        auth.currentUser?.id != widget.product.producerId) {
      return const SizedBox.shrink();
    }
    // Mantener visible el progreso e impedir salir mientras se procesa la escritura.
    return PopScope(
      canPop: !vm.isSubmitting,
      child: OutlinedButton.icon(
        onPressed: vm.isSubmitting || _confirming ? null : _confirm,
        icon: vm.isSubmitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                widget.product.isPublished
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
        label: Text(
          widget.product.isPublished ? 'Ocultar producto' : 'Volver a mostrar',
        ),
      ),
    );
  }
}
