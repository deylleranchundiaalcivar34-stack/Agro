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
import 'package:proyecto_agro/features/chat/presentation/views/chat_list_view.dart';

class _AuthState extends ChangeNotifier implements AuthViewModel {
  _AuthState({required this.authenticated});

  bool authenticated;

  @override
  bool get isAuthenticated => authenticated;

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
    final auth = _AuthState(authenticated: false);
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
      final auth = _AuthState(authenticated: false);
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
    final auth = _AuthState(authenticated: true);
    final router = await _pumpRouter(tester, auth, AppRoutes.welcome);
    addTearDown(router.dispose);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
  });

  testWidgets('una sesion activa puede abrir una ruta protegida del chat', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: true);
    final router = await _pumpRouter(tester, auth, '/chat/room-id');
    addTearDown(router.dispose);

    expect(router.routeInformationProvider.value.uri.path, '/chat/room-id');
  });

  testWidgets('las pantallas del menu de cuenta cambian en 150 ms', (
    tester,
  ) async {
    final auth = _AuthState(authenticated: true);
    final router = await _pumpRouter(tester, auth, AppRoutes.profileSupport);
    addTearDown(router.dispose);

    final route = ModalRoute.of(
      tester.element(find.text('Preguntas frecuentes')),
    );
    expect(route?.transitionDuration, const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'solicitudes de chat tiene transicion breve y encabezado propio',
    (tester) async {
      final auth = _AuthState(authenticated: true);
      final router = await _pumpRouter(tester, auth, AppRoutes.contactRequests);
      addTearDown(router.dispose);

      final chatPages = find.byType(ChatListView);
      final route = ModalRoute.of(tester.element(chatPages.last));
      expect(route?.transitionDuration, const Duration(milliseconds: 180));
      expect(find.text('Solicitudes de contacto'), findsOneWidget);
      expect(find.byTooltip('Volver'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('login footer fits a narrow phone after signing out', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _AuthState(authenticated: false);
    final router = await _pumpRouter(tester, auth, AppRoutes.login);
    addTearDown(router.dispose);

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
