import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class ChatFailure implements Exception {
  const ChatFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ChatRepository {
  ChatRepository({required SupabaseService supabaseService})
    : _service = supabaseService;
  final SupabaseService _service;

  String get currentUserId =>
      _service.currentUser?.id ??
      (throw const ChatFailure('Inicia sesion para usar el chat.'));

  static String cleanMessage(String content) {
    final cleaned = content.trim();
    if (cleaned.isEmpty || cleaned.length > 2000) {
      throw ArgumentError('Escribe un mensaje de hasta 2000 caracteres.');
    }
    return cleaned;
  }

  Future<String> openForProduct(String productId) async {
    if (productId.isEmpty) {
      throw const ChatFailure('El producto no es valido.');
    }
    final buyerId = currentUserId;
    try {
      final row = await _service.client
          .from('chats_negociacion')
          .insert({'id_producto': productId, 'id_comprador': buyerId})
          .select('id_chat')
          .single();
      return row['id_chat'] as String;
    } on PostgrestException catch (error) {
      if (error.code != '23505') {
        throw const ChatFailure('No se pudo abrir el chat de este producto.');
      }
      final existing = await _service.client
          .from('chats_negociacion')
          .select('id_chat')
          .eq('id_producto', productId)
          .eq('id_comprador', buyerId)
          .maybeSingle();
      if (existing == null) {
        throw const ChatFailure('No se pudo recuperar el chat existente.');
      }
      return existing['id_chat'] as String;
    }
  }

  static const _chatSelect =
      'id_chat,id_producto,id_comprador,fecha_inicio,'
      'producto:productos(nombre_producto,id_productor)';

  Future<List<ChatConversation>> listMine() async {
    final rows = await _service.client
        .from('chats_negociacion')
        .select(_chatSelect)
        .order('fecha_inicio', ascending: false);
    return (rows as List)
        .map((row) => ChatConversation.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<ChatConversation?> get(String chatId) async {
    final row = await _service.client
        .from('chats_negociacion')
        .select(_chatSelect)
        .eq('id_chat', chatId)
        .maybeSingle();
    return row == null ? null : ChatConversation.fromMap(row);
  }

  Future<List<ChatMessage>> messages(String chatId) async {
    final rows = await _service.client
        .from('mensajes')
        .select('id_mensaje,id_chat,id_remitente,contenido,fecha_hora_envio')
        .eq('id_chat', chatId)
        .order('fecha_hora_envio');
    return (rows as List)
        .map((row) => ChatMessage.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) => _service.client
      .from('mensajes')
      .stream(primaryKey: ['id_mensaje'])
      .eq('id_chat', chatId)
      .order('fecha_hora_envio')
      .map((rows) => rows.map(ChatMessage.fromMap).toList());

  Future<ChatMessage> send(String chatId, String content) async {
    final cleaned = cleanMessage(content);
    try {
      final row = await _service.client
          .from('mensajes')
          .insert({
            'id_chat': chatId,
            'id_remitente': currentUserId,
            'contenido': cleaned,
          })
          .select('id_mensaje,id_chat,id_remitente,contenido,fecha_hora_envio')
          .single();
      return ChatMessage.fromMap(row);
    } on PostgrestException {
      throw const ChatFailure(
        'No se pudo enviar el mensaje. Intenta de nuevo.',
      );
    }
  }
}
