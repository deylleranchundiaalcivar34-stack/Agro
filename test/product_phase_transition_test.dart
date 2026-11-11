import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/data/models/product_unit.dart';
import 'package:proyecto_agro/features/products/data/services/product_service.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';

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
      'id_fase_actual': 31,
      'nombre_producto': 'Tomates',
      'cantidad_disponible': 8,
      'precio_unitario': 2,
      'unidad_medida': 'kg',
      'estado_publicacion': false,
      'categoria': {'nombre_categoria': 'Hortalizas'},
      'fase': {'nombre_fase': 'Preventa'},
      'fotografias_producto': [],
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
            'id_fase': r.url.queryParameters['nombre_fase'] == 'ilike.Preventa'
                ? 31
                : 77,
          };
        } else if (r.url.path.endsWith('/agro_pasar_a_venta_directa')) {
          await waiting?.future;
          if (errorCode != null) {
            body = {'code': errorCode, 'message': 'server rejected'};
            status = 400;
          } else {
            final data = jsonDecode(r.body) as Map;
            expect(data['p_fase_esperada'], 31);
            expect(data['p_disponible'], true);
            row = {
              ...row,
              'id_fase_actual': 77,
              'cantidad_disponible': data['p_cantidad'],
              'precio_unitario': data['p_precio'],
              'fase': {'nombre_fase': 'Venta directa'},
            };
            history++;
            body = {
              ...row,
              'fase_anterior': 31,
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
  }) => service.transitionToDirectSale(
    'p1',
    quantity: quantity,
    price: price,
    unit: unit,
  );

  test(
    'resuelve IDs reales y confirma datos e historial en una sola RPC',
    () async {
      expect(await transition(), 77);
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
      if (mode == 'phase') row['id_fase_actual'] = 77;
      if (mode == 'unit') row['unidad_medida'] = 'lb';
      if (mode == 'signedOut') supabase.authenticated = false;
      await expectLater(transition(), throwsA(isA<ProductPhaseException>()));
      expect(history, 0);
      expect(requests.any((r) => r.url.path.contains('/rpc/')), false);
    });
  }
  test('valida cantidad precio y compatibilidad de unidades', () async {
    for (final quantity in [0.0, -1.0, double.nan, 1.234, 100000000.0]) {
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
      expect(row['id_fase_actual'], 31);
    });
  }
  test('respuesta sin confirmación de historial no anuncia éxito', () async {
    validHistory = false;
    await expectLater(transition(), throwsA(isA<ProductPhaseException>()));
  });
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
      final operation = vm.transitionToDirectSale(
        product,
        quantity: 5,
        price: 3,
      );
      expect(
        await vm.transitionToDirectSale(product, quantity: 5, price: 3),
        isNull,
      );
      waiting!.complete();
      final updated = await operation;
      expect(updated?.phaseId, 77);
      expect(updated?.isPublished, false);
      expect(vm.myProducts.single.phaseName, 'Venta directa');
      expect(history, 1);
    },
  );
}
