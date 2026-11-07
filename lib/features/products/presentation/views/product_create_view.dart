// Pantalla de alta: recoge datos y fotografia, valida y solicita publicar una preventa.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/product_image_picker.dart';
import '../../data/models/product_unit.dart';
import '../widgets/product_quantity_fields.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../viewmodels/products_viewmodel.dart';

/// Formulario para que un productor publique un lote en preventa.
class ProductCreateView extends StatefulWidget {
  const ProductCreateView({super.key});
  @override
  State<ProductCreateView> createState() => _ProductCreateViewState();
}

// Estado local del formulario; la persistencia y los bloqueos compartidos viven en el ViewModel.
class _ProductCreateViewState extends State<ProductCreateView> {
  // Controladores, seleccion de unidad/categoria y fotografia pendiente de subir.
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  ProductUnit? _unit;
  int? _category;
  XFile? _selectedImage;
  bool _isSelectingImage = false;
  DateTime? _harvest;
  @override
  void initState() {
    super.initState();
    // Carga las categorias que se mostraran en el selector del formulario.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductsViewModel>().loadCatalogue(),
    );
  }

  @override
  void dispose() {
    // Libera los controladores asociados a los campos de texto.
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Abre el selector de la fecha opcional sin guardar cambios todavia.
  Future<void> _pickDate() async {
    // La fecha de cosecha es opcional y se limita a los proximos cinco anos.
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
      initialDate: _harvest ?? DateTime.now(),
    );
    if (value != null && mounted) setState(() => _harvest = value);
  }

  /// Evita envios simultaneos, valida los campos y muestra el resultado de la publicacion.
  Future<void> _submit() async {
    final vm = context.read<ProductsViewModel>();
    if (vm.isSubmitting || vm.publicationRequiresReview || _isSelectingImage) {
      return;
    }
    // Valida el formulario y delega la publicacion en el ViewModel.
    if (!_key.currentState!.validate() || _category == null) {
      if (_category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoria.')),
        );
      }
      return;
    }
    // La imagen sigue siendo local aqui; el repositorio coordina su subida y asociacion.
    final ok = await context.read<ProductsViewModel>().createPreorderProduct(
      name: _name.text,
      image: _selectedImage,
      categoryId: _category!,
      quantity: double.parse(_quantity.text.replaceAll(',', '.')),
      unit: _unit,
      price: double.parse(_price.text.replaceAll(',', '.')),
      estimatedHarvestDate: _harvest,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ProductsViewModel>().publicationWarning ??
                'Tu lote quedo publicado en preventa.',
          ),
        ),
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
    // Solo los productores pueden publicar preventas desde esta pantalla.
    final producer = context.select<AuthViewModel, bool>(
      (auth) => auth.selectedRole == UserRole.producer,
    );
    if (!producer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Publicar preventa')),
        body: const Center(child: Text('Esta accion es para productores.')),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Publicar preventa')),
      body: Consumer<ProductsViewModel>(
        builder: (context, vm, _) => SafeArea(
          child: Form(
            key: _key,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 180),
              children: [
                Text(
                  'Un lote, informacion clara',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate().fadeIn(duration: 220.ms).slideY(begin: .04, end: 0),
                const SizedBox(height: 6),
                Text(
                  'Se mostrara como preventa a compradores con sesion iniciada.',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                // Identificacion del lote y categoria agricola para su clasificacion.
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
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria agricola',
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
                // Cantidad y unidad comparten la validacion con el formulario de edicion.
                ProductQuantityFields(
                  controller: _quantity,
                  unit: _unit,
                  onUnitChanged: (unit) => setState(() => _unit = unit),
                  enabled: !vm.isSubmitting,
                ),
                const SizedBox(height: 16),
                // Precio unitario y fecha estimada de cosecha opcional.
                TextFormField(
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
                const SizedBox(height: 16),
                // Seleccion y vista previa; se impide publicar mientras se lee la imagen.
                ProductImagePicker(
                  enabled: !vm.isSubmitting,
                  onLoadingChanged: (loading) {
                    setState(() => _isSelectingImage = loading);
                  },
                  onChanged: (image) {
                    setState(() {
                      _selectedImage = image;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Un resultado incierto requiere revisar las publicaciones antes de repetir el alta.
                if (vm.publicationRequiresReview)
                  Text(
                    vm.errorMessage ??
                        'Revisa tus publicaciones antes de volver a publicar.',
                  ),
                FilledButton.icon(
                  onPressed:
                      vm.isSubmitting ||
                          _isSelectingImage ||
                          vm.publicationRequiresReview
                      ? null
                      : _submit,
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

  /// Admite precio cero y rechaza valores negativos o no finitos.
  String? _nonNegative(String? v) {
    // El precio admite cero; se normaliza la coma decimal antes de analizarlo.
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    return n == null || !n.isFinite || n < 0
        ? 'Ingresa un precio valido.'
        : null;
  }

  /// Presenta fechas en formato dia/mes/ano sin alterar el valor seleccionado.
  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
