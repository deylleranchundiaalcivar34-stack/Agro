import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../products/data/models/agricultural_product.dart';
import '../viewmodels/favorites_viewmodel.dart';

/// Corazon animado y estado accesible para guardar/quitar una publicacion.
class FavoriteToggleButton extends StatelessWidget {
  const FavoriteToggleButton({
    super.key,
    required this.product,
    this.compact = false,
  });

  final AgriculturalProduct product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isOwner = context.select<AuthViewModel, bool>(
      (auth) => auth.currentUser?.id == product.producerId,
    );
    if (isOwner) return const SizedBox.shrink();
    final isFavorite = context.select<FavoritesViewModel, bool>(
      (state) => state.isFavorite(product.id),
    );
    final isPending = context.select<FavoritesViewModel, bool>(
      (state) => state.isPending(product.id),
    );
    return IconButton(
      tooltip: isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
      onPressed: isPending ? null : () => _toggle(context),
      iconSize: compact ? 21 : 25,
      constraints: BoxConstraints.tightFor(
        width: compact ? 42 : 48,
        height: compact ? 42 : 48,
      ),
      visualDensity: VisualDensity.standard,
      icon: AnimatedScale(
        scale: isFavorite ? 1.08 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: isPending
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? AppColors.error : AppColors.textPrimary,
              ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    try {
      await context.read<FavoritesViewModel>().toggle(product);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar Favoritos. Intenta de nuevo.'),
        ),
      );
    }
  }
}
