import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../../../profile/presentation/widgets/profile_subpage.dart';
import '../viewmodels/favorites_viewmodel.dart';

/// Lista adaptable de publicaciones guardadas por la cuenta actual.
class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) => ProfileSubpage(
    title: 'Favoritos',
    actions: [
      IconButton(
        tooltip: 'Actualizar Favoritos',
        onPressed: () => context.read<FavoritesViewModel>().refresh(),
        icon: const Icon(Icons.refresh_rounded),
      ),
      const SizedBox(width: 4),
    ],
    child: Consumer<FavoritesViewModel>(
      builder: (context, state, _) {
        if (state.isLoading && state.favorites.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final active = state.favorites
            .where(
              (favorite) =>
                  favorite.product?.isPublished == true &&
                  favorite.product!.availableQuantity > 0,
            )
            .toList();
        final unavailable = state.favorites
            .where((favorite) => !active.contains(favorite))
            .toList();

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: state.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _FavoritesHeader(count: active.length),
                ),
              ),
              if (state.error != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ErrorBanner(onRetry: state.refresh),
                  ),
                ),
              if (active.isEmpty && unavailable.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFavorites(),
                )
              else if (active.isNotEmpty)
                SliverLayoutBuilder(
                  builder: (context, _) {
                    final width = MediaQuery.sizeOf(context).width;
                    final cardWidth = ((width > 1200 ? 1200 : width) - 52)
                        .clamp(240.0, 380.0)
                        .toDouble();
                    final imageHeight = ProductCard.imageHeightFor(context);
                    final cardHeight = active
                        .map(
                          (favorite) => ProductCard.heightFor(
                            context,
                            favorite.product!,
                            width: cardWidth,
                            imageHeight: imageHeight,
                          ),
                        )
                        .reduce((a, b) => a > b ? a : b);
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverGrid.builder(
                        itemCount: active.length,
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: cardHeight,
                        ),
                        itemBuilder: (context, index) {
                          final product = active[index].product!;
                          return ProductCard(
                                product: product,
                                imageHeight: imageHeight,
                                onTap: () => context.go(
                                  '${AppRoutes.products}/${product.id}',
                                ),
                              )
                              .animate()
                              .fadeIn(
                                duration: 240.ms,
                                delay: Duration(milliseconds: index * 35),
                              )
                              .slideY(begin: .035, end: 0, duration: 240.ms);
                        },
                      ),
                    );
                  },
                ),
              if (unavailable.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    active.isEmpty ? 8 : 24,
                    20,
                    8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Ya no disponibles',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              if (unavailable.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.builder(
                    itemCount: unavailable.length,
                    itemBuilder: (context, index) {
                      final favorite = unavailable[index];
                      return _UnavailableFavorite(
                        title: favorite.product?.name ?? 'Publicación retirada',
                        onRemove: () => _remove(context, favorite.productId),
                      );
                    },
                  ),
                ),
              if (state.isLoading && state.favorites.isNotEmpty)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(color: AppColors.primary),
                ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _remove(BuildContext context, String productId) async {
    try {
      await context.read<FavoritesViewModel>().removeUnavailable(productId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo quitar este producto.')),
      );
    }
  }
}

class _FavoritesHeader extends StatelessWidget {
  const _FavoritesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider.withValues(alpha: .65)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Productos guardados',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count == 1
                    ? '1 producto disponible'
                    : '$count productos disponibles',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aún no tienes favoritos',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            'Toca el corazón de una publicación para guardarla y encontrarla aquí después.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.products),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Explorar productos'),
          ),
        ],
      ).animate().fadeIn(duration: 260.ms).slideY(begin: .04, end: 0),
    ),
  );
}

class _UnavailableFavorite extends StatelessWidget {
  const _UnavailableFavorite({required this.title, required this.onRemove});

  final String title;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      children: [
        const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              const Text(
                'La publicación ya no está disponible.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Quitar de Favoritos',
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.error),
        const SizedBox(width: 10),
        const Expanded(child: Text('No se pudieron cargar tus Favoritos.')),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
