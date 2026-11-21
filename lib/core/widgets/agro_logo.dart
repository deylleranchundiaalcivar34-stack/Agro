import 'package:flutter/material.dart';

class AgroLogo extends StatelessWidget {
  const AgroLogo({
    super.key,
    required this.size,
    this.cacheWidth,
    this.errorBuilder,
    this.filterQuality = FilterQuality.medium,
  });

  final double size;
  final int? cacheWidth;
  final ImageErrorWidgetBuilder? errorBuilder;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.asset(
      'assets/images/logotipo_oficial.png',
      semanticLabel: 'Logo de Agro+',
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth:
          cacheWidth ?? (size * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: errorBuilder,
      filterQuality: filterQuality,
    ),
  );
}
