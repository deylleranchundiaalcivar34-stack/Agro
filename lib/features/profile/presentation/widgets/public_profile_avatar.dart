import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class PublicProfileAvatar extends StatelessWidget {
  const PublicProfileAvatar({
    super.key,
    required this.radius,
    required this.initial,
    this.imageUrl,
    this.backgroundColor = AppColors.primarySurface,
    this.foregroundColor = AppColors.primaryDark,
  });

  final double radius;
  final String initial;
  final String? imageUrl;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty || !url.startsWith('https://')) {
      return _fallback();
    }
    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => _fallback(),
      errorWidget: (context, url, error) => _fallback(),
      useOldImageOnUrlChange: true,
    );
  }

  Widget _fallback() => CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    child: Text(
      initial.trim().isEmpty ? 'A' : initial.trim()[0].toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}
