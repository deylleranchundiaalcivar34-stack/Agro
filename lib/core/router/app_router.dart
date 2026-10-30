import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/profile_selection_view.dart';
import '../../features/home/presentation/views/home_view.dart';
import '../../features/products/presentation/views/products_catalog_view.dart';
import '../../features/products/presentation/views/product_detail_view.dart';
import '../../features/products/presentation/views/product_create_view.dart';
import '../../features/map/presentation/views/map_view.dart';
import '../../features/chat/presentation/views/chat_list_view.dart';
import '../../features/chat/presentation/views/chat_room_view.dart';
import '../../features/profile/presentation/views/profile_view.dart';
import '../../features/splash/splash_view.dart';
import '../../features/main/presentation/views/main_navigation_view.dart';

/// Router principal de la aplicación usando GoRouter.
///
/// Maneja:
/// - Redirección automática según estado de sesión (Auth Guard).
/// - [StatefulShellRoute.indexedStack] para persistir el estado de cada vista sin reconstruirlas.
/// - Barra de navegación flotante centrada (BorderRadius.circular(100)).
/// - Transiciones suaves de pantalla.
class AppRouter {
  final AuthViewModel authViewModel;

  AppRouter({required this.authViewModel});

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,

    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authViewModel.isAuthenticated;
      final location = state.matchedLocation;

      final publicRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.profileSelection,
        AppRoutes.splash,
      ];

      final isPublicRoute = publicRoutes.any(
        (route) => location.startsWith(route),
      );

      // Si no está autenticado y no es pública -> ir a Login
      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.login;
      }

      // Si está autenticado e intenta ir a Login o Register -> ir a Home
      if (isAuthenticated &&
          ((location == AppRoutes.login &&
                  state.uri.queryParameters['mode'] != 'admin') ||
              location == AppRoutes.register)) {
        return AppRoutes.home;
      }

      return null;
    },

    refreshListenable: authViewModel,

    routes: [
      // -----------------------------------------------------------------------
      // Splash (carga inicial con animación armónica del logo)
      // -----------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashView(),
      ),

      // -----------------------------------------------------------------------
      // Autenticación (Split-screen con cabecera curva ondulada)
      // -----------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fadeTransition(
          state: state,
          child: LoginView(
            adminOnly: state.uri.queryParameters['mode'] == 'admin',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            _slideTransition(state: state, child: const RegisterView()),
      ),
      GoRoute(
        path: AppRoutes.profileSelection,
        pageBuilder: (context, state) =>
            _slideTransition(state: state, child: const ProfileSelectionView()),
      ),

      // -----------------------------------------------------------------------
      // Shell persistente con IndexedStack (No reconstruye vistas al navegar)
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationView(navigationShell: navigationShell);
        },
        branches: [
          // Rama 0: Inicio
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeView(),
              ),
            ],
          ),

          // Rama 1: Catálogo de Productos
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.products,
                builder: (context, state) => const ProductsCatalogView(),
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
            ],
          ),

          // Rama 2: Mapa de Productores
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const MapView(),
              ),
            ],
          ),

          // Rama 3: Chat y Mensajería
          StatefulShellBranch(
            routes: [
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

          // Rama 4: Perfil de Usuario
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileView(),
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text('Ruta no encontrada: ${state.uri}'),
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
          position:
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }
}
