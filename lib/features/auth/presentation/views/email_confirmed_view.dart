import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';

class EmailConfirmedView extends StatelessWidget {
  const EmailConfirmedView({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthViewModel>().isAuthenticated;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: AppColors.primary,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Correo confirmado',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu cuenta ya esta lista. Ya puedes iniciar sesion en Agro+.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(
                    loggedIn ? AppRoutes.home : AppRoutes.login,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(loggedIn ? 'Ir al inicio' : 'Iniciar sesion'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 350.ms).slideY(begin: .05),
          ),
        ),
      ),
    );
  }
}
