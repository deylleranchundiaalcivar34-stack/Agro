import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/data/models/product_quantity.dart';
import 'package:proyecto_agro/features/products/data/models/product_unit.dart';
import 'package:proyecto_agro/features/products/data/models/product_model.dart';
import 'package:proyecto_agro/features/products/presentation/widgets/product_quantity_fields.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/data/services/product_service.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';
import 'package:proyecto_agro/features/products/presentation/views/product_edit_view.dart';
import 'package:proyecto_agro/features/products/presentation/widgets/product_card.dart';

class QuantitySupabase extends SupabaseService {
  QuantitySupabase(this.testClient);
  final SupabaseClient testClient;
  bool authenticated = true;
  @override
  SupabaseClient get client => testClient;
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();
  @override
  User? get currentUser => authenticated
      ? User.fromJson({
          'id': 'owner',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        })
      : null;
}

void main() {
  late SupabaseClient client;
  late QuantitySupabase supabase;
  late ProductService service;
  late ProductsViewModel vm;
  late List<http.Request> requests;
  late Map<String, dynamic> row;
  String role = 'producer';
  Completer<void>? patchWait;
  bool invalidResponse = false;
  bool failRefresh = false;

  setUp(() {
    requests = [];
    role = 'producer';
    patchWait = null;
    invalidResponse = false;
    failRefresh = false;
    row = {
      'id_producto': 'product-1',
      'id_productor': 'owner',
      'nombre_producto': 'Tomates',
      'id_categoria': 1,
      'id_fase_actual': 0,
      'unidad_medida': 'kg',
      'cantidad_disponible': 10.25,
      'precio_unitario': 2,
      'estado_publicacion': true,
      'fecha_estimada_cosecha': '2030-01-15',
      'fase': {'nombre_fase': 'Preventa'},
      'fotografias_producto': [
        {
          'id_fotografia': 'photo-1',
          'url_fotografia': 'https://example.com/old.jpg',
        },
      ],
    };
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        Object? body;
        if (request.url.path.endsWith('/usuarios')) {
          body = {
            'id_usuario': 'owner',
            'tipos_usuario': {'nombre_tipo': role},
          };
        } else if (request.url.path.endsWith('/categorias_agricolas')) {
          body = <Object>[];
        } else if (request.method == 'PATCH') {
          await patchWait?.future;
          row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          body = {...row, if (invalidResponse) 'cantidad_disponible': 999};
        } else {
          if (failRefresh &&
              !request.url.queryParameters.containsKey('id_producto')) {
            return http.Response(
              jsonEncode({'message': 'Offline'}),
              503,
              request: request,
            );
          }
          body = request.url.queryParameters.containsKey('id_producto')
              ? row
              : [row];
        }
        return http.Response(jsonEncode(body), 200, request: request);
      }),
    );
    supabase = QuantitySupabase(client);
    service = ProductService(supabaseService: supabase);
    vm = ProductsViewModel(
      productsRepository: ProductsRepository(supabaseService: supabase),
    );
  });
  tearDown(() async {
    vm.dispose();
    await client.dispose();
  });

  test('respeta los limites y precision de numeric(10,2), sin redondear', () {
    for (final text in ['0,01', '99999999.99', '25', '25.50', '.50']) {
      expect(ProductQuantity.validate(text), isNull, reason: text);
    }
    for (final text in [
      '',
      '0',
      '-1',
      'NaN',
      'Infinity',
      'abc',
      '1e2',
      '1.234',
      '100000000',
      '0.001',
    ]) {
      expect(ProductQuantity.validate(text), isNotNull, reason: text);
    }
    expect(ProductQuantity.parse(' 25,50 '), 25.5);
    expect(ProductQuantity.format(100), '100');
    expect(ProductQuantity.format(100.5), '100,5');
  });

  test('pesos admiten decimales; unidades requieren valores enteros', () {
    expect(ProductQuantity.validate('5,25', unit: ProductUnit.kg), isNull);
    expect(ProductQuantity.validate('5.25', unit: ProductUnit.lb), isNull);
    expect(
      ProductQuantity.validate('5.25', unit: ProductUnit.unidad),
      isNotNull,
    );
    expect(ProductQuantity.validate('5', unit: ProductUnit.unidad), isNull);
  });

  test(
    'presenta cantidades y precios con unidades y conserva NULL sin inventar',
    () {
      for (final entry in [
        ('kg', 12, '12 kg', '\$2.00/kg'),
        ('lb', 5, '5 libras', '\$2.00/libras'),
        ('libras', 5, '5 libras', '\$2.00/libras'),
        ('unidad', 20, '20 unidades', '\$2.00/unidades'),
        ('unidades', 20, '20 unidades', '\$2.00/unidades'),
        (null, 5, '5 (unidad sin registrar)', '\$2.00'),
        ('desconocida', 5, '5 (unidad sin registrar)', '\$2.00'),
      ]) {
        final product = AgriculturalProduct.fromMap({
          ...row,
          'unidad_medida': entry.$1,
          'cantidad_disponible': entry.$2,
        });
        expect(product.quantityWithUnit, entry.$3);
        expect(product.priceWithUnit, entry.$4);
        if (entry.$1 == null) expect(product.unit, isNull);
      }
    },
  );

  test('registros antiguos conservan unidad desconocida', () async {
    row.remove('unidad_medida');
    expect(AgriculturalProduct.fromMap(row).unit, isNull);
    expect(
      AgriculturalProduct.fromMap(row).quantityWithUnit,
      contains('unidad sin registrar'),
    );
    expect(ProductModel.fromJson(row).unidadMedida, isNull);
    await expectLater(
      service.updateQuantity('product-1', 5),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('guarda unidad elegida sin conversiones y refresca el modelo', () async {
    await vm.loadCatalogue();
    expect(
      await vm.updateQuantity('product-1', 5, unit: ProductUnit.lb),
      isTrue,
    );
    expect(row['unidad_medida'], 'lb');
    expect(row['cantidad_disponible'], 5);
    expect(vm.products.single.quantityWithUnit, '5 libras');
    expect(ProductModel.fromJson(row).toJson()['unidad_medida'], 'lb');
    expect(
      ProductModel.fromJson(row)
          .copyWith(nombreProducto: 'Otro nombre')
          .unidadMedida,
      ProductUnit.lb,
    );
  });

  test('servicio bloquea cantidades fraccionarias para unidades', () async {
    await expectLater(
      service.updateQuantity('product-1', 5.5, unit: ProductUnit.unidad),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  testWidgets('selector obligatorio y rechazo de letras en pantalla estrecha', (
    tester,
  ) async {
    final controller = TextEditingController(text: '5');
    addTearDown(controller.dispose);
    final key = GlobalKey<FormState>();
    ProductUnit? unit;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Form(
                key: key,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: 300,
                    child: ProductQuantityFields(
                      controller: controller,
                      unit: unit,
                      onUnitChanged: (value) => setState(() => unit = value),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Selecciona la unidad de medida.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '5kg');
    expect(controller.text, '5');
    await tester.tap(find.byType(DropdownButtonFormField<ProductUnit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unidades (unidades)').last);
    await tester.pumpAndSettle();
    expect(unit, ProductUnit.unidad);
    await tester.enterText(find.byType(TextFormField), '5.5');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('Para unidades ingresa un numero entero positivo.'),
      findsOneWidget,
    );
    rebuild(() => unit = ProductUnit.kg);
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(), isTrue);
    expect(tester.takeException(), isNull);
  });

  test('modifica solo cantidad en el mismo registro, sin fotos ni cambios de fase o estado', () async {
    final photos = jsonEncode(row['fotografias_producto']);
    await service.updateQuantity('product-1', 15.75);
    final write = requests.singleWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(write.body), {
      'unidad_medida': 'kg',
      'cantidad_disponible': 15.75,
    });
    expect(write.url.queryParameters['id_producto'], 'eq.product-1');
    expect(write.url.queryParameters['id_productor'], 'eq.owner');
    expect(row['id_fase_actual'], 0);
    expect(row['estado_publicacion'], isTrue);
    expect(jsonEncode(row['fotografias_producto']), photos);
    expect(
      requests.every((r) => r.method == 'GET' || r.method == 'PATCH'),
      isTrue,
    );
    expect(
      requests.any((r) => r.url.path.endsWith('/fotografias_producto')),
      isFalse,
    );
  });

  test('el servicio rechaza cero, negativos, no finitos, exceso de decimales y desbordamientos', () async {
    for (final number in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      1.234,
      100000000.0,
    ]) {
      await expectLater(
        service.updateQuantity('product-1', number),
        throwsA(isA<ProductEditException>()),
      );
    }
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('sin sesion no realiza peticiones', () async {
    supabase.authenticated = false;
    await expectLater(
      service.updateQuantity('product-1', 5),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests, isEmpty);
  });

  test('un comprador no puede actualizar aunque sea propietario', () async {
    role = 'buyer';
    await expectLater(
      service.updateQuantity('product-1', 5),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('rechaza al productor ajeno antes de escribir', () async {
    row['id_productor'] = 'someone-else';
    await expectLater(
      service.updateQuantity('product-1', 5),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('no anuncia exito si la respuesta contiene otra cantidad', () async {
    invalidResponse = true;
    expect(await vm.updateQuantity('product-1', 5), isFalse);
    expect(vm.errorMessage, contains('No se pudo confirmar'));
  });

  test(
    'el ViewModel bloquea duplicados y refresca la cantidad del catalogo',
    () async {
      await vm.loadCatalogue();
      patchWait = Completer<void>();
      final saving = vm.updateQuantity('product-1', 20);
      expect(vm.isSubmitting, isTrue);
      expect(await vm.updateQuantity('product-1', 30), isFalse);
      patchWait!.complete();
      expect(await saving, isTrue);
      expect(vm.products.single.availableQuantity, 20);
      expect(requests.where((r) => r.method == 'PATCH'), hasLength(1));
    },
  );

  test(
    'conserva la cantidad confirmada localmente si falla el refresco',
    () async {
      await vm.loadCatalogue();
      failRefresh = true;
      expect(await vm.updateQuantity('product-1', 18.25), isTrue);
      expect(vm.products.single.availableQuantity, 18.25);
      expect(vm.products.single.imagenUrl, 'https://example.com/old.jpg');
      expect(vm.catalogueStatus, ProductsStatus.error);
    },
  );

  testWidgets(
    'la tarjeta muestra preventa, cantidad y cosecha sin desbordar en movil',
    (tester) async {
      row['fotografias_producto'] = <Object>[];
      row['nombre_producto'] = 'Tomates de cosecha anunciada';
      row['cantidad_disponible'] = 99999999.99;
      row['unidad_medida'] = 'lb';
      for (final (width, scale) in [
        // Incluir escritorio y texto ampliado para comprobar ambos tamanos de portada.
        for (final width in [134.0, 160.0, 320.0, 640.0])
          for (final scale in [1.0, 1.6, 2.0]) (width, scale),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 800),
                    textScaler: TextScaler.linear(scale),
                  ),
                  // Medir y dibujar con el mismo contexto reproduce la altura real del grid.
                  child: Builder(
                    builder: (context) {
                      final product = AgriculturalProduct.fromMap(row);
                      final imageHeight = ProductCard.imageHeightFor(context);
                      return SizedBox(
                        width: width,
                        height: ProductCard.heightFor(
                          context,
                          product,
                          width: width,
                          imageHeight: imageHeight,
                        ),
                        child: ProductCard(
                          product: product,
                          imageHeight: imageHeight,
                          onTap: () {},
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Preventa'), findsOneWidget);
        expect(find.text('99999999,99 libras'), findsOneWidget);
        expect(find.text('Cosecha: 15/01/2030'), findsOneWidget);
        expect(
          tester.getSize(find.byType(ClipRRect)).height,
          width >= 600 ? 200 : 170,
        );
        // El borde inferior debe quedar junto al margen interior, sin una reserva vacia grande.
        final bottomGap =
            tester.getBottomLeft(find.byType(ProductCard)).dy -
            tester.getBottomLeft(find.text('Cosecha: 15/01/2030')).dy;
        expect(bottomGap, inInclusiveRange(10, 14));
        final nameBottom = tester
            .getBottomLeft(find.text(row['nombre_producto'] as String))
            .dy;
        final quantityTop = tester
            .getTopLeft(find.text('99999999,99 libras'))
            .dy;
        expect(quantityTop - nameBottom, closeTo(4, 0.1));
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'preventa depende de la fase, no de una fecha de cosecha pasada o futura',
    () {
      final future = AgriculturalProduct.fromMap(row);
      expect(future.isPresale, isTrue);
      expect(future.quantityLabel, 'Cantidad anunciada');
      row['fecha_estimada_cosecha'] = '2020-01-01';
      expect(AgriculturalProduct.fromMap(row).isPresale, isTrue);
      row['fase'] = {'nombre_fase': 'Comercializacion'};
      final normal = AgriculturalProduct.fromMap(row);
      expect(normal.isPresale, isFalse);
      expect(normal.quantityLabel, 'Cantidad disponible');
      expect(normal.phaseId, 0); // No se infiere la fase a partir del ID.
    },
  );

  testWidgets(
    'el formulario existente precarga, valida y guarda cantidad con coma decimal',
    (tester) async {
      final auth = AuthViewModel(
        supabaseService: supabase,
        profileRepository: ProfileRepository(supabaseService: supabase),
      );
      await auth.initialLoad;
      addTearDown(auth.dispose);
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Catalogo')),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, _) => const ProductEditView(
                  productId: 'product-1',
                  quantityOnly: true,
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            ChangeNotifierProvider<ProductsViewModel>.value(value: vm),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tomates'), findsOneWidget);
      expect(find.text('Fase: Preventa'), findsOneWidget);
      expect(find.text('Cosecha estimada: 15/01/2030'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '10.25',
      );
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.ensureVisible(find.text('Guardar cantidad'));
      await tester.tap(find.text('Guardar cantidad'));
      await tester.pumpAndSettle();
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      await tester.enterText(find.byType(TextFormField), '12,50');
      await tester.ensureVisible(find.text('Guardar cantidad'));
      await tester.tap(find.text('Guardar cantidad'));
      await tester.pumpAndSettle();
      expect(row['cantidad_disponible'], 12.5);
      expect(
        find.text('Cantidad disponible actualizada correctamente'),
        findsOneWidget,
      );
      expect(find.text('Catalogo'), findsOneWidget);
    },
  );
}
