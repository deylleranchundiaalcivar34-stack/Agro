import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/products/data/models/product_unit.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';

class CatalogueSupabase extends SupabaseService {
  CatalogueSupabase(this.testClient);
  final SupabaseClient testClient;
  @override
  SupabaseClient get client => testClient;
}

void main() {
  final row = <String, dynamic>{
    'id_producto': 'product-1',
    'id_productor': 'producer-1',
    'id_categoria': 1,
    'id_fase_actual': 1,
    'nombre_producto': 'Tomates',
    'cantidad_disponible': 5.5,
    'precio_unitario': 2,
    'estado_publicacion': true,
    'categoria': {'nombre_categoria': 'Hortalizas'},
    'fase': {'nombre_fase': 'Preventa'},
    'fotografias_producto': [
      {
        'id_fotografia': 'photo-1',
        'url_fotografia': 'https://example.com/photo.jpg',
      },
    ],
  };

  ProductsRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fake-key',
      httpClient: MockClient(handler),
    );
    addTearDown(client.dispose);
    return ProductsRepository(supabaseService: CatalogueSupabase(client));
  }

  http.Response missingUnit(http.Request r) => http.Response(
    jsonEncode({
      'code': '42703',
      'message': 'column productos.unidad_medida does not exist',
      'details': null,
      'hint': null,
    }),
    400,
    request: r,
  );

  test('catálogo sin columna unidad: reintenta conservando filtros, orden y relaciones', () async {
    final calls = <http.Request>[];
    final repo = repository((r) async {
      calls.add(r);
      if (r.url.path.endsWith('/categorias_agricolas')) {
        return http.Response(
          '[{"id_categoria":1,"nombre_categoria":"Hortalizas"}]',
          200,
          request: r,
        );
      }
      final select = r.url.queryParameters['select']!;
      expect(
        select,
        contains('categoria:categorias_agricolas(nombre_categoria)'),
      );
      expect(select, contains('fase:fases_comercializacion(nombre_fase)'));
      expect(
        select,
        contains('fotografias_producto(id_fotografia,url_fotografia)'),
      );
      expect(r.url.queryParameters['estado_publicacion'], 'eq.true');
      expect(r.url.queryParameters['order'], 'created_at.desc.nullslast');
      if (select.contains('unidad_medida')) return missingUnit(r);
      return http.Response(jsonEncode([row]), 200, request: r);
    });
    final vm = ProductsViewModel(productsRepository: repo);
    addTearDown(vm.dispose);
    await vm.loadCatalogue();
    expect(vm.catalogueStatus, ProductsStatus.ready);
    expect(vm.products.single.unit, isNull);
    expect(vm.products.single.quantityWithUnit, '5,5 (unidad sin registrar)');
    expect(vm.products.single.categoryName, 'Hortalizas');
    expect(vm.products.single.phaseName, 'Preventa');
    expect(vm.products.single.imagenUrl, 'https://example.com/photo.jpg');
    expect(vm.categories.single.name, 'Hortalizas');
    expect(calls.where((r) => r.url.path.endsWith('/productos')), hasLength(2));
  });

  test('esquema con unidad: conserva unidad y no reintenta', () async {
    var calls = 0;
    final repo = repository((r) async {
      calls++;
      expect(r.url.queryParameters['select'], contains('unidad_medida'));
      return http.Response(
        jsonEncode([
          {...row, 'unidad_medida': 'kg'},
          {...row, 'unidad_medida': 'lb'},
          {...row, 'unidad_medida': 'unidad'},
          {...row, 'unidad_medida': null},
        ]),
        200,
        request: r,
      );
    });
    final products = await repo.getPublishedProducts();
    expect(products.map((p) => p.unit), [
      ProductUnit.kg,
      ProductUnit.lb,
      ProductUnit.unidad,
      null,
    ]);
    expect(products.map((p) => p.quantityWithUnit), [
      '5,5 kg',
      '5,5 libras',
      '5,5 unidades',
      '5,5 (unidad sin registrar)',
    ]);
    expect(calls, 1);
  });

  test(
    'detalle usa la misma compatibilidad y mantiene el filtro del ID',
    () async {
      var calls = 0;
      final repo = repository((r) async {
        calls++;
        expect(r.url.queryParameters['id_producto'], 'eq.product-1');
        if (r.url.queryParameters['select']!.contains('unidad_medida')) {
          return missingUnit(r);
        }
        return http.Response(jsonEncode(row), 200, request: r);
      });
      final product = await repo.getProduct('product-1');
      expect(product?.id, 'product-1');
      expect(product?.unit, isNull);
      expect(calls, 2);
    },
  );

  for (final failure in [
    ('42703', 'column productos.created_at does not exist'),
    ('PGRST200', 'Could not find a relationship'),
    ('42501', 'permission denied for table productos'),
  ]) {
    test('no oculta otros errores ni aplica fallback: ${failure.$1}', () async {
      var calls = 0;
      final repo = repository((r) async {
        calls++;
        return http.Response(
          jsonEncode({'code': failure.$1, 'message': failure.$2}),
          400,
          request: r,
        );
      });
      await expectLater(
        repo.getPublishedProducts(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', failure.$1),
        ),
      );
      expect(calls, 1);
    });
  }

  test('diagnostica las dos consultas por separado sin llevar detalles a la interfaz', () async {
    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = previous);
    final repo = repository(
      (r) async => http.Response(
        jsonEncode({
          'code': '42501',
          'message': 'permission denied for table ${r.url.pathSegments.last}',
        }),
        403,
        request: r,
      ),
    );
    final vm = ProductsViewModel(productsRepository: repo);
    addTearDown(vm.dispose);
    await vm.loadCatalogue();
    expect(vm.catalogueStatus, ProductsStatus.error);
    final output = logs.join('\n');
    expect(output, contains('getPublishedProducts / productos y relaciones'));
    expect(output, contains('getCategories / categorias_agricolas'));
    expect(output, contains('42501'));
    expect(output, contains('products_viewmodel.dart'));
    expect(vm.errorMessage, isNot(contains('permission denied')));
    expect(vm.errorMessage, isNot(contains('42501')));
  });

  test('errores de mapeo se identifican por su operación', () async {
    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = previous);
    final repo = repository(
      (r) async => http.Response(
        jsonEncode(
          r.url.path.endsWith('/productos')
              ? [
                  {...row, 'cantidad_disponible': 'inválida'},
                ]
              : [],
        ),
        200,
        request: r,
      ),
    );
    final vm = ProductsViewModel(productsRepository: repo);
    addTearDown(vm.dispose);
    await vm.loadCatalogue();
    expect(vm.catalogueStatus, ProductsStatus.error);
    expect(
      logs.join('\n'),
      contains('getPublishedProducts / productos y relaciones'),
    );
    expect(logs.join('\n'), contains('AgriculturalProduct.fromMap'));
  });
}
