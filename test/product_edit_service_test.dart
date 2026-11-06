import 'dart:convert';
import 'dart:async';

import 'package:proyecto_agro/features/products/data/models/product_unit.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/products/data/models/product_model.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/data/services/product_service.dart';
import 'package:proyecto_agro/features/products/data/services/product_storage_service.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';

class TestSupabase extends SupabaseService {
  TestSupabase(this.testClient);
  final SupabaseClient testClient;
  @override
  SupabaseClient get client => testClient;
  @override
  User? get currentUser => User.fromJson({
    'id': 'owner',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
  });
}

class TestStorage extends ProductStorageService {
  bool fail = false;
  int uploads = 0;
  Completer<void>? wait;
  @override
  Future<String> subirImagen(XFile imagen) async {
    uploads++;
    await wait?.future;
    if (fail) throw const ProductUploadException('Fallo de subida');
    return 'https://res.cloudinary.com/example/new.jpg';
  }
}

void main() {
  late List<http.Request> requests;
  late Map<String, dynamic> row;
  late ProductService service;
  late TestStorage storage;
  late SupabaseClient client;
  bool failPhoto = false;
  bool noPhoto = false;
  String role = 'producer';

  setUp(() {
    failPhoto = false;
    noPhoto = false;
    role = 'producer';
    requests = [];
    storage = TestStorage();
    row = {
      'id_producto': 'product-1',
      'id_productor': 'owner',
      'id_categoria': 1,
      'id_fase_actual': 0,
      'nombre_producto': 'Tomates',
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
        if (request.url.path.endsWith('/usuarios')) {
          return http.Response(
            jsonEncode({
              'id_usuario': 'owner',
              'tipos_usuario': {'nombre_tipo': role},
            }),
            200,
            request: request,
          );
        }
        if (request.url.path.endsWith('/fases_comercializacion')) {
          return http.Response(
            jsonEncode({'id_fase': 0}),
            200,
            request: request,
          );
        }
        // El refresco de catálogo usa listas, mientras el detalle devuelve un objeto.
        if (request.url.path.endsWith('/categorias_agricolas')) {
          return http.Response('[]', 200, request: request);
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/productos') &&
            !request.url.queryParameters.containsKey('id_producto')) {
          return http.Response(jsonEncode([row]), 200, request: request);
        }
        if (request.url.path.endsWith('/fotografias_producto')) {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(
                noPhoto
                    ? []
                    : [
                        {'id_fotografia': 'photo-1'},
                      ],
              ),
              200,
              request: request,
            );
          }
          if (failPhoto) {
            return http.Response(
              jsonEncode({'message': 'RLS denied'}),
              403,
              request: request,
            );
          }
          return http.Response(
            jsonEncode({'id_fotografia': 'photo-1'}),
            200,
            request: request,
          );
        }
        if (request.method == 'PATCH') {
          row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return http.Response(jsonEncode(row), 200, request: request);
      }),
    );
    service = ProductService(
      supabaseService: TestSupabase(client),
      storageService: storage,
    );
  });
  tearDown(() async => client.dispose());

  ProductModel edited() => ProductModel.fromJson(row).copyWith(
    nombreProducto: 'Tomates nuevos',
    precioUnitario: 0,
    idFaseActual: 1,
  );

  test(
    'la creación de preventas mantiene las inserciones de producto y foto',
    () async {
      final repository = ProductsRepository(
        supabaseService: TestSupabase(client),
        storageService: storage,
      );
      await repository.createPreorderProduct(
        name: 'Tomates',
        unit: ProductUnit.kg,
        categoryId: 1,
        quantity: 10,
        price: 2,
        image: XFile('test.jpg'),
      );
      final inserts = requests.where((r) => r.method == 'POST').toList();
      expect(inserts, hasLength(2));
      expect(jsonDecode(inserts.first.body)['id_fase_actual'], 0);
      expect(jsonDecode(inserts.last.body)['id_producto'], 'product-1');
      expect(
        requests.any((r) => r.method == 'PATCH' || r.method == 'DELETE'),
        isFalse,
      );
    },
  );

  test(
    'actualiza el mismo ID y propietario, conserva fase y fotografías',
    () async {
      final result = await service.updateProduct(edited());
      final write = requests.singleWhere((r) => r.method == 'PATCH');
      expect(write.url.queryParameters['id_producto'], 'eq.product-1');
      expect(write.url.queryParameters['id_productor'], 'eq.owner');
      expect(row['id_fase_actual'], 0);
      expect(result.precioUnitario, 0);
      expect(result.imagenUrl, 'https://example.com/old.jpg');
      expect(
        requests.any((r) => r.method == 'POST' || r.method == 'DELETE'),
        isFalse,
      );
      expect(
        requests.any((r) => r.url.path.endsWith('/fotografias_producto')),
        isFalse,
      );
    },
  );

  test('rechaza productos ajenos sin escribir', () async {
    row['id_productor'] = 'another-owner';
    await expectLater(
      service.updateProduct(edited()),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  // El servicio sigue comprobando el rol aunque el propietario coincida con el usuario.
  test('un comprador propietario no puede editar', () async {
    role = 'buyer';
    await expectLater(
      service.updateProduct(edited()),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('el repositorio rechaza propiedad ajena y unidad ausente', () async {
    final repo = ProductsRepository(supabaseService: TestSupabase(client));
    row['id_productor'] = 'other';
    await expectLater(
      repo.updateProduct(
        productId: 'product-1',
        name: 'Tomates',
        categoryId: 1,
        quantity: 5,
        price: 2,
        unit: ProductUnit.kg,
        isPublished: true,
      ),
      throwsA(isA<ProductEditException>()),
    );
    requests.clear();
    await expectLater(
      repo.updateProduct(
        productId: 'product-1',
        name: 'Tomates',
        categoryId: 1,
        quantity: 5,
        price: 2,
        isPublished: true,
      ),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests, isEmpty);
  });

  test(
    'quitar fecha envía NULL sin crear otro producto ni tocar sus fotografías',
    () async {
      row['fecha_estimada_cosecha'] = '2030-01-15';
      final repo = ProductsRepository(supabaseService: TestSupabase(client));
      await repo.updateProduct(
        productId: 'product-1',
        name: 'Tomates',
        categoryId: 1,
        quantity: 5,
        price: 2,
        unit: ProductUnit.lb,
        isPublished: true,
      );
      final write = requests.singleWhere((r) => r.method == 'PATCH');
      expect(jsonDecode(write.body)['fecha_estimada_cosecha'], isNull);
      expect(jsonDecode(write.body)['unidad_medida'], 'lb');
      expect(
        requests.any((r) => r.method == 'POST' || r.method == 'DELETE'),
        isFalse,
      );
    },
  );

  test(
    'el ViewModel bloquea un segundo guardado mientras se sube la fotografía',
    () async {
      storage.wait = Completer<void>();
      final vm = ProductsViewModel(
        productsRepository: ProductsRepository(
          supabaseService: TestSupabase(client),
          storageService: storage,
        ),
      );
      Future<bool> save() => vm.updateProduct(
        productId: 'product-1',
        name: 'Tomates',
        categoryId: 1,
        quantity: 5,
        price: 2,
        unit: ProductUnit.kg,
        isPublished: true,
        image: XFile('test.jpg'),
      );
      final pending = save();
      expect(vm.isSubmitting, isTrue);
      expect(await save(), isFalse);
      storage.wait!.complete();
      expect(await pending, isTrue);
      expect(storage.uploads, 1);
      expect(
        requests.where(
          (r) => r.method == 'PATCH' && r.url.path.endsWith('/productos'),
        ),
        hasLength(1),
      );
      vm.dispose();
    },
  );

  test('rechaza valores no finitos antes de guardar', () async {
    await expectLater(
      service.updateProduct(edited().copyWith(precioUnitario: double.nan)),
      throwsA(isA<ProductEditException>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  test(
    'un fallo de subida no modifica el producto ni las fotografías',
    () async {
      storage.fail = true;
      await expectLater(
        service.updateProduct(edited(), image: XFile('test.jpg')),
        throwsA(isA<ProductUploadException>()),
      );
      expect(requests.every((r) => r.method == 'GET'), isTrue);
    },
  );

  test('reemplaza la relación existente sin borrar fotografías', () async {
    final result = await service.updateProduct(
      edited(),
      image: XFile('test.jpg'),
    );
    final photoWrite = requests.singleWhere(
      (r) =>
          r.method == 'PATCH' && r.url.path.endsWith('/fotografias_producto'),
    );
    expect(photoWrite.url.queryParameters['id_fotografia'], 'eq.photo-1');
    expect(result.imagenUrl, 'https://res.cloudinary.com/example/new.jpg');
    expect(requests.any((r) => r.method == 'DELETE'), isFalse);
  });

  test('un producto sin fotografía recibe una sola relación nueva', () async {
    noPhoto = true;
    row['fotografias_producto'] = <Object>[];
    await service.updateProduct(edited(), image: XFile('test.jpg'));
    final inserts = requests.where((r) => r.method == 'POST').toList();
    expect(inserts, hasLength(1));
    expect(inserts.single.url.path, endsWith('/fotografias_producto'));
    expect(jsonDecode(inserts.single.body)['id_producto'], 'product-1');
  });

  test(
    'informa del guardado parcial si falla la relación y no borra la anterior',
    () async {
      failPhoto = true;
      await expectLater(
        service.updateProduct(edited(), image: XFile('test.jpg')),
        throwsA(isA<ProductEditException>()),
      );
      expect(row['nombre_producto'], 'Tomates nuevos');
      expect(requests.any((r) => r.method == 'DELETE'), isFalse);
    },
  );
}
