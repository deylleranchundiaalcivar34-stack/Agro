import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/agro_page_app_bar.dart';

class ProfileSubpage extends StatelessWidget {
  const ProfileSubpage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AgroPageAppBar(
      title: title,
      actions: actions,
      logoKey: const Key('agro-subpage-logo'),
    ),
    body: SafeArea(top: false, child: child),
  );
}
