import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/data/services/product_service.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';
import 'package:proyecto_agro/features/products/presentation/widgets/product_delete_button.dart';

class DeleteTestSupabase extends SupabaseService {
  DeleteTestSupabase(this.testClient);
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
  late DeleteTestSupabase supabase;
  late ProductService service;
  late ProductsRepository repository;
  late List<http.Request> requests;
  late Map<String, dynamic> row;
  String role = 'producer';
  bool invalidResponse = false;
  bool denied = false;
  Completer<void>? patchWait;

  setUp(() {
    role = 'producer';
    invalidResponse = false;
    denied = false;
    patchWait = null;
    requests = [];
    row = {
      'id_producto': 'product-1',
      'id_productor': 'owner',
      'nombre_producto': 'Tomates',
      'id_categoria': 1,
      'id_fase_actual': 0,
      'unidad_medida': 'kg',
      'cantidad_disponible': 10,
      'precio_unitario': 2,
      'estado_publicacion': true,
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
          if (denied) {
            return http.Response(
              jsonEncode({'message': 'RLS denied'}),
              403,
              request: request,
            );
          }
          row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          body = {...row, if (invalidResponse) 'id_producto': 'wrong-product'};
        } else {
          body = request.url.queryParameters.containsKey('id_producto')
              ? row
              : [
                  if (request.url.queryParameters['id_productor'] ==
                          'eq.owner' ||
                      row['estado_publicacion'] == true)
                    row,
                ];
        }
        return http.Response(jsonEncode(body), 200, request: request);
      }),
    );
    supabase = DeleteTestSupabase(client);
    service = ProductService(supabaseService: supabase);
    repository = ProductsRepository(supabaseService: supabase);
  });
  tearDown(() async => client.dispose());

  test(
    'eliminacion logica filtra ID y propietario y conserva fase y fotos',
    () async {
      final photos = jsonEncode(row['fotografias_producto']);
      await service.deleteProduct('product-1');
      final write = requests.singleWhere((r) => r.method == 'PATCH');
      expect(write.url.queryParameters['id_producto'], 'eq.product-1');
      expect(write.url.queryParameters['id_productor'], 'eq.owner');
      expect(jsonDecode(write.body), {'estado_publicacion': false});
      expect(row['id_fase_actual'], 0);
      expect(jsonEncode(row['fotografias_producto']), photos);
      expect(
        requests.any(
          (r) =>
              r.method == 'DELETE' ||
              r.url.path.endsWith('/fotografias_producto'),
        ),
        isFalse,
      );
    },
  );

  test('sin sesion no consulta ni modifica registros', () async {
    supabase.authenticated = false;
    await expectLater(
      service.deleteProduct('product-1'),
      throwsA(isA<ProductDeleteException>()),
    );
    expect(requests, isEmpty);
  });

  test('rechaza propietario ajeno', () async {
    row['id_productor'] = 'someone-else';
    await expectLater(
      service.deleteProduct('product-1'),
      throwsA(isA<ProductDeleteException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('rechaza el perfil comprador aunque sea propietario', () async {
    role = 'buyer';
    await expectLater(
      service.deleteProduct('product-1'),
      throwsA(isA<ProductDeleteException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('no confirma exito si Supabase devuelve otro registro', () async {
    invalidResponse = true;
    await expectLater(
      service.deleteProduct('product-1'),
      throwsA(isA<ProductDeleteException>()),
    );
  });

  test('las consultas publicas filtran activos y ocultan detalles inactivos ajenos', () async {
    await repository.getPublishedProducts();
    expect(requests.last.url.queryParameters['estado_publicacion'], 'eq.true');
    row['estado_publicacion'] = false;
    row['id_productor'] = 'someone-else';
    expect(await repository.getProduct('product-1'), isNull);
  });

  test('el ViewModel retira el producto y refresca automaticamente', () async {
    final vm = ProductsViewModel(productsRepository: repository);
    addTearDown(vm.dispose);
    await vm.loadCatalogue();
    expect(vm.products, hasLength(1));
    expect(await vm.deleteProduct('product-1'), isTrue);
    expect(vm.products, isEmpty);
    expect(vm.isSubmitting, isFalse);
  });

  test('un rechazo RLS conserva la lista y muestra error', () async {
    denied = true;
    final vm = ProductsViewModel(productsRepository: repository);
    addTearDown(vm.dispose);
    await vm.loadCatalogue();
    expect(await vm.deleteProduct('product-1'), isFalse);
    expect(vm.products, hasLength(1));
    expect(
      vm.errorMessage,
      'No se pudo confirmar el cambio de visibilidad. Revisa tus publicaciones antes de reintentar.',
    );
  });

  // Ambas direcciones solo escriben estado_publicacion y conservan las fotografias.
  test(
    'volver a mostrar filtra propietario y conserva todos los datos',
    () async {
      row['estado_publicacion'] = false;
      final before = {...row};
      await service.setVisibility('product-1', true);
      final write = requests.singleWhere((r) => r.method == 'PATCH');
      expect(jsonDecode(write.body), {'estado_publicacion': true});
      expect(write.url.queryParameters['id_producto'], 'eq.product-1');
      expect(write.url.queryParameters['id_productor'], 'eq.owner');
      expect(row, {...before, 'estado_publicacion': true});
      expect(
        requests.any(
          (r) =>
              r.method == 'DELETE' ||
              r.url.path.endsWith('/fotografias_producto'),
        ),
        isFalse,
      );
    },
  );

  test(
    'Mis publicaciones consulta al propietario e incluye productos ocultos',
    () async {
      row['estado_publicacion'] = false;
      final products = await repository.getMyProducts();
      expect(products.single.visibilityLabel, 'Oculto');
      final read = requests.last;
      expect(read.url.queryParameters['id_productor'], 'eq.owner');
      expect(
        read.url.queryParameters.containsKey('estado_publicacion'),
        isFalse,
      );
    },
  );

  test(
    'ocultar y restaurar sincronizan catalogo y lista privada sin perder fotos',
    () async {
      final vm = ProductsViewModel(productsRepository: repository);
      addTearDown(vm.dispose);
      await vm.loadCatalogue();
      await vm.loadMyPublications();
      expect(vm.myProducts.single.visibilityLabel, 'Visible');
      expect(await vm.setVisibility('product-1', false), isTrue);
      expect(vm.products, isEmpty);
      expect(vm.myProducts.single.visibilityLabel, 'Oculto');
      expect(vm.myProducts.single.imagenUrl, 'https://example.com/old.jpg');
      expect(await vm.setVisibility('product-1', true), isTrue);
      expect(vm.products.single.isPublished, isTrue);
      expect(vm.myProducts.single.visibilityLabel, 'Visible');
      expect(requests.where((r) => r.method == 'PATCH'), hasLength(2));
    },
  );

  test('la lista privada no se expone despues de cerrar sesion', () async {
    final vm = ProductsViewModel(productsRepository: repository);
    addTearDown(vm.dispose);
    await vm.loadMyPublications();
    expect(vm.myProducts, hasLength(1));
    supabase.authenticated = false;
    expect(vm.myProducts, isEmpty);
  });

  test(
    'un comprador no consulta la lista privada ni restaura productos',
    () async {
      role = 'buyer';
      await expectLater(
        repository.getMyProducts(),
        throwsA(isA<ProductEditException>()),
      );
      await expectLater(
        service.setVisibility('product-1', true),
        throwsA(isA<ProductDeleteException>()),
      );
      expect(
        requests.every(
          (r) => r.method == 'GET' && !r.url.path.endsWith('/productos'),
        ),
        isTrue,
      );
    },
  );

  test('un productor ajeno no puede volver a mostrar', () async {
    row['id_productor'] = 'other';
    await expectLater(
      service.setVisibility('product-1', true),
      throwsA(isA<ProductDeleteException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });
  Future<void> showButton(
    WidgetTester tester, {
    VoidCallback? onDeleted,
  }) async {
    final auth = AuthViewModel(
      supabaseService: supabase,
      profileRepository: ProfileRepository(supabaseService: supabase),
    );
    await auth.initialLoad;
    final vm = ProductsViewModel(productsRepository: repository);
    addTearDown(auth.dispose);
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider<ProductsViewModel>.value(value: vm),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProductDeleteButton(
              product: AgriculturalProduct.fromMap(row),
              onDeleted: onDeleted ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('cancelar no modifica datos ni muestra exito', (tester) async {
    await showButton(tester);
    await tester.tap(find.text('Ocultar producto'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(requests.every((r) => r.method == 'GET'), isTrue);
    expect(find.text('Producto ocultado correctamente'), findsNothing);
  });

  testWidgets('compradores no ven el boton', (tester) async {
    role = 'buyer';
    await showButton(tester);
    expect(find.text('Ocultar producto'), findsNothing);
  });

  testWidgets('un productor no ve el boton en publicaciones ajenas', (
    tester,
  ) async {
    row['id_productor'] = 'someone-else';
    await showButton(tester);
    expect(find.text('Ocultar producto'), findsNothing);
  });

  testWidgets('confirmar guarda una vez, bloquea repeticion y muestra exito', (
    tester,
  ) async {
    bool navigated = false;
    patchWait = Completer<void>();
    await showButton(tester, onDeleted: () => navigated = true);
    await tester.tap(find.text('Ocultar producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ocultar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    patchWait!.complete();
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'PATCH'), hasLength(1));
    expect(navigated, isTrue);
    expect(find.text('Producto ocultado correctamente'), findsOneWidget);
  });
  testWidgets('un producto oculto ofrece Volver a mostrar sin duplicar datos', (
    tester,
  ) async {
    row['estado_publicacion'] = false;
    await showButton(tester);
    expect(find.text('Volver a mostrar'), findsOneWidget);
    await tester.tap(find.text('Volver a mostrar'));
    await tester.pumpAndSettle();
    expect(row['estado_publicacion'], isTrue);
    expect(requests.where((r) => r.method == 'PATCH'), hasLength(1));
    expect(
      requests.any((r) => r.method == 'POST' || r.method == 'DELETE'),
      isFalse,
    );
    expect(find.text('Producto visible nuevamente'), findsOneWidget);
  });
}
