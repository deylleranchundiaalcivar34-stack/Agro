// Catalogo adaptable con busqueda local, filtros por categoria y acceso al detalle de cada lote.

import 'package:flutter/material.dart';

import '../widgets/product_scaffold.dart';

import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/skeleton_block.dart';
import '../../../main/presentation/views/main_navigation_view.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/agricultural_product.dart';
import '../viewmodels/products_viewmodel.dart';
import '../widgets/product_card.dart';
import '../widgets/product_delete_button.dart';
import '../widgets/product_permanent_delete_button.dart';

/// Pantalla de publicaciones activas; conserva el buscador y la categoria seleccionada.
class ProductsCatalogView extends StatefulWidget {
  const ProductsCatalogView({
    super.key,
    this.initialQuery = '',
    this.initialCategory,
    this.initialMine = false,
  });

  final String initialQuery;
  final String? initialCategory;
  final bool initialMine;

  @override
  State<ProductsCatalogView> createState() => _ProductsCatalogViewState();
}

class _ProductsCatalogViewState extends State<ProductsCatalogView> {
  ModuleRefreshRegistry? _refreshRegistry;
  // Filtros locales: escribir o cambiar categoria no realiza otra consulta a Supabase.
  late String _query = widget.initialQuery;
  late String? _category = widget.initialCategory;
  final _searchController = TextEditingController();
  late bool _mine;
  bool? _visibility;
  String? _observedOwner;

  @override
  void didUpdateWidget(covariant ProductsCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialMine != widget.initialMine) {
      _query = widget.initialQuery;
      _category = widget.initialCategory;
      _mine = widget.initialMine;
      _searchController.value = TextEditingValue(
        text: widget.initialQuery,
        selection: TextSelection.collapsed(offset: widget.initialQuery.length),
      );
      if (widget.initialMine &&
          context.read<AuthViewModel>().selectedRole == UserRole.producer) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<ProductsViewModel>().loadMyPublications();
          }
        });
      }
    }
  }

  /// Al refrescar la vista privada se actualiza tambien el catalogo visible.
  Future<void> _refresh(ProductsViewModel vm) async {
    await vm.loadCatalogue(force: true);
    if (mounted &&
        _mine &&
        context.read<AuthViewModel>().selectedRole == UserRole.producer) {
      await vm.loadMyPublications(force: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _mine = widget.initialMine;
    _searchController.text = widget.initialQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = context.read<ProductsViewModel>();
      viewModel.loadCatalogue();
      if (_mine &&
          context.read<AuthViewModel>().selectedRole == UserRole.producer) {
        viewModel.loadMyPublications();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = ModuleRefreshScope.maybeOf(context);
    if (identical(registry, _refreshRegistry)) return;
    _refreshRegistry?.unregister(AppRoutes.products);
    _refreshRegistry = registry;
    _refreshRegistry?.register(AppRoutes.products, () {
      return _refresh(context.read<ProductsViewModel>());
    });
  }

  @override
  void dispose() {
    _refreshRegistry?.unregister(AppRoutes.products);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final producer = context.select<AuthViewModel, bool>(
      (auth) => auth.selectedRole == UserRole.producer,
    );
    final ownerId = context.select<AuthViewModel, String?>(
      (auth) => auth.currentUser?.id,
    );
    if (_observedOwner != ownerId) {
      _observedOwner = ownerId;
      // Recargar la lista privada al cambiar de cuenta, sin mostrar datos de la sesion anterior.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && producer && _mine) {
          context.read<ProductsViewModel>().loadMyPublications(force: true);
        }
      });
    }
    final mine = producer && _mine;
    return ProductScaffold(
      contentMaxWidth: 1180,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          mine ? 'Mis publicaciones' : 'Preventa agricola',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _refresh(context.read<ProductsViewModel>()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar catalogo',
          ),
        ],
      ),
      // Acceso a la publicacion de preventas para cuentas productoras.
      floatingActionButton: producer
          ? Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton.extended(
                onPressed: () => context.go(AppRoutes.productCreate),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Publicar preventa'),
              ),
            )
          : null,
      body: Consumer<ProductsViewModel>(
        builder: (context, vm, _) {
          // Aplicar filtros sobre la lista cargada sin modificar los datos del ViewModel.
          final status = mine ? vm.myStatus : vm.catalogueStatus;
          final products = (mine ? vm.myProducts : vm.products)
              .where(
                (product) => mine
                    ? product.producerId == ownerId
                    : product.isPublished &&
                          (!producer || product.producerId != ownerId),
              )
              .where(
                (p) =>
                    !mine ||
                    _visibility == null ||
                    p.isPublished == _visibility,
              )
              .where(_matches)
              .toList();
          return RefreshIndicator(
            onRefresh: () => _refresh(vm),
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alternar dentro de la misma pantalla conserva la navegacion y los filtros actuales.
                        if (producer) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Comprar'),
                                selected: !mine,
                                onSelected: (_) =>
                                    setState(() => _mine = false),
                              ),
                              ChoiceChip(
                                label: const Text('Mis publicaciones'),
                                selected: mine,
                                onSelected: (_) {
                                  setState(() => _mine = true);
                                  vm.loadMyPublications(force: true);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (mine && status == ProductsStatus.ready) ...[
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _PublicationMetric(
                                label: 'Total de publicaciones',
                                value: vm.myPublicationsTotal,
                              ),
                              _PublicationMetric(
                                label: 'Publicaciones visibles',
                                value: vm.myPublicationsVisible,
                              ),
                              _PublicationMetric(
                                label: 'Publicaciones ocultas',
                                value: vm.myPublicationsHidden,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in <bool?, String>{
                                null: 'Todos',
                                true: 'Visibles',
                                false: 'Ocultos',
                              }.entries)
                                ChoiceChip(
                                  key: ValueKey('visibility-${entry.value}'),
                                  label: Text(entry.value),
                                  selected: _visibility == entry.key,
                                  onSelected: (_) =>
                                      setState(() => _visibility = entry.key),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: 'Buscar por producto o categoria',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.divider,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(
                              label: 'Todos',
                              selected: _category == null,
                              onTap: () => setState(() => _category = null),
                            ),
                            for (final c in vm.categories)
                              _Chip(
                                label: c.name,
                                selected: _category == c.name,
                                onTap: () => setState(() => _category = c.name),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                mine
                                    ? 'Mis publicaciones'
                                    : 'Lotes en preventa',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (status == ProductsStatus.ready)
                              Text(
                                '${products.length} lotes',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                  // Alternar carga, error, catalogo vacio o tarjetas sin exponer detalles de la base.
                  if (status == ProductsStatus.loading ||
                      status == ProductsStatus.idle)
                    const SliverToBoxAdapter(child: _Skeleton())
                  else if (status == ProductsStatus.error)
                    SliverToBoxAdapter(
                      child: _State(
                        icon: Icons.cloud_off_outlined,
                        title: mine
                            ? 'No se pudieron cargar tus publicaciones'
                            : 'No se pudo cargar el catalogo',
                        text:
                            (mine ? vm.myError : vm.errorMessage) ??
                            'Intenta actualizar el catalogo de nuevo.',
                        action: FilledButton(
                          onPressed: () => _refresh(vm),
                          child: const Text('Reintentar'),
                        ),
                      ),
                    )
                  else if (products.isEmpty)
                    SliverToBoxAdapter(
                      child: _State(
                        icon:
                            _query.isNotEmpty ||
                                _category != null ||
                                (mine && _visibility != null)
                            ? Icons.search_off_rounded
                            : Icons.inventory_2_outlined,
                        title: mine && vm.myPublicationsTotal == 0
                            ? 'Aun no tienes publicaciones'
                            : _query.isNotEmpty ||
                                  _category != null ||
                                  (mine && _visibility != null)
                            ? 'No encontramos resultados'
                            : mine
                            ? 'Aun no tienes publicaciones'
                            : 'Aun no hay preventas',
                        text: mine && vm.myPublicationsTotal > 0
                            ? 'Prueba otro nombre, categoria o filtro de visibilidad.'
                            : producer
                            ? 'Publica el primer lote real cuando este listo.'
                            : 'Cuando un productor publique un lote aparecera aqui.',
                        action: mine && vm.myPublicationsTotal == 0
                            ? FilledButton.icon(
                                onPressed: () =>
                                    context.go(AppRoutes.productCreate),
                                icon: const Icon(Icons.add),
                                label: const Text('Crear primera publicacion'),
                              )
                            : null,
                      ),
                    )
                  else
                    // Ajustar columnas al ancho y altura a la escala de texto, evitando huecos excesivos.
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = _catalogueColumns(
                          constraints.crossAxisExtent,
                          MediaQuery.textScalerOf(context),
                          managing: mine,
                        );
                        final width =
                            (constraints.crossAxisExtent - (columns - 1) * 12) /
                            columns;
                        final imageHeight = ProductCard.imageHeightFor(context);
                        // Usar la mayor altura medida mantiene filas alineadas sin una reserva fija excesiva.
                        final extent = products
                            .map(
                              (product) => ProductCard.heightFor(
                                context,
                                product,
                                width: width,
                                imageHeight: imageHeight,
                                showVisibility: mine,
                              ),
                            )
                            .reduce((a, b) => a > b ? a : b);
                        return SliverGrid.builder(
                          itemCount: products.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent:
                                    extent +
                                    (mine
                                        ? 78 +
                                              MediaQuery.textScalerOf(context)
                                                  .scale(56)
                                        : 0),
                              ),
                          itemBuilder: (_, index) {
                            final product = products[index];
                            final card = ProductCard(
                              product: product,
                              imageHeight: imageHeight,
                              showVisibility: mine,
                              onTap: () =>
                                  context.go('/products/${product.id}'),
                            );
                            if (!mine) return card;
                            // La accion queda fuera de los detalles de la tarjeta para no estirar su contenido.
                            return Column(
                              children: [
                                SizedBox(height: extent, child: card),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height:
                                      72 +
                                      MediaQuery.textScalerOf(context)
                                          .scale(56),
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      ProductDeleteButton(
                                        product: product,
                                        onDeleted: () {},
                                      ),
                                      ProductPermanentDeleteButton(
                                        product: product,
                                        busy: vm.isSubmitting,
                                        onConfirmed: (name) async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final deleted = await vm
                                              .permanentlyDeleteProduct(
                                                product.id,
                                                name,
                                              );
                                          // El refresco retira esta tarjeta antes de que vuelva el callback.
                                          if (deleted && context.mounted) {
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Producto eliminado definitivamente',
                                                ),
                                              ),
                                            );
                                          }
                                          return deleted;
                                        },
                                        errorMessage: () => vm.errorMessage,
                                        onDeleted: () {},
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Combina categoria exacta con busqueda por nombre o categoria, sin distinguir mayusculas.
  bool _matches(AgriculturalProduct product) {
    final q = _query.trim().toLowerCase();
    return (_category == null || product.categoryName == _category) &&
        (q.isEmpty ||
            product.name.toLowerCase().contains(q) ||
            product.categoryName.toLowerCase().contains(q));
  }
}

/// Indicadores adaptables de todas las publicaciones propias cargadas.
class _PublicationMetric extends StatelessWidget {
  const _PublicationMetric({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      '$label: $value',
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );
}

/// Opcion visual del filtro de categoria, con seleccion controlada por el catalogo.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: AppColors.primary,
    labelStyle: GoogleFonts.inter(
      color: selected ? AppColors.surface : AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
  );
}

// Mantener un ancho aproximado minimo de 160 px por tarjeta, con hasta cuatro columnas.
// Aumentar el ancho minimo con texto ampliado evita comprimir etiquetas y acciones de gestion.
int _catalogueColumns(
  double width,
  TextScaler scaler, {
  bool managing = false,
}) => ((width + 12) / (scaler.scale(managing ? 240 : 160) + 12)).floor().clamp(
  1,
  4,
);

/// Marcadores de carga con portada y columnas adaptadas al catalogo.
class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _catalogueColumns(
          constraints.maxWidth,
          MediaQuery.textScalerOf(context),
        ),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // Aproximacion solo para la carga; las tarjetas reales miden su contenido.
        mainAxisExtent:
            ProductCard.imageHeightFor(context) +
            MediaQuery.textScalerOf(context).scale(150),
      ),
      itemBuilder: (_, _) => const SkeletonBlock(height: 220, borderRadius: 18),
    ),
  );
}

/// Mensaje reutilizable de error, catalogo vacio o busqueda sin resultados.
class _State extends StatelessWidget {
  const _State({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
    child: Column(
      children: [
        Icon(icon, size: 48, color: AppColors.primary),
        const SizedBox(height: 14),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}
