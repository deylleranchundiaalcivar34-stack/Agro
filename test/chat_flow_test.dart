import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/features/profile/data/models/public_contact_profile.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/chat/data/models/chat_conversation.dart';
import 'package:proyecto_agro/features/chat/data/models/chat_message.dart';
import 'package:proyecto_agro/features/chat/data/repositories/chat_repository.dart';
import 'package:proyecto_agro/features/chat/presentation/views/chat_list_view.dart';
import 'package:proyecto_agro/features/chat/presentation/views/chat_room_view.dart';

class _FakeChats extends ChatRepository {
  _FakeChats() : super(supabaseService: _FakeSupabaseService());
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
  Future<Map<String, PublicContactProfile>> loadParticipantProfiles(
    ChatConversation chat,
  ) async => const {};
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

class _FakeSupabaseService extends SupabaseService {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();
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
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeChats()..failSend = true;
    addTearDown(repository.updates.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomView(roomId: 'chat-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.updates.hasListener, isTrue);
    repository.updates.add([
      ChatMessage(
        id: 'm1',
        chatId: 'chat-1',
        senderId: 'producer-1',
        content: 'Hola',
        sentAt: DateTime(2026, 11, 7),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Hola'), findsOneWidget);
    final shortMessageBubble = find
        .ancestor(
          of: find.text('Hola'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        )
        .first;
    expect(tester.getSize(shortMessageBubble).width, lessThan(220));

    const longContent =
        'Este mensaje es bastante largo y debe crecer de forma adaptable '
        'hasta ocupar el ancho máximo permitido en la conversación.';
    repository.updates.add([
      ChatMessage(
        id: 'm2',
        chatId: 'chat-1',
        senderId: 'buyer-1',
        content: longContent,
        sentAt: DateTime(2026, 11, 7, 0, 1),
      ),
      ChatMessage(
        id: 'other-chat-message',
        chatId: 'chat-2',
        senderId: 'producer-1',
        content: 'No debe mezclarse con esta conversación',
        sentAt: DateTime(2026, 11, 8),
      ),
      ChatMessage(
        id: 'm1',
        chatId: 'chat-1',
        senderId: 'producer-1',
        content: 'Hola',
        sentAt: DateTime(2026, 11, 7),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(longContent), findsOneWidget);
    expect(find.text('No debe mezclarse con esta conversación'), findsNothing);
    expect(
      tester.getTopLeft(find.text(longContent)).dy,
      greaterThan(tester.getTopLeft(find.text('Hola')).dy),
      reason: 'El mensaje más reciente debe quedar debajo del anterior.',
    );
    final longMessageBubble = find
        .ancestor(
          of: find.text(longContent),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        )
        .first;
    final longBubbleWidth = tester.getSize(longMessageBubble).width;
    expect(
      tester.getRect(longMessageBubble).right,
      greaterThan(tester.getRect(shortMessageBubble).right),
      reason: 'Los mensajes del usuario actual deben alinearse a la derecha.',
    );
    expect(longBubbleWidth, greaterThan(180));
    expect(longBubbleWidth, lessThanOrEqualTo(274));

    await tester.enterText(find.byType(TextField), 'Me interesa el tomate');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(find.text('Me interesa el tomate'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(repository.updates.hasListener, isFalse);
  });
}
