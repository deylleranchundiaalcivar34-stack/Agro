import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

/// Vista principal del Home.
/// TODO (Bloque 3): Implementar catálogo de productos con filtros.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();
    final user = authViewModel.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agro+'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Agregar producto',
            onPressed: () => context.go(AppRoutes.productCreate),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await authViewModel.signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 72, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              '¡Bienvenido!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? 'usuario@agro.com',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            const Text(
              '🚧 Catálogo de productos — Bloque 3',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

