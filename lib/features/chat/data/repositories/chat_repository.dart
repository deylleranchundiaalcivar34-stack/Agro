import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../../../profile/data/models/public_contact_profile.dart';
import '../../../profile/data/repositories/public_contact_profile_repository.dart';
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
    : _service = supabaseService,
      _contactProfiles = PublicContactProfileRepository(
        supabaseService: supabaseService,
      ) {
    _authSubscription ??= _service.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) clearMemoryCache();
    });
  }

  final SupabaseService _service;
  final PublicContactProfileRepository _contactProfiles;

  static const _maxCachedConversations = 40;
  static const _maxCachedMessageRows = 100;
  static final LinkedHashMap<String, ChatConversation> _conversationCache =
      LinkedHashMap();
  static final LinkedHashMap<String, List<ChatMessage>> _messageCache =
      LinkedHashMap();
  static StreamSubscription<AuthState>? _authSubscription;

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

  static String _cacheKey(String userId, String chatId) => '$userId:$chatId';

  ChatConversation? cachedConversation(String chatId) =>
      _conversationCache[_cacheKey(currentUserId, chatId)];

  List<ChatMessage> cachedMessages(String chatId) =>
      _messageCache[_cacheKey(currentUserId, chatId)] ?? const [];

  static void clearMemoryCache() {
    _conversationCache.clear();
    _messageCache.clear();
  }

  void _rememberConversation(ChatConversation chat) {
    final key = _cacheKey(currentUserId, chat.id);
    _conversationCache.remove(key);
    _conversationCache[key] = chat;
    while (_conversationCache.length > _maxCachedConversations) {
      _conversationCache.remove(_conversationCache.keys.first);
    }
  }

  void _rememberMessages(String chatId, List<ChatMessage> messages) {
    final key = _cacheKey(currentUserId, chatId);
    final bounded = messages.length <= _maxCachedMessageRows
        ? messages
        : messages.sublist(messages.length - _maxCachedMessageRows);
    _messageCache.remove(key);
    _messageCache[key] = List<ChatMessage>.unmodifiable(bounded);
    while (_messageCache.length > _maxCachedConversations) {
      _messageCache.remove(_messageCache.keys.first);
    }
  }

  Future<String> openForProduct(String productId) async {
    if (productId.isEmpty) {
      throw const ChatFailure('El producto no es valido.');
    }
    final interestedUserId = currentUserId;
    try {
      // Keep the write separate from the read: PostgREST applies the SELECT
      // policy to INSERT ... RETURNING, which can reject a valid chat insert.
      await _service.client.from('chats_negociacion').insert({
        'id_producto': productId,
        'id_comprador': interestedUserId,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') {
        throw const ChatFailure('No se pudo abrir el chat de este producto.');
      }
    }

    try {
      final existing = await _service.client
          .from('chats_negociacion')
          .select('id_chat')
          .eq('id_producto', productId)
          .eq('id_comprador', interestedUserId)
          .maybeSingle();
      if (existing == null) {
        throw const ChatFailure('No se pudo recuperar el chat existente.');
      }
      return existing['id_chat'] as String;
    } on PostgrestException {
      throw const ChatFailure('No se pudo recuperar el chat existente.');
    }
  }

  static const _chatSelect =
      'id_chat,id_producto,id_comprador,fecha_inicio,'
      'producto:productos(nombre_producto,id_productor)';
  static const _chatListSelect =
      '$_chatSelect,mensajes(id_remitente,contenido,fecha_hora_envio)';

  Future<List<ChatConversation>> listMine() async {
    final rows = await _service.client
        .from('chats_negociacion')
        .select(_chatListSelect)
        .order('fecha_inicio', ascending: false)
        .order('fecha_hora_envio', referencedTable: 'mensajes')
        .limit(1, referencedTable: 'mensajes');
    final chats = (rows as List)
        .map((row) => ChatConversation.fromMap(row as Map<String, dynamic>))
        .toList();

    final userId = currentUserId;
    final participantIds = chats
        .map((chat) => chat.otherParticipantIdFor(userId))
        .where((id) => id.isNotEmpty)
        .toSet();
    final producerIds = chats
        .where((chat) => chat.interestedUserId == userId)
        .map((chat) => chat.producerId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    Map<String, PublicContactProfile> profiles = const {};
    Map<String, String> aliases = const {};
    try {
      profiles = await _contactProfiles.getMany(participantIds);
    } catch (_) {
      // Existing chats still work before the public-profile migration is live.
    }
    if (producerIds.isNotEmpty) {
      try {
        final locations = await _service.client
            .from('ubicaciones_productores_publicas')
            .select('id_productor,alias_publico')
            .inFilter('id_productor', producerIds.toList());
        aliases = {
          for (final row in locations as List)
            row['id_productor'] as String: row['alias_publico'] as String,
        };
      } catch (_) {
        // A map profile remains optional and must not block chat.
      }
    }

    final enriched = chats
        .map((chat) {
          final participantId = chat.otherParticipantIdFor(userId);
          return chat.withParticipant(
            participantId: participantId,
            profile: profiles[participantId],
            fallbackName: aliases[participantId],
          );
        })
        .toList(growable: false);
    for (final chat in enriched) {
      _rememberConversation(chat);
    }
    return enriched;
  }

  Future<ChatConversation?> get(String chatId) async {
    final row = await _service.client
        .from('chats_negociacion')
        .select(_chatSelect)
        .eq('id_chat', chatId)
        .maybeSingle();
    if (row == null) return null;
    final chat = ChatConversation.fromMap(row);
    final participantId = chat.otherParticipantIdFor(currentUserId);
    if (participantId.isEmpty) return chat;

    PublicContactProfile? profile;
    String? alias;
    try {
      profile = (await _contactProfiles.getMany([
        participantId,
      ]))[participantId];
    } catch (_) {
      // Keep the room usable while public profile setup is pending.
    }
    if (participantId == chat.producerId) {
      try {
        final location = await _service.client
            .from('ubicaciones_productores_publicas')
            .select('alias_publico')
            .eq('id_productor', participantId)
            .maybeSingle();
        alias = location?['alias_publico'] as String?;
      } catch (_) {
        // Map publication is optional and independent from messaging.
      }
    }
    final enriched = chat.withParticipant(
      participantId: participantId,
      profile: profile,
      fallbackName: alias,
    );
    _rememberConversation(enriched);
    return enriched;
  }

  Future<Map<String, PublicContactProfile>> loadParticipantProfiles(
    ChatConversation chat,
  ) async {
    final ids = <String>{
      currentUserId,
      chat.otherParticipantIdFor(currentUserId),
    }..removeWhere((id) => id.isEmpty);
    try {
      return await _contactProfiles.getMany(ids);
    } catch (_) {
      return const {};
    }
  }

  Future<List<ChatMessage>> messages(String chatId) async {
    final rows = await _service.client
        .from('mensajes')
        .select('id_mensaje,id_chat,id_remitente,contenido,fecha_hora_envio')
        .eq('id_chat', chatId)
        .order('fecha_hora_envio');
    final messages = (rows as List)
        .map((row) => ChatMessage.fromMap(row as Map<String, dynamic>))
        .toList();
    _rememberMessages(chatId, messages);
    return messages;
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) => _service.client
      .from('mensajes')
      .stream(primaryKey: ['id_mensaje'])
      .eq('id_chat', chatId)
      .order('fecha_hora_envio')
      .map((rows) {
        final messages = rows.map(ChatMessage.fromMap).toList();
        _rememberMessages(chatId, messages);
        return messages;
      });

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
      final persisted = ChatMessage.fromMap(row);
      final cached = [...cachedMessages(chatId), persisted]
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      _rememberMessages(chatId, cached);
      return persisted;
    } on PostgrestException {
      throw const ChatFailure(
        'No se pudo enviar el mensaje. Intenta de nuevo.',
      );
    }
  }
}
