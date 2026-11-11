import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shared branded gradient used by the welcome and startup screens.
class AgroBrandBackground extends StatelessWidget {
  const AgroBrandBackground({
    super.key,
    required this.backgroundKey,
    required this.child,
  });

  final Key backgroundKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: backgroundKey,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primaryDark, AppColors.primary],
      ),
    ),
    child: Stack(
      children: [
        const Positioned(
          key: ValueKey('brand-orb-top'),
          top: -110,
          right: -90,
          child: _BrandOrb(size: 260, opacity: .14),
        ),
        const Positioned(
          key: ValueKey('brand-orb-bottom'),
          bottom: 36,
          left: -130,
          child: _BrandOrb(size: 300, opacity: .1),
        ),
        child,
      ],
    ),
  );
}

class _BrandOrb extends StatelessWidget {
  const _BrandOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primaryLight.withValues(alpha: opacity),
    ),
  );
}
