import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:proyecto_agro/core/constants/app_colors.dart';
import 'package:proyecto_agro/features/auth/presentation/views/welcome_view.dart';

void main() {
  late GoRouter router;

  setUp(() => router = _router());
  tearDown(() => router.dispose());

  testWidgets('muestra logo, frase y tres acciones', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Logo de Agro+'), findsOneWidget);
    expect(find.text('Del campo a tu mano'), findsOneWidget);
    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Acceso administrativo'), findsOneWidget);
  });

  testWidgets('usa fondo verde y no muestra una tarjeta de bienvenida', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('welcome-background')),
    );
    final decoration = background.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, [AppColors.primaryDark, AppColors.primary]);
    expect(find.byKey(const ValueKey('welcome-hero')), findsNothing);
  });

  testWidgets('muestra los tres accesos en una pantalla vertical de celular', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    for (final label in [
      'Iniciar sesion',
      'Crear cuenta',
      'Acceso administrativo',
    ]) {
      expect(tester.getRect(find.text(label)).bottom, lessThan(800));
    }
    expect(
      tester.getRect(find.text('Iniciar sesion')).top,
      tester.getRect(find.text('Crear cuenta')).top,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite recorrer las frases deslizando horizontalmente', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(
      find.text('Publica tus cosechas y conecta con compradores.'),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('welcome-phrases')),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Explora productos de productores agricolas.'),
      findsOneWidget,
    );
  });

  testWidgets('avanza las frases automaticamente y vuelve a la primera', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text('Explora productos de productores agricolas.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text('Descubre zonas publicas y conversa por chat.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text('Publica tus cosechas y conecta con compradores.'),
      findsOneWidget,
    );
  });

  testWidgets('deslizar reinicia el tiempo de avance automatico', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('welcome-phrases')),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(
      find.text('Explora productos de productores agricolas.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.text('Descubre zonas publicas y conversa por chat.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'pausa el avance automatico mientras la app esta en segundo plano',
    (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 8));
      expect(
        find.text('Publica tus cosechas y conecta con compradores.'),
        findsOneWidget,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Explora productos de productores agricolas.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('no avanza mientras el usuario mantiene el dedo en la frase', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('welcome-phrases'))),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(
      find.text('Publica tus cosechas y conecta con compradores.'),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text('Explora productos de productores agricolas.'),
      findsOneWidget,
    );
  });

  testWidgets('respeta reducir movimiento y deja las frases manuales', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 12));

    expect(
      find.text('Publica tus cosechas y conecta con compradores.'),
      findsOneWidget,
    );
    expect(
      find.text('Explora productos de productores agricolas.'),
      findsNothing,
    );
  });

  testWidgets('no desborda en movil angosto con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Acceso administrativo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iniciar sesion abre login y Atras vuelve a la bienvenida', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesion'));
    await tester.pumpAndSettle();

    expect(find.text('Destino login'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Del campo a tu mano'), findsOneWidget);
  });

  testWidgets('crear cuenta abre el registro existente', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Destino registro'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Del campo a tu mano'), findsOneWidget);
  });

  testWidgets('acceso administrativo conserva el modo admin', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acceso administrativo'));
    await tester.pumpAndSettle();

    expect(find.text('Destino admin'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Del campo a tu mano'), findsOneWidget);
  });
}

GoRouter _router() => GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeView()),
    GoRoute(
      path: '/home',
      builder: (context, state) => const Scaffold(body: Text('Destino home')),
    ),
    GoRoute(
      path: '/auth/register',
      builder: (context, state) =>
          const Scaffold(body: Text('Destino registro')),
    ),
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => Scaffold(
        body: Text(
          state.uri.queryParameters['mode'] == 'admin'
              ? 'Destino admin'
              : 'Destino login',
        ),
      ),
    ),
  ],
);
