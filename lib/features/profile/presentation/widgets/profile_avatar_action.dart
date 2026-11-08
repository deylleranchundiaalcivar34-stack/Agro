import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

class ProfileAvatarAction extends StatelessWidget {
  const ProfileAvatarAction({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: 'Abrir mi perfil',
        onPressed: () => context.push(AppRoutes.profile),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.surface.withValues(alpha: 0.18),
          foregroundColor: AppColors.surface,
        ),
        icon: CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.primarySurface,
          child: Text(
            auth.userInitial,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
