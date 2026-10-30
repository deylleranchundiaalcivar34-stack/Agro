import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/agricultural_product.dart';
import '../viewmodels/products_viewmodel.dart';

class ProductsCatalogView extends StatefulWidget {
  const ProductsCatalogView({super.key});
  @override
  State<ProductsCatalogView> createState() => _ProductsCatalogViewState();
}

class _ProductsCatalogViewState extends State<ProductsCatalogView> {
  String _query = '';
  String? _category;

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Preventa agrícola',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                context.read<ProductsViewModel>().loadCatalogue(force: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar catálogo',
          ),
        ],
      ),
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
          final products = vm.products.where(_matches).toList();
          return RefreshIndicator(
            onRefresh: () => vm.loadCatalogue(force: true),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar por producto o categoría',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.divider),
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
                            onTap: () => setState(() => _category = c.name),
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
                        'Lotes en preventa',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (vm.catalogueStatus == ProductsStatus.ready)
                      Text(
                        '${products.length} lotes',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (vm.catalogueStatus == ProductsStatus.loading)
                  const _Skeleton()
                else if (vm.catalogueStatus == ProductsStatus.error)
                  _State(
                    icon: Icons.cloud_off_outlined,
                    title: 'No se pudo cargar el catálogo',
                    text: 'Comprueba tu conexión e inténtalo de nuevo.',
                    action: FilledButton(
                      onPressed: () => vm.loadCatalogue(force: true),
                      child: const Text('Reintentar'),
                    ),
                  )
                else if (products.isEmpty)
                  _State(
                    icon: _query.isNotEmpty || _category != null
                        ? Icons.search_off_rounded
                        : Icons.inventory_2_outlined,
                    title: _query.isNotEmpty || _category != null
                        ? 'No encontramos resultados'
                        : 'Aún no hay preventas',
                    text: producer
                        ? 'Publica el primer lote real cuando esté listo.'
                        : 'Cuando un productor publique un lote aparecerá aquí.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .70,
                        ),
                    itemBuilder: (_, index) =>
                        _Card(
                              product: products[index],
                              onTap: () =>
                                  context.go('/products/${products[index].id}'),
                            )
                            .animate(delay: Duration(milliseconds: 40 * index))
                            .fadeIn(duration: 220.ms)
                            .slideY(begin: .04, end: 0, duration: 220.ms),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _matches(AgriculturalProduct product) {
    final q = _query.trim().toLowerCase();
    return (_category == null || product.categoryName == _category) &&
        (q.isEmpty ||
            product.name.toLowerCase().contains(q) ||
            product.categoryName.toLowerCase().contains(q));
  }
}

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

class _Card extends StatelessWidget {
  const _Card({required this.product, required this.onTap});
  final AgriculturalProduct product;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: const Icon(
                Icons.eco_outlined,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.phaseName,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      product.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${product.unitPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.surfaceVariant,
    highlightColor: AppColors.surface,
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .70,
      ),
      itemBuilder: (_, _) => const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
    ),
  );
}

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
