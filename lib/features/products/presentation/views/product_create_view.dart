import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../viewmodels/products_viewmodel.dart';

class ProductCreateView extends StatefulWidget {
  const ProductCreateView({super.key});
  @override
  State<ProductCreateView> createState() => _ProductCreateViewState();
}

class _ProductCreateViewState extends State<ProductCreateView> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  int? _category;
  DateTime? _harvest;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductsViewModel>().loadCatalogue(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
      initialDate: _harvest ?? DateTime.now(),
    );
    if (value != null && mounted) setState(() => _harvest = value);
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate() || _category == null) {
      if (_category == null)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoría.')),
        );
      return;
    }
    final ok = await context.read<ProductsViewModel>().createPreorderProduct(
      name: _name.text,
      categoryId: _category!,
      quantity: double.parse(_quantity.text.replaceAll(',', '.')),
      price: double.parse(_price.text.replaceAll(',', '.')),
      estimatedHarvestDate: _harvest,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu lote quedó publicado en preventa.')),
      );
      context.go(AppRoutes.products);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ProductsViewModel>().errorMessage ??
                'No se pudo publicar.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final producer = context.select<AuthViewModel, bool>(
      (auth) => auth.selectedRole == UserRole.producer,
    );
    if (!producer)
      return Scaffold(
        appBar: AppBar(title: const Text('Publicar preventa')),
        body: const Center(child: Text('Esta acción es para productores.')),
      );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Publicar preventa')),
      body: Consumer<ProductsViewModel>(
        builder: (context, vm, _) => SafeArea(
          child: Form(
            key: _key,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  'Un lote, información clara',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate().fadeIn(duration: 220.ms).slideY(begin: .04, end: 0),
                const SizedBox(height: 6),
                Text(
                  'Se mostrará como preventa a compradores con sesión iniciada.',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                    hintText: 'Ej. Aguacate Hass',
                    prefixIcon: Icon(Icons.eco_outlined),
                  ),
                  validator: (v) => v == null || v.trim().length < 3
                      ? 'Escribe un nombre de al menos 3 caracteres.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría agrícola',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: vm.categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: vm.catalogueStatus == ProductsStatus.loading
                      ? null
                      : (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad disponible',
                          hintText: '0',
                        ),
                        validator: _positive,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio unitario (USD)',
                          hintText: '0.00',
                        ),
                        validator: _nonNegative,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _harvest == null
                          ? 'Fecha estimada de cosecha (opcional)'
                          : 'Cosecha estimada: ${_date(_harvest!)}',
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: vm.isSubmitting ? null : _submit,
                  icon: vm.isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Icon(Icons.publish_outlined),
                  label: Text(
                    vm.isSubmitting ? 'Publicando...' : 'Publicar preventa',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _positive(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    return n == null || n <= 0 ? 'Ingresa un valor mayor a 0.' : null;
  }

  String? _nonNegative(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    return n == null || n < 0 ? 'Ingresa un precio válido.' : null;
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
