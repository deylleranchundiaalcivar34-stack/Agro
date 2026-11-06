// Tarjeta compacta del catálogo; solo presenta el lote y comunica su pulsación al llamador.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/agricultural_product.dart';

/// Ordena portada, fase, nombre, cantidad, categoría y precio sin separadores flexibles.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.imageHeight = 170,
    this.showVisibility = false,
  });
  final AgriculturalProduct product;
  final VoidCallback onTap;
  final double imageHeight;
  // La gestión privada muestra Visible/Oculto; el catálogo conserva su etiqueta de fase.
  final bool showVisibility;

  // Elegir la portada por ancho disponible, también en Chrome con ventana estrecha.
  static double imageHeightFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600 ? 200 : 170;

  // Compartir estilos entre la medición y el dibujo evita reservar alturas arbitrarias.
  static TextStyle? _bodyStyle(TextTheme theme) =>
      theme.bodyMedium?.copyWith(fontSize: 12, height: 1.25);
  static TextStyle? _titleStyle(TextTheme theme) =>
      theme.titleMedium?.copyWith(fontSize: 14, height: 1.2);

  /// Calcula el espacio real del texto, incluida accesibilidad, sin estirar los detalles.
  static double heightFor(
    BuildContext context,
    AgriculturalProduct product, {
    required double width,
    required double imageHeight,
    bool showVisibility = false,
  }) {
    final theme = Theme.of(context).textTheme;
    final body = _bodyStyle(theme);
    final title = _titleStyle(theme);
    double textHeight(
      String text,
      TextStyle? style,
      int lines, {
      double inset = 0,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: (width - 20 - inset).clamp(1, double.infinity));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // 20 de margen interior, 6 de la etiqueta y 20 de separación entre secciones.
    var height =
        imageHeight +
        46 +
        textHeight(
          showVisibility
              ? product.visibilityLabel
              : product.isPublished
              ? product.phaseName
              : 'Oculto',
          body?.copyWith(fontWeight: FontWeight.w700),
          1,
          inset: 14,
        ) +
        textHeight(
          product.name,
          title?.copyWith(fontWeight: FontWeight.w700),
          2,
        ) +
        textHeight(product.quantityWithUnit, body, 2) +
        textHeight(product.categoryName, body, 1) +
        textHeight(
          product.priceWithUnit,
          title?.copyWith(fontWeight: FontWeight.w800),
          2,
        );
    if (product.harvestLabel != null) {
      height +=
          4 +
          textHeight(
            'Cosecha: ${product.harvestLabel}',
            body?.copyWith(fontSize: 11, height: 1.2),
            2,
          );
    }
    // Un pequeño margen absorbe diferencias de redondeo de los píxeles del navegador.
    return height.ceilToDouble() + 2;
  }

  @override
  Widget build(BuildContext context) {
    // Tipografía compacta con alturas de línea previsibles para el grid adaptable.
    final theme = Theme.of(context).textTheme;
    final bodyStyle = _bodyStyle(theme);
    final titleStyle = _titleStyle(theme);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reservar la misma portada para imágenes, cargas e iconos sin fotografía.
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: ColoredBox(
                    color: AppColors.primarySurface,
                    child: imagenProducto(
                      product.imagenUrl,
                      height: imageHeight,
                    ),
                  ),
                ),
              ),
              // Detalles agrupados con separación fija para evitar grandes espacios en blanco.
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        showVisibility
                            ? product.visibilityLabel
                            : product.isPublished
                            ? product.phaseName
                            : 'Oculto',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.quantityWithUnit,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.priceWithUnit,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    // Conservar la cosecha como dato complementario cuando está registrada.
                    if (product.harvestLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Cosecha: ${product.harvestLabel}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle?.copyWith(fontSize: 11, height: 1.2),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Portada compartida por tarjeta y detalle, con estados de carga, ausencia y error.
Widget imagenProducto(String? imagenUrl, {double height = 100}) {
  if (imagenUrl == null || imagenUrl.trim().isEmpty) {
    return const Center(
      child: Icon(Icons.eco, color: AppColors.primary, size: 50),
    );
  }
  return CachedNetworkImage(
    imageUrl: imagenUrl,
    width: double.infinity,
    height: height,
    fit: BoxFit.cover,
    placeholder: (_, _) => Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: const ColoredBox(color: AppColors.surface),
    ),
    errorWidget: (context, url, error) => const Center(
      child: Icon(Icons.broken_image, color: AppColors.textSecondary),
    ),
  );
}
