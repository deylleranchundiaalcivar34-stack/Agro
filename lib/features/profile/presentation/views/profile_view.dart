import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final isProducer = auth.selectedRole == UserRole.producer;
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: IconButton(
          tooltip: 'Volver al inicio',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => context.push(AppRoutes.profileNotifications),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Ayuda y soporte',
            onPressed: () => context.push(AppRoutes.profileSupport),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            _IdentityCard(
              initial: auth.userInitial,
              name: auth.displayName,
              email: profile?.email ?? auth.currentUser?.email ?? '',
              role: auth.selectedRole.label,
            ),
            const SizedBox(height: 24),
            Text(
              'Tu cuenta',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 340 ? 1 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 3.2 : 1.28,
                  children: [
                    _ProfileAction(
                      icon: Icons.receipt_long_outlined,
                      label: 'Mis pedidos',
                      onTap: () => context.push(AppRoutes.profileOrders),
                    ),
                    _ProfileAction(
                      icon: Icons.badge_outlined,
                      label: 'Mis datos',
                      onTap: () => context.push(AppRoutes.profileData),
                    ),
                    _ProfileAction(
                      icon: Icons.notifications_active_outlined,
                      label: 'Notificaciones',
                      onTap: () => context.push(AppRoutes.profileNotifications),
                    ),
                    _ProfileAction(
                      icon: Icons.shield_outlined,
                      label: 'Seguridad',
                      onTap: () => context.push(AppRoutes.profileSecurity),
                    ),
                    if (isProducer) ...[
                      _ProfileAction(
                        icon: Icons.inventory_2_outlined,
                        label: 'Mis publicaciones',
                        onTap: () => context.go(
                          Uri(
                            path: AppRoutes.products,
                            queryParameters: const {'mine': 'true'},
                          ).toString(),
                        ),
                      ),
                      _ProfileAction(
                        icon: Icons.place_outlined,
                        label: 'Mi zona publica',
                        onTap: () => context.push(AppRoutes.publicLocation),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: .35)),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesion?'),
        content: const Text('Tendras que volver a ingresar para usar Agro+.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !context.mounted) return;
    await context.read<AuthViewModel>().signOut();
    if (context.mounted) context.go(AppRoutes.login);
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.initial,
    required this.name,
    required this.email,
    required this.role,
  });

  final String initial;
  final String name;
  final String email;
  final String role;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.divider.withValues(alpha: .55)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: .05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primarySurface,
          child: Text(
            initial,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Text(
                    role,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider.withValues(alpha: .65)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
