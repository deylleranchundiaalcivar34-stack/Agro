import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Estilo limitado a productos: no altera el tema ni la navegacion de otros modulos.
class ProductScaffold extends StatelessWidget {
  const ProductScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.contentMaxWidth = 760,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.divider),
    );
    final button = ButtonStyle(
      shape: WidgetStatePropertyAll(shape),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
    Widget constrained(Widget child) => Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        child: child,
      ),
    );
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          iconTheme: const IconThemeData(color: AppColors.surface),
          actionsIconTheme: const IconThemeData(color: AppColors.surface),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorMaxLines: 3,
        ),
        filledButtonTheme: FilledButtonThemeData(style: button),
        outlinedButtonTheme: OutlinedButtonThemeData(style: button),
        dialogTheme: base.dialogTheme.copyWith(
          shape: shape,
          backgroundColor: AppColors.surface,
        ),
        chipTheme: base.chipTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.background,
        appBar: appBar,
        body: body == null
            ? null
            : LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Center(
                    child: SizedBox(
                      width: math.min(contentMaxWidth, constraints.maxWidth),
                      child: body,
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: bottomNavigationBar == null
            ? null
            : Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: constrained(bottomNavigationBar!),
              ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

class ProductSectionHeading extends StatelessWidget {
  const ProductSectionHeading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    ),
  );
}
