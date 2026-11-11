import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/data/models/product_unit.dart';
import 'package:proyecto_agro/features/products/data/services/product_service.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/products/presentation/widgets/product_phase_section.dart';
import 'package:proyecto_agro/core/constants/app_colors.dart';

import 'product_delete_test.dart' show DeleteTestSupabase;

void main() {
  late SupabaseClient client;
  late DeleteTestSupabase supabase;
  late ProductService service;
  late Map<String, dynamic> row;
  late List<http.Request> requests;
  var role = 'producer';
  var history = 0;
  String? errorCode;
  bool validHistory = true;
  Completer<void>? waiting;

  setUp(() {
    role = 'producer';
    history = 0;
    errorCode = null;
    validHistory = true;
    waiting = null;
    requests = [];
    row = {
      'id_producto': 'p1',
      'id_productor': 'owner',
      'id_categoria': 1,
      'id_fase_actual': 701,
      'nombre_producto': 'Tomates',
      'cantidad_disponible': 8,
      'precio_unitario': 2,
      'unidad_medida': 'kg',
      'estado_publicacion': false,
      'categoria': {'nombre_categoria': 'Hortalizas'},
      'fase': {'nombre_fase': 'Venta directa'},
      'fotografias_producto': [
        {
          'id_fotografia': 'photo-1',
          'url_fotografia': 'https://example.com/photo.jpg',
        },
      ],
    };
    client = SupabaseClient(
      'https://example.supabase.co',
      'fake',
      httpClient: MockClient((r) async {
        requests.add(r);
        Object body;
        var status = 200;
        if (r.url.path.endsWith('/usuarios')) {
          body = {
            'id_usuario': 'owner',
            'tipos_usuario': {'nombre_tipo': role},
          };
        } else if (r.url.path.endsWith('/fases_comercializacion')) {
          body = {
            'id_fase':
                r.url.queryParameters['nombre_fase'] == 'ilike.Venta directa'
                ? 701
                : 909,
          };
        } else if (r.url.path.endsWith('/agro_pasar_a_canales_alternativos')) {
          await waiting?.future;
          if (errorCode != null) {
            body = {'code': errorCode, 'message': 'server rejected'};
            status = 400;
          } else {
            final data = jsonDecode(r.body) as Map;
            expect(data['p_fase_esperada'], 701);
            expect(data['p_confirmado'], true);
            expect(data['p_unidad'], row['unidad_medida']);
            expect(data.keys.toSet(), {
              'p_id_producto',
              'p_cantidad',
              'p_precio',
              'p_unidad',
              'p_fase_esperada',
              'p_confirmado',
            });
            row = {
              ...row,
              'id_fase_actual': 909,
              'cantidad_disponible': data['p_cantidad'],
              'precio_unitario': data['p_precio'],
              'fase': {'nombre_fase': 'Canales alternativos'},
            };
            history++;
            body = {
              ...row,
              'fase_anterior': 701,
              'historial_registrado': validHistory,
            };
          }
        } else if (r.url.path.endsWith('/categorias_agricolas')) {
          body = [];
        } else {
          body = r.url.queryParameters.containsKey('id_producto')
              ? row
              : r.url.queryParameters.containsKey('id_productor') ||
                    row['estado_publicacion'] == true
              ? [row]
              : [];
        }
        return http.Response(jsonEncode(body), status, request: r);
      }),
    );
    supabase = DeleteTestSupabase(client);
    service = ProductService(supabaseService: supabase);
  });
  tearDown(() async => client.dispose());
  Future<int> transition({
    double quantity = 5,
    double price = 3,
    ProductUnit unit = ProductUnit.kg,
  }) => service.transitionToAlternativeChannels(
    'p1',
    quantity: quantity,
    price: price,
    unit: unit,
  );

  test(
    'resuelve IDs reales y confirma datos e historial en una sola RPC',
    () async {
      expect(await transition(), 909);
      expect(history, 1);
      expect(row['estado_publicacion'], false);
      expect(requests.where((r) => r.url.path.contains('/rpc/')), hasLength(1));
      expect(
        requests.any(
          (r) =>
              r.method == 'PATCH' ||
              r.url.path.endsWith('/historial_fases_producto'),
        ),
        false,
      );
      await expectLater(transition(), throwsA(isA<ProductPhaseException>()));
      expect(history, 1);
    },
  );
  for (final mode in ['foreign', 'buyer', 'phase', 'unit', 'signedOut']) {
    test('rechaza $mode sin escrituras', () async {
      if (mode == 'foreign') row['id_productor'] = 'other';
      if (mode == 'buyer') role = 'buyer';
      if (mode == 'phase') row['id_fase_actual'] = 909;
      if (mode == 'unit') row['unidad_medida'] = 'lb';
      if (mode == 'signedOut') supabase.authenticated = false;
      await expectLater(transition(), throwsA(isA<ProductPhaseException>()));
      expect(history, 0);
      expect(requests.any((r) => r.url.path.contains('/rpc/')), false);
    });
  }
  test('valida cantidad precio y compatibilidad de unidades', () async {
    for (final quantity in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      1.234,
      100000000.0,
    ]) {
      await expectLater(
        transition(quantity: quantity),
        throwsA(isA<ProductPhaseException>()),
      );
    }
    for (final price in [-1.0, double.infinity, double.nan]) {
      await expectLater(
        transition(price: price),
        throwsA(isA<ProductPhaseException>()),
      );
    }
    await expectLater(
      transition(quantity: 1.5, unit: ProductUnit.unidad),
      throwsA(isA<ProductPhaseException>()),
    );
    expect(requests, isEmpty);
  });
  for (final code in ['PGRST202', '42501', 'P0001', '23514']) {
    test('rechazo Supabase $code no confirma transición', () async {
      errorCode = code;
      await expectLater(transition(), throwsA(isA<ProductPhaseException>()));
      expect(history, 0);
      expect(row['id_fase_actual'], 701);
    });
  }
  test('respuesta sin confirmación de historial no anuncia éxito', () async {
    validHistory = false;
    await expectLater(transition(), throwsA(isA<ProductPhaseException>()));
  });
  test('rechaza cantidad superior a la disponible sin invocar RPC', () async {
    await expectLater(
      transition(quantity: 8.01),
      throwsA(isA<ProductPhaseException>()),
    );
    expect(requests.any((r) => r.url.path.contains('/rpc/')), false);
    expect(history, 0);
  });
  test(
    'admite exactamente toda la cantidad disponible y precio cero',
    () async {
      expect(await transition(quantity: 8, price: 0), 909);
      expect(row['cantidad_disponible'], 8);
      expect(row['precio_unitario'], 0);
    },
  );
  test('no permite saltar directamente desde Preventa', () async {
    row['id_fase_actual'] = 31;
    await expectLater(transition(), throwsA(isA<ProductPhaseException>()));
    expect(history, 0);
  });
  for (final unit in [ProductUnit.lb, ProductUnit.unidad]) {
    test('conserva ${unit.value} y sus cantidades válidas', () async {
      row['unidad_medida'] = unit.value;
      final quantity = unit == ProductUnit.lb ? 4.25 : 4.0;
      expect(await transition(quantity: quantity, unit: unit), 909);
      expect(row['unidad_medida'], unit.value);
      expect(row['cantidad_disponible'], quantity);
    });
  }
  test('informa específicamente que la nueva RPC no está instalada', () async {
    errorCode = 'PGRST202';
    await expectLater(
      transition(),
      throwsA(
        isA<ProductPhaseException>().having(
          (e) => e.message,
          'mensaje',
          contains('Canales alternativos aún no está habilitado'),
        ),
      ),
    );
  });
  test('sin confirmación de historial no cambia el catálogo local', () async {
    final vm = ProductsViewModel(
      productsRepository: ProductsRepository(supabaseService: supabase),
    );
    addTearDown(vm.dispose);
    await vm.loadMyPublications();
    final original = vm.myProducts.single;
    validHistory = false;
    expect(
      await vm.transitionToAlternativeChannels(original, quantity: 5, price: 3),
      isNull,
    );
    expect(vm.myProducts.single.phaseId, 701);
  });
  test('el catálogo visible cambia solo después de confirmar la RPC', () async {
    row['estado_publicacion'] = true;
    final vm = ProductsViewModel(
      productsRepository: ProductsRepository(supabaseService: supabase),
    );
    addTearDown(vm.dispose);
    await vm.loadCatalogue();
    final original = vm.products.single;
    waiting = Completer<void>();
    final operation = vm.transitionToAlternativeChannels(
      original,
      quantity: 5,
      price: 3,
    );
    expect(vm.products.single.phaseId, 701);
    expect(vm.products.single.availableQuantity, 8);
    waiting!.complete();
    final updated = await operation;
    expect(updated?.phaseId, 909);
    expect(vm.products.single.phaseName, 'Canales alternativos');
    expect(vm.products.single.availableQuantity, 5);
    expect(vm.products.single.isPublished, true);
    expect(vm.products.single.fotografias, original.fotografias);
  });

  // La misma sección debe proteger ambos avances por rol, propiedad y fase.
  testWidgets(
    'solo el propietario productor en Venta directa ve la nueva acción',
    (tester) async {
      final vm = ProductsViewModel(
        productsRepository: ProductsRepository(supabaseService: supabase),
      );
      final auth = AuthViewModel(
        supabaseService: supabase,
        profileRepository: ProfileRepository(supabaseService: supabase),
      );
      addTearDown(vm.dispose);
      addTearDown(auth.dispose);
      await auth.initialLoad;
      for (final mode in [
        'owner',
        'buyer',
        'foreign',
        'presale',
        'alternative',
      ]) {
        auth.setRole(mode == 'buyer' ? UserRole.buyer : UserRole.producer);
        final data = {
          ...row,
          if (mode == 'foreign') 'id_productor': 'other',
          'fase': {
            'nombre_fase': mode == 'presale'
                ? 'Preventa'
                : mode == 'alternative'
                ? 'Canales alternativos'
                : 'Venta directa',
          },
        };
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthViewModel>.value(value: auth),
              ChangeNotifierProvider<ProductsViewModel>.value(value: vm),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProductPhaseSection(
                  product: AgriculturalProduct.fromMap(data),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Pasar a Canales alternativos'),
          mode == 'owner' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Pasar a Venta directa'),
          mode == 'presale' ? findsOneWidget : findsNothing,
        );
      }
    },
  );

  testWidgets(
    'formulario móvil desplazable valida cantidad, confirma y bloquea duplicados',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final vm = ProductsViewModel(
        productsRepository: ProductsRepository(supabaseService: supabase),
      );
      final auth = AuthViewModel(
        supabaseService: supabase,
        profileRepository: ProfileRepository(supabaseService: supabase),
      );
      addTearDown(vm.dispose);
      addTearDown(auth.dispose);
      await auth.initialLoad;
      auth.setRole(UserRole.producer);
      AgriculturalProduct? changed;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            ChangeNotifierProvider<ProductsViewModel>.value(value: vm),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductPhaseSection(
                product: AgriculturalProduct.fromMap(row),
                onChanged: (p) => changed = p,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pasar a Canales alternativos'));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final title = tester.widget<Text>(
        find.text('Pasar a Canales alternativos').last,
      );
      expect(title.style?.color, AppColors.surface);
      expect(
        find.ancestor(
          of: find.text('Pasar a Canales alternativos').last,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.color == AppColors.primary,
          ),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('direct-sale-quantity')),
        '9',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Revisar cambio'));
      await tester.tap(find.text('Revisar cambio'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('no puede superar la disponible'),
        findsOneWidget,
      );
      expect(history, 0);
      await tester.ensureVisible(
        find.byKey(const ValueKey('direct-sale-quantity')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('direct-sale-quantity')),
        '5',
      );
      await tester.ensureVisible(find.text('Revisar cambio'));
      await tester.tap(find.text('Revisar cambio'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cambiar a Canales alternativos?'), findsOneWidget);
      expect(history, 0);
      waiting = Completer<void>();
      await tester.tap(find.text('Confirmar cambio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(changed, isNull);
      expect(find.text('Guardando...'), findsOneWidget);
      final review = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardando...'),
      );
      expect(review.onPressed, isNull);
      waiting!.complete();
      await tester.pumpAndSettle();
      expect(changed?.phaseName, 'Canales alternativos');
      expect(history, 1);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'ViewModel bloquea duplicados y actualiza listas sin cambiar visibilidad',
    () async {
      final vm = ProductsViewModel(
        productsRepository: ProductsRepository(supabaseService: supabase),
      );
      addTearDown(vm.dispose);
      await vm.loadMyPublications();
      final product = AgriculturalProduct.fromMap(row);
      waiting = Completer<void>();
      final operation = vm.transitionToAlternativeChannels(
        product,
        quantity: 5,
        price: 3,
      );
      expect(
        await vm.transitionToAlternativeChannels(
          product,
          quantity: 5,
          price: 3,
        ),
        isNull,
      );
      waiting!.complete();
      final updated = await operation;
      expect(updated?.phaseId, 909);
      expect(updated?.isPublished, false);
      expect(updated?.unit, ProductUnit.kg);
      expect(updated?.imagenUrl, 'https://example.com/photo.jpg');
      expect(updated?.fotografias, ['https://example.com/photo.jpg']);
      expect(vm.myProducts.single.phaseName, 'Canales alternativos');
      expect(history, 1);
    },
  );
}
