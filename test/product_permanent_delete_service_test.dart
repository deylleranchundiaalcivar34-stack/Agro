import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/features/products/data/services/product_service.dart';

import 'product_delete_test.dart' show DeleteTestSupabase;

void main() {
  for (final scenario in [
    'allowed',
    'blocked',
    'foreign',
    'buyer',
    'error',
    'empty',
    'wrongId',
    'wrongName',
    'signedOut',
  ]) {
    test('DELETE definitivo: $scenario', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fake',
        httpClient: MockClient((request) async {
          requests.add(request);
          Object body;
          var status = 200;
          if (request.url.path.endsWith('/usuarios')) {
            body = {
              'id_usuario': 'owner',
              'tipos_usuario': {
                'nombre_tipo': scenario == 'buyer' ? 'buyer' : 'producer',
              },
            };
          } else if (request.method == 'DELETE') {
            if (scenario == 'blocked' || scenario == 'error') {
              status = 400;
              body = {
                'code': scenario == 'blocked' ? 'P0001' : 'XX000',
                'message': 'rejected',
              };
            } else {
              body = scenario == 'empty'
                  ? []
                  : [
                      {
                        'id_producto': scenario == 'wrongId' ? 'wrong' : 'p1',
                        'id_productor': 'owner',
                      },
                    ];
            }
          } else {
            body = {
              'id_producto': 'p1',
              'id_productor': scenario == 'foreign' ? 'other' : 'owner',
              'nombre_producto': 'Tomates',
            };
          }
          return http.Response(jsonEncode(body), status, request: request);
        }),
      );
      final supabase = DeleteTestSupabase(client)
        ..authenticated = scenario != 'signedOut';
      final service = ProductService(supabaseService: supabase);
      try {
        final operation = service.permanentlyDeleteProduct(
          'p1',
          scenario == 'wrongName' ? 'Otro' : 'Tomates',
        );
        if (scenario == 'allowed') {
          await operation;
        } else {
          await expectLater(
            operation,
            throwsA(isA<ProductPermanentDeleteException>()),
          );
        }
        final deletes = requests.where((r) => r.method == 'DELETE').toList();
        if (['foreign', 'buyer', 'wrongName', 'signedOut'].contains(scenario)) {
          expect(deletes, isEmpty);
        } else {
          expect(deletes, hasLength(1));
          expect(deletes.single.url.queryParameters['id_producto'], 'eq.p1');
          expect(
            deletes.single.url.queryParameters['id_productor'],
            'eq.owner',
          );
          expect(
            deletes.single.url.queryParameters['nombre_producto'],
            'eq.Tomates',
          );
          expect(
            deletes.single.headers['prefer'],
            contains('return=representation'),
          );
        }
        expect(requests.any((r) => r.url.path.contains('/rpc/')), false);
      } finally {
        await client.dispose();
      }
    });
  }
}
