import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/agricultural_product.dart';
import '../../data/models/product_quantity.dart';
import '../viewmodels/products_viewmodel.dart';
import 'product_quantity_fields.dart';
import 'product_status_badge.dart';

/// Presenta la fase actual y reserva cada avance al productor propietario.
class ProductPhaseSection extends StatelessWidget {
  const ProductPhaseSection({
    super.key,
    required this.product,
    required this.onChanged,
  });
  final AgriculturalProduct product;
  final ValueChanged<AgriculturalProduct> onChanged;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final vm = context.watch<ProductsViewModel>();
    final owner =
        auth.selectedRole == UserRole.producer &&
        auth.currentUser?.id == product.producerId;
    final canAdvance = owner && (product.isPresale || product.isDirectSale);
    final targetPhase = product.isDirectSale
        ? 'Canales alternativos'
        : 'Venta directa';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fase de comercializacion',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ProductStatusBadge(product.phaseName),
                if (canAdvance) ...[
                  const Icon(
                    Icons.arrow_forward_outlined,
                    color: AppColors.primary,
                  ),
                  ProductStatusBadge(targetPhase, muted: true),
                ],
              ],
            ),
            if (canAdvance) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: vm.isSubmitting
                    ? null
                    : () async {
                        final updated = await showDialog<AgriculturalProduct>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              _PhaseTransitionForm(product: product),
                        );
                        if (updated != null && context.mounted) {
                          onChanged(updated);
                        }
                      },
                icon: const Icon(Icons.storefront_outlined),
                label: Text('Pasar a $targetPhase'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Formulario local: conserva unidad y visibilidad y solicita doble confirmacion explicita.
class _PhaseTransitionForm extends StatefulWidget {
  const _PhaseTransitionForm({required this.product});
  final AgriculturalProduct product;
  @override
  State<_PhaseTransitionForm> createState() => _PhaseTransitionFormState();
}

class _PhaseTransitionFormState extends State<_PhaseTransitionForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  bool _available = false;
  bool _working = false;
  bool _saving = false;
  String? _error;
  bool get _alternative => widget.product.isDirectSale;
  String get _targetPhase =>
      _alternative ? 'Canales alternativos' : 'Venta directa';

  // Mantener las reglas de unidad y limitar solo la cantidad del canal alternativo.
  String? _validateQuantity(String? value) {
    final error = ProductQuantity.validate(value, unit: widget.product.unit);
    if (error != null) return error;
    if (_alternative &&
        ProductQuantity.parse(value!) > widget.product.availableQuantity) {
      return 'La cantidad no puede superar la disponible (${widget.product.quantityWithUnit}).';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: ProductQuantity.format(widget.product.availableQuantity),
    );
    _price = TextEditingController(
      text: widget.product.unitPrice.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Revalida sesion, rol y propietario tras el dialogo; solo la RPC puede confirmar exito.
  Future<void> _submit() async {
    if (_working || !_key.currentState!.validate() || !_available) return;
    if (widget.product.unit == null) {
      setState(
        () =>
            _error = 'Registra primero la unidad del producto mediante Editar.',
      );
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          icon: const Icon(Icons.storefront_outlined, color: AppColors.primary),
          title: Text('¿Cambiar a $_targetPhase?'),
          content: Text(
            _alternative
                ? '¿Confirmas destinar esta cantidad a Canales alternativos con el precio indicado?'
                : '¿Esta seguro de que este producto ya esta disponible para la venta?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Confirmar cambio'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final auth = context.read<AuthViewModel>();
      if (auth.selectedRole != UserRole.producer ||
          auth.currentUser?.id != widget.product.producerId) {
        setState(
          () => _error = 'Solo el productor propietario puede cambiar la fase.',
        );
        return;
      }
      final vm = context.read<ProductsViewModel>();
      // El progreso representa la peticion, no el tiempo de decision del productor.
      setState(() => _saving = true);
      final transition = _alternative
          ? vm.transitionToAlternativeChannels
          : vm.transitionToDirectSale;
      final updated = await transition(
        widget.product,
        quantity: ProductQuantity.parse(_quantity.text),
        price: double.parse(_price.text.trim().replaceAll(',', '.')),
      );
      if (!mounted) return;
      if (updated != null) {
        Navigator.pop(context, updated);
      } else {
        setState(
          () =>
              _error = vm.errorMessage ?? 'No se pudo confirmar la transicion.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    // El formulario es desplazable con teclado y texto ampliado; no oculta las acciones.
    final form = Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: product.name,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Producto'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ProductStatusBadge(product.phaseName),
              const Icon(Icons.arrow_forward_outlined),
              ProductStatusBadge(_targetPhase),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('direct-sale-quantity'),
            controller: _quantity,
            enabled: !_working,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ProductQuantityInputFormatter()],
            decoration: InputDecoration(
              labelText: _alternative
                  ? 'Cantidad destinada al canal alternativo'
                  : 'Cantidad real disponible',
              helperText: _alternative
                  ? 'Disponible: ${product.quantityWithUnit}'
                  : 'Obligatorio · Mayor que cero',
            ),
            validator: _validateQuantity,
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Unidad de medida actual',
            ),
            child: Text(
              product.unit?.label ?? 'Sin registrar: edita primero el producto',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('direct-sale-price'),
            controller: _price,
            enabled: !_working,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio unitario (USD)',
            ),
            validator: (value) {
              final number = double.tryParse(
                (value ?? '').trim().replaceAll(',', '.'),
              );
              return number == null || !number.isFinite || number < 0
                  ? 'Ingresa un precio valido, mayor o igual a cero.'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              _alternative
                  ? 'Confirmo la cantidad destinada a Canales alternativos.'
                  : 'Confirmo que el producto ya esta disponible para comercializacion.',
            ),
            value: _available,
            onChanged: _working
                ? null
                : (value) => setState(() => _available = value == true),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _working || !_available ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_outlined),
            label: Text(_saving ? 'Guardando...' : 'Revisar cambio'),
          ),
          TextButton(
            onPressed: _working ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !_working,
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: AppColors.primary,
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Pasar a $_targetPhase',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: AppColors.surface),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MediaQuery.disableAnimationsOf(context)
                      ? form
                      : form.animate().fadeIn(duration: 250.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
