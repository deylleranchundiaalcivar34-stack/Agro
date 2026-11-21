import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/profile/presentation/widgets/account_navigation_drawer.dart';
import 'package:proyecto_agro/features/profile/presentation/widgets/profile_avatar_action.dart';

class _TestSupabaseService extends SupabaseService {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;
}

void main() {
  late GoRouter router;
  late AuthViewModel authViewModel;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  setUp(() {
    final supabase = _TestSupabaseService();
    authViewModel = AuthViewModel(
      supabaseService: supabase,
      profileRepository: ProfileRepository(supabaseService: supabase),
    );
    router = _testRouter(scaffoldKey);
  });

  tearDown(() {
    router.dispose();
    authViewModel.dispose();
  });

  Future<void> openDrawer(WidgetTester tester, UserRole role) async {
    authViewModel.setRole(role);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authViewModel,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    scaffoldKey.currentState!.openEndDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('comprador ve sus opciones de pedidos y favoritos', (
    tester,
  ) async {
    await openDrawer(tester, UserRole.buyer);

    expect(find.text('Usuario Agro+'), findsOneWidget);
    expect(find.text('Comprador'), findsOneWidget);
    expect(find.text('Mis pedidos'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Mis publicaciones'), findsNothing);
    expect(find.text('Mi zona publica'), findsNothing);
  });

  testWidgets('productor ve sus herramientas de publicacion', (tester) async {
    await openDrawer(tester, UserRole.producer);

    expect(find.text('Productor'), findsOneWidget);
    expect(find.text('Mis pedidos'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Mis publicaciones'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(find.text('Mi zona publica'), findsOneWidget);
  });

  testWidgets('administrador solo ve opciones comunes de cuenta', (
    tester,
  ) async {
    await openDrawer(tester, UserRole.admin);

    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Ver mis datos'), findsOneWidget);
    expect(find.text('Seguridad'), findsOneWidget);
    expect(find.text('Ayuda y soporte'), findsOneWidget);
    expect(find.text('Mis pedidos'), findsNothing);
    expect(find.text('Favoritos'), findsNothing);
    expect(find.text('Mis publicaciones'), findsNothing);
    expect(find.text('Mi zona publica'), findsNothing);
  });

  testWidgets('seleccionar Mis datos cierra el menu y abre su ruta', (
    tester,
  ) async {
    await openDrawer(tester, UserRole.buyer);

    await tester.tap(find.text('Ver mis datos'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla Mis datos'), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.text('Inicio de prueba'), findsOneWidget);
  });

  testWidgets('el encabezado abre Mis datos y vuelve al modulo de origen', (
    tester,
  ) async {
    await openDrawer(tester, UserRole.buyer);

    expect(find.text('Mi perfil'), findsNothing);
    await tester.tap(find.text('Usuario Agro+'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla Mis datos'), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.text('Inicio de prueba'), findsOneWidget);
  });

  testWidgets('Seguridad vuelve al modulo que abrio el menu', (tester) async {
    await openDrawer(tester, UserRole.buyer);

    await tester.tap(find.text('Seguridad'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla Seguridad'), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Inicio de prueba'), findsOneWidget);
  });

  testWidgets('el avatar abre el menu de cuenta del Scaffold', (tester) async {
    authViewModel.setRole(UserRole.buyer);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authViewModel,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: const [ProfileAvatarAction()]),
            endDrawer: const AccountNavigationDrawer(),
            body: const Text('Inicio'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(find.text('CUENTA'), findsOneWidget);
    expect(find.text('Mi perfil'), findsNothing);
    expect(find.text('Ver mis datos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _testRouter(GlobalKey<ScaffoldState> scaffoldKey) => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (_, _) => Scaffold(
        key: scaffoldKey,
        endDrawer: const AccountNavigationDrawer(),
        body: const Text('Inicio de prueba'),
      ),
    ),
    GoRoute(path: '/profile', redirect: (_, _) => '/profile/data'),
    for (final entry in const {
      '/profile/orders': 'Pantalla Mis pedidos',
      '/profile/favorites': 'Pantalla Favoritos',
      '/profile/data': 'Pantalla Mis datos',
      '/profile/notifications': 'Pantalla Notificaciones',
      '/profile/security': 'Pantalla Seguridad',
      '/profile/support': 'Pantalla Ayuda',
      '/profile/public-location': 'Pantalla Mi zona publica',
      '/products': 'Catalogo',
    }.entries)
      GoRoute(
        path: entry.key,
        builder: (_, _) => Scaffold(body: Text(entry.value)),
      ),
  ],
);
