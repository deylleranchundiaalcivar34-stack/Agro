import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../map/data/models/public_producer_location.dart';
import '../../../map/data/repositories/public_location_repository.dart';
import '../../../products/data/models/agricultural_product.dart';
import '../../../products/data/repositories/products_repository.dart';

class PublicProducerProfileView extends StatefulWidget {
  const PublicProducerProfileView({
    super.key,
    required this.producerId,
    this.locationRepository,
    this.productsRepository,
  });

  final String producerId;
  final PublicLocationRepository? locationRepository;
  final ProductsRepository? productsRepository;

  @override
  State<PublicProducerProfileView> createState() =>
      _PublicProducerProfileViewState();
}

class _PublicProducerProfileViewState extends State<PublicProducerProfileView> {
  late final PublicLocationRepository _locations =
      widget.locationRepository ??
      PublicLocationRepository(supabaseService: SupabaseService());
  late final ProductsRepository _products =
      widget.productsRepository ??
      ProductsRepository(supabaseService: SupabaseService());

  PublicProducerLocation? _location;
  List<AgriculturalProduct> _productsForProducer = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _locations.getPublishedForProducer(widget.producerId),
        _products.getPublishedProductsForProducer(widget.producerId),
      ]);
      if (!mounted) return;
      setState(() {
        _location = results[0] as PublicProducerLocation?;
        _productsForProducer = results[1] as List<AgriculturalProduct>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el perfil. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Perfil del productor')),
    body: SafeArea(
      top: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : _location == null
          ? const _NotPublicState()
          : _profile(context, _location!),
    ),
  );

  Widget _profile(BuildContext context, PublicProducerLocation location) {
    final theme = Theme.of(context);
    final productCount = _productsForProducer.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primaryDark,
                  child: Text(
                    location.alias.trim().isEmpty
                        ? 'A'
                        : location.alias.trim()[0].toUpperCase(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.alias,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.surface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.surface,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${location.placeName} · zona aproximada',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Icon(Icons.star_outline, color: AppColors.primary),
              ),
              title: Text('Reputacion', style: theme.textTheme.titleMedium),
              subtitle: const Text(
                'Las resenas apareceran cuando Agro+ pueda verificar pedidos completados.',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Productos disponibles',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Text(
                '$productCount ${productCount == 1 ? 'producto' : 'productos'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_productsForProducer.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Este productor no tiene productos disponibles.'),
              ),
            )
          else
            ..._productsForProducer.map(
              (product) => _ProductTile(product: product),
            ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});
  final AgriculturalProduct product;

  @override
  Widget build(BuildContext context) {
    final image = product.imagenUrl ?? product.fotografias.firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: image == null || image.isEmpty
                ? const ColoredBox(
                    color: AppColors.primarySurface,
                    child: Icon(Icons.eco_outlined, color: AppColors.primary),
                  )
                : CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: AppColors.primarySurface,
                      child: Icon(Icons.eco_outlined, color: AppColors.primary),
                    ),
                  ),
          ),
        ),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${product.categoryName} · ${product.priceWithUnit}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('${AppRoutes.products}/${product.id}'),
      ),
    );
  }
}

class _NotPublicState extends StatelessWidget {
  const _NotPublicState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 60,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Este productor no tiene un perfil publico.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Solo mostramos la zona que la persona decidio publicar.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 56, color: AppColors.error),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    ),
  );
}
