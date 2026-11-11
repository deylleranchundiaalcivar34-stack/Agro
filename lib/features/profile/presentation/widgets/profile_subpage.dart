import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

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
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(top: false, child: child),
  );
}
