import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import 'public_profile_avatar.dart';

class AccountNavigationDrawer extends StatelessWidget {
  const AccountNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final role = auth.selectedRole;
    final isMarketplaceUser =
        role == UserRole.buyer || role == UserRole.producer;
    final isProducer = role == UserRole.producer;
    final width = math.min(MediaQuery.sizeOf(context).width * .88, 360.0);

    return Drawer(
      width: width,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
              child: Row(
                children: [
                  PublicProfileAvatar(
                    radius: 25,
                    initial: auth.userInitial,
                    imageUrl: auth.profile?.avatarUrl,
                    backgroundColor: AppColors.primarySurface,
                    foregroundColor: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          _openDestination(context, AppRoutes.profileData),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              role.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ver mis datos',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionLabel(context, 'CUENTA'),
                  if (isMarketplaceUser) ...[
                    _destination(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: 'Mis pedidos',
                      route: AppRoutes.profileOrders,
                    ),
                    _destination(
                      context,
                      icon: Icons.favorite_border_rounded,
                      label: 'Favoritos',
                      route: AppRoutes.profileFavorites,
                    ),
                  ],
                  _destination(
                    context,
                    icon: Icons.notifications_none_rounded,
                    label: 'Notificaciones',
                    route: AppRoutes.profileNotifications,
                  ),
                  _destination(
                    context,
                    icon: Icons.shield_outlined,
                    label: 'Seguridad',
                    route: AppRoutes.profileSecurity,
                  ),
                  if (isProducer) ...[
                    _sectionLabel(context, 'PRODUCTOR'),
                    _destination(
                      context,
                      icon: Icons.inventory_2_outlined,
                      label: 'Mis publicaciones',
                      route: Uri(
                        path: AppRoutes.products,
                        queryParameters: const {'mine': 'true'},
                      ).toString(),
                    ),
                    _destination(
                      context,
                      icon: Icons.place_outlined,
                      label: 'Mi zona publica',
                      route: AppRoutes.publicLocation,
                    ),
                  ],
                  _sectionLabel(context, 'AYUDA'),
                  _destination(
                    context,
                    icon: Icons.help_outline_rounded,
                    label: 'Ayuda y soporte',
                    route: AppRoutes.profileSupport,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: ListTile(
                minLeadingWidth: 24,
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Cerrar sesion'),
                textColor: AppColors.error,
                iconColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => confirmSignOut(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _destination(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: ListTile(
      minLeadingWidth: 24,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => _openDestination(context, route),
    ),
  );
}

void _openDestination(BuildContext context, String route) {
  Navigator.of(context).pop();
  context.push(route);
}

Future<void> confirmSignOut(BuildContext context) async {
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
