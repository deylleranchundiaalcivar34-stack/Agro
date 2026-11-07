import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:proyecto_agro/core/constants/app_routes.dart';
import 'package:proyecto_agro/core/router/app_router.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';

class _AuthState extends ChangeNotifier implements AuthViewModel {
  _AuthState({required this.authenticated, required this.pendingTotp});

  bool authenticated;
  bool pendingTotp;

  @override
  bool get isAuthenticated => authenticated;

  @override
  bool get mfaRequired => pendingTotp;

  @override
  UserRole get selectedRole => UserRole.buyer;

  @override
  String get displayName => 'Cuenta de prueba';

  @override
  String get userInitial => 'C';

  @override
  bool get isLoading => false;

  @override
  Future<void> signOut() async {
    authenticated = false;
    pendingTotp = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<GoRouter> _pumpRouter(
  WidgetTester tester,
  _AuthState auth,
  String initialLocation,
) async {
  final router = AppRouter(
    authViewModel: auth,
    initialLocation: initialLocation,
  ).router;
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('a pending TOTP session cannot open a deep chat link', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: true, pendingTotp: true);
    final router = await _pumpRouter(tester, auth, '/chat/room-id');
    addTearDown(router.dispose);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.mfaChallenge);
    expect(find.text('Verificacion en dos pasos'), findsOneWidget);
  });

  testWidgets('a pending TOTP session cannot skip challenge via login', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: true, pendingTotp: true);
    final router = await _pumpRouter(tester, auth, AppRoutes.login);
    addTearDown(router.dispose);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.mfaChallenge);
  });

  testWidgets('a session without TOTP can open a protected chat route', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: true, pendingTotp: false);
    final router = await _pumpRouter(tester, auth, '/chat/room-id');
    addTearDown(router.dispose);

    expect(router.routeInformationProvider.value.uri.path, '/chat/room-id');
  });

  testWidgets('a user can sign out from the TOTP challenge', (tester) async {
    final auth = _AuthState(authenticated: true, pendingTotp: true);
    final router = await _pumpRouter(tester, auth, AppRoutes.mfaChallenge);
    addTearDown(router.dispose);

    await tester.tap(find.text('Cerrar sesion'));
    await tester.pumpAndSettle();

    expect(auth.authenticated, isFalse);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
  });

  testWidgets('login footer fits a narrow phone after signing out', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _AuthState(authenticated: false, pendingTotp: false);
    final router = await _pumpRouter(tester, auth, AppRoutes.login);
    addTearDown(router.dispose);

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
