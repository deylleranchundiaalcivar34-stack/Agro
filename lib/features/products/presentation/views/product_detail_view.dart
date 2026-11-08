// Detalle del lote y acciones disponibles para su propietario o una cuenta compradora.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../widgets/product_card.dart';
import '../widgets/product_delete_button.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../chat/presentation/widgets/contact_producer_button.dart';
import '../../data/models/agricultural_product.dart';
import '../viewmodels/products_viewmodel.dart';

/// Carga una publicacion por ID y actualiza su lectura al regresar de la edicion.
class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key, required this.productId});
  final String productId;
  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  // La misma Future se conserva entre reconstrucciones para no repetir consultas involuntarias.
  late Future<AgriculturalProduct?> _product;
  @override
  void initState() {
    super.initState();
    _product = context.read<ProductsViewModel>().getProduct(widget.productId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Detalle de preventa')),
    body: FutureBuilder<AgriculturalProduct?>(
      future: _product,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final product = snapshot.data;
        if (snapshot.hasError || product == null) {
          return const Center(child: Text('Este lote no esta disponible.'));
        }
        return _Detail(
          product: product,
          onQuantity: () => _editQuantity(product.id),
          onEdit: () async {
            await context.push<bool>(
              '${AppRoutes.products}/${product.id}/edit',
            );
            if (!context.mounted) return;
            setState(
              () => _product = context.read<ProductsViewModel>().getProduct(
                widget.productId,
              ),
            );
          },
        );
      },
    ),
  );

  /// Abre la edicion reducida y vuelve a consultar el producto al regresar.
  Future<void> _editQuantity(String productId) async {
    await context.push<bool>(
      '${AppRoutes.products}/$productId/edit?quantity=1',
    );
    if (!mounted) return;
    setState(
      () => _product = context.read<ProductsViewModel>().getProduct(
        widget.productId,
      ),
    );
  }
}

/// Contenido del detalle y permisos visuales de edicion, retirada e interes.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.product,
    required this.onEdit,
    required this.onQuantity,
  });
  final VoidCallback onEdit;
  final VoidCallback onQuantity;
  final AgriculturalProduct product;
  @override
  Widget build(BuildContext context) {
    final role = context.select<AuthViewModel, UserRole>(
      (auth) => auth.selectedRole,
    );
    final userId = context.select<AuthViewModel, String?>(
      (auth) => auth.currentUser?.id,
    );
    // La interfaz distingue al propietario; el servicio y RLS siguen controlando las escrituras.
    final owner = userId == product.producerId;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // Portada y datos informativos del lote, con icono alternativo si no hay fotografia.
          Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: imagenProducto(product.imagenUrl),
          ),
          const SizedBox(height: 22),
          Text(
            product.phaseName,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.categoryName,
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _Row(
            icon: Icons.inventory_2_outlined,
            label: product.quantityLabel,
            value: product.quantityWithUnit,
          ),
          _Row(
            icon: Icons.payments_outlined,
            label: 'Precio unitario',
            value: product.priceWithUnit,
          ),
          if (product.estimatedHarvestDate != null)
            _Row(
              icon: Icons.event_outlined,
              label: 'Cosecha estimada',
              value: _date(product.estimatedHarvestDate!),
            ),
          const SizedBox(height: 28),
          if (owner && role == UserRole.producer)
            _Row(
              icon: product.isPublished
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              label: 'Visibilidad',
              value: product.visibilityLabel,
            ),
          // Las acciones de gestion se muestran unicamente al productor propietario.
          if (owner && role == UserRole.producer)
            FilledButton.icon(
              onPressed: context.watch<ProductsViewModel>().isSubmitting
                  ? null
                  : onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar publicacion'),
            ),
          // Las acciones de gestion se muestran unicamente al productor propietario.
          if (owner && role == UserRole.producer) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: context.watch<ProductsViewModel>().isSubmitting
                  ? null
                  : onQuantity,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Actualizar cantidad'),
            ),
            const SizedBox(height: 8),
            ProductDeleteButton(
              product: product,
              onDeleted: () => context.go(AppRoutes.products),
            ),
          ],
          if (owner)
            const _Notice(
              text: 'Esta es tu publicacion. Los intereses se guardan de forma privada.',
            )
          else if ((role == UserRole.buyer || role == UserRole.producer) &&
              product.isPublished &&
              product.availableQuantity > 0) ...[
            FilledButton.icon(
              onPressed: () => _interestSheet(context),
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Registrar interes'),
            ),
            if (product.isPublished && product.availableQuantity > 0) ...[
              const SizedBox(height: 8),
              ContactProducerButton(productId: product.id),
            ],
          ] else
            const _Notice(
              text: 'El interes esta disponible en publicaciones activas de otras personas con unidades disponibles.',
            ),
        ],
      ),
    );
  }

  /// Recoge una cantidad proyectada; registrar interes no descuenta existencias.
  Future<void> _interestSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _InterestFormSheet(
        product: product,
        onRegistered: () => messenger.showSnackBar(
          const SnackBar(content: Text('Tu interes fue registrado.')),
        ),
      ),
    );
  }

  /// Muestra dia, mes y ano para la fecha de cosecha.
  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _InterestFormSheet extends StatefulWidget {
  const _InterestFormSheet({required this.product, required this.onRegistered});

  final AgriculturalProduct product;
  final VoidCallback onRegistered;

  @override
  State<_InterestFormSheet> createState() => _InterestFormSheetState();
}

class _InterestFormSheetState extends State<_InterestFormSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interes de preventa',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Indica la cantidad que te interesaria adquirir de ${widget.product.name}.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cantidad proyectada'),
            validator: (value) {
              final quantity = double.tryParse(
                (value ?? '').replaceAll(',', '.'),
              );
              return quantity == null || quantity <= 0
                  ? 'Ingresa una cantidad mayor a 0.'
                  : null;
            },
          ),
          const SizedBox(height: 20),
          Consumer<ProductsViewModel>(
            builder: (context, viewModel, _) => FilledButton(
              onPressed: viewModel.isSubmitting
                  ? null
                  : () => _submit(viewModel),
              child: Text(
                viewModel.isSubmitting ? 'Guardando...' : 'Confirmar interes',
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit(ProductsViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;

    final saved = await viewModel.registerInterest(
      productId: widget.product.id,
      quantity: double.parse(_controller.text.replaceAll(',', '.')),
    );
    if (!mounted) return;

    if (saved) {
      Navigator.pop(context);
      widget.onRegistered();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'No se pudo registrar.'),
        ),
      );
    }
  }
}

/// Fila informativa reutilizable con icono, etiqueta y valor.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// Aviso contextual para el propietario o cuentas sin acceso al registro de interes.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
