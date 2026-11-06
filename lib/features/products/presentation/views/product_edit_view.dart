// Edición completa o solo de cantidad de una publicación perteneciente al productor activo.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/product_image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/agricultural_product.dart';
import '../../data/models/product_quantity.dart';
import '../../data/models/product_unit.dart';
import '../widgets/product_quantity_fields.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../viewmodels/products_viewmodel.dart';

/// Edita una publicación propia conservando su fase comercial.
class ProductEditView extends StatefulWidget {
  const ProductEditView({
    super.key,
    required this.productId,
    this.quantityOnly = false,
  });
  final String productId;
  // Permite reutilizar la pantalla para una actualización limitada a cantidad y unidad.
  final bool quantityOnly;
  @override
  State<ProductEditView> createState() => _ProductEditViewState();
}

// Conserva los valores precargados y la fotografía nueva hasta confirmar el guardado.
class _ProductEditViewState extends State<ProductEditView> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  AgriculturalProduct? _product;
  String? _loadError;
  bool _published = true;
  ProductUnit? _unit;
  int? _category;
  XFile? _selectedImage;
  bool _isSelectingImage = false;
  DateTime? _harvest;
  @override
  void initState() {
    super.initState();
    // Carga las categorías que se mostrarán en el selector del formulario.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    // Libera los controladores asociados a los campos de texto.
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Obtiene el producto, comprueba acceso y precarga los campos editables.
  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final vm = context.read<ProductsViewModel>();
      if (!widget.quantityOnly) await vm.loadCatalogue();
      final product = await vm.getProduct(widget.productId);
      if (!mounted) return;
      final auth = context.read<AuthViewModel>();
      if (product == null ||
          product.producerId != auth.currentUser?.id ||
          auth.selectedRole != UserRole.producer) {
        throw StateError('Solo puedes editar tus publicaciones.');
      }
      if (!widget.quantityOnly &&
          !vm.categories.any((c) => c.id == product.categoryId)) {
        throw StateError(
          'No se pudieron cargar las categorías. Intenta de nuevo.',
        );
      }
      setState(() {
        _product = product;
        _name.text = product.name;
        _quantity.text = product.availableQuantity.toString();
        _price.text = product.unitPrice.toString();
        _unit = product.unit;
        _category = product.categoryId;
        _harvest = product.estimatedHarvestDate;
        _published = product.isPublished;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError = 'No se pudo cargar la publicación o no tienes permiso para editarla.',
        );
      }
    }
  }

  /// Permite conservar fechas históricas o lejanas ya presentes en la publicación.
  Future<void> _pickDate() async {
    // La fecha de cosecha es opcional y se limita a los próximos cinco años.
    final value = await showDatePicker(
      context: context,
      firstDate: _harvest != null && _harvest!.isBefore(DateTime.now())
          ? _harvest!
          : DateTime.now(),
      lastDate: DateTime(
        (_harvest?.year ?? DateTime.now().year) > DateTime.now().year + 5
            ? _harvest!.year + 1
            : DateTime.now().year + 5,
      ),
      initialDate: _harvest ?? DateTime.now(),
    );
    if (value != null && mounted) setState(() => _harvest = value);
  }

  /// Selecciona la operación de cantidad o edición completa y comunica su resultado.
  Future<void> _submit() async {
    // Bloquear también llamadas repetidas mientras se selecciona una imagen o se guarda.
    if (context.read<ProductsViewModel>().isSubmitting || _isSelectingImage) {
      return;
    }
    // El modo reducido evita enviar nombre, precio, categoría, estado y fotografías.
    if (widget.quantityOnly) {
      if (!_key.currentState!.validate()) return;
      final vm = context.read<ProductsViewModel>();
      final ok = await vm.updateQuantity(
        widget.productId,
        ProductQuantity.parse(_quantity.text),
        unit: _unit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? AppColors.primary : AppColors.error,
          content: Text(
            ok
                ? 'Cantidad disponible actualizada correctamente'
                : vm.errorMessage ?? 'No se pudo actualizar la cantidad.',
          ),
        ),
      );
      if (ok) context.pop(true);
      return;
    }
    // Valida el formulario y delega la publicación en el ViewModel.
    if (!_key.currentState!.validate() || _category == null) {
      if (_category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoría.')),
        );
      }
      return;
    }
    final ok = await context.read<ProductsViewModel>().updateProduct(
      productId: widget.productId,
      isPublished: _published,
      name: _name.text,
      image: _selectedImage,
      categoryId: _category!,
      quantity: ProductQuantity.parse(_quantity.text),
      unit: _unit,
      price: double.parse(_price.text.replaceAll(',', '.')),
      harvest: _harvest,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publicación actualizada correctamente')),
      );
      context.pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ProductsViewModel>().errorMessage ??
                'No se pudo guardar.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      'Editar publicación',
      style: Theme.of(context).textTheme.headlineSmall,
    );
    // Comprobar también la sesión si cambia mientras el formulario está abierto.
    final producer = context.select<AuthViewModel, bool>(
      (auth) =>
          auth.selectedRole == UserRole.producer &&
          (_product == null || auth.currentUser?.id == _product!.producerId),
    );
    if (!producer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar publicación')),
        body: const Center(child: Text('Esta acción es para productores.')),
      );
    }
    // La edición espera la carga inicial y ofrece reintento si no se pudo completar.
    if (_product == null && producer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar publicación')),
        body: Center(
          child: _loadError == null
              ? Shimmer.fromColors(
                  baseColor: AppColors.surfaceVariant,
                  highlightColor: AppColors.surface,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: List.generate(
                      5,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: ColoredBox(
                          color: AppColors.surface,
                          child: SizedBox(height: 56),
                        ),
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
        ),
      );
    }
    if (widget.quantityOnly) return _quantityForm(context);
    // Impide salir durante el guardado y bloquea la edición simultánea de los campos.
    return PopScope(
      canPop: !context.watch<ProductsViewModel>().isSubmitting,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Editar publicación')),
        body: Consumer<ProductsViewModel>(
          builder: (context, vm, _) => SafeArea(
            child: AbsorbPointer(
              absorbing: vm.isSubmitting,
              child: Form(
                key: _key,
                // Mantener campos y vista previa montados evita perder selección o validadores al desplazarse.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (MediaQuery.disableAnimationsOf(context))
                        heading
                      else
                        heading
                            .animate()
                            .fadeIn(duration: 220.ms)
                            .slideY(begin: .04, end: 0),
                      const SizedBox(height: 16),
                      // Cabecera compacta: foto actual o nueva y opción para deshacer el cambio local.
                      ProductImagePicker(
                        productName: _product!.name,
                        initialImageUrl: _product!.imagenUrl,
                        enabled: !vm.isSubmitting,
                        onLoadingChanged: (loading) =>
                            setState(() => _isSelectingImage = loading),
                        onChanged: (image) =>
                            setState(() => _selectedImage = image),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fase actual: ${_product!.phaseName}. Se conservará al guardar.',
                        style: Theme.of(context).textTheme.bodyMedium,
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
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoría agrícola',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: vm.categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: vm.catalogueStatus == ProductsStatus.loading
                            ? null
                            : (value) => setState(() => _category = value),
                        validator: (value) =>
                            value == null ? 'Selecciona una categoría.' : null,
                      ),
                      const SizedBox(height: 16),
                      // Cantidad y unidad se validan juntas según las reglas compartidas.
                      ProductQuantityFields(
                        controller: _quantity,
                        unit: _unit,
                        onUnitChanged: (unit) => setState(() => _unit = unit),
                        enabled: !vm.isSubmitting,
                        label: _product!.quantityLabel,
                      ),
                      const SizedBox(height: 16),
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
                      // Quitar una fecha opcional se transmite como NULL explícito al repositorio.
                      if (_harvest != null)
                        TextButton.icon(
                          onPressed: () => setState(() => _harvest = null),
                          icon: const Icon(Icons.event_busy_outlined),
                          label: const Text('Quitar fecha de cosecha'),
                        ),
                      const SizedBox(height: 16),
                      // La publicación puede retirarse del catálogo conservando sus datos.
                      SwitchListTile(
                        title: const Text('Visibilidad del producto'),
                        subtitle: Text(_published ? 'Visible' : 'Oculto'),
                        value: _published,
                        onChanged: vm.isSubmitting
                            ? null
                            : (value) => setState(() => _published = value),
                      ),
                      if ((_product?.fotografias.length ?? 0) > 1) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Otras fotografías (se conservan)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final url in _product!.fotografias.skip(1))
                              SizedBox(
                                width: 96,
                                height: 72,
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Las acciones permanecen por encima de la navegación inferior y del área segura.
        bottomNavigationBar: Consumer<ProductsViewModel>(
          builder: (context, vm, _) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: vm.isSubmitting || _isSelectingImage
                        ? null
                        : _submit,
                    icon: vm.isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      vm.isSubmitting ? 'Guardando...' : 'Guardar cambios',
                    ),
                  ),
                  TextButton(
                    onPressed: vm.isSubmitting ? null : () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Formulario reducido que muestra el contexto del lote y modifica cantidad y unidad.
  Widget _quantityForm(BuildContext context) {
    final vm = context.watch<ProductsViewModel>();
    final product = _product!;
    // Impide salir durante el guardado y bloquea la edición simultánea de los campos.
    return PopScope(
      canPop: !vm.isSubmitting,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Actualizar cantidad')),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: vm.isSubmitting,
            child: Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fase: ${product.phaseName}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    'Precio unitario: USD ${product.unitPrice.toStringAsFixed(2)}',
                  ),
                  Text(
                    '${product.quantityLabel} actual: ${product.quantityWithUnit}',
                  ),
                  if (product.harvestLabel != null)
                    Text('Cosecha estimada: ${product.harvestLabel}'),
                  const SizedBox(height: 24),
                  ProductQuantityFields(
                    controller: _quantity,
                    unit: _unit,
                    label: product.quantityLabel,
                    enabled: !vm.isSubmitting,
                    onUnitChanged: (unit) => setState(() => _unit = unit),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: vm.isSubmitting ? null : _submit,
                    icon: vm.isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      vm.isSubmitting ? 'Guardando...' : 'Guardar cantidad',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: vm.isSubmitting ? null : () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Valida el precio sin permitir negativos ni valores no finitos.
  String? _nonNegative(String? v) {
    // El precio admite cero; se normaliza la coma decimal antes de analizarlo.
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    return n == null || !n.isFinite || n < 0
        ? 'Ingresa un precio válido.'
        : null;
  }

  /// Formatea la fecha visible sin modificar su almacenamiento.
  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
