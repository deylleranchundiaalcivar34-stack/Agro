import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/map/data/models/public_producer_location.dart';
import 'package:proyecto_agro/features/map/data/repositories/public_location_repository.dart';

class _TestSupabaseService extends SupabaseService {
  _TestSupabaseService(this.testClient, {this.userId});

  final SupabaseClient testClient;
  final String? userId;

  @override
  SupabaseClient get client => testClient;

  @override
  User? get currentUser => userId == null
      ? null
      : User.fromJson({
          'id': userId,
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        });
}

void main() {
  test('published map locations exclude the signed in producer', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fake-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['id_productor'], 'neq.producer-1');
        return http.Response(
          jsonEncode([
            {
              'id_productor': 'producer-2',
              'alias_publico': 'Finca Sur',
              'nombre_lugar': 'Guano',
              'latitud': -1.67,
              'longitud': -78.65,
            },
          ]),
          200,
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = PublicLocationRepository(
      supabaseService: _TestSupabaseService(client, userId: 'producer-1'),
    );

    final locations = await repository.listPublished();

    expect(locations.map((location) => location.producerId), ['producer-2']);
  });

  test('anonymous map query does not filter other producers', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fake-key',
      httpClient: MockClient((request) async {
        expect(
          request.url.queryParameters.containsKey('id_productor'),
          isFalse,
        );
        return http.Response('[]', 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = PublicLocationRepository(
      supabaseService: _TestSupabaseService(client),
    );

    expect(await repository.listPublished(), isEmpty);
  });

  test('published point is rounded to an approximate zone', () {
    final point = PublicProducerLocation.manual(
      producerId: 'producer-1',
      alias: 'Finca Norte',
      placeName: 'Guano',
      latitude: -1.67452,
      longitude: -78.65249,
    );
    expect(point.latitude, -1.67);
    expect(point.longitude, -78.65);
  });

  test('manual location requires a name and valid coordinates', () {
    expect(
      () => PublicProducerLocation.manual(
        producerId: 'producer-1',
        alias: ' ',
        placeName: 'Guano',
        latitude: -1,
        longitude: -78,
      ),
      throwsArgumentError,
    );
    expect(
      () => PublicProducerLocation.manual(
        producerId: 'producer-1',
        alias: 'Finca',
        placeName: 'Guano',
        latitude: 91,
        longitude: -78,
      ),
      throwsArgumentError,
    );
  });
}
