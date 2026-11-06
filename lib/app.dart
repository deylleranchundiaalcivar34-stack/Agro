import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';

class AgroApp extends StatefulWidget {
  const AgroApp({super.key});

  @override
  State<AgroApp> createState() => _AgroAppState();
}

class _AgroAppState extends State<AgroApp> {
  late final AppRouter _appRouter;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    final authViewModel = context.read<AuthViewModel>();
    _appRouter = AppRouter(
      authViewModel: authViewModel,
      initialLocation: authViewModel.isAuthenticated
          ? AppRoutes.home
          : AppRoutes.login,
    );
    _linkSubscription = AppLinks().uriLinkStream.listen(_openEmailConfirmed);
  }

  Future<void> _openEmailConfirmed(Uri uri) async {
    if (uri.scheme != 'io.supabase.agro' || uri.host != 'auth') return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) _appRouter.router.go(AppRoutes.emailConfirmed);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Agro+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _appRouter.router,
    );
  }
}
