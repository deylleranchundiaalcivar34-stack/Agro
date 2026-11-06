// Catálogo adaptable con búsqueda local, filtros por categoría y acceso al detalle de cada lote.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/agricultural_product.dart';
import '../viewmodels/products_viewmodel.dart';
import '../widgets/product_card.dart';
import '../widgets/product_delete_button.dart';

/// Pantalla de publicaciones activas; conserva el buscador y la categoría seleccionada.
class ProductsCatalogView extends StatefulWidget {
  const ProductsCatalogView({super.key});
  @override
  State<ProductsCatalogView> createState() => _ProductsCatalogViewState();
}

class _ProductsCatalogViewState extends State<ProductsCatalogView> {
  // Filtros locales: escribir o cambiar categoría no realiza otra consulta a Supabase.
  String _query = '';
  String? _category;
  bool _mine = false;
  String? _observedOwner;

  /// Al refrescar la vista privada se actualiza también el catálogo visible.
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductsViewModel>().loadCatalogue(),
    );
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
      // Recargar la lista privada al cambiar de cuenta, sin mostrar datos de la sesión anterior.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && producer && _mine) {
          context.read<ProductsViewModel>().loadMyPublications(force: true);
        }
      });
    }
    final mine = producer && _mine;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Preventa agrícola',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _refresh(context.read<ProductsViewModel>()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar catálogo',
          ),
        ],
      ),
      // Acceso a la publicación de preventas para cuentas productoras.
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
                (product) =>
                    mine ? product.producerId == ownerId : product.isPublished,
              )
              .where(_matches)
              .toList();
          return RefreshIndicator(
            onRefresh: () => _refresh(vm),
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alternar dentro de la misma pantalla conserva la navegación y los filtros actuales.
                        if (producer) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Catálogo'),
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
                        TextField(
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: 'Buscar por producto o categoría',
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
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _Chip(
                                label: 'Todos',
                                selected: _category == null,
                                onTap: () => setState(() => _category = null),
                              ),
                              ...vm.categories.map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _Chip(
                                    label: c.name,
                                    selected: _category == c.name,
                                    onTap: () =>
                                        setState(() => _category = c.name),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                  // Alternar carga, error, catálogo vacío o tarjetas sin exponer detalles de la base.
                  if (status == ProductsStatus.loading ||
                      status == ProductsStatus.idle)
                    const SliverToBoxAdapter(child: _Skeleton())
                  else if (status == ProductsStatus.error)
                    SliverToBoxAdapter(
                      child: _State(
                        icon: Icons.cloud_off_outlined,
                        title: mine
                            ? 'No se pudieron cargar tus publicaciones'
                            : 'No se pudo cargar el catálogo',
                        text:
                            (mine ? vm.myError : vm.errorMessage) ??
                            'Intenta actualizar el catálogo de nuevo.',
                        action: FilledButton(
                          onPressed: () => _refresh(vm),
                          child: const Text('Reintentar'),
                        ),
                      ),
                    )
                  else if (products.isEmpty)
                    SliverToBoxAdapter(
                      child: _State(
                        icon: _query.isNotEmpty || _category != null
                            ? Icons.search_off_rounded
                            : Icons.inventory_2_outlined,
                        title: _query.isNotEmpty || _category != null
                            ? 'No encontramos resultados'
                            : mine
                            ? 'Aún no tienes publicaciones'
                            : 'Aún no hay preventas',
                        text: producer
                            ? 'Publica el primer lote real cuando esté listo.'
                            : 'Cuando un productor publique un lote aparecerá aquí.',
                      ),
                    )
                  else
                    // Ajustar columnas al ancho y altura a la escala de texto, evitando huecos excesivos.
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = _catalogueColumns(
                          constraints.crossAxisExtent,
                          MediaQuery.textScalerOf(context),
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
                                        ? 22 +
                                              MediaQuery.textScalerOf(context)
                                                  .scale(28)
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
                            // La acción queda fuera de los detalles de la tarjeta para no estirar su contenido.
                            return Column(
                              children: [
                                SizedBox(height: extent, child: card),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height:
                                      16 +
                                      MediaQuery.textScalerOf(context)
                                          .scale(28),
                                  width: double.infinity,
                                  child: ProductDeleteButton(
                                    product: product,
                                    onDeleted: () {},
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 112)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Combina categoría exacta con búsqueda por nombre o categoría, sin distinguir mayúsculas.
  bool _matches(AgriculturalProduct product) {
    final q = _query.trim().toLowerCase();
    return (_category == null || product.categoryName == _category) &&
        (q.isEmpty ||
            product.name.toLowerCase().contains(q) ||
            product.categoryName.toLowerCase().contains(q));
  }
}

/// Opción visual del filtro de categoría, con selección controlada por el catálogo.
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

// Mantener un ancho aproximado mínimo de 160 px por tarjeta, con hasta cuatro columnas.
// Aumentar el ancho mínimo con texto ampliado evita comprimir etiquetas y acciones de gestión.
int _catalogueColumns(double width, TextScaler scaler) =>
    ((width + 12) / (scaler.scale(160) + 12)).floor().clamp(1, 4);

/// Marcadores de carga con portada y columnas adaptadas al catálogo.
class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.surfaceVariant,
    highlightColor: AppColors.surface,
    child: LayoutBuilder(
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
          // Aproximación solo para la carga; las tarjetas reales miden su contenido.
          mainAxisExtent:
              ProductCard.imageHeightFor(context) +
              MediaQuery.textScalerOf(context).scale(150),
        ),
        itemBuilder: (_, _) => const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
    ),
  );
}

/// Mensaje reutilizable de error, catálogo vacío o búsqueda sin resultados.
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
