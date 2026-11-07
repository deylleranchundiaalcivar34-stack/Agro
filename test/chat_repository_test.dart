import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/chat/data/models/chat_message.dart';
import 'package:proyecto_agro/features/chat/data/repositories/chat_repository.dart';

class _ChatService extends SupabaseService {
  _ChatService(this.testClient);
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
  test('two concurrent opens resolve to the same persisted chat', () async {
    var inserts = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/chats_negociacion')) {
          inserts++;
          if (inserts == 1) {
            return http.Response(
              jsonEncode({'id_chat': 'chat-1'}),
              201,
              request: request,
            );
          }
          return http.Response(
            jsonEncode({
              'code': '23505',
              'message': 'duplicate key value violates unique constraint',
            }),
            409,
            request: request,
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/chats_negociacion')) {
          return http.Response(
            jsonEncode({'id_chat': 'chat-1'}),
            200,
            request: request,
          );
        }
        return http.Response('{}', 404, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = ChatRepository(supabaseService: _ChatService(client));
    final ids = await Future.wait([
      repository.openForProduct('product-1'),
      repository.openForProduct('product-1'),
    ]);
    expect(ids, ['chat-1', 'chat-1']);
    expect(inserts, 2);
  });

  test('messages parse persisted columns and reject blank content', () {
    final message = ChatMessage.fromMap({
      'id_mensaje': 'm1',
      'id_chat': 'c1',
      'id_remitente': 'buyer-1',
      'contenido': 'Hola',
      'fecha_hora_envio': '2026-11-07T12:00:00',
    });
    expect(message.content, 'Hola');
    expect(ChatRepository.cleanMessage('  hola  '), 'hola');
    expect(() => ChatRepository.cleanMessage('  '), throwsArgumentError);
  });

  test('database denial never yields a chat ID', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied'}),
          403,
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final repository = ChatRepository(supabaseService: _ChatService(client));
    expect(repository.openForProduct('product-1'), throwsA(isA<ChatFailure>()));
  });

  test('failed send reports failure without inventing a message', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/mensajes'));
        return http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied'}),
          403,
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = ChatRepository(supabaseService: _ChatService(client));
    expect(repository.send('chat-1', 'Hola'), throwsA(isA<ChatFailure>()));
  });
}
