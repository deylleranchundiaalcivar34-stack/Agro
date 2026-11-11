import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';
import 'package:proyecto_agro/features/products/presentation/views/products_catalog_view.dart';
import 'package:proyecto_agro/features/products/presentation/widgets/product_card.dart';

import 'package:proyecto_agro/features/products/presentation/views/product_create_view.dart';
import 'package:proyecto_agro/features/products/presentation/views/product_edit_view.dart';
import 'package:proyecto_agro/features/products/presentation/views/product_detail_view.dart';

import 'product_delete_test.dart' show DeleteTestSupabase;

void main() {
  late SupabaseClient client;
  late AuthViewModel auth;
  late ProductsViewModel vm;
  var calls = 0;
  var emptyRows = false;
  var transitions = 0;
  var phaseEnabled = true;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    emptyRows = false;
    calls = 0;
    transitions = 0;
    phaseEnabled = true;
    final rows = [
      for (var i = 0; i < 2; i++)
        {
          'id_producto': 'p$i',
          'id_productor': 'owner',
          'id_categoria': i + 1,
          'id_fase_actual': 1,
          'nombre_producto': i == 0 ? 'Tomates' : 'Papas',
          'cantidad_disponible': 5,
          'unidad_medida': 'kg',
          'precio_unitario': 2,
          'estado_publicacion': i == 0,
          'categoria': {
            'nombre_categoria': i == 0 ? 'Hortalizas' : 'Tubérculos',
          },
          'fase': {'nombre_fase': 'Preventa'},
          'fotografias_producto': [],
        },
    ];
    client = SupabaseClient(
      'https://example.supabase.co',
      'fake',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        calls++;
        Object body;
        if (r.url.path.endsWith('/usuarios')) {
          body = {
            'id_usuario': 'owner',
            'tipos_usuario': {'nombre_tipo': 'producer'},
          };
        } else if (r.url.path.endsWith('/fases_comercializacion')) {
          body = {
            'id_fase': r.url.queryParameters['nombre_fase'] == 'ilike.Preventa'
                ? 1
                : 87,
          };
        } else if (r.url.path.endsWith('/agro_pasar_a_venta_directa')) {
          transitions++;
          if (!phaseEnabled) {
            return http.Response(
              jsonEncode({'code': 'PGRST202', 'message': 'missing function'}),
              404,
              request: r,
            );
          }
          final values = jsonDecode(r.body) as Map;
          rows.first.addAll({
            'id_fase_actual': 87,
            'fase': {'nombre_fase': 'Venta directa'},
            'cantidad_disponible': values['p_cantidad'],
            'precio_unitario': values['p_precio'],
          });
          body = {
            ...rows.first,
            'fase_anterior': 1,
            'historial_registrado': true,
          };
        } else if (r.url.path.endsWith('/categorias_agricolas')) {
          body = [
            {'id_categoria': 1, 'nombre_categoria': 'Hortalizas'},
            {'id_categoria': 2, 'nombre_categoria': 'Tubérculos'},
          ];
        } else {
          body = r.url.queryParameters.containsKey('id_producto')
              ? rows.first
              : emptyRows
              ? []
              : rows
                    .where(
                      (row) =>
                          r.url.queryParameters.containsKey('id_productor') ||
                          row['estado_publicacion'] == true,
                    )
                    .toList();
        }
        return http.Response(jsonEncode(body), 200, request: r);
      }),
    );
    final supabase = DeleteTestSupabase(client);
    auth = AuthViewModel(
      supabaseService: supabase,
      profileRepository: ProfileRepository(supabaseService: supabase),
    );
    await auth.initialLoad;
    vm = ProductsViewModel(
      productsRepository: ProductsRepository(supabaseService: supabase),
    );
    addTearDown(() async {
      auth.dispose();
      vm.dispose();
      await client.dispose();
    });
  });

  Future<int Function()> open(
    WidgetTester tester, {
    bool empty = false,
    double width = 390,
    double height = 1400,
    double scale = 1,
    Widget? page,
  }) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    emptyRows = empty;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider<ProductsViewModel>.value(value: vm),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: page ?? const ProductsCatalogView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (page == null) {
      await tester.tap(find.widgetWithText(ChoiceChip, 'Mis publicaciones'));
    }
    await tester.pumpAndSettle();
    return () => calls;
  }

  List<String> names(WidgetTester tester) => tester
      .widgetList<ProductCard>(find.byType(ProductCard))
      .map((c) => c.product.name)
      .toList();

  testWidgets(
    'resumen completo y filtros combinados sin consultar otra vez Supabase',
    (tester) async {
      final calls = await open(tester);
      final before = calls();
      expect(find.text('Total de publicaciones: 2'), findsOneWidget);
      expect(find.text('Publicaciones visibles: 1'), findsOneWidget);
      expect(find.text('Publicaciones ocultas: 1'), findsOneWidget);
      expect(names(tester), containsAll(['Tomates', 'Papas']));
      expect(find.text('Preventa'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('visibility-Visibles')));
      await tester.pumpAndSettle();
      expect(names(tester), ['Tomates']);
      await tester.tap(find.byKey(const ValueKey('visibility-Ocultos')));
      await tester.pumpAndSettle();
      expect(names(tester), ['Papas']);
      await tester.enterText(find.byType(TextField), 'tubérculos');
      await tester.pumpAndSettle();
      expect(names(tester), ['Papas']);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hortalizas'));
      await tester.pumpAndSettle();
      expect(find.text('No encontramos resultados'), findsOneWidget);
      expect(find.text('Total de publicaciones: 2'), findsOneWidget);
      expect(find.text('Crear primera publicación'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.byKey(const ValueKey('visibility-Todos')));
      await tester.pumpAndSettle();
      expect(names(tester), ['Tomates']);
      expect(calls(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lista vacía ofrece crear la primera publicación', (
    tester,
  ) async {
    await open(tester, empty: true);
    expect(find.text('Total de publicaciones: 0'), findsOneWidget);
    expect(find.text('Aún no tienes publicaciones'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Crear primera publicación'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumen y tarjetas se adaptan a escritorio y texto ampliado', (
    tester,
  ) async {
    await open(tester, width: 1100, scale: 1.8);
    expect(find.text('Total de publicaciones: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final entry in <String, Widget>{
    'crear': const ProductCreateView(),
    'editar': const ProductEditView(productId: 'p0'),
    'cantidad': const ProductEditView(productId: 'p0', quantityOnly: true),
    'detalle': const ProductDetailView(productId: 'p0'),
  }.entries) {
    testWidgets('${entry.key} en móvil pequeño con texto ampliado', (
      tester,
    ) async {
      await open(
        tester,
        width: 320,
        height: 800,
        scale: 1.5,
        page: entry.value,
      );
      expect(tester.takeException(), isNull);
      if (entry.key == 'detalle' || entry.key == 'cantidad') {
        expect(find.text('Tomates'), findsWidgets);
      } else {
        expect(find.byType(TextFormField), findsWidgets);
      }
      final scroll = find.byType(Scrollable).first;
      await tester.drag(scroll, const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (entry.key == 'editar' || entry.key == 'cantidad') {
        final label = entry.key == 'editar'
            ? 'Guardar cambios'
            : 'Guardar cantidad';
        if (entry.key == 'cantidad') {
          await tester.scrollUntilVisible(
            find.text(label),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
        }
        expect(tester.getRect(find.text(label)).bottom, lessThanOrEqualTo(520));
      }
    });
  }
  for (final enabled in [true, false]) {
    testWidgets(
      'transición confirma servidor y refresca detalle, habilitada=$enabled',
      (tester) async {
        phaseEnabled = enabled;
        await open(
          tester,
          width: 390,
          page: const ProductDetailView(productId: 'p0'),
        );
        final button = find.widgetWithText(
          FilledButton,
          'Pasar a Venta directa',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        // El formulario exige disponibilidad y conserva la unidad sin selector editable.
        expect(
          find.byKey(const ValueKey('direct-sale-quantity')),
          findsOneWidget,
        );
        final checkbox = find.byType(CheckboxListTile);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        final review = find.widgetWithText(FilledButton, 'Revisar cambio');
        await tester.ensureVisible(review);
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(find.text('¿Cambiar a Venta directa?'), findsOneWidget);
        // Cancelar la confirmación final no envía ninguna escritura.
        await tester.tap(find.widgetWithText(TextButton, 'Cancelar').last);
        await tester.pumpAndSettle();
        expect(transitions, 0);
        await tester.tap(review);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar cambio'));
        await tester.pumpAndSettle();
        expect(transitions, 1);
        if (enabled) {
          expect(
            find.text('Producto actualizado a Venta directa'),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(FilledButton, 'Pasar a Venta directa'),
            findsNothing,
          );
          expect(find.text('Cantidad disponible'), findsOneWidget);
        } else {
          expect(
            find.textContaining('La transición aún no está habilitada'),
            findsOneWidget,
          );
          expect(
            find.text('Producto actualizado a Venta directa'),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
