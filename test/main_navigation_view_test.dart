import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/main/presentation/views/main_navigation_view.dart';

class _TestSupabaseService extends SupabaseService {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;
}

void main() {
  late GoRouter router;
  late AuthViewModel authViewModel;

  setUp(() {
    final supabase = _TestSupabaseService();
    authViewModel = AuthViewModel(
      supabaseService: supabase,
      profileRepository: ProfileRepository(supabaseService: supabase),
    );
    router = _testRouter();
  });

  tearDown(() {
    router.dispose();
    authViewModel.dispose();
  });

  Widget testApp({Widget Function(BuildContext, Widget?)? builder}) =>
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authViewModel,
        child: MaterialApp.router(routerConfig: router, builder: builder),
      );

  testWidgets('muestra la navegacion integrada en una pantalla principal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Comprar'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Perfil'), findsNothing);
  });

  testWidgets('silencia las animaciones de las ramas fuera de pantalla', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());

    expect(
      tester
          .widget<TickerMode>(find.byKey(const Key('branch-ticker-mode-0')))
          .enabled,
      isTrue,
    );

    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TickerMode>(find.byKey(const Key('branch-ticker-mode-2')))
          .enabled,
      isTrue,
    );
    final cachedProductsBranch = find.byKey(const Key('branch-ticker-mode-1'));
    if (cachedProductsBranch.evaluate().isNotEmpty) {
      expect(tester.widget<TickerMode>(cachedProductsBranch).enabled, isFalse);
    }
  });

  testWidgets('la navegacion se adapta a etiquetas ampliadas', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('oculta la navegacion principal en las rutas secundarias', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    for (final location in [
      '/products/test',
      '/products/test/edit',
      '/chat/room-1',
      '/profile/public-location',
    ]) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing, reason: location);
    }
  });

  testWidgets('oculta al bajar y reaparece al subir por el contenido', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('home-scroll')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('navigation-bar-slot'))).height,
      0,
    );

    await tester.drag(
      find.byKey(const Key('home-scroll')),
      const Offset(0, 240),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('navigation-bar-slot'))).height,
      greaterThan(0),
    );
  });

  testWidgets('mantiene navegables los cuatro destinos principales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.tap(find.text('Comprar'));
    await tester.pumpAndSettle();

    expect(_currentPath(router), '/products');
    expect(find.text('Catalogo principal'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('conserva el desplazamiento de cada rama al cambiar de modulo', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    final homeList = find.descendant(
      of: find.byKey(const Key('home-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(homeList, const Offset(0, -300));
    await tester.pumpAndSettle();
    final homeScrollPosition = tester
        .state<ScrollableState>(homeList)
        .position
        .pixels;

    await tester.dragFrom(const Offset(180, 320), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(60, 320), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(_currentPath(router), '/home');
    expect(
      tester.state<ScrollableState>(homeList).position.pixels,
      homeScrollPosition,
    );
  });

  testWidgets('un deslizamiento a la izquierda avanza un modulo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp());
    await tester.dragFrom(const Offset(180, 320), const Offset(-220, 0));
    await tester.pumpAndSettle();

    expect(_currentPath(router), '/products');
  });

  testWidgets('un deslizamiento a la derecha retrocede un modulo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router.go('/products');
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(60, 320), const Offset(220, 0));
    await tester.pumpAndSettle();

    expect(_currentPath(router), '/home');
  });

  testWidgets('el desplazamiento vertical o corto no cambia de modulo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp());
    await tester.dragFrom(const Offset(180, 320), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/home');

    await tester.dragFrom(const Offset(180, 320), const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/home');
  });

  testWidgets('un gesto diagonal no cambia de modulo', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp());
    await tester.dragFrom(const Offset(180, 320), const Offset(-80, -120));
    await tester.pumpAndSettle();

    expect(_currentPath(router), '/home');
  });

  testWidgets('no envuelve al deslizar mas alla de los extremos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp());
    await tester.dragFrom(const Offset(60, 320), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/home');

    router.go('/chat');
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(180, 320), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/chat');
  });

  testWidgets('no cambia de modulo desde una ruta secundaria', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router.go('/products/test');
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(180, 320), const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(_currentPath(router), '/products/test');
  });

  testWidgets('un gesto horizontal en el mapa no cambia de modulo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router.go('/map');
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(180, 320), const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(_currentPath(router), '/map');
  });

  testWidgets('la pagina sigue el dedo antes de soltar', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    final pageViewFinder = find.byKey(const Key('module-page-view'));
    expect(pageViewFinder, findsOneWidget);
    final controller = tester.widget<PageView>(pageViewFinder).controller!;
    final gesture = await tester.startGesture(tester.getCenter(pageViewFinder));
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.page, greaterThan(0));
    expect(controller.page, lessThan(0.5));
    expect(_currentPath(router), '/home');

    for (var step = 0; step < 6; step++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.page, greaterThan(0.45));
    expect(_currentPath(router), '/products');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });
}

String _currentPath(GoRouter router) =>
    router.routeInformationProvider.value.uri.path;

GoRouter _testRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/profile',
      builder: (_, _) => const Scaffold(body: Text('Perfil principal')),
      routes: [
        GoRoute(
          path: 'public-location',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('Zona publica de prueba')),
          ),
        ),
      ],
    ),
    StatefulShellRoute(
      builder: (context, state, shell) => MainNavigationView(
        navigationShell: shell,
        locationPath: state.uri.path,
      ),
      navigatorContainerBuilder: (context, shell, children) =>
          AnimatedBranchContainer(navigationShell: shell, children: children),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const _HomePage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/products',
              builder: (_, _) => const _CatalogPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, _) => const Scaffold(
                    body: Center(child: Text('Detalle de prueba')),
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, _) => const Scaffold(
                        body: Center(child: Text('Edicion de prueba')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (_, _) => const Scaffold(body: Text('Mapa principal')),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (_, _) => const Scaffold(body: Text('Chat principal')),
              routes: [
                GoRoute(
                  path: ':roomId',
                  builder: (_, _) => const Scaffold(
                    body: Center(child: Text('Sala de prueba')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView.builder(
      key: const Key('home-scroll'),
      itemCount: 40,
      itemExtent: 72,
      itemBuilder: (context, index) => index == 0
          ? Center(
              child: FilledButton(
                key: const Key('open-product-detail'),
                onPressed: () => context.push('/products/test'),
                child: const Text('Abrir detalle'),
              ),
            )
          : ListTile(title: Text('Elemento $index')),
    ),
  );
}

class _CatalogPage extends StatelessWidget {
  const _CatalogPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Catalogo principal')));
}
