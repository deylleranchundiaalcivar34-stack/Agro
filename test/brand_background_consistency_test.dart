import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/features/auth/presentation/views/welcome_view.dart';
import 'package:proyecto_agro/features/splash/splash_view.dart';

void main() {
  testWidgets('carga y bienvenida comparten el mismo fondo de marca', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeView()));
    final welcomeBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('welcome-background')),
    );
    final welcomeGradient =
        (welcomeBackground.decoration as BoxDecoration).gradient!
            as LinearGradient;

    await tester.pumpWidget(
      const MaterialApp(home: SplashView(autoNavigate: false)),
    );
    await tester.pump(const Duration(seconds: 1));
    final splashBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('splash-background')),
    );
    final splashGradient =
        (splashBackground.decoration as BoxDecoration).gradient!
            as LinearGradient;

    expect(splashGradient.colors, welcomeGradient.colors);
    expect(splashGradient.begin, welcomeGradient.begin);
    expect(splashGradient.end, welcomeGradient.end);
    expect(find.byKey(const ValueKey('brand-orb-top')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-orb-bottom')), findsOneWidget);
  });
}
