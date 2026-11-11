import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Etiqueta compartida de fase y visibilidad con altura predecible.
class ProductStatusBadge extends StatelessWidget {
  const ProductStatusBadge(
    this.label, {
    super.key,
    this.muted = false,
    this.style,
  });
  final String label;
  final bool muted;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: muted ? AppColors.surfaceVariant : AppColors.primarySurface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (style ?? Theme.of(context).textTheme.labelMedium)?.copyWith(
        fontWeight: FontWeight.w700,
        color: muted ? AppColors.textSecondary : AppColors.primaryDark,
      ),
    ),
  );
}
