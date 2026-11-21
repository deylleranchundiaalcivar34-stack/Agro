import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_agro/core/constants/app_colors.dart';
import 'package:proyecto_agro/features/profile/presentation/widgets/profile_subpage.dart';

void main() {
  testWidgets('account subpage shares Agro header and back action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSubpage(
          title: 'Seguridad',
          child: Text('Contenido de prueba'),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isFalse);
    expect(appBar.backgroundColor, AppColors.primary);
    expect(appBar.foregroundColor, AppColors.surface);
    expect(appBar.leading, isA<IconButton>());
    expect((appBar.leading as IconButton).tooltip, 'Volver');
    expect(find.byKey(const Key('agro-subpage-logo')), findsNothing);
    expect(find.text('Seguridad'), findsOneWidget);
    expect(find.byTooltip('Volver'), findsOneWidget);
    expect(find.text('Contenido de prueba'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
