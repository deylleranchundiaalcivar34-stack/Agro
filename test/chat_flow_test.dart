import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/chat/data/models/chat_conversation.dart';
import 'package:proyecto_agro/features/chat/data/models/chat_message.dart';
import 'package:proyecto_agro/features/chat/data/repositories/chat_repository.dart';
import 'package:proyecto_agro/features/chat/presentation/views/chat_list_view.dart';
import 'package:proyecto_agro/features/chat/presentation/views/chat_room_view.dart';

class _FakeChats extends ChatRepository {
  _FakeChats() : super(supabaseService: SupabaseService());
  final updates = StreamController<List<ChatMessage>>.broadcast();
  bool failSend = false;
  @override
  String get currentUserId => 'buyer-1';
  @override
  Future<List<ChatConversation>> listMine() async => [];
  @override
  Future<ChatConversation?> get(String chatId) async => const ChatConversation(
    id: 'chat-1',
    productId: 'product-1',
    buyerId: 'buyer-1',
    productName: 'Tomate',
    producerId: 'producer-1',
  );
  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) => updates.stream;
  @override
  Future<ChatMessage> send(String chatId, String content) async {
    if (failSend) throw const ChatFailure('No se pudo enviar');
    return ChatMessage(
      id: 'm2',
      chatId: chatId,
      senderId: 'buyer-1',
      content: content,
      sentAt: DateTime(2026, 11, 7),
    );
  }
}

void main() {
  testWidgets('empty chat list is honest and actionable', (tester) async {
    final repository = _FakeChats();
    addTearDown(repository.updates.close);
    await tester.pumpWidget(
      MaterialApp(home: ChatListView(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aun no tienes conversaciones'), findsOneWidget);
  });

  testWidgets('new messages appear and a failed send keeps the draft', (
    tester,
  ) async {
    final repository = _FakeChats()..failSend = true;
    addTearDown(repository.updates.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomView(roomId: 'chat-1', repository: repository),
      ),
    );
    await tester.pump();
    repository.updates.add([
      ChatMessage(
        id: 'm1',
        chatId: 'chat-1',
        senderId: 'producer-1',
        content: 'Buenos dias',
        sentAt: DateTime(2026, 11, 7),
      ),
    ]);
    await tester.pump();
    expect(find.text('Buenos dias'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Me interesa el tomate');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(find.text('Me interesa el tomate'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(repository.updates.hasListener, isFalse);
  });
}
