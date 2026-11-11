import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/skeleton_block.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../main/presentation/views/main_navigation_view.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../products/data/models/agricultural_product.dart';
import '../../../products/presentation/viewmodels/products_viewmodel.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(supabaseService: SupabaseService()),
      child: const _HomeViewContent(),
    );
  }
}

class _HomeViewContent extends StatefulWidget {
  const _HomeViewContent();

  @override
  State<_HomeViewContent> createState() => _HomeViewContentState();
}

class _HomeViewContentState extends State<_HomeViewContent> {
  ModuleRefreshRegistry? _refreshRegistry;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final products = context.read<ProductsViewModel>();
      products.loadCatalogue();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = ModuleRefreshScope.maybeOf(context);
    if (identical(registry, _refreshRegistry)) return;
    _refreshRegistry?.unregister(AppRoutes.home);
    _refreshRegistry = registry;
    _refreshRegistry?.register(AppRoutes.home, _refresh);
  }

  @override
  void dispose() {
    _refreshRegistry?.unregister(AppRoutes.home);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      context.read<HomeViewModel>().refresh(),
      context.read<ProductsViewModel>().loadCatalogue(force: true),
    ]);
  }

  void _openCatalog({String? query, String? category}) {
    final trimmedQuery = query?.trim() ?? '';
    final uri = Uri(
      path: AppRoutes.products,
      queryParameters: {
        if (trimmedQuery.isNotEmpty) 'q': trimmedQuery,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeViewModel>();
    final auth = context.watch<AuthViewModel>();
    final products = context.watch<ProductsViewModel>();
    final isProducer = auth.selectedRole == UserRole.producer;
    final userId = auth.currentUser?.id;
    final discoverProducts = products.products
        .where(
          (product) =>
              product.isPublished &&
              (!isProducer || product.producerId != userId),
        )
        .toList();
    final recentProducts = discoverProducts.take(8).toList();
    final availableCategories = products.categories
        .where(
          (category) => discoverProducts.any(
            (product) => product.categoryId == category.id,
          ),
        )
        .take(8)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              _buildHeader(context, auth, isProducer: isProducer),
              const SizedBox(height: 20),
              _buildMarketplaceHero(context, isProducer: isProducer),
              const SizedBox(height: 20),
              _buildSearchField(),
              const SizedBox(height: 24),
              _buildSectionHeading(
                context,
                title: 'Explora por categoria',
                action: availableCategories.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => _openCatalog(),
                        child: const Text('Ver todas'),
                      ),
              ),
              const SizedBox(height: 10),
              if (products.catalogueStatus == ProductsStatus.error)
                _buildInlineProblem(
                  context,
                  message: 'No pudimos cargar las categorias.',
                  action: TextButton(
                    onPressed: () => products.loadCatalogue(force: true),
                    child: const Text('Reintentar'),
                  ),
                )
              else if (products.catalogueStatus == ProductsStatus.loading ||
                  products.catalogueStatus == ProductsStatus.idle)
                const _CategoryLoadingRow()
              else if (availableCategories.isEmpty)
                Text(
                  'Las categorias apareceran cuando haya publicaciones disponibles.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                )
              else
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = availableCategories[index];
                      return ActionChip(
                        avatar: const Icon(
                          Icons.eco_outlined,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        label: Text(category.name),
                        onPressed: () => _openCatalog(category: category.name),
                        backgroundColor: AppColors.primarySurface,
                        labelStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: AppColors.primaryDark),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              _buildSectionHeading(
                context,
                title: 'Cosechas para descubrir',
                action: TextButton(
                  onPressed: () => _openCatalog(),
                  child: const Text('Ver catalogo'),
                ),
              ),
              const SizedBox(height: 10),
              _buildProductShelf(context, products, recentProducts),
              const SizedBox(height: 24),
              _buildMapCard(context),
              if (!isProducer) ...[
                const SizedBox(height: 24),
                _buildSummary(context, home),
              ],
              const SizedBox(height: 12),
              _buildChatShortcut(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuthViewModel auth, {
    required bool isProducer,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, ${auth.displayName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isProducer
                    ? 'Gestiona tus cosechas y explora otros productores'
                    : 'Productos frescos, directo del campo',
                maxLines: 2,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarketplaceHero(
    BuildContext context, {
    required bool isProducer,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isProducer
                      ? 'Tu cosecha tambien encuentra mercado'
                      : 'Del campo a tu mano',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.surface,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isProducer
                      ? 'Administra tus lotes y descubre productos de otras personas.'
                      : 'Encuentra cosechas y conecta directamente con productores.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.surface.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => _openCatalog(),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Explorar productos'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryDark,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.agriculture_rounded,
            size: 58,
            color: AppColors.surface,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) => _openCatalog(query: value),
      decoration: InputDecoration(
        hintText: 'Buscar productos o categorias',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Buscar en el catalogo',
          onPressed: () => _openCatalog(query: _searchController.text),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(
    BuildContext context, {
    required String title,
    Widget? action,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      ?action,
    ],
  );

  Widget _buildProductShelf(
    BuildContext context,
    ProductsViewModel viewModel,
    List<AgriculturalProduct> recentProducts, {
    ProductsStatus? status,
  }) {
    final shelfStatus = status ?? viewModel.catalogueStatus;
    if (shelfStatus == ProductsStatus.loading ||
        shelfStatus == ProductsStatus.idle) {
      return const _ProductLoadingRow();
    }
    if (shelfStatus == ProductsStatus.error) {
      return _ProductStateCard(
        icon: Icons.cloud_off_outlined,
        message: viewModel.errorMessage ?? 'No se pudo cargar el catalogo.',
        actionLabel: 'Reintentar',
        onPressed: () => viewModel.loadCatalogue(force: true),
      );
    }
    if (recentProducts.isEmpty) {
      return _ProductStateCard(
        icon: Icons.eco_outlined,
        message:
            'Aun no hay publicaciones disponibles. Puedes revisar el catalogo.',
        actionLabel: 'Abrir catalogo',
        onPressed: () => _openCatalog(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 360
            ? constraints.maxWidth * 0.78
            : 228.0;
        const imageHeight = 136.0;
        final products = recentProducts;
        final height = products.fold<double>(0, (maxHeight, product) {
          final cardHeight = ProductCard.heightFor(
            context,
            product,
            width: width,
            imageHeight: imageHeight,
          );
          return cardHeight > maxHeight ? cardHeight : maxHeight;
        });
        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: width,
                child: ProductCard(
                  product: product,
                  imageHeight: imageHeight,
                  onTap: () =>
                      context.go('${AppRoutes.products}/${product.id}'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMapCard(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: () => context.go(AppRoutes.map),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.map_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productores cerca de ti',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explora zonas publicas en el mapa',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    ),
  );

  Widget _buildSummary(BuildContext context, HomeViewModel viewModel) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Actividad del catalogo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (viewModel.errorMessage != null)
              TextButton(
                onPressed: viewModel.refresh,
                child: const Text('Reintentar'),
              )
            else
              Text(
                viewModel.summaryLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < viewModel.metrics.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 78),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        viewModel.metrics[index].value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        viewModel.metrics[index].label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChatShortcut(BuildContext context) => OutlinedButton.icon(
    onPressed: () => context.go(AppRoutes.chatList),
    icon: const Icon(Icons.chat_bubble_outline_rounded),
    label: const Text('Ir a mis conversaciones'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryDark,
      minimumSize: const Size.fromHeight(48),
      side: const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  Widget _buildInlineProblem(
    BuildContext context, {
    required String message,
    Widget? action,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ),
      ?action,
    ],
  );
}

class _CategoryLoadingRow extends StatelessWidget {
  const _CategoryLoadingRow();

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      3,
      (index) => Container(
        margin: const EdgeInsets.only(right: 8),
        child: SkeletonBlock(
          width: 92 + index * 16,
          height: 36,
          borderRadius: 12,
        ),
      ),
    ),
  );
}

class _ProductLoadingRow extends StatelessWidget {
  const _ProductLoadingRow();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) =>
          const SkeletonBlock(width: 228, height: 300, borderRadius: 18),
    ),
  );
}

class _ProductStateCard extends StatelessWidget {
  const _ProductStateCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 32),
        const SizedBox(height: 8),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    ),
  );
}
