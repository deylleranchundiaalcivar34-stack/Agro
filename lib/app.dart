import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';

/// Punto de entrada de la aplicación.
/// Separa la configuración del árbol de widgets de [main.dart]
/// para mantener el bootstrap limpio.
class AgroApp extends StatefulWidget {
  const AgroApp({super.key});

  @override
  State<AgroApp> createState() => _AgroAppState();
}

class _AgroAppState extends State<AgroApp> {
  // El router se crea una sola vez y se le pasa la referencia
  // del AuthViewModel para que pueda redirigir según el estado de sesión.
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    // Accedemos al AuthViewModel sin escuchar (listen: false) porque
    // estamos en initState, no en build.
    final authViewModel = context.read<AuthViewModel>();
    _appRouter = AppRouter(authViewModel: authViewModel);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Agro+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Conectamos el router de GoRouter al MaterialApp
      routerConfig: _appRouter.router,
    );
  }
}

