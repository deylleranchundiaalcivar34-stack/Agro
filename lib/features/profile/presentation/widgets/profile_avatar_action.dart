import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import 'public_profile_avatar.dart';

class ProfileAvatarAction extends StatelessWidget {
  const ProfileAvatarAction({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          tooltip: 'Abrir menú de cuenta',
          onPressed: () => Scaffold.of(context).openEndDrawer(),
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.surface,
            shape: const CircleBorder(),
          ),
          icon: PublicProfileAvatar(
            radius: 20,
            initial: auth.userInitial,
            imageUrl: auth.profile?.avatarUrl,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}
