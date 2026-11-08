import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A low-cost static loading placeholder for content that is not ready yet.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.color = AppColors.surfaceVariant,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
  );
}
