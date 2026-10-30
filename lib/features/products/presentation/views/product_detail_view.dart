import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/agricultural_product.dart';
import '../viewmodels/products_viewmodel.dart';

class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key, required this.productId});
  final String productId;
  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  late final Future<AgriculturalProduct?> _product;
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
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        final product = snapshot.data;
        if (snapshot.hasError || product == null)
          return const Center(child: Text('Este lote no está disponible.'));
        return _Detail(product: product);
      },
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.product});
  final AgriculturalProduct product;
  @override
  Widget build(BuildContext context) {
    final role = context.select<AuthViewModel, UserRole>(
      (auth) => auth.selectedRole,
    );
    final userId = context.select<AuthViewModel, String?>(
      (auth) => auth.currentUser?.id,
    );
    final owner = userId == product.producerId;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.eco_outlined,
              size: 78,
              color: AppColors.primary,
            ),
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
            label: 'Disponible',
            value: _amount(product.availableQuantity),
          ),
          _Row(
            icon: Icons.payments_outlined,
            label: 'Precio unitario',
            value: '\$${product.unitPrice.toStringAsFixed(2)}',
          ),
          if (product.estimatedHarvestDate != null)
            _Row(
              icon: Icons.event_outlined,
              label: 'Cosecha estimada',
              value: _date(product.estimatedHarvestDate!),
            ),
          const SizedBox(height: 28),
          if (owner)
            const _Notice(
              text: 'Esta es tu publicación. Los intereses de compradores se guardan de forma privada.',
            )
          else if (role == UserRole.buyer)
            FilledButton.icon(
              onPressed: () => _interestSheet(context),
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Registrar interés'),
            )
          else
            const _Notice(
              text: 'El registro de interés está disponible para cuentas compradoras.',
            ),
        ],
      ),
    );
  }

  Future<void> _interestSheet(BuildContext context) async {
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(sheet).bottom + 24,
        ),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interés de preventa',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Indica la cantidad que te interesaría adquirir de ${product.name}.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cantidad proyectada',
                ),
                validator: (value) {
                  final q = double.tryParse((value ?? '').replaceAll(',', '.'));
                  return q == null || q <= 0
                      ? 'Ingresa una cantidad mayor a 0.'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              Consumer<ProductsViewModel>(
                builder: (context, vm, _) => FilledButton(
                  onPressed: vm.isSubmitting
                      ? null
                      : () async {
                          if (!key.currentState!.validate()) return;
                          final ok = await vm.registerInterest(
                            productId: product.id,
                            quantity: double.parse(
                              controller.text.replaceAll(',', '.'),
                            ),
                          );
                          if (!sheet.mounted) return;
                          if (ok) {
                            Navigator.pop(sheet);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tu interés fue registrado.'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(sheet).showSnackBar(
                              SnackBar(
                                content: Text(
                                  vm.errorMessage ?? 'No se pudo registrar.',
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    vm.isSubmitting ? 'Guardando...' : 'Confirmar interés',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  String _amount(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

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
