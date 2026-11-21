import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_agro/core/constants/app_colors.dart';
import 'package:proyecto_agro/core/widgets/agro_page_app_bar.dart';

void main() {
  testWidgets('authenticated detail pages share the green Agro header', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: AgroPageAppBar(title: 'Detalle del producto'),
          body: SizedBox.expand(),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isFalse);
    expect(appBar.backgroundColor, AppColors.primary);
    expect(appBar.foregroundColor, AppColors.surface);
    expect(appBar.titleTextStyle?.color, AppColors.surface);
    expect(appBar.systemOverlayStyle?.statusBarColor, AppColors.primary);
    expect(
      appBar.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.light,
    );
    expect(appBar.leading, isA<IconButton>());
    expect((appBar.leading as IconButton).tooltip, 'Volver');
    expect(appBar.titleSpacing, 0);
    expect(find.byKey(const Key('agro-page-logo')), findsNothing);
    expect(find.text('Detalle del producto'), findsOneWidget);
    expect(find.byTooltip('Volver'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared header preserves a conversation contact title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AgroPageAppBar(
            title: 'Conversacion',
            titleContent: const Row(
              children: [
                CircleAvatar(child: Text('P')),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nombre de productor bastante extenso',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Informacion del contacto',
                onPressed: null,
                icon: Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.leading, isA<IconButton>());
    expect((appBar.leading as IconButton).tooltip, 'Volver');
    expect(find.byKey(const Key('agro-page-logo')), findsNothing);
    expect(find.text('Nombre de productor bastante extenso'), findsOneWidget);
    expect(find.byTooltip('Informacion del contacto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main destinations keep the logo without a back button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: AgroPageAppBar(title: 'Inicio', showBackButton: false),
          body: SizedBox.expand(),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.leading, isNull);
    expect(appBar.titleSpacing, 16);
    expect(find.byKey(const Key('agro-page-logo')), findsOneWidget);
    expect(find.byTooltip('Volver'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
