// Confirmación destructiva independiente de la ocultación lógica del catálogo.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/agricultural_product.dart';

/// El llamador debe confirmar el DELETE real del servidor antes de devolver true.
/// Este componente no elimina registros ni archivos remotos por sí mismo.
class ProductPermanentDeleteButton extends StatefulWidget {
  const ProductPermanentDeleteButton({
    super.key,
    required this.product,
    required this.onConfirmed,
    required this.onDeleted,
    this.busy = false,
    this.errorMessage,
  });

  final AgriculturalProduct product;
  final Future<bool> Function(String confirmationName) onConfirmed;
  final VoidCallback onDeleted;
  final bool busy;
  final String? Function()? errorMessage;

  @override
  State<ProductPermanentDeleteButton> createState() =>
      _ProductPermanentDeleteButtonState();
}

class _ProductPermanentDeleteButtonState
    extends State<ProductPermanentDeleteButton> {
  bool _confirming = false;
  bool _deleting = false;

  // Volver a comprobar la sesión después del diálogo evita usar permisos anteriores.
  bool _isOwner(AuthViewModel auth) =>
      auth.selectedRole == UserRole.producer &&
      auth.currentUser?.id == widget.product.producerId;

  Future<void> _confirm() async {
    if (_confirming ||
        _deleting ||
        widget.busy ||
        !_isOwner(context.read<AuthViewModel>())) {
      return;
    }
    final productId = widget.product.id;
    final productName = widget.product.name.trim();
    setState(() => _confirming = true);
    try {
      final confirmation = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PermanentDeleteDialog(productName: productName),
      );
      if (!mounted ||
          confirmation == null ||
          widget.busy ||
          !_isOwner(context.read<AuthViewModel>()) ||
          widget.product.id != productId ||
          widget.product.name.trim() != productName ||
          confirmation != productName) {
        return;
      }
      setState(() => _deleting = true);
      // La escritura se delegará al flujo autorizado una vez revisadas las relaciones reales.
      final deleted = await widget.onConfirmed(confirmation);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: deleted ? AppColors.primary : AppColors.error,
          content: Text(
            deleted
                ? 'Producto eliminado definitivamente'
                : widget.errorMessage?.call() ?? 'No se pudo confirmar la eliminación. Revisa el producto antes de reintentar.',
          ),
        ),
      );
      if (deleted) widget.onDeleted();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo confirmar la eliminación. Revisa el producto antes de reintentar.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner(context.watch<AuthViewModel>())) {
      return const SizedBox.shrink();
    }
    return PopScope(
      canPop: !_deleting,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
        ),
        onPressed: _confirming || _deleting || widget.busy ? null : _confirm,
        icon: _deleting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_forever_outlined),
        label: Text(_deleting ? 'Eliminando...' : 'Eliminar definitivamente'),
      ),
    );
  }
}

/// Solo devuelve una confirmación explícita cuando coincide el nombre completo.
class _PermanentDeleteDialog extends StatefulWidget {
  const _PermanentDeleteDialog({required this.productName});
  final String productName;
  @override
  State<_PermanentDeleteDialog> createState() => _PermanentDeleteDialogState();
}

class _PermanentDeleteDialogState extends State<_PermanentDeleteDialog> {
  String _typedName = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('¿Eliminar producto definitivamente?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estás a punto de eliminar permanentemente esta publicación. Esta acción no se puede deshacer y el producto dejará de estar disponible en Agro+.',
        ),
        const SizedBox(height: 12),
        const Text('Las fotografías pueden permanecer en Cloudinary.'),
        const SizedBox(height: 16),
        Text('Escribe el nombre del producto: ${widget.productName}'),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Nombre del producto',
            helperText: 'Debe coincidir exactamente con el nombre mostrado.',
          ),
          onChanged: (value) => setState(() => _typedName = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        ),
        onPressed:
            _typedName.trim().isNotEmpty &&
                _typedName.trim() == widget.productName.trim()
            ? () => Navigator.pop(context, _typedName.trim())
            : null,
        child: const Text('Eliminar definitivamente'),
      ),
    ],
  );
}
