import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/chat/data/models/contact_request.dart';
import 'package:proyecto_agro/features/chat/data/repositories/contact_requests_repository.dart';
import 'package:proyecto_agro/features/chat/presentation/views/contact_requests_view.dart';

class _Requests extends ContactRequestsRepository {
  _Requests() : super(supabaseService: SupabaseService());

  @override
  String get currentUserId => 'producer-1';

  bool? accepted;
  ContactRequest request = const ContactRequest(
    id: 'request-1',
    productId: 'product-1',
    buyerId: 'buyer-1',
    productName: 'Mora',
    buyerName: 'Ana Paz',
    productUnit: 'kg',
    quantity: 5,
    initialMessage: 'Hola, me interesan 5 kg de mora.',
    status: 'pendiente',
    createdAt: null,
  );

  @override
  Future<List<ContactRequest>> listMine() async => [request];

  @override
  Future<String?> respond({
    required String requestId,
    required bool accept,
  }) async {
    accepted = accept;
    request = ContactRequest(
      id: request.id,
      productId: request.productId,
      buyerId: request.buyerId,
      productName: request.productName,
      buyerName: request.buyerName,
      productUnit: request.productUnit,
      quantity: request.quantity,
      initialMessage: request.initialMessage,
      status: accept ? 'aceptada' : 'rechazada',
      createdAt: request.createdAt,
      chatId: accept ? 'chat-1' : null,
    );
    return accept ? 'chat-1' : null;
  }
}

void main() {
  testWidgets('producer can reject a pending contact request', (tester) async {
    final repository = _Requests();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ContactRequestsView(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Paz consulta por Mora'), findsOneWidget);
    expect(find.text('Hola, me interesan 5 kg de mora.'), findsOneWidget);
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();

    expect(repository.accepted, isFalse);
    expect(find.text('Rechazada'), findsOneWidget);
  });

  testWidgets('accepting a request opens the linked conversation', (
    tester,
  ) async {
    final repository = _Requests();
    final router = GoRouter(
      initialLocation: '/requests',
      routes: [
        GoRoute(
          path: '/requests',
          builder: (_, _) =>
              Scaffold(body: ContactRequestsView(repository: repository)),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Chat ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar y abrir chat'));
    await tester.pumpAndSettle();

    expect(repository.accepted, isTrue);
    expect(find.text('Chat chat-1'), findsOneWidget);
  });
}
