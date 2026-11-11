import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_category.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';

import 'package:proyecto_agro/core/constants/app_routes.dart';
import 'package:proyecto_agro/core/router/app_router.dart';
import 'package:proyecto_agro/app.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/auth/presentation/views/login_view.dart';

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
  User? get currentUser => null;

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

class _ProductsState extends ChangeNotifier implements ProductsViewModel {
  @override
  List<AgriculturalProduct> get products => const [];

  @override
  List<AgriculturalCategory> get categories => const [];

  @override
  ProductsStatus get catalogueStatus => ProductsStatus.idle;

  @override
  Future<void> loadCatalogue({bool force = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<GoRouter> _pumpRouter(
  WidgetTester tester,
  _AuthState auth,
  String initialLocation,
) async {
  final products = _ProductsState();
  final router = AppRouter(
    authViewModel: auth,
    initialLocation: initialLocation,
  ).router;
  addTearDown(products.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
        ChangeNotifierProvider<ProductsViewModel>.value(value: products),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('AgroApp siempre inicia por la bienvenida', () {
    expect(AgroApp.entryLocation, AppRoutes.welcome);
  });

  testWidgets('las rutas usan duracion cero si el sistema reduce movimiento', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: false, pendingTotp: false);
    final router = AppRouter(
      authViewModel: auth,
      initialLocation: AppRoutes.welcome,
    ).router;
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go(AppRoutes.login);
    await tester.pump();

    final route = ModalRoute.of(tester.element(find.byType(LoginView)));
    expect(route?.transitionDuration, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la bienvenida es publica sin sesion y rutas protegidas abren login',
    (tester) async {
      final auth = _AuthState(authenticated: false, pendingTotp: false);
      final router = await _pumpRouter(tester, auth, AppRoutes.welcome);
      addTearDown(router.dispose);

      expect(router.routeInformationProvider.value.uri.path, AppRoutes.welcome);
      expect(find.text('Del campo a tu mano'), findsOneWidget);

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    },
  );

  testWidgets('una sesion activa abre Inicio en vez de la bienvenida', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: true, pendingTotp: false);
    final router = await _pumpRouter(tester, auth, AppRoutes.welcome);
    addTearDown(router.dispose);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
  });

  testWidgets(
    'una sesion con TOTP pendiente abre el desafio desde bienvenida',
    (tester) async {
      final auth = _AuthState(authenticated: true, pendingTotp: true);
      final router = await _pumpRouter(tester, auth, AppRoutes.welcome);
      addTearDown(router.dispose);

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.mfaChallenge,
      );
    },
  );

  testWidgets('a pending TOTP session cannot open a deep chat link', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: true, pendingTotp: true);
    final router = await _pumpRouter(tester, auth, '/chat/room-id');
    addTearDown(router.dispose);

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.mfaChallenge,
    );
    expect(find.text('Verificacion en dos pasos'), findsOneWidget);
  });

  testWidgets('a pending TOTP session cannot skip challenge via login', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: true, pendingTotp: true);
    final router = await _pumpRouter(tester, auth, AppRoutes.login);
    addTearDown(router.dispose);

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.mfaChallenge,
    );
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
