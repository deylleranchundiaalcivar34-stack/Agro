import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_routes.dart';
import 'agro_logo.dart';

class AgroPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AgroPageAppBar({
    super.key,
    this.appBarKey,
    required this.title,
    this.titleContent,
    this.actions = const [],
    this.showBackButton = true,
    this.backTooltip = 'Volver',
    this.onBack,
    this.logoKey = const Key('agro-page-logo'),
  });

  final Key? appBarKey;
  final String title;
  final Widget? titleContent;
  final List<Widget> actions;
  final bool showBackButton;
  final String backTooltip;
  final VoidCallback? onBack;
  final Key? logoKey;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    key: appBarKey,
    automaticallyImplyLeading: false,
    centerTitle: false,
    titleSpacing: showBackButton ? 0 : 16,
    leading: showBackButton
        ? IconButton(
            tooltip: backTooltip,
            onPressed: onBack ?? () => _goBack(context),
            icon: const Icon(Icons.arrow_back_rounded),
          )
        : null,
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    systemOverlayStyle: const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    titleTextStyle: Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: AppColors.surface, fontWeight: FontWeight.w700),
    title: Row(
      children: [
        if (!showBackButton) ...[
          AgroLogo(key: logoKey, size: 30, filterQuality: FilterQuality.low),
          const SizedBox(width: 10),
        ],
        Expanded(
          child:
              titleContent ??
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.surface.withValues(alpha: .18),
      ),
    ),
  );

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}
