import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/profile_selection_view.dart';
import '../../features/auth/presentation/views/forgot_password_view.dart';
import '../../features/auth/presentation/views/reset_password_view.dart';
import '../../features/auth/presentation/views/mfa_setup_view.dart';
import '../../features/auth/presentation/views/mfa_challenge_view.dart';
import '../../features/auth/presentation/views/email_confirmed_view.dart';
import '../../features/home/presentation/views/home_view.dart';
import '../../features/products/presentation/views/products_catalog_view.dart';
import '../../features/products/presentation/views/product_detail_view.dart';
import '../../features/products/presentation/views/product_create_view.dart';
import '../../features/products/presentation/views/product_edit_view.dart';
import '../../features/map/presentation/views/map_view.dart';
import '../../features/chat/presentation/views/chat_list_view.dart';
import '../../features/chat/presentation/views/chat_room_view.dart';
import '../../features/profile/presentation/views/profile_view.dart';
import '../../features/splash/splash_view.dart';
import '../../features/main/presentation/views/main_navigation_view.dart';

class AppRouter {
  final AuthViewModel authViewModel;
  final String initialLocation;

  AppRouter({required this.authViewModel, required this.initialLocation});

  late final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,

    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authViewModel.isAuthenticated;
      final location = state.matchedLocation;

      final publicRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.profileSelection,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
        AppRoutes.mfaSetup,
        AppRoutes.mfaChallenge,
        AppRoutes.emailConfirmed,
        AppRoutes.splash,
      ];

      final isPublicRoute = publicRoutes.any(
        (route) => location.startsWith(route),
      );

      if (isAuthenticated &&
          authViewModel.mfaRequired &&
          location != AppRoutes.mfaChallenge) {
        return AppRoutes.mfaChallenge;
      }

      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.login;
      }

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
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashView(),
      ),

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
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) =>
            _slideTransition(state: state, child: const ForgotPasswordView()),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        pageBuilder: (context, state) =>
            _slideTransition(state: state, child: const ResetPasswordView()),
      ),
      GoRoute(
        path: AppRoutes.mfaSetup,
        pageBuilder: (context, state) =>
            _slideTransition(state: state, child: const MfaSetupView()),
      ),
      GoRoute(
        path: AppRoutes.mfaChallenge,
        pageBuilder: (context, state) =>
            _slideTransition(state: state, child: const MfaChallengeView()),
      ),
      GoRoute(
        path: AppRoutes.emailConfirmed,
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const EmailConfirmedView()),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationView(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeView(),
              ),
            ],
          ),

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
                    routes: [
                      GoRoute(
                        path: 'edit',
                        pageBuilder: (context, state) => _slideTransition(
                          state: state,
                          child: ProductEditView(
                            productId: state.pathParameters['id']!,
                            quantityOnly:
                                state.uri.queryParameters['quantity'] == '1',
                          ),
                        ),
                      ),
                    ],
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

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const MapView(),
              ),
            ],
          ),

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
      appBar: AppBar(title: const Text('Pagina no encontrada')),
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
