// Detalle del lote y acciones disponibles para su propietario o una cuenta compradora.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../widgets/product_delete_button.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/agro_page_app_bar.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../chat/presentation/widgets/contact_producer_button.dart';
import '../../../favorites/presentation/widgets/favorite_toggle_button.dart';
import '../../../map/data/models/public_producer_location.dart';
import '../../../map/data/repositories/public_location_repository.dart';
import '../../../profile/data/repositories/public_contact_profile_repository.dart';
import '../../../profile/presentation/widgets/public_profile_avatar.dart';
import '../../../../core/widgets/skeleton_block.dart';
import '../../data/models/agricultural_product.dart';
import '../viewmodels/products_viewmodel.dart';

/// Carga una publicacion por ID y actualiza su lectura al regresar de la edicion.
class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key, required this.productId});
  final String productId;
  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  // La misma Future se conserva entre reconstrucciones para no repetir consultas involuntarias.
  late Future<AgriculturalProduct?> _product;
  @override
  void initState() {
    super.initState();
    _product = context.read<ProductsViewModel>().getProduct(widget.productId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: const AgroPageAppBar(title: 'Detalle de preventa'),
    body: FutureBuilder<AgriculturalProduct?>(
      future: _product,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final product = snapshot.data;
        if (snapshot.hasError || product == null) {
          return const Center(child: Text('Este lote no esta disponible.'));
        }
        return _Detail(
          product: product,
          onQuantity: () => _editQuantity(product.id),
          onEdit: () async {
            await context.push<bool>(
              '${AppRoutes.products}/${product.id}/edit',
            );
            if (!context.mounted) return;
            setState(
              () => _product = context.read<ProductsViewModel>().getProduct(
                widget.productId,
              ),
            );
          },
        );
      },
    ),
  );

  /// Abre la edicion reducida y vuelve a consultar el producto al regresar.
  Future<void> _editQuantity(String productId) async {
    await context.push<bool>(
      '${AppRoutes.products}/$productId/edit?quantity=1',
    );
    if (!mounted) return;
    setState(
      () => _product = context.read<ProductsViewModel>().getProduct(
        widget.productId,
      ),
    );
  }
}

/// Contenido del detalle, informacion del productor y acciones disponibles.
class _Detail extends StatefulWidget {
  const _Detail({
    required this.product,
    required this.onEdit,
    required this.onQuantity,
  });
  final VoidCallback onEdit;
  final VoidCallback onQuantity;
  final AgriculturalProduct product;

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  late final Future<PublicProducerLocation?> _producerLocation =
      PublicLocationRepository(supabaseService: SupabaseService())
          .getPublishedForProducer(widget.product.producerId);
  late final Future<String?> _producerAvatar =
      PublicContactProfileRepository(supabaseService: SupabaseService())
          .getMany([widget.product.producerId])
          .then((profiles) => profiles[widget.product.producerId]?.avatarUrl);

  @override
  Widget build(BuildContext context) {
    final role = context.select<AuthViewModel, UserRole>(
      (auth) => auth.selectedRole,
    );
    final userId = context.select<AuthViewModel, String?>(
      (auth) => auth.currentUser?.id,
    );
    final product = widget.product;
    // La interfaz distingue al propietario; el servicio y RLS siguen controlando las escrituras.
    final owner = userId == product.producerId;
    final canContact =
        !owner &&
        (role == UserRole.buyer || role == UserRole.producer) &&
        product.isPublished &&
        product.availableQuantity > 0;
    final isManaging = context.select<ProductsViewModel, bool>(
      (state) => state.isSubmitting,
    );

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                sliver: SliverList.list(
                  children: [
                    _ProductGallery(product: product, isOwner: owner),
                    const SizedBox(height: 22),
                    _ProductHeading(product: product),
                    const SizedBox(height: 18),
                    _ProductFacts(product: product),
                    const SizedBox(height: 18),
                    FutureBuilder<PublicProducerLocation?>(
                      future: _producerLocation,
                      builder: (context, snapshot) => FutureBuilder<String?>(
                        future: _producerAvatar,
                        builder: (context, avatarSnapshot) => _ProducerCard(
                          location: snapshot.data,
                          avatarUrl: avatarSnapshot.data,
                          loading:
                              snapshot.connectionState != ConnectionState.done,
                          onTap: snapshot.data == null
                              ? null
                              : () => context.push(
                                  AppRoutes.publicProducerProfile.replaceFirst(
                                    ':producerId',
                                    product.producerId,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (owner && role == UserRole.producer) ...[
                      const SizedBox(height: 18),
                      _OwnerActions(
                        product: product,
                        isSubmitting: isManaging,
                        onEdit: widget.onEdit,
                        onQuantity: widget.onQuantity,
                      ),
                    ] else if (!canContact) ...[
                      const SizedBox(height: 18),
                      const _Notice(
                        text: 'Esta publicación no tiene unidades disponibles para consulta en este momento.',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (canContact) _ContactFooter(product: product),
      ],
    );
  }
}

class _ProductGallery extends StatelessWidget {
  const _ProductGallery({required this.product, required this.isOwner});
  final AgriculturalProduct product;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final images = product.fotografias.isNotEmpty
        ? product.fotografias
        : product.imagenUrl == null
        ? const <String>[]
        : <String>[product.imagenUrl!];
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * .72)
            .clamp(250.0, 360.0)
            .toDouble();
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.primarySurface,
                  child: images.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.eco_outlined,
                            size: 72,
                            color: AppColors.primary,
                          ),
                        )
                      : PageView.builder(
                          itemCount: images.length,
                          itemBuilder: (context, index) => CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.contain,
                            placeholder: (_, _) => const SkeletonBlock(),
                            errorWidget: (_, _, _) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                ),
                if (!isOwner)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: AppColors.surface.withValues(alpha: .96),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: FavoriteToggleButton(product: product),
                    ),
                  ),
                if (images.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            '${images.length} fotos · desliza para ver',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.surface),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 280.ms).slideY(begin: .025, end: 0);
      },
    );
  }
}

class _ProductHeading extends StatelessWidget {
  const _ProductHeading({required this.product});
  final AgriculturalProduct product;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          product.phaseName,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        product.name,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          const Icon(
            Icons.category_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            product.categoryName,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    ],
  );
}

class _ProductFacts extends StatelessWidget {
  const _ProductFacts({required this.product});
  final AgriculturalProduct product;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _FactCard(
              icon: Icons.inventory_2_outlined,
              label: product.quantityLabel,
              value: product.quantityWithUnit,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FactCard(
              icon: Icons.payments_outlined,
              label: 'Precio unitario',
              value: product.priceWithUnit,
              emphasize: true,
            ),
          ),
        ],
      ),
      if (product.estimatedHarvestDate != null) ...[
        const SizedBox(height: 12),
        _FactCard(
          icon: Icons.calendar_month_outlined,
          label: 'Cosecha estimada',
          value: _date(product.estimatedHarvestDate!),
          horizontal: true,
        ),
      ],
    ],
  );

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.horizontal = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;
  final bool horizontal;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider.withValues(alpha: .7)),
    ),
    child: horizontal
        ? Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: _FactText(label: label, value: value),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 10),
              _FactText(label: label, value: value, emphasize: emphasize),
            ],
          ),
  );
}

class _FactText extends StatelessWidget {
  const _FactText({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: emphasize ? AppColors.primaryDark : AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _ProducerCard extends StatelessWidget {
  const _ProducerCard({
    required this.location,
    required this.avatarUrl,
    required this.loading,
    required this.onTap,
  });
  final PublicProducerLocation? location;
  final String? avatarUrl;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final alias = location?.alias ?? 'Productor de Agro+';
    final initial = alias.trim().isEmpty ? 'P' : alias.trim()[0].toUpperCase();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider.withValues(alpha: .7)),
          ),
          child: Row(
            children: [
              PublicProfileAvatar(
                radius: 27,
                initial: initial,
                imageUrl: avatarUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendido por',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loading ? 'Cargando productor…' : alias,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${location!.placeName} · zona aproximada',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ] else if (!loading)
                      Text(
                        'Productor local',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({
    required this.product,
    required this.isSubmitting,
    required this.onEdit,
    required this.onQuantity,
  });
  final AgriculturalProduct product;
  final bool isSubmitting;
  final VoidCallback onEdit;
  final VoidCallback onQuantity;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.visibility_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Estado: ${product.visibilityLabel}'),
        ],
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: isSubmitting ? null : onEdit,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Editar publicación'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: isSubmitting ? null : onQuantity,
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Actualizar cantidad'),
      ),
      const SizedBox(height: 8),
      ProductDeleteButton(
        product: product,
        onDeleted: () => context.go(AppRoutes.products),
      ),
      const SizedBox(height: 8),
      const _Notice(
        text: 'Las consultas de compradores aparecerán en Conversaciones > Solicitudes.',
      ),
    ],
  );
}

class _ContactFooter extends StatelessWidget {
  const _ContactFooter({required this.product});
  final AgriculturalProduct product;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border(
        top: BorderSide(color: AppColors.divider.withValues(alpha: .75)),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: .05),
          blurRadius: 14,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Consulta disponibilidad y coordina directamente con el productor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ContactProducerButton(product: product),
        ],
      ),
    ),
  );
}

/// Aviso contextual para el propietario o cuentas sin acceso al registro de interes.
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
