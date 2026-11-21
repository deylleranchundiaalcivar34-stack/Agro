import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/chat/data/repositories/contact_requests_repository.dart';

class _TestSupabaseService extends SupabaseService {
  _TestSupabaseService(this.testClient);

  final SupabaseClient testClient;

  @override
  SupabaseClient get client => testClient;

  @override
  User? get currentUser => User.fromJson({
    'id': 'buyer-1',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
  });
}

void main() {
  test('creates an inquiry without the unsupported buyer embedding', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fake-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/solicitudes_contacto'));
        expect(
          request.url.queryParameters['select'],
          isNot(contains('perfiles_contacto_publicos')),
        );
        expect(jsonDecode(request.body), {
          'id_producto': 'product-1',
          'id_comprador': 'buyer-1',
          'cantidad_solicitada': 2,
          'mensaje_inicial': 'Me interesa el producto.',
        });
        return http.Response(
          jsonEncode({
            'id_solicitud': 'request-1',
            'id_producto': 'product-1',
            'id_comprador': 'buyer-1',
            'cantidad_solicitada': 2,
            'mensaje_inicial': 'Me interesa el producto.',
            'estado_solicitud': 'pendiente',
            'id_chat': null,
            'created_at': '2026-11-18T04:00:00Z',
            'producto': {'nombre_producto': 'Papas', 'unidad_medida': 'kg'},
          }),
          201,
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = ContactRequestsRepository(
      supabaseService: _TestSupabaseService(client),
    );

    final request = await repository.create(
      productId: 'product-1',
      quantity: 2,
      initialMessage: 'Me interesa el producto.',
    );

    expect(request.id, 'request-1');
    expect(request.productName, 'Papas');
  });

  test(
    'loads buyer names through the public profile table separately',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fake-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/solicitudes_contacto')) {
            expect(request.method, 'GET');
            expect(
              request.url.queryParameters['select'],
              isNot(contains('perfiles_contacto_publicos')),
            );
            return http.Response(
              jsonEncode([
                {
                  'id_solicitud': 'request-1',
                  'id_producto': 'product-1',
                  'id_comprador': 'buyer-1',
                  'cantidad_solicitada': 2,
                  'mensaje_inicial': 'Me interesa el producto.',
                  'estado_solicitud': 'pendiente',
                  'id_chat': null,
                  'created_at': '2026-11-18T04:00:00Z',
                  'producto': {
                    'nombre_producto': 'Papas',
                    'unidad_medida': 'kg',
                  },
                },
              ]),
              200,
              request: request,
            );
          }
          if (request.url.path.endsWith('/perfiles_contacto_publicos')) {
            expect(request.method, 'GET');
            expect(
              request.url.queryParameters['id_usuario'],
              contains('buyer-1'),
            );
            return http.Response(
              jsonEncode([
                {'id_usuario': 'buyer-1', 'nombre_publico': 'Ana Paz'},
              ]),
              200,
              request: request,
            );
          }
          return http.Response('{}', 404, request: request);
        }),
      );
      addTearDown(client.dispose);
      final repository = ContactRequestsRepository(
        supabaseService: _TestSupabaseService(client),
      );

      final result = await repository.listMine();

      expect(result, hasLength(1));
      expect(result.single.buyerName, 'Ana Paz');
      expect(result.single.productName, 'Papas');
      expect(requests, hasLength(2));
    },
  );
}
