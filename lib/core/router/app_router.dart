import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/home/presentation/views/home_view.dart';
import '../../features/products/presentation/views/product_detail_view.dart';
import '../../features/products/presentation/views/product_create_view.dart';
import '../../features/map/presentation/views/map_view.dart';
import '../../features/chat/presentation/views/chat_list_view.dart';
import '../../features/chat/presentation/views/chat_room_view.dart';
import '../../features/splash/splash_view.dart';

/// Router principal de la aplicación usando GoRouter.
///
/// Maneja:
/// - Redirección automática según estado de sesión (Auth Guard).
/// - Rutas anidadas para Chat y Auth.
/// - Transiciones de página personalizadas.
class AppRouter {
  final AuthViewModel authViewModel;

  AppRouter({required this.authViewModel});

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true, // Desactivar en producción

    /// [redirect] se ejecuta antes de cada navegación.
    /// Es el "Auth Guard": decide si el usuario puede acceder a la ruta.
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authViewModel.isAuthenticated;
      final location = state.matchedLocation;

      // Rutas que NO requieren autenticación
      final publicRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.splash,
      ];

      final isPublicRoute = publicRoutes.any(
        (route) => location.startsWith(route),
      );

      // Si NO está autenticado y trata de acceder a ruta protegida → Login
      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.login;
      }

      // Si YA está autenticado y trata de ir a Login/Register → Home
      if (isAuthenticated &&
          (location == AppRoutes.login || location == AppRoutes.register)) {
        return AppRoutes.home;
      }

      // Sin redirección: permite continuar a la ruta solicitada
      return null;
    },

    /// Refresca el router cuando cambia el estado del AuthViewModel.
    /// Así GoRouter reacciona automáticamente al login/logout.
    refreshListenable: authViewModel,

    routes: [
      // -----------------------------------------------------------------------
      // Splash (carga inicial mientras se verifica la sesión)
      // -----------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashView(),
      ),

      // -----------------------------------------------------------------------
      // Autenticación
      // -----------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fadeTransition(
          state: state,
          child: const LoginView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const RegisterView(),
        ),
      ),

      // -----------------------------------------------------------------------
      // Shell principal con BottomNavigationBar
      // -----------------------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeView(),
          ),
          GoRoute(
            path: AppRoutes.products,
            builder: (context, state) => const HomeView(), // lista embebida en home
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (context, state) => _slideTransition(
                  state: state,
                  child: const ProductCreateView(),
                ),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => _slideTransition(
                  state: state,
                  child: ProductDetailView(
                    productId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.map,
            builder: (context, state) => const MapView(),
          ),
          GoRoute(
            path: AppRoutes.chatList,
            builder: (context, state) => const ChatListView(),
            routes: [
              GoRoute(
                path: ':roomId',
                pageBuilder: (context, state) => _slideTransition(
                  state: state,
                  child: ChatRoomView(
                    roomId: state.pathParameters['roomId']!,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],

    // Manejo de rutas no encontradas
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Ruta no encontrada: ${state.uri}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Transiciones de página
  // ---------------------------------------------------------------------------

  static CustomTransitionPage _fadeTransition({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static CustomTransitionPage _slideTransition({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Shell principal: BottomNavigationBar persistente entre rutas
// -----------------------------------------------------------------------------

/// Wrapper que envuelve las rutas principales con una barra de navegación inferior.
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const List<_NavItem> _navItems = [
    _NavItem(label: 'Inicio', icon: Icons.home_outlined, activeIcon: Icons.home, route: '/home'),
    _NavItem(label: 'Mapa', icon: Icons.map_outlined, activeIcon: Icons.map, route: '/map'),
    _NavItem(label: 'Chat', icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, route: '/chat'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) =>
            context.go(_navItems[index].route),
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].route)) return i;
    }
    return 0;
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

